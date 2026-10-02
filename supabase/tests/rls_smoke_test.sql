-- VetApp: RLS smoke test (manual, ejecutar en el SQL Editor de Supabase después de aplicar schema.sql).
--
-- Cómo usar:
--   1. Aplica supabase/schema.sql completo en el proyecto (SQL Editor -> Run).
--   2. Pega el CONTENIDO COMPLETO de este archivo en una nueva query y ejecútalo.
--   3. El script SIEMPRE termina lanzando un ERROR cuyo mensaje comienza con
--      "RLS SMOKE: PASS" o "RLS SMOKE: FAIL" -- es intencional: esa excepción
--      revierte (rollback) todas las filas creadas por el script (usuarios,
--      clínicas, perfiles, clientes, mascotas de prueba), así que no queda
--      ningún residuo en la base real sin importar el resultado.
--   4. Si el setup falla con "permission denied for table users", reporta el
--      mensaje completo: el rol usado por el SQL Editor no tiene permiso para
--      insertar directamente en auth.users. Alternativa (no implementada aquí):
--      registrar 3 cuentas reales desde la app (2 VETERINARIO en clínicas
--      distintas, 1 CLIENTE) y adaptar el bloque de "Setup" para buscar sus
--      auth.users.id por email en lugar de insertarlos.
--
-- Cobertura: clinicas, perfiles, clientes, mascotas -- positivo y negativo,
-- incluyendo el intento de auto-escalación de privilegios en perfiles (D-03/D-04).
-- Fase 2: mascota_pesos (historial de peso append-only), las 3 RPCs atómicas
-- (registrar_cliente_con_mascota, registrar_mascota, generar_codigo_vinculacion),
-- las columnas de código de vinculación en clientes, y storage.objects del bucket
-- privado mascota-fotos -- todo scoped por clínica.
-- Fase 3: consultas (historia clínica append-only) + registrar_consulta, scoped
-- por clínica, incluyendo la atomicidad consulta+peso (D-02) y HIST-04
-- (update/delete siempre 0 filas, incluso para el propio veterinario autor).
-- Fase 4: citas, cita_mascotas, crear_cita/actualizar_cita, registrar_consulta(p_cita_id), cascada al borrar cliente (D-20).
-- Fixes 04-REVIEW: HI-01 (writes directos: dueño en cita_mascotas, columnas inmutables
-- y máquina de estados de citas incl. Reabrir/Deshacer, consultas.cita_id de la misma
-- clínica y cita, bloque N + J6), ME-04 (consultas sobre citas canceladas, N9/N18/N19), HI-02 (borrar vet con citas -> restrict, bloque O).
-- Fase 4.1 (bloque P, P1..P30): equipo de la clínica -- backfill admin, sin auto-escalación (privilegios por
-- columna), invitaciones (uso único, vencida, revocada, inexistente, metadata falsificada), RPC solo-admin y
-- aisladas por clínica, último admin, auto-retiro (D-14), reasignación de citas (D-15), acceso cortado al
-- retirar (T6), autoría visible (D-13), citas por veterinario (D-07) y consultas FK restrict (D-06). Total esperado: 145.

do $$
declare
  vet_a_id uuid := gen_random_uuid();
  vet_b_id uuid := gen_random_uuid();
  cliente_c_id uuid := gen_random_uuid();
  clinica_a_id uuid;
  clinica_b_id uuid;
  cliente_a_id uuid;
  cliente_b_id uuid;
  mascota_a_id uuid;
  mascota_b_id uuid;
  failures text[] := '{}';
  checks int := 0;
  n int;
  n_pesos int;
  v_codigo text;
  v_codigo2 text;
  v_expira timestamptz;
  v_reemplazo boolean;
  v_uuid uuid;
  v_cli uuid;
  v_masc uuid;
  v_consulta uuid;
  v_texto text;
  cita_a_id uuid;
  cita_a2_id uuid;
  cliente_a2_id uuid;
  mascota_a2_id uuid;
  mascota_a3_id uuid;
  cita_b_id uuid;
  cita_vieja_id uuid;
  cita_cancelada_id uuid;
  n_total int;
  -- Fase 4.1 (bloque P)
  vet_a2_id uuid := gen_random_uuid();
  vet_a3_id uuid := gen_random_uuid();
  vet_a4_id uuid := gen_random_uuid();
  vet_c_id uuid := gen_random_uuid();
  cli_code_id uuid := gen_random_uuid();
  v_cod_p text;
  v_cod_b text;
  v_inv_id uuid;
  v_clinica_nueva uuid;
  v_clinica_c uuid;
  v_count int;
  v_cita1 uuid;
  v_cita2 uuid;
  v_cita_done uuid;
  v_cita_pasada uuid;
  v_ok boolean;
