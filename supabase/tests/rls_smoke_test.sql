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

  -- J6: estado reservado 'solicitada' aceptado (1 fila); se devuelve a pendiente.
  checks := checks + 1;
  update public.citas set estado = 'solicitada' where id = cita_a_id;
  get diagnostics n = row_count;
  if n <> 1 then failures := failures || format('J6 update a solicitada afectó %s filas, esperaba 1', n); end if;
  update public.citas set estado = 'pendiente' where id = cita_a_id;

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