begin
  -------------------------------------------------------------------------
  -- Setup (como postgres, sin RLS): 3 cuentas via insert directo en
  -- auth.users para disparar on_auth_user_created / crear_perfil_nuevo_usuario.
  -------------------------------------------------------------------------
  insert into auth.users (
    id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at
  ) values
    (vet_a_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'smoke-vet-a@vetapp.invalid',
     jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Vet A', 'clinica_nombre', 'Smoke Clinica A'),
     now(), now()),
    (vet_b_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'smoke-vet-b@vetapp.invalid',
     jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Vet B', 'clinica_nombre', 'Smoke Clinica B'),
     now(), now()),
    (cliente_c_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'smoke-cliente@vetapp.invalid',
     jsonb_build_object('rol', 'CLIENTE', 'nombre', 'Smoke Cliente'),
     now(), now());

  select clinica_id into clinica_a_id from public.perfiles where id = vet_a_id;
  select clinica_id into clinica_b_id from public.perfiles where id = vet_b_id;

  -- Verificación del trigger de signup (Pitfall 5) -- no cuenta en "checks".
  if not exists (select 1 from public.perfiles where id = vet_a_id and rol = 'VETERINARIO' and clinica_id is not null) then
    failures := failures || 'SETUP1 vet A no quedó con rol VETERINARIO y clinica_id asignada';
  end if;
  if not exists (select 1 from public.perfiles where id = vet_b_id and rol = 'VETERINARIO' and clinica_id is not null) then
    failures := failures || 'SETUP2 vet B no quedó con rol VETERINARIO y clinica_id asignada';
  end if;
  if not exists (select 1 from public.perfiles where id = cliente_c_id and rol = 'CLIENTE' and clinica_id is null) then
    failures := failures || 'SETUP3 cliente no quedó con rol CLIENTE y clinica_id nula';
  end if;
  if clinica_a_id is null or clinica_b_id is null then
    failures := failures || 'SETUP4 no se pudo leer clinica_id de vet A/B, abortando checks dependientes';
  end if;

  -------------------------------------------------------------------------
  -- Seed (como postgres, bypassa RLS): un cliente y una mascota por clínica.
  -------------------------------------------------------------------------
  insert into public.clientes (clinica_id, nombre, telefono)
    values (clinica_a_id, 'Cliente Seed A', '3000000001') returning id into cliente_a_id;
  insert into public.clientes (clinica_id, nombre, telefono)
    values (clinica_b_id, 'Cliente Seed B', '3000000002') returning id into cliente_b_id;

  insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
    values (cliente_a_id, clinica_a_id, 'Mascota Seed A', 'perro') returning id into mascota_a_id;
  insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
    values (cliente_b_id, clinica_b_id, 'Mascota Seed B', 'gato') returning id into mascota_b_id;

  insert into public.mascota_pesos (mascota_id, peso_kg) values (mascota_a_id, 10.00);
  insert into public.mascota_pesos (mascota_id, peso_kg) values (mascota_b_id, 20.00);

  -- Fase 3: una consulta seed por clínica.
  insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento)
    values (mascota_a_id, vet_a_id, 'Smoke dx A', 'Smoke tx A');
  insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento)
    values (mascota_b_id, vet_b_id, 'Smoke dx B', 'Smoke tx B');

  insert into storage.objects (bucket_id, name)
    values ('mascota-fotos', clinica_a_id::text || '/' || mascota_a_id::text || '/smoke-a.jpg');
  insert into storage.objects (bucket_id, name)
    values ('mascota-fotos', clinica_b_id::text || '/' || mascota_b_id::text || '/smoke-b.jpg');

  -------------------------------------------------------------------------
  -- Impersonar vet A (positivo + negativo).
  -------------------------------------------------------------------------
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- A1: clinicas visible = 1 y es la propia.
  checks := checks + 1;
  select count(*) into n from public.clinicas;
  if n <> 1 then
    failures := failures || format('A1 vet A esperaba ver 1 clinica, vio %s', n);
  elsif not exists (select 1 from public.clinicas where id = clinica_a_id) then
    failures := failures || 'A1 vet A ve una clinica pero no es la propia';
  end if;

  -- A2: clinicas de B -> 0.
  checks := checks + 1;
  select count(*) into n from public.clinicas where id = clinica_b_id;
  if n <> 0 then failures := failures || format('A2 vet A vio %s filas de clinica B', n); end if;

  -- A3: perfiles propio visible = 1.
  checks := checks + 1;
  select count(*) into n from public.perfiles where id = vet_a_id;
  if n <> 1 then failures := failures || format('A3 vet A no ve su propio perfil (%s filas)', n); end if;

  -- A4: perfiles de vet B -> 0.
  checks := checks + 1;
  select count(*) into n from public.perfiles where id = vet_b_id;
  if n <> 0 then failures := failures || format('A4 vet A ve perfil de vet B (%s filas)', n); end if;

  -- A5: clientes de clinica A visible = 1.
  checks := checks + 1;
  select count(*) into n from public.clientes where clinica_id = clinica_a_id;
  if n <> 1 then failures := failures || format('A5 vet A esperaba 1 cliente de su clinica, vio %s', n); end if;

  -- A6: clientes de clinica B -> 0.
  checks := checks + 1;
  select count(*) into n from public.clientes where clinica_id = clinica_b_id;
  if n <> 0 then failures := failures || format('A6 vet A ve clientes de clinica B (%s filas)', n); end if;

  -- A7: insert clientes para clinica A -> éxito.
  checks := checks + 1;
  begin
    insert into public.clientes (clinica_id, nombre) values (clinica_a_id, 'A7 cliente nuevo');
  exception when others then
    failures := failures || ('A7 insert cliente propia clinica debía funcionar, error: ' || sqlerrm);
  end;

  -- A8: insert clientes para clinica B -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.clientes (clinica_id, nombre) values (clinica_b_id, 'A8 intento cruzado');
    failures := failures || 'A8 insert cliente en clinica B debía fallar pero tuvo éxito';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('A8 error inesperado: ' || sqlerrm);
  end;

  -- A9: update clientes de B -> 0 filas (silencioso, RLS-filtrado).
  checks := checks + 1;
  update public.clientes set nombre = 'A9 hackeado' where id = cliente_b_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('A9 update sobre cliente B afectó %s filas, esperaba 0', n); end if;

  -- A10: delete clientes de B -> 0 filas.
  checks := checks + 1;
  delete from public.clientes where id = cliente_b_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('A10 delete sobre cliente B afectó %s filas, esperaba 0', n); end if;

  -- A11: mascotas de clinica A visible = 1.
  checks := checks + 1;
  select count(*) into n from public.mascotas where clinica_id = clinica_a_id;
  if n <> 1 then failures := failures || format('A11 vet A esperaba 1 mascota de su clinica, vio %s', n); end if;

  -- A12: mascotas de clinica B -> 0.
  checks := checks + 1;
  select count(*) into n from public.mascotas where clinica_id = clinica_b_id;
  if n <> 0 then failures := failures || format('A12 vet A ve mascotas de clinica B (%s filas)', n); end if;

  -- A13: insert mascota (dueno cA, clinica A) -> éxito.
  checks := checks + 1;
  begin
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'A13 mascota nueva', 'perro');
  exception when others then
    failures := failures || ('A13 insert mascota propia clinica debía funcionar, error: ' || sqlerrm);
  end;

  -- A14: insert mascota (dueno cB, clinica B) -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_b_id, clinica_b_id, 'A14 mascota cruzada', 'gato');
    failures := failures || 'A14 insert mascota en clinica B debía fallar pero tuvo éxito';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('A14 error inesperado: ' || sqlerrm);
  end;

  -- A15: insert mascota (dueno cB, clinica A) -> foreign_key_violation (FK compuesta).
  checks := checks + 1;
  begin
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_b_id, clinica_a_id, 'A15 mascota FK cruzada', 'perro');
    failures := failures || 'A15 insert mascota con dueno de otra clinica debía fallar pero tuvo éxito';
  exception
    when foreign_key_violation then null;
    when others then failures := failures || ('A15 error inesperado: ' || sqlerrm);
  end;

  -- A16: update propio perfiles.telefono -> 1 fila.
  checks := checks + 1;
  update public.perfiles set telefono = '3009999999' where id = vet_a_id;
  get diagnostics n = row_count;
  if n <> 1 then failures := failures || format('A16 update propio telefono afectó %s filas, esperaba 1', n); end if;

  -- A17: update propio perfiles.clinica_id a clinica B -> insufficient_privilege.
  checks := checks + 1;
  begin
    update public.perfiles set clinica_id = clinica_b_id where id = vet_a_id;
    failures := failures || 'A17 vet A pudo cambiar su clinica_id (auto-reasignación no bloqueada)';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('A17 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Impersonar vet B (negativo cruzado contra datos de A).
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- B1: clientes de clinica A -> 0.
  checks := checks + 1;
  select count(*) into n from public.clientes where clinica_id = clinica_a_id;
  if n <> 0 then failures := failures || format('B1 vet B ve clientes de clinica A (%s filas)', n); end if;

  -- B2: mascotas de clinica A -> 0.
  checks := checks + 1;
  select count(*) into n from public.mascotas where clinica_id = clinica_a_id;
  if n <> 0 then failures := failures || format('B2 vet B ve mascotas de clinica A (%s filas)', n); end if;

  -------------------------------------------------------------------------
  -- Impersonar cliente (sin clinica; intento de auto-escalación).
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', cliente_c_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- C1: clinicas -> 0.
  checks := checks + 1;
  select count(*) into n from public.clinicas;
  if n <> 0 then failures := failures || format('C1 cliente ve %s clinicas, esperaba 0', n); end if;

  -- C2: clientes -> 0.
  checks := checks + 1;
  select count(*) into n from public.clientes;
  if n <> 0 then failures := failures || format('C2 cliente ve %s filas de clientes, esperaba 0', n); end if;

  -- C3: mascotas -> 0.
  checks := checks + 1;
  select count(*) into n from public.mascotas;
  if n <> 0 then failures := failures || format('C3 cliente ve %s filas de mascotas, esperaba 0', n); end if;

  -- C4: perfiles visible = 1 (solo el propio).
  checks := checks + 1;
  select count(*) into n from public.perfiles;
  if n <> 1 then failures := failures || format('C4 cliente esperaba ver solo su perfil (1 fila), vio %s', n); end if;

  -- C5: update propio rol + clinica_id -> insufficient_privilege (el ataque real).
  checks := checks + 1;
  begin
    update public.perfiles set rol = 'VETERINARIO', clinica_id = clinica_a_id where id = cliente_c_id;
    failures := failures || 'C5 cliente pudo auto-escalar a VETERINARIO con clinica_id asignada';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('C5 error inesperado: ' || sqlerrm);
  end;

  -- C6: update propio clinica_id (rol sin cambios) -> insufficient_privilege.
  checks := checks + 1;
  begin
    update public.perfiles set clinica_id = clinica_a_id where id = cliente_c_id;
    failures := failures || 'C6 cliente pudo cambiar su clinica_id sin cambiar de rol';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('C6 error inesperado: ' || sqlerrm);
  end;

  -- C7: update propio nombre -> 1 fila (campos no sensibles siguen editables).
  checks := checks + 1;
  update public.perfiles set nombre = 'Smoke Cliente Editado' where id = cliente_c_id;
  get diagnostics n = row_count;
  if n <> 1 then failures := failures || format('C7 update propio nombre afectó %s filas, esperaba 1', n); end if;

  -- C8: insert clientes para clinica A -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.clientes (clinica_id, nombre) values (clinica_a_id, 'C8 intento cliente');
    failures := failures || 'C8 cliente pudo insertar en la tabla clientes';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('C8 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Fase 2: volver a impersonar vet A -- mascota_pesos, RPCs atómicas,
  -- código de vinculación y storage.objects (positivo + negativo).
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- D1: insert mascota_pesos (mascota A) -> éxito.
  checks := checks + 1;
  begin
    insert into public.mascota_pesos (mascota_id, peso_kg) values (mascota_a_id, 5.5);
  exception when others then
    failures := failures || ('D1 insert peso de mascota propia debía funcionar, error: ' || sqlerrm);
  end;

  -- D2: insert mascota_pesos (mascota B) -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.mascota_pesos (mascota_id, peso_kg) values (mascota_b_id, 7.0);
    failures := failures || 'D2 vet A insertó peso de mascota B';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('D2 error inesperado: ' || sqlerrm);
  end;

  -- D3: select mascota_pesos de mascota B -> 0.
  checks := checks + 1;
  select count(*) into n from public.mascota_pesos where mascota_id = mascota_b_id;
  if n <> 0 then failures := failures || format('D3 vet A ve %s pesos de mascota B, esperaba 0', n); end if;

  -- D4: update mascota_pesos de mascota A -> 0 filas (append-only).
  checks := checks + 1;
  update public.mascota_pesos set peso_kg = 99 where mascota_id = mascota_a_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('D4 update mascota_pesos afectó %s filas, esperaba 0 (append-only)', n); end if;

  -- D5: delete mascota_pesos de mascota A -> 0 filas (append-only).
  checks := checks + 1;
  delete from public.mascota_pesos where mascota_id = mascota_a_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('D5 delete mascota_pesos afectó %s filas, esperaba 0 (append-only)', n); end if;

  -- D6: insert mascota_pesos peso 0 -> check_violation.
  checks := checks + 1;
  begin
    insert into public.mascota_pesos (mascota_id, peso_kg) values (mascota_a_id, 0);
    failures := failures || 'D6 insert peso 0 debía fallar pero tuvo éxito';
  exception
    when check_violation then null;
    when others then failures := failures || ('D6 error inesperado: ' || sqlerrm);
  end;

  -- D7: registrar_cliente_con_mascota crea cliente+mascota+peso atómicamente en clinica A.
  checks := checks + 1;
  begin
    select cliente_id, mascota_id into v_cli, v_masc
      from public.registrar_cliente_con_mascota('Smoke RPC Cliente', '3000000000', 'Smoke RPC Pet', 'perro', '', null, 4.5);
    if not exists (select 1 from public.clientes where id = v_cli and clinica_id = clinica_a_id) then
      failures := failures || 'D7 cliente creado por RPC no quedó en clinica A';
    end if;
    if not exists (select 1 from public.mascotas where id = v_masc and clinica_id = clinica_a_id) then
      failures := failures || 'D7 mascota creada por RPC no quedó en clinica A';
    end if;
    select count(*) into n from public.mascota_pesos where mascota_id = v_masc;
    if n <> 1 then failures := failures || format('D7 esperaba 1 fila de peso para la mascota nueva, vio %s', n); end if;
  exception when others then
    failures := failures || ('D7 registrar_cliente_con_mascota propia clinica debía funcionar, error: ' || sqlerrm);
  end;

  -- D8: registrar_mascota con dueño de otra clinica -> foreign_key_violation.
  checks := checks + 1;
  begin
    perform public.registrar_mascota(cliente_b_id, 'Smoke Intruso', 'gato');
    failures := failures || 'D8 registrar_mascota con dueño de otra clinica debía fallar pero tuvo éxito';
  exception
    when foreign_key_violation then null;
    when others then failures := failures || ('D8 error inesperado: ' || sqlerrm);
  end;

  -- D9: registrar_mascota con dueño propio y peso inicial -> éxito, 1 fila de peso.
  checks := checks + 1;
  begin
    select public.registrar_mascota(cliente_a_id, 'Smoke Luna', 'gato', '', null, 3.2) into v_uuid;
    select count(*) into n from public.mascota_pesos where mascota_id = v_uuid;
    if n <> 1 then failures := failures || format('D9 esperaba 1 fila de peso para Smoke Luna, vio %s', n); end if;
  exception when others then
    failures := failures || ('D9 registrar_mascota propia clinica debía funcionar, error: ' || sqlerrm);
  end;

  -- D10: generar_codigo_vinculacion primera vez -- formato de 6 dígitos, no expirado, reemplazo_expirado false.
  checks := checks + 1;
  begin
    select codigo, expira_en, reemplazo_expirado into v_codigo, v_expira, v_reemplazo
      from public.generar_codigo_vinculacion(cliente_a_id);
    if v_codigo !~ '^[0-9]{6}$' then
      failures := failures || format('D10 codigo generado no tiene formato de 6 dígitos: %s', v_codigo);
    end if;
    if v_reemplazo is distinct from false then
      failures := failures || 'D10 reemplazo_expirado debía ser false en la primera generación';
    end if;
    if v_expira <= now() then
      failures := failures || 'D10 expira_en no quedó en el futuro';
    end if;
    if not exists (select 1 from public.clientes where id = cliente_a_id and codigo_vinculacion = v_codigo) then
      failures := failures || 'D10 clientes.codigo_vinculacion no quedó igual al codigo devuelto';
    end if;
  exception when others then
    failures := failures || ('D10 generar_codigo_vinculacion propio cliente debía funcionar, error: ' || sqlerrm);
  end;

  -- D11: pedirlo otra vez antes de expirar -> mismo codigo.
  checks := checks + 1;
  begin
    select codigo into v_codigo2 from public.generar_codigo_vinculacion(cliente_a_id);
    if v_codigo2 is distinct from v_codigo then
      failures := failures || format('D11 esperaba el mismo codigo vigente, obtuvo %s vs %s', v_codigo2, v_codigo);
    end if;
  exception when others then
    failures := failures || ('D11 error inesperado: ' || sqlerrm);
  end;

  -- D12: forzar expiración y regenerar -> reemplazo_expirado true, nueva expiración futura.
  checks := checks + 1;
  update public.clientes set codigo_expira_en = now() - interval '1 minute' where id = cliente_a_id;
  begin
    select codigo, expira_en, reemplazo_expirado into v_codigo2, v_expira, v_reemplazo
      from public.generar_codigo_vinculacion(cliente_a_id);
    if v_reemplazo is distinct from true then
      failures := failures || 'D12 reemplazo_expirado debía ser true tras expirar el codigo anterior';
    end if;
    if v_expira <= now() then
      failures := failures || 'D12 expira_en no quedó en el futuro tras regenerar';
    end if;
  exception when others then
    failures := failures || ('D12 error inesperado: ' || sqlerrm);
  end;

  -- D13: generar_codigo_vinculacion sobre cliente de otra clinica -> no_data_found.
  checks := checks + 1;
  begin
    perform public.generar_codigo_vinculacion(cliente_b_id);
    failures := failures || 'D13 generar_codigo_vinculacion sobre cliente de otra clinica debía fallar pero tuvo éxito';
  exception
    when no_data_found then null;
    when others then failures := failures || ('D13 error inesperado: ' || sqlerrm);
  end;

  -- D14: codigo_vinculacion con formato inválido -> check_violation.
  checks := checks + 1;
  begin
    update public.clientes set codigo_vinculacion = 'abc123' where id = cliente_a_id;
    failures := failures || 'D14 codigo_vinculacion con formato inválido debía fallar pero tuvo éxito';
  exception
    when check_violation then null;
    when others then failures := failures || ('D14 error inesperado: ' || sqlerrm);
  end;

  -- D15: update codigo_vinculacion de cliente B -> 0 filas (RLS-filtrado).
  checks := checks + 1;
  update public.clientes set codigo_vinculacion = '000001' where id = cliente_b_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('D15 update codigo_vinculacion sobre cliente B afectó %s filas, esperaba 0', n); end if;

  -- D16: insert storage.objects en la carpeta de la propia clinica -> éxito.
  checks := checks + 1;
  begin
    insert into storage.objects (bucket_id, name)
      values ('mascota-fotos', clinica_a_id::text || '/' || mascota_a_id::text || '/smoke-a2.jpg');
  exception when others then
    failures := failures || ('D16 insert storage.objects en carpeta propia debía funcionar, error: ' || sqlerrm);
  end;

  -- D17: insert storage.objects en carpeta de otra clinica -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into storage.objects (bucket_id, name)
      values ('mascota-fotos', clinica_b_id::text || '/' || mascota_b_id::text || '/smoke-intruso.jpg');
    failures := failures || 'D17 insert storage.objects en carpeta de otra clinica debía fallar pero tuvo éxito';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('D17 error inesperado: ' || sqlerrm);
  end;

  -- D18: select storage.objects bajo el prefijo de clinica B -> 0.
  checks := checks + 1;
  begin
    select count(*) into n from storage.objects
      where bucket_id = 'mascota-fotos' and name like clinica_b_id::text || '/%';
    if n <> 0 then failures := failures || format('D18 vet A ve %s objetos de storage de clinica B, esperaba 0', n); end if;
  exception when others then
    failures := failures || ('D18 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Fase 2: impersonar vet B -- negativo cruzado contra datos de A.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- E1: select mascota_pesos de mascota A -> 0.
  checks := checks + 1;
  select count(*) into n from public.mascota_pesos where mascota_id = mascota_a_id;
  if n <> 0 then failures := failures || format('E1 vet B ve %s pesos de mascota A, esperaba 0', n); end if;

  -- E2: select clientes con codigo_vinculacion de cliente A -> 0.
  checks := checks + 1;
  select count(*) into n from public.clientes where id = cliente_a_id and codigo_vinculacion is not null;
  if n <> 0 then failures := failures || format('E2 vet B ve codigo_vinculacion de cliente A (%s filas), esperaba 0', n); end if;

  -- E3: select storage.objects bajo el prefijo de clinica A -> 0.
  checks := checks + 1;
  begin
    select count(*) into n from storage.objects
      where bucket_id = 'mascota-fotos' and name like clinica_a_id::text || '/%';
    if n <> 0 then failures := failures || format('E3 vet B ve %s objetos de storage de clinica A, esperaba 0', n); end if;
  exception when others then
    failures := failures || ('E3 error inesperado: ' || sqlerrm);
  end;

  -- E4: generar_codigo_vinculacion sobre cliente de otra clinica -> no_data_found.
  checks := checks + 1;
  begin
    perform public.generar_codigo_vinculacion(cliente_a_id);
    failures := failures || 'E4 vet B pudo generar codigo para cliente de otra clinica';
  exception
    when no_data_found then null;
    when others then failures := failures || ('E4 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Fase 2: impersonar cliente (sin clinica) -- sin acceso alguno.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', cliente_c_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- F1: select mascota_pesos -> 0.
  checks := checks + 1;
  select count(*) into n from public.mascota_pesos;
  if n <> 0 then failures := failures || format('F1 cliente ve %s filas de mascota_pesos, esperaba 0', n); end if;

  -- F2: registrar_cliente_con_mascota -> insufficient_privilege.
  checks := checks + 1;
  begin
    perform public.registrar_cliente_con_mascota('F2 Cliente', '3000000003', 'F2 Mascota', 'perro');
    failures := failures || 'F2 cliente pudo ejecutar registrar_cliente_con_mascota';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('F2 error inesperado: ' || sqlerrm);
  end;

  -- F3: select storage.objects del bucket mascota-fotos -> 0.
  checks := checks + 1;
  begin
    select count(*) into n from storage.objects where bucket_id = 'mascota-fotos';
    if n <> 0 then failures := failures || format('F3 cliente ve %s objetos en mascota-fotos, esperaba 0', n); end if;
  exception when others then
    failures := failures || ('F3 error inesperado: ' || sqlerrm);
  end;

  -- F4: insert storage.objects en carpeta de clinica A -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into storage.objects (bucket_id, name)
      values ('mascota-fotos', clinica_a_id::text || '/' || mascota_a_id::text || '/smoke-cliente.jpg');
    failures := failures || 'F4 cliente pudo insertar objeto en storage de clinica A';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('F4 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Fase 3: impersonar vet A -- registrar_consulta (positivo + negativo) y
  -- HIST-04 (update/delete siempre 0 filas, incluso para el autor).
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- G1: registrar_consulta sin peso -> éxito; anamnesis/evolucion/peso_kg quedan null; sin nueva fila de peso.
  checks := checks + 1;
  begin
    select count(*) into n_pesos from public.mascota_pesos where mascota_id = mascota_a_id;
    v_consulta := public.registrar_consulta(mascota_a_id, 'Smoke Otitis', 'Smoke Gotas');
    if not exists (
      select 1 from public.consultas
      where id = v_consulta and veterinario_id = vet_a_id
        and anamnesis is null and evolucion is null and peso_kg is null
    ) then
      failures := failures || 'G1 la consulta creada no quedó con veterinario_id/anamnesis/evolucion/peso_kg esperados';
    end if;
    select count(*) into n from public.mascota_pesos where mascota_id = mascota_a_id;
    if n <> n_pesos then
      failures := failures || format('G1 registrar_consulta sin peso alteró mascota_pesos (%s -> %s)', n_pesos, n);
    end if;
  exception when others then
    failures := failures || ('G1 registrar_consulta sin peso debía funcionar, error: ' || sqlerrm);
  end;

  -- G2: registrar_consulta con peso -> consulta.peso_kg = 7.25 y mascota_pesos crece en exactamente 1.
  checks := checks + 1;
  begin
    select count(*) into n_pesos from public.mascota_pesos where mascota_id = mascota_a_id;
    v_consulta := public.registrar_consulta(mascota_a_id, 'Smoke Control', 'Smoke Nada', p_peso_kg => 7.25);
    if not exists (select 1 from public.consultas where id = v_consulta and peso_kg = 7.25) then
      failures := failures || 'G2 la consulta creada no quedó con peso_kg = 7.25';
    end if;
    select count(*) into n from public.mascota_pesos where mascota_id = mascota_a_id and peso_kg = 7.25;
    if n <> 1 then
      failures := failures || format('G2 esperaba exactamente 1 fila nueva de peso 7.25, vio %s', n);
    end if;
    select count(*) into n from public.mascota_pesos where mascota_id = mascota_a_id;
    if n <> n_pesos + 1 then
      failures := failures || format('G2 mascota_pesos debía crecer en 1 (%s -> %s)', n_pesos, n);
    end if;
  exception when others then
    failures := failures || ('G2 registrar_consulta con peso debía funcionar, error: ' || sqlerrm);
  end;

  -- G3: anamnesis/evolucion en blanco quedan null (nunca '').
  checks := checks + 1;
  begin
    v_consulta := public.registrar_consulta(mascota_a_id, 'Smoke Dx', 'Smoke Tx', p_anamnesis => '   ', p_evolucion => '');
    select anamnesis into v_texto from public.consultas where id = v_consulta;
    if v_texto is not null then
      failures := failures || format('G3 anamnesis en blanco no quedó null, quedó %L', v_texto);
    end if;
    select evolucion into v_texto from public.consultas where id = v_consulta;
    if v_texto is not null then
      failures := failures || format('G3 evolucion en blanco no quedó null, quedó %L', v_texto);
    end if;
  exception when others then
    failures := failures || ('G3 error inesperado: ' || sqlerrm);
  end;

  -- G4: registrar_consulta contra mascota de otra clinica -> foreign_key_violation.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_b_id, 'Smoke Intruso', 'Smoke Tx');
    failures := failures || 'G4 registrar_consulta contra mascota de otra clinica debía fallar pero tuvo éxito';
  exception
    when foreign_key_violation then null;
    when others then failures := failures || ('G4 error inesperado: ' || sqlerrm);
  end;

  -- G5: diagnostico en blanco -> check_violation.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a_id, '   ', 'Smoke Tx');
    failures := failures || 'G5 registrar_consulta con diagnostico en blanco debía fallar pero tuvo éxito';
  exception
    when check_violation then null;
    when others then failures := failures || ('G5 error inesperado: ' || sqlerrm);
  end;

  -- G6: signo vital inválido (temperatura negativa) -> check_violation.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a_id, 'Smoke Dx', 'Smoke Tx', p_temperatura_c => -1);
    failures := failures || 'G6 registrar_consulta con temperatura negativa debía fallar pero tuvo éxito';
  exception
    when check_violation then null;
    when others then failures := failures || ('G6 error inesperado: ' || sqlerrm);
  end;

  -- G7: insert directo con veterinario_id suplantado (vet B) -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento)
      values (mascota_a_id, vet_b_id, 'x', 'y');
    failures := failures || 'G7 insert directo con veterinario_id suplantado debía fallar pero tuvo éxito';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('G7 error inesperado: ' || sqlerrm);
  end;

  -- G8: insert directo contra mascota de otra clinica -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento)
      values (mascota_b_id, vet_a_id, 'x', 'y');
    failures := failures || 'G8 insert directo contra mascota de otra clinica debía fallar pero tuvo éxito';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('G8 error inesperado: ' || sqlerrm);
  end;

  -- G9: select consultas de mascota B -> 0.
  checks := checks + 1;
  select count(*) into n from public.consultas where mascota_id = mascota_b_id;
  if n <> 0 then failures := failures || format('G9 vet A ve %s consultas de mascota B, esperaba 0', n); end if;

  -- G10: update consultas propias -> 0 filas (append-only, HIST-04).
  checks := checks + 1;
  update public.consultas set diagnostico = 'editado' where mascota_id = mascota_a_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('G10 update consultas afectó %s filas, esperaba 0 (append-only)', n); end if;

  -- G11: delete consultas propias -> 0 filas (append-only, HIST-04).
  checks := checks + 1;
  delete from public.consultas where mascota_id = mascota_a_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('G11 delete consultas afectó %s filas, esperaba 0 (append-only)', n); end if;

  -------------------------------------------------------------------------
  -- Fase 3: impersonar vet B -- negativo cruzado contra datos de A y
  -- HIST-04 sobre la propia consulta.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- H1: select consultas de mascota A -> 0.
  checks := checks + 1;
  select count(*) into n from public.consultas where mascota_id = mascota_a_id;
  if n <> 0 then failures := failures || format('H1 vet B ve %s consultas de mascota A, esperaba 0', n); end if;

  -- H2: registrar_consulta contra mascota A -> foreign_key_violation.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a_id, 'x', 'y');
    failures := failures || 'H2 vet B pudo registrar consulta contra mascota de otra clinica';
  exception
    when foreign_key_violation then null;
    when others then failures := failures || ('H2 error inesperado: ' || sqlerrm);
  end;

  -- H3: update de su propia consulta (mascota B) -> 0 filas (append-only, ni el propio autor).
  checks := checks + 1;
  update public.consultas set diagnostico = 'editado' where mascota_id = mascota_b_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('H3 vet B update sobre su propia consulta afectó %s filas, esperaba 0', n); end if;

  -- H4: delete de su propia consulta (mascota B) -> 0 filas (append-only, ni el propio autor).
  checks := checks + 1;
  delete from public.consultas where mascota_id = mascota_b_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('H4 vet B delete sobre su propia consulta afectó %s filas, esperaba 0', n); end if;

  -------------------------------------------------------------------------
  -- Fase 3: impersonar cliente (sin clinica) -- sin acceso alguno a consultas.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', cliente_c_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- I1: select consultas -> 0.
  checks := checks + 1;
  select count(*) into n from public.consultas;
  if n <> 0 then failures := failures || format('I1 cliente ve %s filas de consultas, esperaba 0', n); end if;

  -- I2: registrar_consulta -> insufficient_privilege.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a_id, 'x', 'y');
    failures := failures || 'I2 cliente pudo ejecutar registrar_consulta';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('I2 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Fase 4 / bloque J: impersonar vet A -- citas, cita_mascotas, RPCs.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- Setup de Fase 4 (no cuenta en checks): segundo cliente+mascota y segunda mascota del cliente A.
  begin
    select cliente_id, mascota_id into cliente_a2_id, mascota_a2_id
      from public.registrar_cliente_con_mascota('Smoke Cliente A2', '3000000003', 'Smoke Pet A2', 'perro', '', null, null);
    mascota_a3_id := public.registrar_mascota(cliente_a_id, 'Smoke Pet A3', 'gato');
  exception when others then
    failures := failures || ('SETUP5 setup de Fase 4 falló: ' || sqlerrm);
  end;

  -- J1: crear_cita con 2 mascotas del mismo cliente -> id y 2 filas en cita_mascotas.
  checks := checks + 1;
  begin
    cita_a_id := public.crear_cita(cliente_a_id, array[mascota_a_id, mascota_a3_id], now() + interval '1 day');
    if cita_a_id is null then
      failures := failures || 'J1 crear_cita devolvió null';
    else
      select count(*) into n from public.cita_mascotas where cita_id = cita_a_id;
      if n <> 2 then failures := failures || format('J1 esperaba 2 filas en cita_mascotas, vio %s', n); end if;
    end if;
  exception when others then
    failures := failures || ('J1 crear_cita multi-mascota debía funcionar, error: ' || sqlerrm);
  end;

  -- J2: lista de mascotas vacía -> check_violation.
  checks := checks + 1;
  begin
    perform public.crear_cita(cliente_a_id, array[]::uuid[], now() + interval '1 day');
    failures := failures || 'J2 crear_cita con lista vacía debía fallar pero tuvo éxito';
  exception
    when check_violation then null;
    when others then failures := failures || ('J2 error inesperado: ' || sqlerrm);
  end;

  -- J3: mascota de otro dueño (misma clínica) -> foreign_key_violation.
  checks := checks + 1;
  begin
    perform public.crear_cita(cliente_a_id, array[mascota_a2_id], now() + interval '1 day');
    failures := failures || 'J3 crear_cita con mascota de otro dueño debía fallar pero tuvo éxito';
  exception
    when foreign_key_violation then null;
    when others then failures := failures || ('J3 error inesperado: ' || sqlerrm);
  end;

  -- J4: domicilio sin dirección -> check_violation.
  checks := checks + 1;
  begin
    perform public.crear_cita(cliente_a_id, array[mascota_a_id], now() + interval '1 day', 30, 'domicilio', '   ');
    failures := failures || 'J4 crear_cita a domicilio sin dirección debía fallar pero tuvo éxito';
  exception
    when check_violation then null;
    when others then failures := failures || ('J4 error inesperado: ' || sqlerrm);
  end;

  -- J5: estado inválido -> check_violation.
  checks := checks + 1;
  begin
    update public.citas set estado = 'invalido' where id = cita_a_id;
    failures := failures || 'J5 estado inválido debía fallar pero tuvo éxito';
  exception
    when check_violation then null;
    when others then failures := failures || ('J5 error inesperado: ' || sqlerrm);
  end;

  -- J6: estado reservado 'solicitada' (Fase 9) -> el vet no puede ponerlo (HI-01) -> check_violation.
  checks := checks + 1;
  begin
    update public.citas set estado = 'solicitada' where id = cita_a_id;
    failures := failures || 'J6 el vet pudo pasar una cita a solicitada';
  exception
    when check_violation then null;
    when others then failures := failures || ('J6 error inesperado: ' || sqlerrm);
  end;

  -- J7: estado confirmada (1 fila).
  checks := checks + 1;
  update public.citas set estado = 'confirmada' where id = cita_a_id;
  get diagnostics n = row_count;
  if n <> 1 then failures := failures || format('J7 update a confirmada afectó %s filas, esperaba 1', n); end if;

  -- J8: delete de cita -> 0 filas (sin política delete).
  checks := checks + 1;
  delete from public.citas where id = cita_a_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('J8 delete de cita afectó %s filas, esperaba 0', n); end if;

  -- J9: update de cita_mascotas -> 0 filas (sin política update).
  checks := checks + 1;
  update public.cita_mascotas set mascota_id = mascota_a_id where cita_id = cita_a_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('J9 update de cita_mascotas afectó %s filas, esperaba 0', n); end if;

  -- J10: actualizar_cita deja solo 1 mascota.
  checks := checks + 1;
  begin
    perform public.actualizar_cita(cita_a_id, array[mascota_a_id], now() + interval '2 days');
    select count(*) into n from public.cita_mascotas where cita_id = cita_a_id;
    if n <> 1 then failures := failures || format('J10 esperaba 1 fila en cita_mascotas tras actualizar, vio %s', n); end if;
  exception when others then
    failures := failures || ('J10 actualizar_cita debía funcionar, error: ' || sqlerrm);
  end;

  -- J11: actualizar_cita sobre cita cancelada -> check_violation; se devuelve a pendiente.
  checks := checks + 1;
  update public.citas set estado = 'cancelada' where id = cita_a_id;
  begin
    perform public.actualizar_cita(cita_a_id, array[mascota_a_id], now() + interval '2 days');
    failures := failures || 'J11 actualizar_cita sobre cita cancelada debía fallar pero tuvo éxito';
  exception
    when check_violation then null;
    when others then failures := failures || ('J11 error inesperado: ' || sqlerrm);
  end;
  update public.citas set estado = 'pendiente' where id = cita_a_id;

  -------------------------------------------------------------------------
  -- Fase 4 / bloque K: impersonar vet B -- aislamiento entre clínicas.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- K1: select citas de A -> 0.
  checks := checks + 1;
  select count(*) into n from public.citas where id = cita_a_id;
  if n <> 0 then failures := failures || format('K1 vet B ve %s citas de A, esperaba 0', n); end if;

  -- K2: select cita_mascotas de A -> 0.
  checks := checks + 1;
  select count(*) into n from public.cita_mascotas where cita_id = cita_a_id;
  if n <> 0 then failures := failures || format('K2 vet B ve %s filas de cita_mascotas de A, esperaba 0', n); end if;

  -- K3: crear_cita con cliente/mascota de A -> foreign_key_violation.
  checks := checks + 1;
  begin
    perform public.crear_cita(cliente_a_id, array[mascota_a_id], now());
    failures := failures || 'K3 vet B pudo crear cita para cliente de otra clinica';
  exception
    when foreign_key_violation then null;
    when others then failures := failures || ('K3 error inesperado: ' || sqlerrm);
  end;

  -- K4: insert directo en citas de la clínica A -> insufficient_privilege (RLS).
  checks := checks + 1;
  begin
    insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora)
      values (clinica_a_id, cliente_a_id, vet_b_id, now());
    failures := failures || 'K4 insert directo de vet B en citas de clinica A debía fallar pero tuvo éxito';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('K4 error inesperado: ' || sqlerrm);
  end;

  -- K5: update de cita de A -> 0 filas.
  checks := checks + 1;
  update public.citas set notas = 'x' where id = cita_a_id;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('K5 vet B actualizó %s citas de A, esperaba 0', n); end if;

  -- K6: registrar_consulta ligada a cita de A -> foreign_key_violation.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a_id, 'x', 'y', p_cita_id => cita_a_id);
    failures := failures || 'K6 vet B pudo registrar consulta ligada a cita de otra clinica';
  exception
    when foreign_key_violation then null;
    when others then failures := failures || ('K6 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Fase 4 / bloque L: vet A de nuevo -- vínculo consulta/cita y append-only.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- L1: consulta ligada a la cita.
  checks := checks + 1;
  begin
    v_consulta := public.registrar_consulta(mascota_a_id, 'dx', 'tx', p_cita_id => cita_a_id);
    if not exists (select 1 from public.consultas where id = v_consulta and cita_id = cita_a_id) then
      failures := failures || 'L1 la consulta no quedó ligada a la cita';
    end if;
  exception when others then
    failures := failures || ('L1 registrar_consulta con cita debía funcionar, error: ' || sqlerrm);
  end;

  -- L2: segunda consulta para el mismo (cita, mascota) -> unique_violation.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a_id, 'dx', 'tx', p_cita_id => cita_a_id);
    failures := failures || 'L2 segunda consulta para la misma cita y mascota debía fallar pero tuvo éxito';
  exception
    when unique_violation then null;
    when others then failures := failures || ('L2 error inesperado: ' || sqlerrm);
  end;

  -- L3: mascota que ya no pertenece a la cita -> foreign_key_violation.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a3_id, 'dx', 'tx', p_cita_id => cita_a_id);
    failures := failures || 'L3 consulta de mascota fuera de la cita debía fallar pero tuvo éxito';
  exception
    when foreign_key_violation then null;
    when others then failures := failures || ('L3 error inesperado: ' || sqlerrm);
  end;

  -- L4: llamada de 3 argumentos sigue funcionando (sin ambigüedad de sobrecarga).
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a_id, 'x', 'y');
  exception when others then
    failures := failures || ('L4 registrar_consulta de 3 argumentos debía funcionar, error: ' || sqlerrm);
  end;

  -- L5: update de consultas.cita_id -> 0 filas (append-only).
  checks := checks + 1;
  update public.consultas set cita_id = null where id = v_consulta;
  get diagnostics n = row_count;
  if n <> 0 then failures := failures || format('L5 update de consultas afectó %s filas, esperaba 0 (append-only)', n); end if;

  -------------------------------------------------------------------------
  -- Fix 04-review HI-01 / bloque N: los writes directos (PostgREST) respetan las
  -- mismas guardas que las RPC. Estado de partida: cita_a_id pendiente, con solo
  -- mascota_a_id (consulta ligada en L1); mascota_a3_id es del cliente A pero ya no
  -- está en cita_a_id; mascota_a2_id es de otro cliente de la clínica A.
  -------------------------------------------------------------------------
  -- Setup de bloque N (como postgres, no cuenta en checks): una cita de la clínica B,
  -- una cita completada hace 1 hora (fuera de la ventana de deshacer) con mascota_a3,
  -- y una cita cancelada con mascota_a.
  perform set_config('role', 'postgres', true);
  begin
    insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora)
      values (clinica_b_id, cliente_b_id, vet_b_id, now()) returning id into cita_b_id;
    insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
      values (cita_b_id, mascota_b_id, clinica_b_id);

    insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora, estado, created_at, updated_at)
      values (clinica_a_id, cliente_a_id, vet_a_id, now() - interval '2 hours', 'completada',
              now() - interval '2 hours', now() - interval '1 hour')
      returning id into cita_vieja_id;
    insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
      values (cita_vieja_id, mascota_a3_id, clinica_a_id);

    insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora, estado)
      values (clinica_a_id, cliente_a_id, vet_a_id, now() + interval '3 days', 'cancelada')
      returning id into cita_cancelada_id;
    insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
      values (cita_cancelada_id, mascota_a_id, clinica_a_id);
  exception when others then
    failures := failures || ('SETUP6 setup de bloque N falló: ' || sqlerrm);
  end;

  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- N1: insert directo en cita_mascotas con mascota de OTRO dueño -> insufficient_privilege (RLS).
  checks := checks + 1;
  begin
    insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
      values (cita_a_id, mascota_a2_id, clinica_a_id);
    failures := failures || 'N1 insert directo de mascota de otro dueño en cita_mascotas debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('N1 error inesperado: ' || sqlerrm);
  end;

  -- N2: insert directo con mascota del MISMO dueño -> 1 fila; se borra para volver al estado previo.
  checks := checks + 1;
  begin
    insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
      values (cita_a_id, mascota_a3_id, clinica_a_id);
    get diagnostics n = row_count;
    if n <> 1 then failures := failures || format('N2 insert de mascota del mismo dueño afectó %s filas, esperaba 1', n); end if;
    delete from public.cita_mascotas where cita_id = cita_a_id and mascota_id = mascota_a3_id;
    get diagnostics n = row_count;
    if n <> 1 then failures := failures || format('N2 limpieza borró %s filas, esperaba 1', n); end if;
  exception when others then
    failures := failures || ('N2 insert directo de mascota del mismo dueño debía funcionar, error: ' || sqlerrm);
  end;

  -- N3: insert directo en cita_mascotas de una cita cancelada (mismo dueño) -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
      values (cita_cancelada_id, mascota_a3_id, clinica_a_id);
    failures := failures || 'N3 agregar mascota a una cita cancelada debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('N3 error inesperado: ' || sqlerrm);
  end;

  -- N4: update directo de citas.cliente_id -> check_violation.
  checks := checks + 1;
  begin
    update public.citas set cliente_id = cliente_a2_id where id = cita_a_id;
    failures := failures || 'N4 cambiar el cliente de la cita debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('N4 error inesperado: ' || sqlerrm);
  end;

  -- N5: update directo de citas.veterinario_id -> check_violation.
  checks := checks + 1;
  begin
    update public.citas set veterinario_id = vet_b_id where id = cita_a_id;
    failures := failures || 'N5 cambiar el veterinario de la cita debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('N5 error inesperado: ' || sqlerrm);
  end;

  -- N6: insert directo de una cita ya completada -> insufficient_privilege (RLS).
  checks := checks + 1;
  begin
    insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora, estado)
      values (clinica_a_id, cliente_a_id, vet_a_id, now(), 'completada');
    failures := failures || 'N6 insert directo de cita completada debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('N6 error inesperado: ' || sqlerrm);
  end;

  -- N7: "Completar" + "Deshacer": pendiente -> completada -> pendiente (dentro de la ventana).
  checks := checks + 1;
  begin
    n_total := 0;
    update public.citas set estado = 'completada' where id = cita_a_id;
    get diagnostics n = row_count; n_total := n_total + n;
    update public.citas set estado = 'pendiente' where id = cita_a_id;
    get diagnostics n = row_count; n_total := n_total + n;
    if n_total <> 2 then failures := failures || format('N7 completar+deshacer afectó %s filas, esperaba 2', n_total); end if;
  exception when others then
    failures := failures || ('N7 completar+deshacer debía funcionar, error: ' || sqlerrm);
  end;

  -- N8: Confirmar, "No asistió" + "Deshacer" (-> confirmada), "Marcar como pendiente".
  checks := checks + 1;
  begin
    n_total := 0;
    update public.citas set estado = 'confirmada' where id = cita_a_id;
    get diagnostics n = row_count; n_total := n_total + n;
    update public.citas set estado = 'no_asistio' where id = cita_a_id;
    get diagnostics n = row_count; n_total := n_total + n;
    update public.citas set estado = 'confirmada' where id = cita_a_id;
    get diagnostics n = row_count; n_total := n_total + n;
    update public.citas set estado = 'pendiente' where id = cita_a_id;
    get diagnostics n = row_count; n_total := n_total + n;
    if n_total <> 4 then failures := failures || format('N8 transiciones legítimas afectaron %s filas, esperaba 4', n_total); end if;
  exception when others then
    failures := failures || ('N8 transiciones legítimas debían funcionar, error: ' || sqlerrm);
  end;

  -- N9: cancelada -> completada -> check_violation (ME-04: no se completa una cita cancelada).
  checks := checks + 1;
  begin
    update public.citas set estado = 'completada' where id = cita_cancelada_id;
    failures := failures || 'N9 completar una cita cancelada debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('N9 error inesperado: ' || sqlerrm);
  end;

  -- N10: "Reabrir cita": cancelada -> pendiente (siempre, sin ventana) -> 1 fila; se re-cancela.
  checks := checks + 1;
  begin
    update public.citas set estado = 'pendiente' where id = cita_cancelada_id;
    get diagnostics n = row_count;
    if n <> 1 then failures := failures || format('N10 reabrir afectó %s filas, esperaba 1', n); end if;
    update public.citas set estado = 'cancelada' where id = cita_cancelada_id;
  exception when others then
    failures := failures || ('N10 reabrir cita cancelada debía funcionar, error: ' || sqlerrm);
  end;

  -- N11: completada -> cancelada (terminal -> terminal) -> check_violation.
  checks := checks + 1;
  begin
    update public.citas set estado = 'cancelada' where id = cita_vieja_id;
    failures := failures || 'N11 pasar una cita completada a cancelada debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('N11 error inesperado: ' || sqlerrm);
  end;

  -- N12: completada hace 1 hora -> pendiente (fuera de la ventana de deshacer) -> check_violation.
  checks := checks + 1;
  begin
    update public.citas set estado = 'pendiente' where id = cita_vieja_id;
    failures := failures || 'N12 revertir una cita completada fuera de la ventana debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('N12 error inesperado: ' || sqlerrm);
  end;

  -- N13: editar fecha_hora de una cita completada -> check_violation.
  checks := checks + 1;
  begin
    update public.citas set fecha_hora = now() where id = cita_vieja_id;
    failures := failures || 'N13 editar la fecha de una cita completada debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('N13 error inesperado: ' || sqlerrm);
  end;

  -- N14: recordatorio_enviado_at se marca y se deshace en cualquier estado -> 2 filas.
  checks := checks + 1;
  begin
    n_total := 0;
    update public.citas set recordatorio_enviado_at = now() where id = cita_vieja_id;
    get diagnostics n = row_count; n_total := n_total + n;
    update public.citas set recordatorio_enviado_at = null where id = cita_vieja_id;
    get diagnostics n = row_count; n_total := n_total + n;
    if n_total <> 2 then failures := failures || format('N14 marcar/deshacer recordatorio afectó %s filas, esperaba 2', n_total); end if;
  exception when others then
    failures := failures || ('N14 marcar recordatorio debía funcionar, error: ' || sqlerrm);
  end;

  -- N15: insert directo de consulta ligada a una cita de OTRA clínica -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento, cita_id)
      values (mascota_a_id, vet_a_id, 'dx', 'tx', cita_b_id);
    failures := failures || 'N15 consulta directa ligada a cita de otra clínica debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('N15 error inesperado: ' || sqlerrm);
  end;

  -- N16: insert directo de consulta con una mascota que no está en la cita -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento, cita_id)
      values (mascota_a3_id, vet_a_id, 'dx', 'tx', cita_a_id);
    failures := failures || 'N16 consulta directa de mascota fuera de la cita debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('N16 error inesperado: ' || sqlerrm);
  end;

  -- N17: insert directo legítimo (mascota de la cita, cita completada de la clínica) -> 1 fila.
  checks := checks + 1;
  begin
    insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento, cita_id)
      values (mascota_a3_id, vet_a_id, 'dx', 'tx', cita_vieja_id);
    get diagnostics n = row_count;
    if n <> 1 then failures := failures || format('N17 consulta directa legítima afectó %s filas, esperaba 1', n); end if;
  exception when others then
    failures := failures || ('N17 consulta directa legítima debía funcionar, error: ' || sqlerrm);
  end;

  -- N18 (ME-04): registrar_consulta ligada a una cita cancelada -> check_violation.
  checks := checks + 1;
  begin
    perform public.registrar_consulta(mascota_a_id, 'dx', 'tx', p_cita_id => cita_cancelada_id);
    failures := failures || 'N18 registrar_consulta sobre cita cancelada debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('N18 error inesperado: ' || sqlerrm);
  end;

  -- N19 (ME-04): insert directo de consulta ligada a una cita cancelada -> insufficient_privilege.
  checks := checks + 1;
  begin
    insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento, cita_id)
      values (mascota_a_id, vet_a_id, 'dx', 'tx', cita_cancelada_id);
    failures := failures || 'N19 consulta directa sobre cita cancelada debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('N19 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Fase 4 / bloque M: cliente sin clínica, y cascada D-20.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', cliente_c_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  -- M1: cliente ve 0 citas.
  checks := checks + 1;
  select count(*) into n from public.citas;
  if n <> 0 then failures := failures || format('M1 cliente ve %s citas, esperaba 0', n); end if;

  -- M2: cliente no puede crear citas.
  checks := checks + 1;
  begin
    perform public.crear_cita(cliente_a_id, array[mascota_a_id], now());
    failures := failures || 'M2 cliente pudo ejecutar crear_cita';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('M2 error inesperado: ' || sqlerrm);
  end;

  -- M3: borrar un cliente borra sus citas en cascada (D-20).
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  checks := checks + 1;
  begin
    cita_a2_id := public.crear_cita(cliente_a2_id, array[mascota_a2_id], now());
    perform set_config('role', 'postgres', true);
    delete from public.clientes where id = cliente_a2_id;
    select count(*) into n from public.citas where id = cita_a2_id;
    if n <> 0 then failures := failures || format('M3 la cita sobrevivió al borrado del cliente (%s filas)', n); end if;
  exception when others then
    failures := failures || ('M3 cascada de cliente a citas falló, error: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- Fix 04-review HI-02 / bloque O (como postgres): borrar la cuenta de un
  -- veterinario con citas NO borra la agenda -- citas_veterinario_id_fkey es restrict.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);

  -- O1: delete de auth.users del vet A (tiene citas) -> foreign_key_violation en citas.
  checks := checks + 1;
  begin
    delete from auth.users where id = vet_a_id;
    failures := failures || 'O1 borrar el vet A debía fallar (restrict) pero borró sus citas en cascada';
  exception
    when foreign_key_violation then
      get stacked diagnostics v_texto = constraint_name;
      -- Fase 4.1: ya no es solo citas_veterinario_id_fkey. Borrar auth.users también dispara
      -- (en orden no determinista) las FK restrict de consultas y las cascadas a perfiles
      -- bloqueadas por las FK *_veterinario_perfil_fkey; cualquiera de las 4 prueba que no se borra nada.
      if v_texto is distinct from 'citas_veterinario_id_fkey'
         and v_texto is distinct from 'citas_veterinario_perfil_fkey'
         and v_texto is distinct from 'consultas_veterinario_id_fkey'
         and v_texto is distinct from 'consultas_veterinario_perfil_fkey' then
        failures := failures || format('O1 foreign_key_violation por %s, esperaba una FK restrict de citas/consultas', v_texto);
      end if;
    when others then failures := failures || ('O1 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- ===== P: Equipo de la clínica (Fase 4.1) =====
  -- Setup (vet A es admin): vet_a2 y vet_a3 se registran con un código de invitación.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  select g.codigo into v_cod_p from public.generar_invitacion_clinica() g;
  perform set_config('role', 'postgres', true);
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (vet_a2_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'smoke-vet-a2@vetapp.invalid',
      jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Vet A2', 'codigo_invitacion', v_cod_p),
      now(), now());

  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  select g.codigo into v_cod_p from public.generar_invitacion_clinica() g;
  perform set_config('role', 'postgres', true);
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (vet_a3_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'smoke-vet-a3@vetapp.invalid',
      jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Vet A3', 'codigo_invitacion', v_cod_p),
      now(), now());

  -- P1: backfill D-04 -- ningún veterinario sin rol_clinica; vet A es admin y activo.
  checks := checks + 1;
  select count(*) into n from public.perfiles where rol = 'VETERINARIO' and rol_clinica is null;
  if n <> 0 or not exists (
    select 1 from public.perfiles where id = vet_a_id and rol_clinica = 'admin' and activo
  ) then
    failures := failures || format('P1 backfill: %s veterinarios sin rol_clinica o vet A no es admin activo', n);
  end if;

  -- P2..P5: vet_a2 (no admin) no puede auto-escalar ni moverse (privilegios por columna, T1).
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a2_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);

  checks := checks + 1;
  begin
    update public.perfiles set rol_clinica = 'admin' where id = vet_a2_id;
    failures := failures || 'P2 vet no-admin pudo cambiar su rol_clinica';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('P2 error inesperado: ' || sqlerrm);
  end;

  checks := checks + 1;
  begin
    update public.perfiles set activo = true where id = vet_a2_id;
    failures := failures || 'P3 vet pudo escribir su columna activo';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('P3 error inesperado: ' || sqlerrm);
  end;

  checks := checks + 1;
  begin
    update public.perfiles set clinica_id = clinica_b_id where id = vet_a2_id;
    failures := failures || 'P4 vet pudo cambiar su clinica_id';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('P4 error inesperado: ' || sqlerrm);
  end;

  checks := checks + 1;
  begin
    update public.perfiles set rol = 'CLIENTE' where id = vet_a2_id;
    failures := failures || 'P5 vet pudo cambiar su rol';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('P5 error inesperado: ' || sqlerrm);
  end;

  -- P6: vet_a2 edita nombre/telefono/matricula propios (TEAM-05).
  checks := checks + 1;
  begin
    update public.perfiles
      set nombre = 'Smoke Vet A2 Editado', telefono = '3001112222', matricula = 'MP-12345'
      where id = vet_a2_id;
    get diagnostics n = row_count;
    select matricula into v_texto from public.perfiles where id = vet_a2_id;
    if n <> 1 or v_texto is distinct from 'MP-12345' then
      failures := failures || format('P6 update propio afectó %s filas, matricula=%s', n, v_texto);
    end if;
  exception when others then
    failures := failures || ('P6 error inesperado: ' || sqlerrm);
  end;

  -- P7: signup de vet_a4 con código válido (minúsculas con guion) -> entra a la clínica A.
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  select g.codigo into v_cod_p from public.generar_invitacion_clinica() g;
  perform set_config('role', 'postgres', true);

  checks := checks + 1;
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
      values (vet_a4_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'smoke-vet-a4@vetapp.invalid',
        jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Vet A4',
          'codigo_invitacion', lower(substr(v_cod_p, 1, 4) || '-' || substr(v_cod_p, 5))),
        now(), now());
    if not exists (
      select 1 from public.perfiles
      where id = vet_a4_id and clinica_id = clinica_a_id and rol_clinica = 'veterinario' and activo
    ) or not exists (
      select 1 from public.clinica_invitaciones where codigo = v_cod_p and usada_por = vet_a4_id
    ) then
      failures := failures || 'P7 el alta con código válido no dejó al vet en clínica A como veterinario activo con la invitación usada';
    end if;
  exception when others then
    failures := failures || ('P7 error inesperado: ' || sqlerrm);
  end;

  -- P8: reusar el mismo código -> el alta falla y no queda perfil.
  checks := checks + 1;
  v_uuid := gen_random_uuid();
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
      values (v_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'smoke-p8@vetapp.invalid',
        jsonb_build_object('rol', 'VETERINARIO', 'codigo_invitacion', v_cod_p), now(), now());
    failures := failures || 'P8 reusar un código debía fallar';
  exception when others then
    if sqlerrm not like '%ya fue utilizado%' then
      failures := failures || ('P8 error inesperado: ' || sqlerrm);
    end if;
  end;
  if exists (select 1 from public.perfiles where id = v_uuid) then
    failures := failures || 'P8 quedó un perfil pese al código reusado';
  end if;

  -- P9: código vencido.
  insert into public.clinica_invitaciones (clinica_id, codigo, creada_por, expira_en)
    values (clinica_a_id, 'SMKEXPAA', vet_a_id, now() - interval '1 hour');
  checks := checks + 1;
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
      values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'smoke-p9@vetapp.invalid',
        jsonb_build_object('rol', 'VETERINARIO', 'codigo_invitacion', 'SMKEXPAA'), now(), now());
    failures := failures || 'P9 un código vencido debía fallar';
  exception when others then
    if sqlerrm not like '%venci%' then
      failures := failures || ('P9 error inesperado: ' || sqlerrm);
    end if;
  end;

  -- P10: código revocado.
  insert into public.clinica_invitaciones (clinica_id, codigo, creada_por, expira_en, revocada)
    values (clinica_a_id, 'SMKREVAA', vet_a_id, now() + interval '1 day', true);
  checks := checks + 1;
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
      values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'smoke-p10@vetapp.invalid',
        jsonb_build_object('rol', 'VETERINARIO', 'codigo_invitacion', 'SMKREVAA'), now(), now());
    failures := failures || 'P10 un código revocado debía fallar';
  exception when others then
    if sqlerrm not like '%no es válido%' then
      failures := failures || ('P10 error inesperado: ' || sqlerrm);
    end if;
  end;

  -- P11: código inexistente.
  checks := checks + 1;
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
      values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'smoke-p11@vetapp.invalid',
        jsonb_build_object('rol', 'VETERINARIO', 'codigo_invitacion', 'ZZZZZZZZ'), now(), now());
    failures := failures || 'P11 un código inexistente debía fallar';
  exception when others then
    if sqlerrm not like '%no es válido%' then
      failures := failures || ('P11 error inesperado: ' || sqlerrm);
    end if;
  end;

  -- P12: metadata falsificada (clinica_id = A, rol_clinica = admin) sin código -> clínica NUEVA propia (T2).
  checks := checks + 1;
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
      values (vet_c_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'smoke-vet-c@vetapp.invalid',
        jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Vet C', 'clinica_nombre', 'Smoke Clinica C',
          'clinica_id', clinica_a_id::text, 'rol_clinica', 'admin', 'activo', true),
        now(), now());
    select clinica_id into v_clinica_c from public.perfiles where id = vet_c_id;
    if v_clinica_c is null or v_clinica_c = clinica_a_id or not exists (
      select 1 from public.perfiles where id = vet_c_id and rol_clinica = 'admin' and activo
    ) then
      failures := failures || 'P12 la metadata falsificada afectó la clínica/rol del perfil nuevo';
    end if;
  exception when others then
    failures := failures || ('P12 error inesperado: ' || sqlerrm);
  end;

  -- P13: un CLIENTE que trae un código válido lo ignora; la invitación sigue sin usar.
  insert into public.clinica_invitaciones (clinica_id, codigo, creada_por, expira_en)
    values (clinica_a_id, 'SMKVAKBB', vet_a_id, now() + interval '1 day');
  checks := checks + 1;
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
      values (cli_code_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'smoke-cliente-code@vetapp.invalid',
        jsonb_build_object('rol', 'CLIENTE', 'nombre', 'Smoke Cliente Code', 'codigo_invitacion', 'SMKVAKBB'),
        now(), now());
    if not exists (select 1 from public.perfiles where id = cli_code_id and rol = 'CLIENTE' and clinica_id is null)
       or exists (select 1 from public.clinica_invitaciones where codigo = 'SMKVAKBB' and usada_por is not null) then
      failures := failures || 'P13 el CLIENTE con código quedó con clínica o consumió la invitación';
    end if;
  exception when others then
    failures := failures || ('P13 error inesperado: ' || sqlerrm);
  end;

  -- P14: un no-admin no puede generar invitaciones.
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a2_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  checks := checks + 1;
  begin
    perform public.generar_invitacion_clinica();
    failures := failures || 'P14 un vet no-admin pudo generar una invitación';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('P14 error inesperado: ' || sqlerrm);
  end;

  -- P15: el admin genera; el formato es de 8 caracteres del alfabeto de 31, 72 h, un solo código vigente.
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  checks := checks + 1;
  begin
    perform public.generar_invitacion_clinica();
    select g.id, g.codigo, g.expira_en into v_inv_id, v_cod_p, v_expira from public.generar_invitacion_clinica() g;
    select count(*) into v_count from public.clinica_invitaciones
      where usada_por is null and not revocada and expira_en > now();
    if v_cod_p !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$'
       or v_expira < now() + interval '71 hours 59 minutes'
       or v_expira > now() + interval '72 hours 1 minute'
       or v_count <> 1 then
      failures := failures || format('P15 código=%s expira=%s vigentes=%s fuera de lo esperado', v_cod_p, v_expira, v_count);
    end if;
  exception when others then
    failures := failures || ('P15 error inesperado: ' || sqlerrm);
  end;

  -- P16: ni el admin de B ni un no-admin de A ven las invitaciones de A.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into n from public.clinica_invitaciones where clinica_id = clinica_a_id;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a2_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into n_total from public.clinica_invitaciones where clinica_id = clinica_a_id;
  if n <> 0 or n_total <> 0 then
    failures := failures || format('P16 admin B ve %s y vet no-admin A ve %s invitaciones de A, esperaba 0 y 0', n, n_total);
  end if;

  -- P17: un no-admin y el admin de OTRA clínica no pueden revocar; la invitación no cambia.
  checks := checks + 1;
  v_ok := true;
  begin
    perform public.revocar_invitacion(v_inv_id);
    v_ok := false;
    failures := failures || 'P17 un vet no-admin pudo revocar una invitación';
  exception when others then null;
  end;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.revocar_invitacion(v_inv_id);
    v_ok := false;
    failures := failures || 'P17 el admin de B pudo revocar una invitación de A';
  exception when others then null;
  end;
  perform set_config('role', 'postgres', true);
  if v_ok and exists (select 1 from public.clinica_invitaciones where id = v_inv_id and revocada) then
    failures := failures || 'P17 la invitación quedó revocada pese a los rechazos';
  end if;

  -- P18: el admin de B no puede retirar a un miembro de A.
  checks := checks + 1;
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.retirar_miembro(vet_a2_id);
    failures := failures || 'P18 el admin de B pudo retirar a un miembro de A';
  exception when others then null;
  end;
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.perfiles where id = vet_a2_id and activo) then
    failures := failures || 'P18 vet_a2 quedó inactivo';
  end if;

  -- P19: el admin de B no puede cambiar el rol de un miembro de A.
  checks := checks + 1;
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.cambiar_rol_miembro(vet_a2_id, 'admin');
    failures := failures || 'P19 el admin de B pudo cambiar el rol de un miembro de A';
  exception when others then null;
  end;
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.perfiles where id = vet_a2_id and rol_clinica = 'veterinario') then
    failures := failures || 'P19 el rol de vet_a2 cambió';
  end if;

  -- P20: un no-admin no puede retirar a nadie.
  checks := checks + 1;
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a2_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.retirar_miembro(vet_a_id);
    failures := failures || 'P20 un vet no-admin pudo retirar a otro';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('P20 error inesperado: ' || sqlerrm);
  end;

  -- P21: el único admin no puede quitarse el rol ni retirarse (la clínica no queda sin admin).
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.cambiar_rol_miembro(vet_a_id, 'veterinario');
    failures := failures || 'P21 el único admin pudo degradarse';
  exception when others then
    if sqlerrm not like '%al menos un administrador%' then
      failures := failures || ('P21 degradarse: error inesperado: ' || sqlerrm);
    end if;
  end;
  begin
    perform public.retirar_miembro(vet_a_id);
    failures := failures || 'P21 el único admin pudo retirarse';
  exception when others then
    if sqlerrm not like '%al menos un administrador%' then
      failures := failures || ('P21 retirarse: error inesperado: ' || sqlerrm);
    end if;
  end;

  -- P22: crear_cita asigna al vet elegido o, sin elegir, al llamador; vet_a2 registra una consulta.
  checks := checks + 1;
  begin
    v_cita1 := public.crear_cita(cliente_a_id, array[mascota_a_id], now() + interval '3 days',
      30, 'consultorio', '', 'Smoke P22', '', vet_a2_id);
    v_cita2 := public.crear_cita(cliente_a_id, array[mascota_a_id], now() + interval '4 days');
    perform set_config('role', 'postgres', true);
    if not exists (select 1 from public.citas where id = v_cita1 and veterinario_id = vet_a2_id)
       or not exists (select 1 from public.citas where id = v_cita2 and veterinario_id = vet_a_id) then
      failures := failures || 'P22 la cita no quedó asignada al veterinario esperado';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a2_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_consulta(p_mascota_id => mascota_a_id, p_diagnostico => 'dx P22', p_tratamiento => 'tx P22');
    perform set_config('role', 'postgres', true);
    if not exists (select 1 from public.consultas where mascota_id = mascota_a_id and veterinario_id = vet_a2_id) then
      failures := failures || 'P22 la consulta de vet_a2 no quedó registrada';
    end if;
  exception when others then
    failures := failures || ('P22 error inesperado: ' || sqlerrm);
  end;

  -- P23: asignar a un vet de otra clínica falla (RPC e insert directo).
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  checks := checks + 1;
  begin
    perform public.crear_cita(cliente_a_id, array[mascota_a_id], now() + interval '5 days',
      30, 'consultorio', '', 'Smoke P23', '', vet_b_id);
    failures := failures || 'P23 crear_cita con un vet de otra clínica debía fallar';
  exception when others then null;
  end;
  begin
    insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora)
      values (clinica_a_id, cliente_a_id, vet_b_id, now() + interval '5 days');
    failures := failures || 'P23 insert directo con un vet de otra clínica debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('P23 insert directo: error inesperado: ' || sqlerrm);
  end;

  -- P24: una cita abierta se reasigna; una completada no.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora, estado)
    values (clinica_a_id, cliente_a_id, vet_a_id, now() - interval '5 days', 'completada')
    returning id into v_cita_done;
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.actualizar_cita(v_cita2, array[mascota_a_id], now() + interval '4 days',
      30, 'consultorio', '', 'Consulta general', '', vet_a2_id);
    perform set_config('role', 'postgres', true);
    if not exists (select 1 from public.citas where id = v_cita2 and veterinario_id = vet_a2_id) then
      failures := failures || 'P24 la cita abierta no se reasignó a vet_a2';
    end if;
  exception when others then
    failures := failures || ('P24 reasignar cita abierta: error inesperado: ' || sqlerrm);
  end;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    update public.citas set veterinario_id = vet_a2_id where id = v_cita_done;
    failures := failures || 'P24 reasignar una cita completada debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('P24 cita completada: error inesperado: ' || sqlerrm);
  end;

  -- P25: vet_a promueve a vet_a3; vet_a3 (admin) se auto-retira (D-14) porque queda otro admin.
  checks := checks + 1;
  begin
    perform public.cambiar_rol_miembro(vet_a3_id, 'admin');
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a3_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.retirar_miembro(vet_a3_id);
    perform set_config('role', 'postgres', true);
    if exists (select 1 from public.perfiles where id = vet_a3_id and activo) then
      failures := failures || 'P25 vet_a3 sigue activo tras auto-retirarse';
    end if;
  exception when others then
    failures := failures || ('P25 error inesperado: ' || sqlerrm);
  end;

  -- P26: retirar a vet_a2 mueve sus citas futuras abiertas al admin que retira; no toca las pasadas.
  perform set_config('role', 'postgres', true);
  insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora, estado)
    values (clinica_a_id, cliente_a_id, vet_a2_id, now() - interval '2 days', 'pendiente')
    returning id into v_cita_pasada;
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  checks := checks + 1;
  begin
    n := public.retirar_miembro(vet_a2_id);
    perform set_config('role', 'postgres', true);
    if n < 1
       or not exists (select 1 from public.citas where id = v_cita1 and veterinario_id = vet_a_id)
       or not exists (select 1 from public.perfiles where id = vet_a2_id and not activo and clinica_id = clinica_a_id)
       or not exists (select 1 from public.citas where id = v_cita_pasada and veterinario_id = vet_a2_id) then
      failures := failures || format('P26 retiro: movidas=%s o estado de perfil/citas inesperado', n);
    end if;
  exception when others then
    failures := failures || ('P26 retiro: error inesperado: ' || sqlerrm);
  end;
  -- La cita pasada que sigue a nombre del vet retirado se edita reenviando el mismo vet o null.
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.actualizar_cita(v_cita_pasada, array[mascota_a_id], now() - interval '2 days',
      30, 'consultorio', '', 'Editada con vet actual', '', vet_a2_id);
    perform public.actualizar_cita(v_cita_pasada, array[mascota_a_id], now() - interval '2 days',
      30, 'consultorio', '', 'Editada con null', '', null);
    perform set_config('role', 'postgres', true);
    if not exists (select 1 from public.citas where id = v_cita_pasada and veterinario_id = vet_a2_id and motivo = 'Editada con null') then
      failures := failures || 'P26 editar la cita pasada de un vet retirado no la dejó intacta a su nombre';
    end if;
  exception when others then
    failures := failures || ('P26 editar cita de vet retirado: error inesperado: ' || sqlerrm);
  end;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.actualizar_cita(v_cita_pasada, array[mascota_a_id], now() - interval '2 days',
      30, 'consultorio', '', 'Editada a vet retirado', '', vet_a3_id);
    failures := failures || 'P26 reasignar a un vet retirado debía fallar';
  exception when others then
    if sqlerrm not like '%ya no está en tu clínica%' then
      failures := failures || ('P26 reasignar a retirado: error inesperado: ' || sqlerrm);
    end if;
  end;

  -- P27: vet_a2 retirado no ve nada de la clínica y no puede operar (T6).
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a2_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    select (select count(*) from public.clientes) + (select count(*) from public.mascotas)
         + (select count(*) from public.citas) + (select count(*) from public.consultas) into n;
    if n <> 0 or public.es_veterinario() or public.mi_clinica_id() is not null then
      failures := failures || format('P27 vet retirado ve %s filas o conserva acceso (es_veterinario/mi_clinica_id)', n);
    end if;
    begin
      perform public.crear_cita(cliente_a_id, array[mascota_a_id], now() + interval '6 days');
      failures := failures || 'P27 vet retirado pudo crear una cita';
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('P27 crear_cita: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('P27 error inesperado: ' || sqlerrm);
  end;

  -- P28: vet_a2 abre su propia clínica; vet A sigue leyendo su nombre por autoría (D-13).
  checks := checks + 1;
  begin
    v_clinica_nueva := public.crear_mi_clinica('Clínica Nueva');
    perform set_config('role', 'postgres', true);
    if not exists (
      select 1 from public.perfiles
      where id = vet_a2_id and clinica_id = v_clinica_nueva and rol_clinica = 'admin' and activo
    ) then
      failures := failures || 'P28 vet_a2 no quedó admin activo de su clínica nueva';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select nombre into v_texto from public.perfiles where id = vet_a2_id;
    if v_texto is distinct from 'Smoke Vet A2 Editado' then
      failures := failures || format('P28 vet A no lee el nombre del autor movido de clínica (leyó %s)', v_texto);
    end if;
    begin
      perform public.crear_mi_clinica('Otra Clínica');
      failures := failures || 'P28 un vet activo pudo crear otra clínica';
    exception when others then
      if sqlerrm not like '%Ya perteneces a una clínica activa%' then
        failures := failures || ('P28 crear_mi_clinica activo: error inesperado: ' || sqlerrm);
      end if;
    end;
  exception when others then
    failures := failures || ('P28 error inesperado: ' || sqlerrm);
  end;

  -- P29: unirse_a_clinica. Admin A y no-admin vet_a4 (clínica con datos) no pueden fusionarse con B;
  -- vet C (clínica propia vacía) sí, y su clínica vacía se elimina.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  select g.codigo into v_cod_b from public.generar_invitacion_clinica() g;

  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.unirse_a_clinica(v_cod_b);
    failures := failures || 'P29 vet A (clínica con datos) pudo unirse a B';
  exception when others then
    if sqlerrm not like '%ya tiene datos%' then
      failures := failures || ('P29 vet A: error inesperado: ' || sqlerrm);
    end if;
  end;

  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a4_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.unirse_a_clinica(v_cod_b);
    failures := failures || 'P29 vet no-admin A4 pudo unirse a B';
  exception when others then
    if sqlerrm not like '%ya tiene datos%' then
      failures := failures || ('P29 vet A4: error inesperado: ' || sqlerrm);
    end if;
  end;
  perform set_config('role', 'postgres', true);
  if not exists (
       select 1 from public.perfiles
       where id = vet_a4_id and clinica_id = clinica_a_id and rol_clinica = 'veterinario' and activo
     ) or exists (select 1 from public.clinica_invitaciones where codigo = v_cod_b and usada_por is not null) then
    failures := failures || 'P29 vet A4 cambió de clínica o el código de B se consumió';
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', vet_c_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    v_uuid := public.unirse_a_clinica(v_cod_b);
    perform set_config('role', 'postgres', true);
    if v_uuid is distinct from clinica_b_id
       or not exists (
         select 1 from public.perfiles
         where id = vet_c_id and clinica_id = clinica_b_id and rol_clinica = 'veterinario' and activo
       )
       or exists (select 1 from public.clinicas where id = v_clinica_c) then
      failures := failures || 'P29 vet C no se unió a B como veterinario o su clínica vacía no se eliminó';
    end if;
  exception when others then
    failures := failures || ('P29 vet C: error inesperado: ' || sqlerrm);
  end;

  -- P30: consultas/citas -> perfiles existen y ninguna FK de consultas.veterinario_id hace cascade (D-06).
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  if (select count(*) from pg_constraint
        where conname = 'consultas_veterinario_perfil_fkey' and conrelid = 'public.consultas'::regclass) <> 1
     or (select count(*) from pg_constraint
        where conname = 'citas_veterinario_perfil_fkey' and conrelid = 'public.citas'::regclass) <> 1
     or exists (
       select 1 from pg_constraint c
       where c.conrelid = 'public.consultas'::regclass
         and c.contype = 'f'
         and c.confdeltype not in ('r', 'a')
         and c.conkey = array[(
           select a.attnum from pg_attribute a
           where a.attrelid = 'public.consultas'::regclass and a.attname = 'veterinario_id'
         )]
     ) then
    failures := failures || 'P30 faltan las FK *_veterinario_perfil_fkey o consultas.veterinario_id aún hace cascade';
  end if;

  -------------------------------------------------------------------------
  -- Volver a postgres y reportar. SIEMPRE se lanza una excepción para
  -- revertir todo lo insertado (auth.users incluido) -- cero residuo.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);

  if array_length(failures, 1) > 0 then
    raise exception 'RLS SMOKE: FAIL (% de % checks) -> %',
      array_length(failures, 1), checks, array_to_string(failures, ' | ');
  else
    raise exception 'RLS SMOKE: PASS (% checks) - cambios revertidos', checks;
  end if;
end $$;
