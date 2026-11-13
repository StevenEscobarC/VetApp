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
-- retirar (T6), autoría visible (D-13), citas por veterinario (D-07) y consultas FK restrict (D-06).
-- Fase 5 (bloque Q, 48 checks): vacunación — aislamiento, solo-append, cálculo derivado, alertas, enlace público, logo de la clínica.
-- Fase 5.1 (bloque R, 45 checks): planes y límites — plan efectivo, asignar_plan solo service_role, límite de 50, prueba Clínica y cupos, solo lectura, logo/protocolos.
-- Fase 6 (bloque S, 23 checks): inventario — aislamiento, solo-append, mover_stock atómico sin negativos, deshacer (solo de ajustes), conteo con cantidad esperada (IN004), solo admin, resumen de stock bajo, solo lectura, autoría.
-- Fase 7 (bloque T, 23 checks hasta ahora): facturación — numeración por clínica sin huecos, idempotencia, descuento y devolución de stock, anular solo admin/autor, pagos, cotizaciones y conversión, visita ya cobrada, solo lectura, autoría. Total esperado: 284.

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
  -- Fase 5 (bloque Q)
  q_hoy date := date '2026-06-01';
  q_vet_noadmin uuid := gen_random_uuid();
  q_vet_x uuid := gen_random_uuid();
  q_logo text;
  q_cliente_ana uuid;
  q_m uuid;
  q_m_b uuid;
  q_m_ana uuid;
  q_m_cach uuid;
  q_dosis uuid;
  q_dosis2 uuid;
  q_dosis3 uuid;
  q_tok text;
  q_tok2 text;
  q_row record;
  q_row2 record;
  q_json jsonb;
  q_arr text[];
  q_sig text;
  q_cita uuid;
  q_cita2 uuid;
  q_prox date;
  q_n int;
  -- Fase 5.1 (bloque R)
  r_hoy date;
  r_vet_n uuid := gen_random_uuid();
  r_vet_g uuid := gen_random_uuid();
  r_vet_s uuid := gen_random_uuid();
  r_vet_s2 uuid := gen_random_uuid();
  r_vet_s3 uuid := gen_random_uuid();
  r_vet_s4 uuid := gen_random_uuid();
  r_vet_l uuid := gen_random_uuid();
  r_c_n uuid;
  r_c_g uuid;
  r_c_s uuid;
  r_c_l uuid;
  r_c_deriv uuid;
  r_cliente uuid;
  r_cliente2 uuid;
  r_m uuid;
  r_cita uuid;
  r_dosis uuid;
  r_s_cliente uuid;
  r_s_m uuid;
  r_s_cita uuid;
  r_s_dosis uuid;
  r_l_cliente uuid;
  r_l_m uuid;
  r_row record;
  r_row2 record;
  r_json jsonb;
  r_n int;
  r_n2 int;
  r_cod text;
  r_cod2 text;
  r_tok text;
  r_logo text;
  r_logo2 text;
  r_proto text;
  r_arr text[];
  r_d date;
  -- Fase 6 (bloque S)
  s_hoy date;
  s_vet_admin uuid := gen_random_uuid();
  s_vet_col uuid := gen_random_uuid();
  s_vet_otro uuid := gen_random_uuid();
  s_vet_res uuid := gen_random_uuid();
  s_c uuid;
  s_c_otro uuid;
  s_c_res uuid;
  s_p1 uuid;
  s_p2 uuid;
  s_p3 uuid;
  s_pi uuid;
  s_mov uuid;
  s_mov2 uuid;
  s_mov_alta uuid;
  s_pc uuid;
  s_row record;
  s_n int;
  s_n2 int;
  s_cod text;
  s_t text;
  s_p text;
  s_sql text;
  -- Fase 7 (bloque T)
  t_vet_admin uuid := gen_random_uuid();
  t_vet_col uuid := gen_random_uuid();
  t_vet_col2 uuid := gen_random_uuid();
  t_vet_q uuid := gen_random_uuid();
  t_vet_otro uuid := gen_random_uuid();
  t_c uuid;
  t_c_otro uuid;
  t_cli uuid;
  t_cli2 uuid;
  t_cli_otro uuid;
  t_m uuid;
  t_m2 uuid;
  t_m_otro uuid;
  t_p1 uuid;
  t_p2 uuid;
  t_p_arch uuid;
  t_p_otro uuid;
  t_s1 uuid;
  t_s_otro uuid;
  t_cita uuid;
  t_cita2 uuid;
  t_cons uuid;
  t_cobro uuid;
  t_cobro2 uuid;
  t_cobro3 uuid;
  t_cot uuid;
  t_cot2 uuid;
  t_cot3 uuid;
  t_cc_conv uuid;
  t_cc_cita uuid;
  t_cc_cons uuid;
  t_clave uuid;
  t_clave2 uuid;
  t_hoy date;
  t_n int;
  t_n2 int;
  t_n3 int;
  t_n4 int;
  t_row record;
  t_sql text;
  t_json jsonb;
  t_cod text;
  t_items jsonb;
  t_t text;
  t_p text;
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
  -- Fase 5, bloque Q (Q1..Q48): vacunación y desparasitación + logo de la clínica.
  -- Las derivaciones usan fechas explícitas (q_hoy fijo) salvo Q24-Q26, que dependen
  -- de _hoy_bogota() por el corte de 180 días. Todo se revierte con el resto del script.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  q_logo := clinica_a_id::text || '/logo-1700000000000.jpg';

  -- Setup Q: dos veterinarios NO admin en la clínica A (uno solo retirado de clínica en Q28),
  -- un dueño con nombre largo y una mascota con dosis (una anulada) para el carné público.
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values
      (q_vet_noadmin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-q-noadmin@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Q NoAdmin', 'clinica_nombre', 'Smoke Clinica Q1'),
       now(), now()),
      (q_vet_x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-q-x@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Q X', 'clinica_nombre', 'Smoke Clinica Q2'),
       now(), now());
    update public.perfiles set clinica_id = clinica_a_id, rol_clinica = 'veterinario', activo = true
      where id in (q_vet_noadmin, q_vet_x);

    insert into public.clientes (clinica_id, nombre, telefono)
      values (clinica_a_id, 'Ana María Rojas Pérez', '3009998877') returning id into q_cliente_ana;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie, fecha_nacimiento)
      values (q_cliente_ana, clinica_a_id, 'Q Luna', 'perro', q_hoy - 400) returning id into q_m_ana;

    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_dosis := public.registrar_dosis(
      p_mascota_id => q_m_ana, p_codigo_protocolo => 'bordetella', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2026-04-01', p_observaciones => 'nota interna secreta', p_lote => 'LOTE-Q1');
    q_dosis2 := public.registrar_dosis(
      p_mascota_id => q_m_ana, p_codigo_protocolo => 'polivalente', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2026-04-02');
    perform public.anular_dosis(q_dosis2, 'Error de registro Q');
  exception when others then
    failures := failures || ('SETUPQ error inesperado: ' || sqlerrm);
  end;

  -- Q1: protocolos_efectivos('perro') devuelve las 7 semillas de perro.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select array_agg(codigo order by codigo) into q_arr from public.protocolos_efectivos('perro');
    if q_arr is distinct from array['antirrabica', 'bordetella', 'desp_externa', 'desp_interna',
                                    'leptospirosis', 'polivalente', 'puppy_dp'] then
      failures := failures || ('Q1 protocolos_efectivos(perro) devolvió: ' || coalesce(array_to_string(q_arr, ','), 'null'));
    end if;
  exception when others then
    failures := failures || ('Q1 error inesperado: ' || sqlerrm);
  end;

  -- Q2: registrar_dosis feliz: veterinario_id = vet A, biologico_nombre sale del catálogo.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m2', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_dosis := public.registrar_dosis(q_m, 'polivalente', null, date '2026-04-01');
    perform set_config('role', 'postgres', true);
    select veterinario_id, biologico_nombre into q_row from public.dosis_aplicadas where id = q_dosis;
    if q_row.veterinario_id is distinct from vet_a_id or q_row.biologico_nombre is distinct from 'Polivalente' then
      failures := failures || format('Q2 dosis guardada con veterinario=%s nombre=%s', q_row.veterinario_id, q_row.biologico_nombre);
    end if;
  exception when others then
    failures := failures || ('Q2 error inesperado: ' || sqlerrm);
  end;

  -- Q3: vet B ve 0 dosis (las de A existen: control positivo con vet A).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into n from public.dosis_aplicadas;
    if n <> 0 then failures := failures || format('Q3 vet B ve %s dosis de la clínica A', n); end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into n from public.dosis_aplicadas;
    if n < 1 then failures := failures || 'Q3 vet A no ve sus propias dosis'; end if;
  exception when others then
    failures := failures || ('Q3 error inesperado: ' || sqlerrm);
  end;

  -- Q4: vet B no puede registrar una dosis sobre una mascota de A.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2026-04-02');
    failures := failures || 'Q4 vet B pudo registrar una dosis en una mascota de A';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q4 error inesperado: ' || sqlerrm);
  end;

  -- Q5: INSERT directo en dosis_aplicadas como authenticated falla.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    insert into public.dosis_aplicadas (mascota_id, clinica_id, veterinario_id, codigo_protocolo, biologico_nombre, tipo, fecha_aplicacion)
      values (q_m, clinica_a_id, vet_a_id, 'polivalente', 'Directa', 'vacuna', date '2026-04-03');
    failures := failures || 'Q5 INSERT directo en dosis_aplicadas debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q5 error inesperado: ' || sqlerrm);
  end;

  -- Q6: UPDATE directo cambia 0 filas (o es rechazado).
  checks := checks + 1;
  begin
    update public.dosis_aplicadas set observaciones = 'manipulada' where id = q_dosis;
    get diagnostics n = row_count;
    if n <> 0 then failures := failures || format('Q6 UPDATE directo afectó %s filas', n); end if;
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q6 error inesperado: ' || sqlerrm);
  end;

  -- Q7: DELETE directo cambia 0 filas (o es rechazado).
  checks := checks + 1;
  begin
    delete from public.dosis_aplicadas where id = q_dosis;
    get diagnostics n = row_count;
    if n <> 0 then failures := failures || format('Q7 DELETE directo afectó %s filas', n); end if;
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q7 error inesperado: ' || sqlerrm);
  end;

  -- Q8: fecha futura -> check_violation.
  checks := checks + 1;
  begin
    perform public.registrar_dosis(q_m, 'bordetella', null, public._hoy_bogota() + 1);
    failures := failures || 'Q8 una dosis con fecha futura debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('Q8 error inesperado: ' || sqlerrm);
  end;

  -- Q9: anular con motivo en blanco -> check_violation.
  checks := checks + 1;
  begin
    perform public.anular_dosis(q_dosis, '   ');
    failures := failures || 'Q9 anular con motivo en blanco debía fallar';
  exception
    when check_violation then null;
    when others then failures := failures || ('Q9 error inesperado: ' || sqlerrm);
  end;

  -- Q10: una dosis se anula una sola vez (D-08); el segundo intento falla.
  checks := checks + 1;
  begin
    perform public.anular_dosis(q_dosis, 'Error de digitación');
    begin
      perform public.anular_dosis(q_dosis, 'Otra vez');
      failures := failures || 'Q10 la segunda anulación debía fallar';
    exception
      when check_violation then null;
      when others then failures := failures || ('Q10 segunda anulación: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    select anulada, motivo_anulacion, anulada_por into q_row from public.dosis_aplicadas where id = q_dosis;
    if q_row.anulada is not true or q_row.motivo_anulacion is distinct from 'Error de digitación'
       or q_row.anulada_por is distinct from vet_a_id then
      failures := failures || 'Q10 la dosis no quedó anulada con motivo y autor';
    end if;
  exception when others then
    failures := failures || ('Q10 error inesperado: ' || sqlerrm);
  end;

  -- Q11: anulada no cuenta para la serie (Pitfall 4): la dosis que queda es la posición 1.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m11', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_dosis := public.registrar_dosis(q_m, 'polivalente', null, date '2026-03-01');
    q_dosis2 := public.registrar_dosis(q_m, 'polivalente', null, date '2026-03-22');
    perform public.anular_dosis(q_dosis, 'Fecha mal digitada');
    perform set_config('role', 'postgres', true);
    select po.posicion, po.etiqueta_dosis into q_row
      from public._dosis_posiciones(clinica_a_id, q_m) po where po.dosis_id = q_dosis2;
    if q_row.posicion is distinct from 1 or q_row.etiqueta_dosis is distinct from 'Dosis 1 de 3' then
      failures := failures || format('Q11 tras anular la dosis 1 la restante es posicion=%s etiqueta=%s', q_row.posicion, q_row.etiqueta_dosis);
    end if;
  exception when others then
    failures := failures || ('Q11 error inesperado: ' || sqlerrm);
  end;

  -- Q12: polivalente con una dosis -> próxima +21 días, "Dosis 2 de 3".
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m12', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2026-04-01');
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'polivalente';
    if q_row.proxima_fecha is distinct from date '2026-04-22' or q_row.etiqueta_proxima is distinct from 'Dosis 2 de 3' then
      failures := failures || format('Q12 proxima=%s etiqueta=%s', q_row.proxima_fecha, q_row.etiqueta_proxima);
    end if;
  exception when others then
    failures := failures || ('Q12 error inesperado: ' || sqlerrm);
  end;

  -- Q13: tres dosis -> "Refuerzo", próxima = última + 365.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m13', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2026-01-01');
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2026-01-22');
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2026-02-12');
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'polivalente';
    if q_row.etiqueta_proxima is distinct from 'Refuerzo' or q_row.proxima_fecha is distinct from date '2026-02-12' + 365 then
      failures := failures || format('Q13 etiqueta=%s proxima=%s', q_row.etiqueta_proxima, q_row.proxima_fecha);
    end if;
  exception when others then
    failures := failures || ('Q13 error inesperado: ' || sqlerrm);
  end;

  -- Q14: antirrábica con duración 1095 -> +1095; con 999 -> check_violation (D-03).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m14', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'antirrabica', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2026-01-10', p_duracion_elegida_dias => 1095);
    begin
      perform public.registrar_dosis(
        p_mascota_id => q_m, p_codigo_protocolo => 'antirrabica', p_biologico_nombre => null,
        p_fecha_aplicacion => date '2026-01-11', p_duracion_elegida_dias => 999);
      failures := failures || 'Q14 una duración fuera de las opciones debía fallar';
    exception
      when check_violation then null;
      when others then failures := failures || ('Q14 duración 999: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'antirrabica';
    if q_row.proxima_fecha is distinct from date '2026-01-10' + 1095 then
      failures := failures || format('Q14 proxima=%s esperaba %s', q_row.proxima_fecha, date '2026-01-10' + 1095);
    end if;
  exception when others then
    failures := failures || ('Q14 error inesperado: ' || sqlerrm);
  end;

  -- Q15: sin_refuerzo -> estado completo y próxima nula.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m15', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'antirrabica', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2026-01-10', p_sin_refuerzo => true);
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'antirrabica';
    if q_row.estado is distinct from 'completo' or q_row.proxima_fecha is not null then
      failures := failures || format('Q15 estado=%s proxima=%s', q_row.estado, q_row.proxima_fecha);
    end if;
  exception when others then
    failures := failures || ('Q15 error inesperado: ' || sqlerrm);
  end;

  -- Q16: es_refuerzo en la primera dosis de polivalente -> posición 3, próxima +365.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m16', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'polivalente', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2026-01-10', p_es_refuerzo => true);
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'polivalente';
    if q_row.posicion is distinct from 3 or q_row.proxima_fecha is distinct from date '2026-01-10' + 365 then
      failures := failures || format('Q16 posicion=%s proxima=%s', q_row.posicion, q_row.proxima_fecha);
    end if;
  exception when others then
    failures := failures || ('Q16 error inesperado: ' || sqlerrm);
  end;

  -- Q17: inicia_serie reinicia la serie -> posición 1 aunque ya hubiera tres dosis.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m17', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2025-03-01');
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2025-03-22');
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2025-04-12');
    perform public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'polivalente', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2026-05-20', p_inicia_serie => true);
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'polivalente';
    if q_row.posicion is distinct from 1 or q_row.proxima_fecha is distinct from date '2026-05-20' + 21 then
      failures := failures || format('Q17 posicion=%s proxima=%s', q_row.posicion, q_row.proxima_fecha);
    end if;
  exception when others then
    failures := failures || ('Q17 error inesperado: ' || sqlerrm);
  end;

  -- Q18: ventana de refuerzo (D-11): faltan 15 días -> al_dia; faltan 14 -> proxima. (q_m y q_prox se reusan en Q21.)
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m18', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'polivalente', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2025-03-01', p_es_refuerzo => true);
    perform set_config('role', 'postgres', true);
    q_prox := date '2025-03-01' + 365;
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_prox - 15) f where f.codigo_protocolo = 'polivalente';
    select * into q_row2 from public._carne_filas(clinica_a_id, q_m, q_prox - 14) f where f.codigo_protocolo = 'polivalente';
    if q_row.estado is distinct from 'al_dia' or q_row2.estado is distinct from 'proxima' then
      failures := failures || format('Q18 -15d=%s -14d=%s', q_row.estado, q_row2.estado);
    end if;
  exception when others then
    failures := failures || ('Q18 error inesperado: ' || sqlerrm);
  end;

  -- Q19: ventana de serie: faltan 4 -> al_dia; faltan 3 -> proxima.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m19', 'perro') returning id into q_m_b;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m_b, 'polivalente', null, date '2026-04-01');
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m_b, date '2026-04-22' - 4) f where f.codigo_protocolo = 'polivalente';
    select * into q_row2 from public._carne_filas(clinica_a_id, q_m_b, date '2026-04-22' - 3) f where f.codigo_protocolo = 'polivalente';
    if q_row.estado is distinct from 'al_dia' or q_row2.estado is distinct from 'proxima' then
      failures := failures || format('Q19 -4d=%s -3d=%s', q_row.estado, q_row2.estado);
    end if;
  exception when others then
    failures := failures || ('Q19 error inesperado: ' || sqlerrm);
  end;

  -- Q20: ventana de desparasitación: faltan 6 -> al_dia; faltan 5 -> proxima.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m20', 'perro') returning id into q_m_b;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m_b, 'desp_interna', null, date '2025-03-01');
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m_b, date '2025-03-01' + 90 - 6) f where f.codigo_protocolo = 'desp_interna';
    select * into q_row2 from public._carne_filas(clinica_a_id, q_m_b, date '2025-03-01' + 90 - 5) f where f.codigo_protocolo = 'desp_interna';
    if q_row.estado is distinct from 'al_dia' or q_row2.estado is distinct from 'proxima' then
      failures := failures || format('Q20 -6d=%s -5d=%s', q_row.estado, q_row2.estado);
    end if;
  exception when others then
    failures := failures || ('Q20 error inesperado: ' || sqlerrm);
  end;

  -- Q21: el mismo día de la próxima -> proxima; un día después -> vencida con dias_vencida = 1 (D-11). Usa q_m/q_prox de Q18.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_prox) f where f.codigo_protocolo = 'polivalente';
    select * into q_row2 from public._carne_filas(clinica_a_id, q_m, q_prox + 1) f where f.codigo_protocolo = 'polivalente';
    if q_row.estado is distinct from 'proxima' or q_row2.estado is distinct from 'vencida'
       or q_row2.dias_vencida is distinct from 1 then
      failures := failures || format('Q21 hoy=prox:%s, +1d:%s dias_vencida=%s', q_row.estado, q_row2.estado, q_row2.dias_vencida);
    end if;
  exception when others then
    failures := failures || ('Q21 error inesperado: ' || sqlerrm);
  end;

  -- Q22: desparasitación interna por edad (D-03): cachorro de 20 días -> +15; adulto -> +90.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie, fecha_nacimiento)
      values (cliente_a_id, clinica_a_id, 'Q cachorro', 'perro', q_hoy - 30) returning id into q_m_cach;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie, fecha_nacimiento)
      values (cliente_a_id, clinica_a_id, 'Q adulto', 'perro', q_hoy - 400) returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m_cach, 'desp_interna', null, date '2026-05-22');
    perform public.registrar_dosis(q_m, 'desp_interna', null, date '2026-05-22');
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m_cach, q_hoy) f where f.codigo_protocolo = 'desp_interna';
    select * into q_row2 from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'desp_interna';
    if q_row.proxima_fecha is distinct from date '2026-05-22' + 15 or q_row2.proxima_fecha is distinct from date '2026-05-22' + 90 then
      failures := failures || format('Q22 cachorro=%s adulto=%s', q_row.proxima_fecha, q_row2.proxima_fecha);
    end if;
  exception when others then
    failures := failures || ('Q22 error inesperado: ' || sqlerrm);
  end;

  -- Q23: una dosis externa cuenta para la serie (posición avanza) y se marca externa en el carné.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m23', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2026-03-01');
    perform public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'polivalente', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2026-03-22', p_externa => true, p_clinica_externa => 'Otra Clínica Vet');
    q_json := public.carne_de_mascota(q_m);
    perform set_config('role', 'postgres', true);
    select * into q_row from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'polivalente';
    if q_row.posicion is distinct from 2 or q_row.etiqueta_proxima is distinct from 'Dosis 3 de 3'
       or not (q_json -> 'dosis') @> '[{"externa": true}]'::jsonb then
      failures := failures || format('Q23 posicion=%s etiqueta=%s o la dosis externa no está marcada', q_row.posicion, q_row.etiqueta_proxima);
    end if;
  exception when others then
    failures := failures || ('Q23 error inesperado: ' || sqlerrm);
  end;

  -- Q24: D-13 (depende de hoy): vencida de 180 días aparece; de 181 queda oculta (ocultas_antiguas).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m24a', 'perro') returning id into q_m;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m24b', 'perro') returning id into q_m_b;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_dosis := public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'polivalente', p_biologico_nombre => null,
      p_fecha_aplicacion => public._hoy_bogota() - 545, p_es_refuerzo => true);
    q_dosis2 := public.registrar_dosis(
      p_mascota_id => q_m_b, p_codigo_protocolo => 'polivalente', p_biologico_nombre => null,
      p_fecha_aplicacion => public._hoy_bogota() - 546, p_es_refuerzo => true);
    select count(*) into n from public.vacunas_pendientes() where mascota_id = q_m;
    select count(*) into q_n from public.vacunas_pendientes() where mascota_id = q_m_b;
    select * into q_row from public.vacunas_resumen();
    if n <> 1 or q_n <> 0 then
      failures := failures || format('Q24 a 180 dias aparece %s veces y a 181 dias %s veces', n, q_n);
    end if;
    if q_row.vencidas < 1 or q_row.ocultas_antiguas < 1 then
      failures := failures || format('Q24 vacunas_resumen vencidas=%s ocultas_antiguas=%s', q_row.vencidas, q_row.ocultas_antiguas);
    end if;
  exception when others then
    failures := failures || ('Q24 error inesperado: ' || sqlerrm);
  end;

  -- Q25: posponer 7 días oculta la alerta; restaurar la devuelve (usa q_m/q_dosis de Q24).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.gestionar_alerta_vacuna(q_dosis, 'posponer', null, 7);
    select count(*) into n from public.vacunas_pendientes() where mascota_id = q_m;
    perform public.gestionar_alerta_vacuna(q_dosis, 'restaurar');
    select count(*) into q_n from public.vacunas_pendientes() where mascota_id = q_m;
    if n <> 0 or q_n <> 1 then
      failures := failures || format('Q25 pospuesta=%s restaurada=%s (esperaba 0 y 1)', n, q_n);
    end if;
  exception when others then
    failures := failures || ('Q25 error inesperado: ' || sqlerrm);
  end;

  -- Q26: descartar oculta; una dosis nueva del mismo biológico muestra la alerta nueva (D-12).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.gestionar_alerta_vacuna(q_dosis, 'descartar', 'No volverá', null);
    select count(*) into n from public.vacunas_pendientes() where mascota_id = q_m;
    q_dosis3 := public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'polivalente', p_biologico_nombre => null,
      p_fecha_aplicacion => public._hoy_bogota() - 380, p_es_refuerzo => true);
    select count(*) into q_n from public.vacunas_pendientes()
      where mascota_id = q_m and codigo_protocolo = 'polivalente' and ultima_dosis_id = q_dosis3;
    if n <> 0 or q_n <> 1 then
      failures := failures || format('Q26 descartada=%s alerta nueva tras dosis=%s (esperaba 0 y 1)', n, q_n);
    end if;
  exception when others then
    failures := failures || ('Q26 error inesperado: ' || sqlerrm);
  end;

  -- Q27: vet B no gestiona alertas de una dosis de A.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    perform public.gestionar_alerta_vacuna(q_dosis, 'descartar', 'intruso', null);
    failures := failures || 'Q27 vet B pudo gestionar una alerta de la clínica A';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q27 error inesperado: ' || sqlerrm);
  end;

  -- Q28: D-09: quien solo dejó una dosis en A y pasó a la clínica B sigue legible por vet A.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m28', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', q_vet_x, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m, 'bordetella', null, date '2026-04-10');
    perform set_config('role', 'postgres', true);
    update public.perfiles set clinica_id = clinica_b_id where id = q_vet_x;
    if not exists (select 1 from public.perfiles where id = q_vet_x and clinica_id = clinica_b_id) then
      failures := failures || 'Q28 setup: el autor no quedó en la clínica B';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into n from public.perfiles where id = q_vet_x;
    if n <> 1 then
      failures := failures || format('Q28 vet A ve %s perfiles del autor de dosis movido de clínica (esperaba 1)', n);
    end if;
  exception when others then
    failures := failures || ('Q28 error inesperado: ' || sqlerrm);
  end;

  -- Q29: la FK dosis_veterinario_perfil_fkey existe y es restrict.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  if (select count(*) from pg_constraint
        where conname = 'dosis_veterinario_perfil_fkey' and conrelid = 'public.dosis_aplicadas'::regclass
          and contype = 'f' and confdeltype = 'r') <> 1 then
    failures := failures || 'Q29 falta dosis_veterinario_perfil_fkey o no es restrict';
  end if;

  -- Q30: obtener_o_crear_enlace_carne devuelve 64 hex y el mismo token en la segunda llamada.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_tok := public.obtener_o_crear_enlace_carne(q_m_ana);
    q_tok2 := public.obtener_o_crear_enlace_carne(q_m_ana);
    if q_tok is null or q_tok !~ '^[0-9a-f]{64}$' or q_tok2 is distinct from q_tok then
      failures := failures || format('Q30 token=%s segunda llamada=%s', q_tok, q_tok2);
    end if;
  exception when others then
    failures := failures || ('Q30 error inesperado: ' || sqlerrm);
  end;

  -- Q31: regenerar cambia el token; el viejo deja de funcionar y el nuevo sí (D-16).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_tok2 := public.regenerar_enlace_carne(q_m_ana);
    perform set_config('role', 'postgres', true);
    if q_tok2 is null or q_tok2 = q_tok then
      failures := failures || 'Q31 el token regenerado debía ser distinto';
    end if;
    if public.carne_publico(q_tok) is not null then
      failures := failures || 'Q31 el token viejo sigue devolviendo el carné';
    end if;
    if public.carne_publico(q_tok2) is null then
      failures := failures || 'Q31 el token nuevo no devuelve el carné';
    end if;
    q_tok := q_tok2;
  exception when others then
    failures := failures || ('Q31 error inesperado: ' || sqlerrm);
  end;

  -- Q32: forma del carné público (D-15, D-20): claves exactas, sin ids ni contacto, "Nombre I.".
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    q_json := public.carne_publico(q_tok);
    select array_agg(k order by k) into q_arr from jsonb_object_keys(q_json) k;
    if q_arr is distinct from array['biologicos', 'clinica', 'dosis', 'hoy', 'mascota', 'propietario'] then
      failures := failures || ('Q32 claves de primer nivel: ' || coalesce(array_to_string(q_arr, ','), 'null'));
    end if;
    if (q_json -> 'mascota' -> 'id') is not null or (q_json -> 'mascota' -> 'dueno_id') is not null then
      failures := failures || 'Q32 la mascota pública expone id o dueno_id';
    end if;
    if q_json ->> 'propietario' is distinct from 'Ana M.' then
      failures := failures || format('Q32 propietario=%s esperaba "Ana M."', q_json ->> 'propietario');
    end if;
    if q_json::text like '%3009998877%' or q_json::text like '%Rojas%' or q_json::text like '%nota interna%' then
      failures := failures || 'Q32 el carné público filtra teléfono, apellido completo u observaciones internas';
    end if;
  exception when others then
    failures := failures || ('Q32 error inesperado: ' || sqlerrm);
  end;

  -- Q33: una dosis anulada no sale en el carné público (D-23) pero sí (anulada) en el del veterinario.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    q_json := public.carne_publico(q_tok);
    if jsonb_array_length(q_json -> 'dosis') <> 1
       or (q_json -> 'dosis') @> '[{"biologico_nombre": "Polivalente"}]'::jsonb then
      failures := failures || format('Q33 el carné público trae %s dosis (esperaba 1, sin la anulada)', jsonb_array_length(q_json -> 'dosis'));
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_json := public.carne_de_mascota(q_m_ana);
    if not (q_json -> 'dosis') @> '[{"anulada": true}]'::jsonb then
      failures := failures || 'Q33 carne_de_mascota no muestra la dosis anulada';
    end if;
  exception when others then
    failures := failures || ('Q33 error inesperado: ' || sqlerrm);
  end;

  -- Q34: anon no puede ejecutar ninguna RPC ni función interna nueva.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  begin
  foreach q_sig in array array[
    'public.protocolos_efectivos(text,boolean)',
    'public.guardar_protocolo(text,text,text,text[],int,int,int,int[])',
    'public.restablecer_protocolo(text)',
    'public.desactivar_protocolo(text)',
    'public.registrar_dosis(uuid,text,text,date,int,boolean,boolean,boolean,boolean,text,text,text,text,uuid,boolean)',
    'public.anular_dosis(uuid,text)',
    'public.previsualizar_dosis(uuid,text,date,int,boolean,boolean,boolean)',
    'public.carne_de_mascota(uuid)',
    'public.vacunas_pendientes()',
    'public.vacunas_resumen()',
    'public.vacunas_resumen_mascotas()',
    'public.gestionar_alerta_vacuna(uuid,text,text,int)',
    'public.obtener_o_crear_enlace_carne(uuid)',
    'public.regenerar_enlace_carne(uuid)',
    'public.carne_publico(text)',
    'public._carne_filas(uuid,uuid,date)',
    'public._dosis_posiciones(uuid,uuid)'
  ] loop
    if has_function_privilege('anon', q_sig, 'execute') then
      failures := failures || ('Q34 anon puede ejecutar ' || q_sig);
    end if;
  end loop;
  exception when others then
    failures := failures || ('Q34 error inesperado: ' || sqlerrm);
  end;

  -- Q35: authenticated NO ejecuta carne_publico / _carne_filas / _dosis_posiciones (VAC-04).
  checks := checks + 1;
  begin
  foreach q_sig in array array[
    'public.carne_publico(text)',
    'public._carne_filas(uuid,uuid,date)',
    'public._dosis_posiciones(uuid,uuid)'
  ] loop
    if has_function_privilege('authenticated', q_sig, 'execute') then
      failures := failures || ('Q35 authenticated puede ejecutar ' || q_sig);
    end if;
  end loop;
  exception when others then
    failures := failures || ('Q35 error inesperado: ' || sqlerrm);
  end;

  -- Q36: vet B no ve enlaces de A ni su carné (control positivo: vet A sí ve el enlace).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into n from public.carne_enlaces;
    if n < 1 then failures := failures || 'Q36 vet A no ve su propio enlace de carné'; end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into n from public.carne_enlaces;
    if n <> 0 then failures := failures || format('Q36 vet B ve %s enlaces de la clínica A', n); end if;
    begin
      perform public.carne_de_mascota(q_m_ana);
      failures := failures || 'Q36 vet B pudo leer el carné de una mascota de A';
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('Q36 carne_de_mascota: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('Q36 error inesperado: ' || sqlerrm);
  end;

  -- Q37: solo el admin edita el catálogo (D-24); el override de polivalente queda como personalizado.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', q_vet_noadmin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.guardar_protocolo('polivalente', 'Polivalente', 'vacuna', array['perro'], 3, 28, 365, '{}'::int[]);
      failures := failures || 'Q37 un veterinario no admin pudo modificar el catálogo';
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('Q37 no admin: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.guardar_protocolo('polivalente', 'Polivalente', 'vacuna', array['perro'], 3, 28, 365, '{}'::int[]);
    select personalizado, intervalo_serie_dias into q_row from public.protocolos_efectivos('perro') where codigo = 'polivalente';
    if q_row.personalizado is not true or q_row.intervalo_serie_dias is distinct from 28 then
      failures := failures || format('Q37 override: personalizado=%s intervalo=%s', q_row.personalizado, q_row.intervalo_serie_dias);
    end if;
  exception when others then
    failures := failures || ('Q37 error inesperado: ' || sqlerrm);
  end;

  -- Q38: el override de A no se filtra a B; después se restablece el catálogo de A.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select personalizado, intervalo_serie_dias into q_row from public.protocolos_efectivos('perro') where codigo = 'polivalente';
    if q_row.personalizado is not false or q_row.intervalo_serie_dias is distinct from 21 then
      failures := failures || format('Q38 vet B ve personalizado=%s intervalo=%s (esperaba false y 21)', q_row.personalizado, q_row.intervalo_serie_dias);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.restablecer_protocolo('polivalente');
    select personalizado into q_row from public.protocolos_efectivos('perro') where codigo = 'polivalente';
    if q_row.personalizado is not false then
      failures := failures || 'Q38 restablecer_protocolo no devolvió la semilla';
    end if;
  exception when others then
    failures := failures || ('Q38 error inesperado: ' || sqlerrm);
  end;

  -- Q39: D-22: la cita debe incluir a la mascota; con una cita válida se guarda cita_id.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m39', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_cita := public.crear_cita(cliente_a_id, array[q_m], now() + interval '9 days');
    q_cita2 := public.crear_cita(cliente_a_id, array[mascota_a_id], now() + interval '10 days');
    begin
      perform public.registrar_dosis(
        p_mascota_id => q_m, p_codigo_protocolo => 'bordetella', p_biologico_nombre => null,
        p_fecha_aplicacion => date '2026-04-10', p_cita_id => q_cita2);
      failures := failures || 'Q39 una cita que no incluye a la mascota debía fallar';
    exception
      when foreign_key_violation then null;
      when others then failures := failures || ('Q39 cita ajena: error inesperado: ' || sqlerrm);
    end;
    q_dosis := public.registrar_dosis(
      p_mascota_id => q_m, p_codigo_protocolo => 'bordetella', p_biologico_nombre => null,
      p_fecha_aplicacion => date '2026-04-10', p_cita_id => q_cita);
    perform set_config('role', 'postgres', true);
    if not exists (select 1 from public.dosis_aplicadas where id = q_dosis and cita_id = q_cita) then
      failures := failures || 'Q39 la dosis no guardó cita_id';
    end if;
  exception when others then
    failures := failures || ('Q39 error inesperado: ' || sqlerrm);
  end;

  -- Q40: previsualizar_dosis coincide con lo que _carne_filas informa tras registrar la misma dosis.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (cliente_a_id, clinica_a_id, 'Q m40', 'perro') returning id into q_m;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2026-04-01');
    select * into q_row from public.previsualizar_dosis(q_m, 'polivalente', date '2026-04-22');
    perform public.registrar_dosis(q_m, 'polivalente', null, date '2026-04-22');
    perform set_config('role', 'postgres', true);
    select * into q_row2 from public._carne_filas(clinica_a_id, q_m, q_hoy) f where f.codigo_protocolo = 'polivalente';
    if q_row.proxima_fecha is null
       or q_row.proxima_fecha is distinct from q_row2.proxima_fecha
       or q_row.etiqueta_proxima is distinct from q_row2.etiqueta_proxima
       or q_row.posicion is distinct from q_row2.posicion then
      failures := failures || format('Q40 previsualizar=(%s,%s,%s) vs carne=(%s,%s,%s)',
        q_row.posicion, q_row.proxima_fecha, q_row.etiqueta_proxima,
        q_row2.posicion, q_row2.proxima_fecha, q_row2.etiqueta_proxima);
    end if;
  exception when others then
    failures := failures || ('Q40 error inesperado: ' || sqlerrm);
  end;

  -- Q41: esquema del logo: columna logo_path y bucket clinica-logos privado, 1 MB, solo JPEG (D-26).
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  if not exists (
       select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'clinicas' and column_name = 'logo_path'
     ) or not exists (
       select 1 from storage.buckets
       where id = 'clinica-logos' and public = false and file_size_limit = 1048576
         and allowed_mime_types = array['image/jpeg']
     ) then
    failures := failures || 'Q41 falta clinicas.logo_path o el bucket clinica-logos no es privado/1 MB/solo JPEG';
  end if;

  -- Q42: el admin sube el logo; un veterinario no admin no puede.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    insert into storage.objects (bucket_id, name) values ('clinica-logos', q_logo);
  exception when others then
    failures := failures || ('Q42 el admin no pudo subir el logo: ' || sqlerrm);
  end;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', q_vet_noadmin, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    insert into storage.objects (bucket_id, name)
      values ('clinica-logos', clinica_a_id::text || '/logo-1700000000001.jpg');
    failures := failures || 'Q42 un veterinario no admin pudo subir un logo';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q42 no admin: error inesperado: ' || sqlerrm);
  end;

  -- Q43: el admin no escribe en la carpeta de otra clínica ni con nombres fuera del patrón.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    insert into storage.objects (bucket_id, name)
      values ('clinica-logos', clinica_b_id::text || '/logo-1700000000000.jpg');
    failures := failures || 'Q43 el admin de A pudo escribir en la carpeta de B';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q43 carpeta de B: error inesperado: ' || sqlerrm);
  end;
  begin
    insert into storage.objects (bucket_id, name) values ('clinica-logos', clinica_a_id::text || '/../x.jpg');
    failures := failures || 'Q43 un nombre con ../ debía ser rechazado';
  exception when others then null;
  end;
  begin
    insert into storage.objects (bucket_id, name)
      values ('clinica-logos', clinica_a_id::text || '/sub/logo-1700000000002.jpg');
    failures := failures || 'Q43 un nombre en subcarpeta debía ser rechazado';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q43 subcarpeta: error inesperado: ' || sqlerrm);
  end;
  begin
    insert into storage.objects (bucket_id, name)
      values ('clinica-logos', clinica_a_id::text || '/logo-1700000000003.png');
    failures := failures || 'Q43 un logo .png debía ser rechazado';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q43 png: error inesperado: ' || sqlerrm);
  end;

  -- Q44: vet B no ve el logo de A; los miembros de A sí; un no admin no puede borrarlo.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into n from storage.objects
      where bucket_id = 'clinica-logos' and name like clinica_a_id::text || '/%';
    if n <> 0 then failures := failures || format('Q44 vet B ve %s logos de la clínica A', n); end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', q_vet_noadmin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into n from storage.objects
      where bucket_id = 'clinica-logos' and name like clinica_a_id::text || '/%';
    if n <> 1 then failures := failures || format('Q44 un miembro de A ve %s logos (esperaba 1)', n); end if;
    begin
      delete from storage.objects where bucket_id = 'clinica-logos';
      get diagnostics n = row_count;
      if n <> 0 then failures := failures || format('Q44 un no admin borró %s logos', n); end if;
    exception when others then null;
    end;
    perform set_config('role', 'postgres', true);
    if not exists (select 1 from storage.objects where bucket_id = 'clinica-logos' and name = q_logo) then
      failures := failures || 'Q44 el logo desapareció tras el intento de borrado de un no admin';
    end if;
  exception when others then
    failures := failures || ('Q44 error inesperado: ' || sqlerrm);
  end;

  -- Q45: actualizar_clinica es solo admin y no hay UPDATE directo sobre clinicas.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', q_vet_noadmin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.actualizar_clinica('Hack', 'x', 'y', '1', null);
      failures := failures || 'Q45 un veterinario no admin pudo ejecutar actualizar_clinica';
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('Q45 no admin: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      update public.clinicas set nombre = 'x' where id = clinica_a_id;
      get diagnostics n = row_count;
      if n <> 0 then failures := failures || format('Q45 UPDATE directo sobre clinicas afectó %s filas', n); end if;
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('Q45 UPDATE directo: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('Q45 error inesperado: ' || sqlerrm);
  end;

  -- Q46: validaciones de actualizar_clinica y camino feliz (recorta espacios, guarda logo_path).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.actualizar_clinica('   ', 'Cali', 'Cra 1', '3000000000', null);
      failures := failures || 'Q46 un nombre en blanco debía fallar';
    exception
      when check_violation then null;
      when others then failures := failures || ('Q46 nombre en blanco: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.actualizar_clinica('Clínica Smoke', 'Cali', 'Cra 1', '3000000000',
        clinica_b_id::text || '/logo-1700000000000.jpg');
      failures := failures || 'Q46 un logo en la carpeta de B debía fallar';
    exception
      when check_violation then null;
      when others then failures := failures || ('Q46 logo de B: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.actualizar_clinica('Clínica Smoke', 'Cali', 'Cra 1', '3000000000',
        clinica_a_id::text || '/logo-1700000000099.jpg');
      failures := failures || 'Q46 un logo inexistente en storage debía fallar';
    exception
      when check_violation then null;
      when others then failures := failures || ('Q46 logo inexistente: error inesperado: ' || sqlerrm);
    end;
    q_json := public.actualizar_clinica('  Clínica Smoke ', 'Cali', 'Cra 1', '3000000000', q_logo);
    if q_json ->> 'logo_path' is distinct from q_logo then
      failures := failures || format('Q46 actualizar_clinica devolvió logo_path=%s', q_json ->> 'logo_path');
    end if;
    perform set_config('role', 'postgres', true);
    if not exists (
      select 1 from public.clinicas where id = clinica_a_id and nombre = 'Clínica Smoke' and logo_path = q_logo
    ) then
      failures := failures || 'Q46 la fila de clinicas no quedó con nombre recortado y logo_path';
    end if;
  exception when others then
    failures := failures || ('Q46 error inesperado: ' || sqlerrm);
  end;

  -- Q47: el logo viaja como ruta en el carné (veterinario y público), sin URL ni token; null al quitarlo.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    q_json := public.carne_de_mascota(q_m_ana);
    if q_json -> 'clinica' ->> 'logo_path' is distinct from q_logo then
      failures := failures || format('Q47 carne_de_mascota logo_path=%s', q_json -> 'clinica' ->> 'logo_path');
    end if;
    perform set_config('role', 'postgres', true);
    q_json := public.carne_publico(q_tok);
    select array_agg(k order by k) into q_arr from jsonb_object_keys(q_json -> 'clinica') k;
    if q_arr is distinct from array['ciudad', 'direccion', 'logo_path', 'nombre', 'telefono'] then
      failures := failures || ('Q47 claves de clinica en el carné público: ' || coalesce(array_to_string(q_arr, ','), 'null'));
    end if;
    if q_json -> 'clinica' ->> 'logo_path' is distinct from q_logo
       or (q_json -> 'clinica')::text like '%http%' or (q_json -> 'clinica')::text like '%token=%' then
      failures := failures || 'Q47 el logo del carné público no es solo la ruta (o trae URL/token)';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.actualizar_clinica('Clínica Smoke', 'Cali', 'Cra 1', '3000000000', null);
    perform set_config('role', 'postgres', true);
    q_json := public.carne_publico(q_tok);
    if jsonb_typeof(q_json -> 'clinica' -> 'logo_path') is distinct from 'null' then
      failures := failures || 'Q47 tras quitar el logo, logo_path del carné público debía ser null';
    end if;
  exception when others then
    failures := failures || ('Q47 error inesperado: ' || sqlerrm);
  end;

  -- Q48: actualizar_clinica: anon no la ejecuta, authenticated sí.
  checks := checks + 1;
  perform set_config('role', 'postgres', true);
  if has_function_privilege('anon', 'public.actualizar_clinica(text,text,text,text,text)', 'execute')
     or not has_function_privilege('authenticated', 'public.actualizar_clinica(text,text,text,text,text)', 'execute') then
    failures := failures || 'Q48 grants de actualizar_clinica incorrectos (anon debe fallar, authenticated ejecutar)';
  end if;

  -------------------------------------------------------------------------
  -- ===== R: Planes y límites (Fase 5.1) =====
  -- R1..R45. Las derivaciones usan fechas explícitas (p_hoy = r_hoy + n); r_hoy es _hoy_bogota()
  -- fijado al inicio. Cada regreso a postgres limpia request.jwt.claims (auth.uid() null), porque
  -- asignar_plan, guard_solo_lectura y puede_escribir leen auth.uid(). Todo se revierte al final.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
  r_hoy := public._hoy_bogota();

  -- Setup R (no cuenta en checks): vets nuevos con clínica propia (Pro de prueba por 30 días).
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values
      (r_vet_n, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-r-n@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke R N', 'clinica_nombre', 'Smoke Clinica R N'),
       now(), now()),
      (r_vet_g, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-r-g@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke R G', 'clinica_nombre', 'Smoke Clinica R G'),
       now(), now()),
      (r_vet_s, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-r-s@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke R S', 'clinica_nombre', 'Smoke Clinica R S'),
       now(), now()),
      (r_vet_l, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-r-l@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke R L', 'clinica_nombre', 'Smoke Clinica R L'),
       now(), now());
    select clinica_id into r_c_n from public.perfiles where id = r_vet_n;
    select clinica_id into r_c_g from public.perfiles where id = r_vet_g;
    select clinica_id into r_c_s from public.perfiles where id = r_vet_s;
    select clinica_id into r_c_l from public.perfiles where id = r_vet_l;
  exception when others then
    failures := failures || ('SETUPR error inesperado: ' || sqlerrm);
  end;

  -- R1: clinica_planes existe, RLS activa y exactamente una policy (SELECT).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if not exists (select 1 from pg_class where oid = 'public.clinica_planes'::regclass and relrowsecurity) then
      failures := failures || 'R1 clinica_planes no tiene RLS activa';
    end if;
    select count(*) into r_n from pg_policies where schemaname = 'public' and tablename = 'clinica_planes';
    select count(*) into r_n2 from pg_policies
      where schemaname = 'public' and tablename = 'clinica_planes' and cmd = 'SELECT';
    if r_n <> 1 or r_n2 <> 1 then
      failures := failures || format('R1 policies de clinica_planes: total=%s select=%s (se esperaba 1 y 1)', r_n, r_n2);
    end if;
  exception when others then
    failures := failures || ('R1 error inesperado: ' || sqlerrm);
  end;

  -- R2: clínica nueva -> fila gratis con Pro de prueba +30; mi_plan devuelve Pro/prueba_pro con las 21 claves.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into r_row2 from public.clinica_planes where clinica_id = r_c_n;
    if not found or r_row2.plan is distinct from 'gratis' or r_row2.prueba_pro_hasta is distinct from r_hoy + 30 then
      failures := failures || format('R2 fila de plan de la clínica nueva: plan=%s prueba_pro_hasta=%s', r_row2.plan, r_row2.prueba_pro_hasta);
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_n, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_json := public.mi_plan();
    if r_json ->> 'plan' is distinct from 'pro' or r_json ->> 'origen' is distinct from 'prueba_pro'
       or r_json ->> 'estado' is distinct from 'vigente'
       or (r_json ->> 'dias_restantes')::int is distinct from 30
       or (r_json ->> 'miembros_max')::int is distinct from 1
       or jsonb_typeof(r_json -> 'pacientes_max') is distinct from 'null'
       or (r_json ->> 'logo_permitido')::boolean is not true
       or (r_json ->> 'puede_escribir')::boolean is not true
       or (r_json ->> 'prueba_clinica_disponible')::boolean is not true then
      failures := failures || ('R2 mi_plan de la clínica nueva: ' || r_json::text);
    end if;
    select count(*) into r_n from jsonb_object_keys(r_json);
    select count(*) into r_n2 from jsonb_object_keys(r_json) k
      where k = any (array['plan', 'origen', 'estado', 'fundador', 'vigente_hasta', 'gracia_hasta',
                           'dias_restantes', 'ultimo_vencimiento', 'ultimo_origen', 'pacientes_count',
                           'pacientes_max', 'veterinarios_activos', 'miembros_max', 'logo_permitido',
                           'logo_guardado', 'protocolos_propios_permitidos', 'puede_escribir',
                           'prueba_clinica_disponible', 'prueba_clinica_miembros', 'hay_colegas',
                           'clinica_nombre']);
    if r_n <> 21 or r_n2 <> 21 then
      failures := failures || format('R2 mi_plan debía tener exactamente las 21 claves del contrato (total=%s conocidas=%s)', r_n, r_n2);
    end if;
  exception when others then
    failures := failures || ('R2 error inesperado: ' || sqlerrm);
  end;

  -- R3: un insert directo en clinicas (como crear_mi_clinica) también crea la fila de plan.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into public.clinicas (nombre) values ('Smoke R Directa') returning id into r_c_deriv;
    select * into r_row2 from public.clinica_planes where clinica_id = r_c_deriv;
    if not found or r_row2.prueba_pro_hasta is distinct from public._hoy_bogota() + 30 then
      failures := failures || format('R3 la clínica insertada directo no recibió Pro de prueba +30 (prueba_pro_hasta=%s)', r_row2.prueba_pro_hasta);
    end if;
  exception when others then
    failures := failures || ('R3 error inesperado: ' || sqlerrm);
  end;

  -- R4: un veterinario no puede cambiar su propio plan (sin privilegio UPDATE); la fila no cambia.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_n, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      update public.clinica_planes
         set plan = 'clinica', miembros_max = 5, pagado_hasta = public._hoy_bogota() + 365
       where clinica_id = r_c_n;
      get diagnostics r_n = row_count;
      if r_n <> 0 then
        failures := failures || format('R4 el veterinario modificó %s fila(s) de su plan', r_n);
      end if;
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('R4 update: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if not exists (
      select 1 from public.clinica_planes
      where clinica_id = r_c_n and plan = 'gratis' and miembros_max = 1 and pagado_hasta is null
    ) then
      failures := failures || 'R4 la fila de plan cambió tras el intento de auto-ascenso';
    end if;
  exception when others then
    failures := failures || ('R4 error inesperado: ' || sqlerrm);
  end;

  -- R5: un veterinario no puede insertar filas en clinica_planes.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_n, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      insert into public.clinica_planes (clinica_id) values (clinica_a_id);
      failures := failures || 'R5 el veterinario pudo insertar en clinica_planes';
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('R5 insert: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R5 error inesperado: ' || sqlerrm);
  end;

  -- R6: un veterinario no puede borrar filas de clinica_planes; la fila sigue ahí.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_n, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      delete from public.clinica_planes;
      get diagnostics r_n = row_count;
      if r_n <> 0 then
        failures := failures || format('R6 el veterinario borró %s fila(s) de clinica_planes', r_n);
      end if;
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('R6 delete: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if not exists (select 1 from public.clinica_planes where clinica_id = r_c_n) then
      failures := failures || 'R6 la fila de plan de la clínica desapareció';
    end if;
  exception when others then
    failures := failures || ('R6 error inesperado: ' || sqlerrm);
  end;

  -- R7: aislamiento por clínica: vet B no ve el plan de la clínica de r_vet_n y solo ve el suyo.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into r_n from public.clinica_planes where clinica_id = r_c_n;
    select count(*) into r_n2 from public.clinica_planes;
    if r_n <> 0 or r_n2 <> 1 then
      failures := failures || format('R7 vet B ve %s fila(s) de la clínica ajena y %s en total (se esperaba 0 y 1)', r_n, r_n2);
    end if;
  exception when others then
    failures := failures || ('R7 error inesperado: ' || sqlerrm);
  end;

  -- R8: grants de la superficie nueva.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if has_function_privilege('authenticated', 'public.asignar_plan(uuid,text,int,date,boolean,date)', 'execute')
       or has_function_privilege('authenticated', 'public._plan_efectivo(uuid,date)', 'execute')
       or has_function_privilege('anon', 'public.mi_plan()', 'execute')
       or has_function_privilege('anon', 'public.puede_escribir()', 'execute')
       or has_function_privilege('anon', 'public.plan_permite_logo()', 'execute')
       or has_function_privilege('anon', 'public.asignar_plan(uuid,text,int,date,boolean,date)', 'execute')
       or has_table_privilege('authenticated', 'public.clinica_planes', 'UPDATE') then
      failures := failures || 'R8 grants demasiado abiertos (asignar_plan/_plan_efectivo para authenticated, RPC de plan para anon o UPDATE en clinica_planes)';
    end if;
    if not has_function_privilege('authenticated', 'public.mi_plan()', 'execute')
       or not has_function_privilege('authenticated', 'public.puede_escribir()', 'execute')
       or not has_function_privilege('service_role', 'public.asignar_plan(uuid,text,int,date,boolean,date)', 'execute') then
      failures := failures || 'R8 faltan grants: mi_plan/puede_escribir para authenticated o asignar_plan para service_role';
    end if;
  exception when others then
    failures := failures || ('R8 error inesperado: ' || sqlerrm);
  end;

  -- R9: asignar_plan con sesión de veterinario se rechaza.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_n, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.asignar_plan(r_c_n, 'beta');
      failures := failures || 'R9 el veterinario pudo ejecutar asignar_plan';
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('R9 asignar_plan: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R9 error inesperado: ' || sqlerrm);
  end;

  -- R10: prueba Pro sin gracia: el último día incluido es vigente, el siguiente cae a Gratis.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    update public.clinica_planes set prueba_pro_hasta = r_hoy + 3 where clinica_id = r_c_deriv;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 3);
    if r_row.plan is distinct from 'pro' or r_row.origen is distinct from 'prueba_pro'
       or r_row.estado is distinct from 'vigente' or r_row.dias_restantes is distinct from 0 then
      failures := failures || format('R10 último día de la prueba Pro: plan=%s origen=%s estado=%s dias=%s', r_row.plan, r_row.origen, r_row.estado, r_row.dias_restantes);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 4);
    if r_row.plan is distinct from 'gratis' or r_row.ultimo_origen is distinct from 'prueba_pro'
       or r_row.ultimo_vencimiento is distinct from r_hoy + 3 then
      failures := failures || format('R10 día siguiente a la prueba Pro: plan=%s ultimo_origen=%s ultimo_vencimiento=%s', r_row.plan, r_row.ultimo_origen, r_row.ultimo_vencimiento);
    end if;
  exception when others then
    failures := failures || ('R10 error inesperado: ' || sqlerrm);
  end;

  -- R11: Pro pagado: vigente, gracia de 15 días y luego Gratis con el último vencimiento.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    perform public.asignar_plan(r_c_deriv, 'pro', null, r_hoy + 10);
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy);
    if r_row.plan is distinct from 'pro' or r_row.origen is distinct from 'pagado'
       or r_row.estado is distinct from 'vigente' or r_row.dias_restantes is distinct from 10 then
      failures := failures || format('R11 Pro pagado vigente: plan=%s origen=%s estado=%s dias=%s', r_row.plan, r_row.origen, r_row.estado, r_row.dias_restantes);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 11);
    if r_row.plan is distinct from 'pro' or r_row.origen is distinct from 'pagado'
       or r_row.estado is distinct from 'gracia' or r_row.gracia_hasta is distinct from r_hoy + 25
       or r_row.dias_restantes is distinct from 14 then
      failures := failures || format('R11 primer día de gracia: estado=%s gracia_hasta=%s dias=%s', r_row.estado, r_row.gracia_hasta, r_row.dias_restantes);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 25);
    if r_row.estado is distinct from 'gracia' or r_row.dias_restantes is distinct from 0 then
      failures := failures || format('R11 último día de gracia: estado=%s dias=%s', r_row.estado, r_row.dias_restantes);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 26);
    if r_row.plan is distinct from 'gratis' or r_row.ultimo_origen is distinct from 'pagado'
       or r_row.ultimo_vencimiento is distinct from r_hoy + 10 then
      failures := failures || format('R11 tras la gracia: plan=%s ultimo_origen=%s ultimo_vencimiento=%s', r_row.plan, r_row.ultimo_origen, r_row.ultimo_vencimiento);
    end if;
  exception when others then
    failures := failures || ('R11 error inesperado: ' || sqlerrm);
  end;

  -- R12: Clínica pagada con tramo; tramos y fechas inválidos fallan con check_violation.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    perform public.asignar_plan(r_c_deriv, 'clinica', 3, r_hoy + 30);
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy);
    if r_row.plan is distinct from 'clinica' or r_row.miembros_max is distinct from 3 then
      failures := failures || format('R12 Clínica tramo 3: plan=%s miembros_max=%s', r_row.plan, r_row.miembros_max);
    end if;
    begin
      perform public.asignar_plan(r_c_deriv, 'clinica', 4, r_hoy + 30);
      failures := failures || 'R12 el tramo 4 debía fallar con check_violation';
    exception
      when check_violation then null;
      when others then failures := failures || ('R12 tramo 4: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.asignar_plan(r_c_deriv, 'clinica', 3, null, false);
      failures := failures || 'R12 Clínica sin pagado_hasta debía fallar con check_violation';
    exception
      when check_violation then null;
      when others then failures := failures || ('R12 sin pagado_hasta: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R12 error inesperado: ' || sqlerrm);
  end;

  -- R13: prueba Clínica: 5 cupos vigente, gracia de 15 días y luego se acaba.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    r_d := r_hoy + 10;
    update public.clinica_planes set prueba_clinica_usada = true, prueba_clinica_hasta = r_d where clinica_id = r_c_deriv;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_d);
    if r_row.plan is distinct from 'clinica' or r_row.origen is distinct from 'prueba_clinica'
       or r_row.estado is distinct from 'vigente' or r_row.miembros_max is distinct from 5 then
      failures := failures || format('R13 prueba Clínica vigente: plan=%s origen=%s estado=%s miembros_max=%s', r_row.plan, r_row.origen, r_row.estado, r_row.miembros_max);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_d + 15);
    if r_row.origen is distinct from 'prueba_clinica' or r_row.estado is distinct from 'gracia' then
      failures := failures || format('R13 último día de gracia de la prueba Clínica: origen=%s estado=%s', r_row.origen, r_row.estado);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_d + 16);
    if r_row.origen is not distinct from 'prueba_clinica' then
      failures := failures || 'R13 la prueba Clínica seguía activa 16 días después de su fin';
    end if;
  exception when others then
    failures := failures || ('R13 error inesperado: ' || sqlerrm);
  end;

  -- R14: Beta sin vencimiento (sin tope de cupos) y Beta con fecha (sin gracia).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    perform public.asignar_plan(r_c_deriv, 'beta');
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 400);
    if r_row.plan is distinct from 'beta' or r_row.estado is distinct from 'sin_vencimiento'
       or r_row.miembros_max < 999 or r_row.logo_permitido is not true
       or r_row.protocolos_propios_permitidos is not true then
      failures := failures || format('R14 Beta sin fecha: plan=%s estado=%s miembros_max=%s logo=%s protocolos=%s', r_row.plan, r_row.estado, r_row.miembros_max, r_row.logo_permitido, r_row.protocolos_propios_permitidos);
    end if;
    perform public.asignar_plan(r_c_deriv, 'beta', null, null, false, r_hoy + 5);
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 6);
    if r_row.plan is not distinct from 'beta' then
      failures := failures || 'R14 la Beta con fecha seguía activa el día siguiente (no tiene gracia)';
    end if;
  exception when others then
    failures := failures || ('R14 error inesperado: ' || sqlerrm);
  end;

  -- R15: Fundador es solo una marca de precio: el plan pagado vence igual (vigente, gracia, Gratis).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    perform public.asignar_plan(r_c_deriv, 'pro', null, r_hoy + 5, true);
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 3);
    if r_row.fundador is not true or r_row.plan is distinct from 'pro' or r_row.estado is distinct from 'vigente' then
      failures := failures || format('R15 Fundador vigente: fundador=%s plan=%s estado=%s', r_row.fundador, r_row.plan, r_row.estado);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 6);
    if r_row.plan is distinct from 'pro' or r_row.estado is distinct from 'gracia' then
      failures := failures || format('R15 Fundador vencido debía quedar en gracia: plan=%s estado=%s', r_row.plan, r_row.estado);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 21);
    if r_row.plan is distinct from 'gratis' then
      failures := failures || format('R15 Fundador no vence nunca: a los 16 días de gracia plan=%s (se esperaba gratis)', r_row.plan);
    end if;
    begin
      perform public.asignar_plan(r_c_deriv, 'pro', null, null, true);
      failures := failures || 'R15 Fundador sin pagado_hasta debía fallar con check_violation';
    exception
      when check_violation then null;
      when others then failures := failures || ('R15 sin pagado_hasta: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R15 error inesperado: ' || sqlerrm);
  end;

  -- R16: jerarquía y desempate (Beta > Clínica > Pro > Gratis; a igual rango gana lo pagado) y
  -- asignar_plan no toca las pruebas de la clínica.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    -- (a) Beta sin fecha + prueba Clínica vigente -> Beta.
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    update public.clinica_planes set plan = 'beta', prueba_clinica_usada = true, prueba_clinica_hasta = r_hoy + 20 where clinica_id = r_c_deriv;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy);
    if r_row.plan is distinct from 'beta' or r_row.miembros_max is distinct from 999 then
      failures := failures || format('R16 Beta + prueba Clínica: plan=%s miembros_max=%s', r_row.plan, r_row.miembros_max);
    end if;
    -- (b) Pro pagado vigente + prueba Pro vigente -> gana lo pagado.
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    update public.clinica_planes set plan = 'pro', pagado_hasta = r_hoy + 5, prueba_pro_hasta = r_hoy + 20 where clinica_id = r_c_deriv;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy);
    if r_row.plan is distinct from 'pro' or r_row.origen is distinct from 'pagado' then
      failures := failures || format('R16 Pro pagado + prueba Pro: plan=%s origen=%s', r_row.plan, r_row.origen);
    end if;
    -- (c) Pro pagado en gracia + prueba Pro vigente -> sigue ganando lo pagado (en gracia).
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    update public.clinica_planes set plan = 'pro', pagado_hasta = r_hoy - 3, prueba_pro_hasta = r_hoy + 20 where clinica_id = r_c_deriv;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy);
    if r_row.origen is distinct from 'pagado' or r_row.estado is distinct from 'gracia' then
      failures := failures || format('R16 Pro en gracia + prueba Pro: origen=%s estado=%s', r_row.origen, r_row.estado);
    end if;
    -- (d) Pro pagado vigente + prueba Clínica vigente -> Clínica (mayor rango).
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    update public.clinica_planes set plan = 'pro', pagado_hasta = r_hoy + 5, prueba_clinica_usada = true, prueba_clinica_hasta = r_hoy + 20 where clinica_id = r_c_deriv;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy);
    if r_row.plan is distinct from 'clinica' then
      failures := failures || format('R16 Pro pagado + prueba Clínica: plan=%s (se esperaba clinica)', r_row.plan);
    end if;
    -- (e) asignar_plan no modifica prueba_pro_hasta ni prueba_clinica_*.
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    update public.clinica_planes set prueba_pro_hasta = r_hoy + 20, prueba_clinica_usada = true, prueba_clinica_hasta = r_hoy + 7 where clinica_id = r_c_deriv;
    perform public.asignar_plan(r_c_deriv, 'pro', null, r_hoy + 5);
    perform public.asignar_plan(r_c_deriv, 'beta');
    if not exists (
      select 1 from public.clinica_planes
      where clinica_id = r_c_deriv and prueba_pro_hasta = r_hoy + 20
        and prueba_clinica_hasta = r_hoy + 7 and prueba_clinica_usada
    ) then
      failures := failures || 'R16 asignar_plan modificó las pruebas de la clínica';
    end if;
  exception when others then
    failures := failures || ('R16 error inesperado: ' || sqlerrm);
  end;

  -- Setup R-G (no cuenta en checks): clínica en Gratis sin prueba, con 1 cliente y 49 mascotas.
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set prueba_pro_hasta = r_hoy - 1 where clinica_id = r_c_g;
    insert into public.clientes (clinica_id, nombre, telefono)
      values (r_c_g, 'Smoke R Cliente G', '3000000001') returning id into r_cliente;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      select r_cliente, r_c_g, 'Smoke R Pet ' || g, 'perro' from generate_series(1, 49) g;
    select id into r_m from public.mascotas where clinica_id = r_c_g order by created_at, id limit 1;
  exception when others then
    failures := failures || ('SETUPR-G error inesperado: ' || sqlerrm);
  end;

  -- R17: con 49 el registro 50 pasa; mi_plan reporta 50 de 50.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_g, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_mascota(r_cliente, 'Smoke R Pet 50', 'perro');
    r_json := public.mi_plan();
    if (r_json ->> 'pacientes_count')::int is distinct from 50 or (r_json ->> 'pacientes_max')::int is distinct from 50 then
      failures := failures || ('R17 mi_plan con 50 pacientes: ' || r_json::text);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into r_n from public.mascotas where clinica_id = r_c_g;
    if r_n <> 50 then
      failures := failures || format('R17 la clínica tiene %s mascotas (se esperaban 50)', r_n);
    end if;
  exception when others then
    failures := failures || ('R17 error inesperado: ' || sqlerrm);
  end;

  -- R18: el INSERT directo de la mascota 51 se rechaza con LP001.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_g, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
        values (r_cliente, r_c_g, 'Smoke R Pet 51', 'perro');
      failures := failures || 'R18 el insert directo de la mascota 51 debía fallar con LP001';
    exception
      when sqlstate 'LP001' then null;
      when others then failures := failures || ('R18 insert directo: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R18 error inesperado: ' || sqlerrm);
  end;

  -- R19: registrar_mascota en 50 falla con LP001.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_g, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.registrar_mascota(r_cliente, 'Smoke R Pet 51', 'perro');
      failures := failures || 'R19 registrar_mascota en 50 debía fallar con LP001';
    exception
      when sqlstate 'LP001' then null;
      when others then failures := failures || ('R19 registrar_mascota: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R19 error inesperado: ' || sqlerrm);
  end;

  -- R20: registrar_cliente_con_mascota en 50 falla con LP001 sin dejar un cliente huérfano.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into r_n from public.clientes where clinica_id = r_c_g;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_g, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.registrar_cliente_con_mascota('Smoke R Huerfano', '3000000009', 'Smoke R Pet X', 'perro');
      failures := failures || 'R20 registrar_cliente_con_mascota en 50 debía fallar con LP001';
    exception
      when sqlstate 'LP001' then null;
      when others then failures := failures || ('R20 registrar_cliente_con_mascota: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into r_n2 from public.clientes where clinica_id = r_c_g;
    if r_n2 <> r_n then
      failures := failures || format('R20 quedó un cliente huérfano (antes=%s después=%s)', r_n, r_n2);
    end if;
  exception when others then
    failures := failures || ('R20 error inesperado: ' || sqlerrm);
  end;

  -- R21: en 50 se pueden editar mascotas existentes y registrar consultas.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_g, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    update public.mascotas set nombre = 'Smoke R Renombrada' where id = r_m;
    get diagnostics r_n = row_count;
    if r_n <> 1 then
      failures := failures || format('R21 el update de una mascota existente afectó %s fila(s)', r_n);
    end if;
    perform public.registrar_consulta(r_m, 'Smoke R dx', 'Smoke R tx');
  exception when others then
    failures := failures || ('R21 error inesperado: ' || sqlerrm);
  end;

  -- R22: en 50 siguen permitidos cita, dosis y enlace del carné (D-02).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_g, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_cita := public.crear_cita(r_cliente, array[r_m], now() + interval '1 day');
    r_dosis := public.registrar_dosis(r_m, 'polivalente', null, r_hoy - 10);
    r_tok := public.obtener_o_crear_enlace_carne(r_m);
    if r_cita is null or r_dosis is null or r_tok !~ '^[0-9a-f]{64}$' then
      failures := failures || 'R22 cita, dosis o enlace del carné no se crearon con 50 pacientes';
    end if;
  exception when others then
    failures := failures || ('R22 error inesperado: ' || sqlerrm);
  end;

  -- R23: al borrar uno se puede registrar de nuevo (D-04); con Pro pagado no hay tope.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    delete from public.mascotas
      where id = (select id from public.mascotas where clinica_id = r_c_g and id <> r_m order by created_at desc, id desc limit 1);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_g, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_mascota(r_cliente, 'Smoke R Pet Nueva', 'perro');
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into r_n from public.mascotas where clinica_id = r_c_g;
    if r_n <> 50 then
      failures := failures || format('R23 tras borrar y registrar quedaron %s mascotas (se esperaban 50)', r_n);
    end if;
    perform public.asignar_plan(r_c_g, 'pro', null, r_hoy + 30);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_g, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.registrar_mascota(r_cliente, 'Smoke R Pet 51 Pro', 'perro');
    perform public.registrar_mascota(r_cliente, 'Smoke R Pet 52 Pro', 'perro');
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into r_n from public.mascotas where clinica_id = r_c_g;
    if r_n <> 52 then
      failures := failures || format('R23 con Pro pagado quedaron %s mascotas (se esperaban 52)', r_n);
    end if;
  exception when others then
    failures := failures || ('R23 error inesperado: ' || sqlerrm);
  end;

  -- R24: primer código sin cupo abre la prueba Clínica (+30 días, una vez) en la misma transacción.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_json := public.mi_plan();
    if (r_json ->> 'prueba_clinica_disponible')::boolean is not true then
      failures := failures || 'R24 mi_plan debía ofrecer la prueba Clínica antes de generar el código';
    end if;
    select g.codigo into r_cod from public.generar_invitacion_clinica() g;
    if r_cod is null then
      failures := failures || 'R24 generar_invitacion_clinica no devolvió un código';
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into r_row2 from public.clinica_planes where clinica_id = r_c_s;
    if r_row2.prueba_clinica_usada is not true or r_row2.prueba_clinica_hasta is distinct from r_hoy + 30 then
      failures := failures || format('R24 prueba Clínica: usada=%s hasta=%s (se esperaba true y %s)', r_row2.prueba_clinica_usada, r_row2.prueba_clinica_hasta, r_hoy + 30);
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_json := public.mi_plan();
    if r_json ->> 'plan' is distinct from 'clinica' or r_json ->> 'origen' is distinct from 'prueba_clinica'
       or (r_json ->> 'miembros_max')::int is distinct from 5 then
      failures := failures || ('R24 mi_plan tras abrir la prueba Clínica: ' || r_json::text);
    end if;
  exception when others then
    failures := failures || ('R24 error inesperado: ' || sqlerrm);
  end;

  -- Setup R-S (no cuenta en checks): datos de la clínica S para los checks de solo lectura.
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into public.clientes (clinica_id, nombre, telefono)
      values (r_c_s, 'Smoke R Cliente S', '3000000003') returning id into r_s_cliente;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (r_s_cliente, r_c_s, 'Smoke R Mascota S', 'perro') returning id into r_s_m;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_s_dosis := public.registrar_dosis(r_s_m, 'polivalente', null, r_hoy - 10);
    perform public.registrar_consulta(r_s_m, 'Smoke R dx S', 'Smoke R tx S');
    r_s_cita := public.crear_cita(r_s_cliente, array[r_s_m], now() + interval '3 days');
  exception when others then
    failures := failures || ('SETUPR-S error inesperado: ' || sqlerrm);
  end;

  -- R25: un colega se une con el código durante la prueba Clínica y puede escribir.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (r_vet_s2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'smoke-r-s2@vetapp.invalid',
            jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke R S2', 'codigo_invitacion', r_cod),
            now(), now());
    if not exists (
      select 1 from public.perfiles
      where id = r_vet_s2 and clinica_id = r_c_s and rol = 'VETERINARIO' and activo
    ) then
      failures := failures || 'R25 el colega no quedó como veterinario activo de la clínica S';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s2, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.clientes (clinica_id, nombre, telefono) values (r_c_s, 'Smoke R Cliente S2', '3000000002');
    if not public.puede_escribir() then
      failures := failures || 'R25 el colega debía poder escribir durante la prueba Clínica';
    end if;
  exception when others then
    failures := failures || ('R25 error inesperado: ' || sqlerrm);
  end;

  -- R26: un segundo código con cupo libre no reinicia la prueba Clínica.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select g.codigo into r_cod2 from public.generar_invitacion_clinica() g;
    if r_cod2 is null then
      failures := failures || 'R26 el segundo código no se generó';
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into r_row2 from public.clinica_planes where clinica_id = r_c_s;
    if r_row2.prueba_clinica_hasta is distinct from r_hoy + 30 then
      failures := failures || format('R26 prueba_clinica_hasta cambió a %s', r_row2.prueba_clinica_hasta);
    end if;
  exception when others then
    failures := failures || ('R26 error inesperado: ' || sqlerrm);
  end;

  -- R27: Clínica pagada de 2 cupos con 2 activos -> generar_invitacion_clinica falla con LP002.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform public.asignar_plan(r_c_s, 'clinica', 2, r_hoy + 30);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform g.codigo from public.generar_invitacion_clinica() g;
      failures := failures || 'R27 generar con los 2 cupos llenos debía fallar con LP002';
    exception
      when sqlstate 'LP002' then null;
      when others then failures := failures || ('R27 generar: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R27 error inesperado: ' || sqlerrm);
  end;

  -- R28: el cupo se re-verifica al consumir: con el cupo ya lleno, unirse_a_clinica falla con LP002.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform public.asignar_plan(r_c_s, 'clinica', 3, r_hoy + 30);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select g.codigo into r_cod2 from public.generar_invitacion_clinica() g;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values
      (r_vet_s3, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-r-s3@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke R S3', 'clinica_nombre', 'Smoke Clinica R S3'),
       now(), now()),
      (r_vet_s4, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-r-s4@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke R S4', 'clinica_nombre', 'Smoke Clinica R S4'),
       now(), now());
    update public.perfiles set clinica_id = r_c_s, rol_clinica = 'veterinario', activo = true where id = r_vet_s3;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s4, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.unirse_a_clinica(r_cod2);
      failures := failures || 'R28 unirse_a_clinica con el cupo lleno debía fallar con LP002';
    exception
      when sqlstate 'LP002' then null;
      when others then failures := failures || ('R28 unirse_a_clinica: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if exists (select 1 from public.clinica_invitaciones where codigo = r_cod2 and usada_por is not null) then
      failures := failures || 'R28 la invitación quedó consumida pese al LP002';
    end if;
  exception when others then
    failures := failures || ('R28 error inesperado: ' || sqlerrm);
  end;

  -- R29: con la prueba Clínica ya usada y plan Gratis, generar falla con LP002 y no reabre la prueba.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes
       set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, beta_hasta = null,
           prueba_pro_hasta = r_hoy - 40, prueba_clinica_usada = true, prueba_clinica_hasta = r_hoy - 16
     where clinica_id = r_c_s;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform g.codigo from public.generar_invitacion_clinica() g;
      failures := failures || 'R29 generar con la prueba Clínica ya usada debía fallar con LP002';
    exception
      when sqlstate 'LP002' then null;
      when others then failures := failures || ('R29 generar: error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into r_row2 from public.clinica_planes where clinica_id = r_c_s;
    if r_row2.prueba_clinica_hasta is distinct from r_hoy - 16 then
      failures := failures || format('R29 prueba_clinica_hasta cambió a %s (una prueba por clínica)', r_row2.prueba_clinica_hasta);
    end if;
  exception when others then
    failures := failures || ('R29 error inesperado: ' || sqlerrm);
  end;

  -- R30: solo lectura (Clínica terminó hace 16 días, Gratis): el colega no escribe en ninguna de las 6 vías.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s2, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    if public.puede_escribir() then
      failures := failures || 'R30 puede_escribir() debía ser false para el colega';
    end if;
    begin
      insert into public.clientes (clinica_id, nombre, telefono) values (r_c_s, 'Smoke R Bloqueado', '3000000004');
      failures := failures || 'R30 insert de cliente debía fallar con LP004';
    exception
      when sqlstate 'LP004' then null;
      when others then failures := failures || ('R30 insert cliente: error inesperado: ' || sqlerrm);
    end;
    begin
      update public.mascotas set nombre = 'Smoke R Bloqueada' where id = r_s_m;
      failures := failures || 'R30 update de mascota debía fallar con LP004';
    exception
      when sqlstate 'LP004' then null;
      when others then failures := failures || ('R30 update mascota: error inesperado: ' || sqlerrm);
    end;
    begin
      insert into public.mascota_pesos (mascota_id, peso_kg) values (r_s_m, 5);
      failures := failures || 'R30 insert de peso debía fallar con LP004';
    exception
      when sqlstate 'LP004' then null;
      when others then failures := failures || ('R30 insert peso: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.crear_cita(r_s_cliente, array[r_s_m], now() + interval '5 days');
      failures := failures || 'R30 crear_cita debía fallar con LP004';
    exception
      when sqlstate 'LP004' then null;
      when others then failures := failures || ('R30 crear_cita: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.registrar_consulta(r_s_m, 'Smoke R x', 'Smoke R y');
      failures := failures || 'R30 registrar_consulta debía fallar con LP004';
    exception
      when sqlstate 'LP004' then null;
      when others then failures := failures || ('R30 registrar_consulta: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.registrar_dosis(r_s_m, 'polivalente', null, r_hoy - 3);
      failures := failures || 'R30 registrar_dosis debía fallar con LP004';
    exception
      when sqlstate 'LP004' then null;
      when others then failures := failures || ('R30 registrar_dosis: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R30 error inesperado: ' || sqlerrm);
  end;

  -- R31: el colega en solo lectura sigue leyendo, compartiendo el carné, gestionando alertas y marcando recordatorios.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s2, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into r_n from public.clientes where clinica_id = r_c_s;
    select count(*) into r_n2 from public.mascotas where clinica_id = r_c_s;
    if r_n < 1 or r_n2 < 1 or (select count(*) from public.consultas c join public.mascotas m on m.id = c.mascota_id where m.clinica_id = r_c_s) < 1 then
      failures := failures || format('R31 lecturas de solo lectura: clientes=%s mascotas=%s', r_n, r_n2);
    end if;
    begin
      perform public.carne_de_mascota(r_s_m);
    exception when others then
      failures := failures || ('R31 carne_de_mascota: error inesperado: ' || sqlerrm);
    end;
    begin
      r_tok := public.obtener_o_crear_enlace_carne(r_s_m);
      if r_tok is null then
        failures := failures || 'R31 obtener_o_crear_enlace_carne no devolvió token';
      end if;
    exception when others then
      failures := failures || ('R31 enlace del carné: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.gestionar_alerta_vacuna(r_s_dosis, 'recordado');
    exception when others then
      failures := failures || ('R31 gestionar_alerta_vacuna: error inesperado: ' || sqlerrm);
    end;
    begin
      update public.citas set recordatorio_enviado_at = now() where id = r_s_cita;
      get diagnostics r_n = row_count;
      if r_n <> 1 then
        failures := failures || format('R31 marcar recordatorio de la cita afectó %s fila(s)', r_n);
      end if;
    exception when others then
      failures := failures || ('R31 recordatorio de cita: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R31 error inesperado: ' || sqlerrm);
  end;

  -- R32: en el mismo estado el admin sí escribe; mi_plan refleja puede_escribir por usuario.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.clientes (clinica_id, nombre, telefono) values (r_c_s, 'Smoke R Admin Escribe', '3000000005');
    r_json := public.mi_plan();
    if (r_json ->> 'puede_escribir')::boolean is not true then
      failures := failures || 'R32 mi_plan del admin debía tener puede_escribir=true';
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s2, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_json := public.mi_plan();
    if (r_json ->> 'puede_escribir')::boolean is not false then
      failures := failures || 'R32 mi_plan del colega debía tener puede_escribir=false';
    end if;
  exception when others then
    failures := failures || ('R32 error inesperado: ' || sqlerrm);
  end;

  -- R33: en gracia de la prueba Clínica el colega escribe; el DELETE del admin borra exactamente 1 fila (Pitfall 3).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set prueba_clinica_hasta = r_hoy - 1 where clinica_id = r_c_s;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s2, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    insert into public.clientes (clinica_id, nombre, telefono)
      values (r_c_s, 'Smoke R Gracia', '3000000006') returning id into r_cliente2;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_s, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    delete from public.clientes where id = r_cliente2;
    get diagnostics r_n = row_count;
    if r_n <> 1 then
      failures := failures || format('R33 el DELETE del admin afectó %s fila(s) (se esperaba 1)', r_n);
    end if;
  exception when others then
    failures := failures || ('R33 error inesperado: ' || sqlerrm);
  end;

  -- Setup R-L (no cuenta en checks): durante su Pro de prueba el admin L crea un protocolo propio y
  -- sube y fija un logo; luego la clínica pasa a Gratis sin prueba. r_logo2 es un objeto válido nuevo.
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    r_logo := r_c_l::text || '/logo-1700000000100.jpg';
    r_logo2 := r_c_l::text || '/logo-1700000000200.jpg';
    insert into public.clientes (clinica_id, nombre, telefono)
      values (r_c_l, 'Smoke R Cliente L', '3000000007') returning id into r_l_cliente;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (r_l_cliente, r_c_l, 'Smoke R Mascota L', 'perro') returning id into r_l_m;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_proto := public.guardar_protocolo(null, 'Smoke R Propio', 'vacuna', array['perro'], 1, null, 365, '{}'::int[]);
    insert into storage.objects (bucket_id, name) values ('clinica-logos', r_logo);
    perform public.actualizar_clinica('Smoke Clinica R L', 'Cali', 'Cra 1', '3000000000', r_logo);
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into storage.objects (bucket_id, name) values ('clinica-logos', r_logo2);
    update public.clinica_planes
       set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, beta_hasta = null,
           prueba_pro_hasta = r_hoy - 1, prueba_clinica_hasta = null, prueba_clinica_usada = false
     where clinica_id = r_c_l;
  exception when others then
    failures := failures || ('SETUPR-L error inesperado: ' || sqlerrm);
  end;

  -- R34: en Gratis un logo nuevo falla con LP003; la misma ruta con otro nombre y quitar el logo pasan.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.actualizar_clinica('Smoke Clinica R L', 'Cali', 'Cra 1', '3000000000', r_logo2);
      failures := failures || 'R34 un logo nuevo en Gratis debía fallar con LP003';
    exception
      when sqlstate 'LP003' then null;
      when others then failures := failures || ('R34 logo nuevo: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.actualizar_clinica('Smoke Clinica R L2', 'Cali', 'Cra 1', '3000000000', r_logo);
    exception when others then
      failures := failures || ('R34 misma ruta con otro nombre debía pasar: ' || sqlerrm);
    end;
    begin
      perform public.actualizar_clinica('Smoke Clinica R L2', 'Cali', 'Cra 1', '3000000000', null);
    exception when others then
      failures := failures || ('R34 quitar el logo debía pasar: ' || sqlerrm);
    end;
    -- Restaurar la ruta guardada como postgres: se hace bajo Pro pagado (el trigger valida el plan) y se vuelve a Gratis.
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform public.asignar_plan(r_c_l, 'pro', null, r_hoy + 30);
    update public.clinicas set logo_path = r_logo where id = r_c_l;
    update public.clinica_planes
       set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, beta_hasta = null,
           prueba_pro_hasta = r_hoy - 1, prueba_clinica_hasta = null, prueba_clinica_usada = false
     where clinica_id = r_c_l;
  exception when others then
    failures := failures || ('R34 error inesperado: ' || sqlerrm);
  end;

  -- R35: en Gratis el admin no puede subir un logo al storage (plan_permite_logo es false).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      insert into storage.objects (bucket_id, name)
        values ('clinica-logos', r_c_l::text || '/logo-1700000000300.jpg');
      failures := failures || 'R35 subir un logo en Gratis debía fallar';
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('R35 storage: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R35 error inesperado: ' || sqlerrm);
  end;

  -- R36: en Gratis no se crean protocolos propios ni se sobrescribe una semilla (LP003).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.guardar_protocolo(null, 'Smoke R Otro', 'vacuna', array['perro'], 1, null, 365, '{}'::int[]);
      failures := failures || 'R36 crear un protocolo propio en Gratis debía fallar con LP003';
    exception
      when sqlstate 'LP003' then null;
      when others then failures := failures || ('R36 protocolo nuevo: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.guardar_protocolo('polivalente', 'Polivalente', 'vacuna', array['perro'], 3, 28, 365, '{}'::int[]);
      failures := failures || 'R36 sobrescribir la semilla polivalente en Gratis debía fallar con LP003';
    exception
      when sqlstate 'LP003' then null;
      when others then failures := failures || ('R36 override de semilla: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R36 error inesperado: ' || sqlerrm);
  end;

  -- R37: el protocolo propio existente sigue usable en Gratis y, aun desactivado, su próxima fecha se calcula (D-06).
  -- Nota: registrar_dosis solo acepta protocolos activos, por eso la dosis se registra ANTES de desactivarlo.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_dosis := public.registrar_dosis(r_l_m, r_proto, null, r_hoy - 10);
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select f.proxima_fecha into r_d from public._carne_filas(r_c_l, r_l_m, r_hoy) f where f.codigo_protocolo = r_proto;
    if r_d is null then
      failures := failures || 'R37 la dosis del protocolo propio en Gratis no calculó proxima_fecha';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.desactivar_protocolo(r_proto);
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if exists (select 1 from public.protocolos_vacunacion where clinica_id = r_c_l and codigo = r_proto and activo) then
      failures := failures || 'R37 desactivar_protocolo no desactivó el protocolo en Gratis';
    end if;
    select f.proxima_fecha into r_d from public._carne_filas(r_c_l, r_l_m, r_hoy) f where f.codigo_protocolo = r_proto;
    if r_d is null then
      failures := failures || 'R37 desactivado el protocolo, la próxima fecha dejó de calcularse';
    end if;
  exception when others then
    failures := failures || ('R37 error inesperado: ' || sqlerrm);
  end;

  -- R38: en Gratis el carné del veterinario no entrega la ruta del logo aunque siga guardada.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_json := public.carne_de_mascota(r_l_m);
    if jsonb_typeof(r_json -> 'clinica' -> 'logo_path') is distinct from 'null' then
      failures := failures || ('R38 el carné entregó logo_path en Gratis: ' || coalesce(r_json -> 'clinica' ->> 'logo_path', 'null'));
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if not exists (select 1 from public.clinicas where id = r_c_l and logo_path is not null) then
      failures := failures || 'R38 la ruta del logo no quedó guardada en clinicas.logo_path';
    end if;
  exception when others then
    failures := failures || ('R38 error inesperado: ' || sqlerrm);
  end;

  -- R39: el carné público en Gratis conserva el enlace y las 5 claves de clínica, con logo_path null.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_tok := public.obtener_o_crear_enlace_carne(r_l_m);
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    r_json := public.carne_publico(r_tok);
    if r_json is null then
      failures := failures || 'R39 el enlace público dejó de funcionar en Gratis';
    else
      select array_agg(k order by k) into r_arr from jsonb_object_keys(r_json -> 'clinica') k;
      if r_arr is distinct from array['ciudad', 'direccion', 'logo_path', 'nombre', 'telefono'] then
        failures := failures || ('R39 claves de clinica en el carné público: ' || coalesce(array_to_string(r_arr, ','), 'null'));
      end if;
      if jsonb_typeof(r_json -> 'clinica' -> 'logo_path') is distinct from 'null' then
        failures := failures || 'R39 el carné público entregó logo_path en Gratis';
      end if;
    end if;
  exception when others then
    failures := failures || ('R39 error inesperado: ' || sqlerrm);
  end;

  -- R40: al volver a un plan con logo reaparece la ruta guardada y mi_plan lo refleja.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform public.asignar_plan(r_c_l, 'pro', null, r_hoy + 30);
    r_json := public.carne_publico(r_tok);
    if r_json -> 'clinica' ->> 'logo_path' is distinct from r_logo then
      failures := failures || ('R40 con Pro el logo_path del carné público es: ' || coalesce(r_json -> 'clinica' ->> 'logo_path', 'null'));
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_l, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_json := public.mi_plan();
    if (r_json ->> 'logo_guardado')::boolean is not true or (r_json ->> 'logo_permitido')::boolean is not true then
      failures := failures || ('R40 mi_plan con Pro: ' || r_json::text);
    end if;
  exception when others then
    failures := failures || ('R40 error inesperado: ' || sqlerrm);
  end;

  -- R41: toda clínica tiene exactamente una fila de plan y el backfill es idempotente (0 filas al repetirlo).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into r_n from public.clinicas c
      where (select count(*) from public.clinica_planes cp where cp.clinica_id = c.id) <> 1;
    if r_n <> 0 then
      failures := failures || format('R41 hay %s clínica(s) sin exactamente una fila de plan', r_n);
    end if;
    insert into public.clinica_planes (clinica_id, plan) select c.id, 'beta' from public.clinicas c where not exists (select 1 from public.clinica_planes);
    get diagnostics r_n2 = row_count;
    if r_n2 <> 0 then
      failures := failures || format('R41 el backfill repetido insertó %s fila(s)', r_n2);
    end if;
  exception when others then
    failures := failures || ('R41 error inesperado: ' || sqlerrm);
  end;

  -- R42: asignar_plan valida plan, clínica y fechas.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    begin
      perform public.asignar_plan(r_c_deriv, 'oro');
      failures := failures || 'R42 el plan oro debía fallar con check_violation';
    exception
      when check_violation then null;
      when others then failures := failures || ('R42 plan oro: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.asignar_plan(gen_random_uuid(), 'pro', null, r_hoy + 30);
      failures := failures || 'R42 una clínica inexistente debía fallar con foreign_key_violation';
    exception
      when foreign_key_violation then null;
      when others then failures := failures || ('R42 clínica inexistente: error inesperado: ' || sqlerrm);
    end;
    begin
      perform public.asignar_plan(r_c_deriv, 'pro', null, null, false);
      failures := failures || 'R42 Pro sin pagado_hasta debía fallar con check_violation';
    exception
      when check_violation then null;
      when others then failures := failures || ('R42 Pro sin fecha: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('R42 error inesperado: ' || sqlerrm);
  end;

  -- R43: asignar_plan devuelve jsonb con el plan efectivo resultante.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    r_json := public.asignar_plan(r_c_deriv, 'pro', null, r_hoy + 20);
    select * into r_row from public._plan_efectivo(r_c_deriv);
    if r_json ->> 'plan' is distinct from r_row.plan or r_json ->> 'estado' is distinct from r_row.estado
       or r_json ->> 'plan' is distinct from 'pro' then
      failures := failures || ('R43 asignar_plan devolvió: ' || coalesce(r_json::text, 'null'));
    end if;
  exception when others then
    failures := failures || ('R43 error inesperado: ' || sqlerrm);
  end;

  -- R44: anon sin acceso y triggers de la fase en su sitio (guarda en exactamente 13 tablas).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if has_table_privilege('anon', 'public.clinica_planes', 'SELECT') then
      failures := failures || 'R44 anon tiene SELECT sobre clinica_planes';
    end if;
    if not exists (
      select 1 from pg_trigger t
      where t.tgrelid = 'public.clinicas'::regclass and t.tgname = 'clinicas_crear_plan' and not t.tgisinternal
        and (t.tgtype & 1) = 1 and (t.tgtype & 2) = 0 and (t.tgtype & 4) <> 0
    ) then
      failures := failures || 'R44 falta clinicas_crear_plan (AFTER INSERT) en clinicas';
    end if;
    if not exists (select 1 from pg_trigger t where t.tgrelid = 'public.mascotas'::regclass and t.tgname = 'mascotas_validar_limite' and not t.tgisinternal)
       or not exists (select 1 from pg_trigger t where t.tgrelid = 'public.clinicas'::regclass and t.tgname = 'clinicas_validar_logo' and not t.tgisinternal)
       or not exists (select 1 from pg_trigger t where t.tgrelid = 'public.protocolos_vacunacion'::regclass and t.tgname = 'protocolos_validar_plan' and not t.tgisinternal) then
      failures := failures || 'R44 faltan mascotas_validar_limite, clinicas_validar_logo o protocolos_validar_plan';
    end if;
    select array_agg(c.relname::text order by c.relname) into r_arr
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
     where t.tgname = 'guard_solo_lectura' and not t.tgisinternal and n.nspname = 'public';
    if r_arr is null or cardinality(r_arr) <> 13
       or not (r_arr <@ array['cita_mascotas', 'citas', 'clientes', 'clinica_servicios', 'cobro_contadores', 'cobro_items', 'cobros', 'consultas', 'dosis_aplicadas', 'mascota_pesos', 'mascotas', 'movimientos_inventario', 'productos']
               and array['cita_mascotas', 'citas', 'clientes', 'clinica_servicios', 'cobro_contadores', 'cobro_items', 'cobros', 'consultas', 'dosis_aplicadas', 'mascota_pesos', 'mascotas', 'movimientos_inventario', 'productos'] <@ r_arr) then
      failures := failures || ('R44 guard_solo_lectura está en: ' || coalesce(array_to_string(r_arr, ','), 'ninguna tabla'));
    end if;
  exception when others then
    failures := failures || ('R44 error inesperado: ' || sqlerrm);
  end;

  -- R45: Beta con fecha alimenta el aviso de Beta: vigente con días restantes, también en mi_plan.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null, prueba_pro_hasta = null, prueba_clinica_hasta = null, prueba_clinica_usada = false, beta_hasta = null where clinica_id = r_c_deriv;
    perform public.asignar_plan(r_c_deriv, 'beta', null, null, false, r_hoy + 5);
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy);
    if r_row.plan is distinct from 'beta' or r_row.estado is distinct from 'vigente'
       or r_row.vigente_hasta is distinct from r_hoy + 5 or r_row.dias_restantes is distinct from 5 then
      failures := failures || format('R45 Beta con fecha: plan=%s estado=%s hasta=%s dias=%s', r_row.plan, r_row.estado, r_row.vigente_hasta, r_row.dias_restantes);
    end if;
    select * into r_row from public._plan_efectivo(r_c_deriv, r_hoy + 5);
    if r_row.estado is distinct from 'vigente' or r_row.dias_restantes is distinct from 0 then
      failures := failures || format('R45 último día de la Beta: estado=%s dias=%s', r_row.estado, r_row.dias_restantes);
    end if;
    perform public.asignar_plan(r_c_n, 'beta', null, null, false, r_hoy + 5);
    perform set_config('request.jwt.claims', json_build_object('sub', r_vet_n, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    r_json := public.mi_plan();
    if r_json ->> 'plan' is distinct from 'beta' or r_json ->> 'estado' is distinct from 'vigente'
       or (r_json ->> 'vigente_hasta')::date is distinct from r_hoy + 5
       or (r_json ->> 'dias_restantes')::int is distinct from 5 then
      failures := failures || ('R45 mi_plan con Beta con fecha: ' || r_json::text);
    end if;
  exception when others then
    failures := failures || ('R45 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- ===== S: Inventario (Fase 6) =====
  -- S1..S23. Fixtures propios (s_*): nunca vet_a/vet_b, cuyo plan se muta en bloques previos.
  -- Cada regreso a postgres limpia request.jwt.claims. Todo se revierte al final.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);

  -- Setup S (no cuenta en checks): admin, otro admin, admin del resumen y un colega no admin de la clínica S.
  begin
    s_hoy := public._hoy_bogota();
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values
      (s_vet_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-s-admin@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke S Admin', 'clinica_nombre', 'Smoke Clinica S Admin'),
       now(), now()),
      (s_vet_otro, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-s-otro@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke S Otro', 'clinica_nombre', 'Smoke Clinica S Otro'),
       now(), now()),
      (s_vet_res, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-s-res@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke S Resumen', 'clinica_nombre', 'Smoke Clinica S Resumen'),
       now(), now());
    select clinica_id into s_c from public.perfiles where id = s_vet_admin;
    select clinica_id into s_c_otro from public.perfiles where id = s_vet_otro;
    select clinica_id into s_c_res from public.perfiles where id = s_vet_res;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select g.codigo into s_cod from public.generar_invitacion_clinica() g;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (s_vet_col, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'smoke-s-col@vetapp.invalid',
            jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke S Colega', 'codigo_invitacion', s_cod),
            now(), now());
  exception when others then
    failures := failures || ('SETUPS error inesperado: ' || sqlerrm);
  end;

  -- S1: estructura de las dos tablas.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    foreach s_t in array array['productos', 'movimientos_inventario'] loop
      if not exists (select 1 from pg_class c where c.oid = ('public.' || s_t)::regclass and c.relrowsecurity) then
        failures := failures || ('S1 ' || s_t || ' sin RLS habilitado');
      end if;
      select count(*) into s_n from pg_policies p where p.schemaname = 'public' and p.tablename = s_t;
      if s_n <> 1 or not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = s_t and p.cmd = 'SELECT') then
        failures := failures || ('S1 ' || s_t || ' debe tener exactamente una policy SELECT (hay ' || s_n || ')');
      end if;
    end loop;
    if not exists (select 1 from pg_constraint where conname = 'productos_cantidad_no_negativa')
       or not exists (select 1 from pg_constraint where conname = 'movimientos_producto_misma_clinica_fkey')
       or not exists (select 1 from pg_constraint where conname = 'movimientos_veterinario_perfil_fkey')
       or not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'productos_clinica_nombre_activo_uq') then
      failures := failures || 'S1 faltan constraints o el índice único parcial de nombre';
    end if;
  exception when others then
    failures := failures || ('S1 error inesperado: ' || sqlerrm);
  end;

  -- S2: privilegios (anon nada, authenticated sin escritura directa, RPC solo authenticated).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    foreach s_t in array array['public.productos', 'public.movimientos_inventario'] loop
      if has_table_privilege('anon', s_t, 'SELECT') then
        failures := failures || ('S2 anon tiene SELECT sobre ' || s_t);
      end if;
      foreach s_p in array array['INSERT', 'UPDATE', 'DELETE'] loop
        if has_table_privilege('authenticated', s_t, s_p) then
          failures := failures || ('S2 authenticated tiene ' || s_p || ' sobre ' || s_t);
        end if;
      end loop;
    end loop;
    foreach s_t in array array[
      'public.crear_producto(text,text,int,int,text,date,int,int)',
      'public.actualizar_producto(uuid,text,text,date,int,int,int)',
      'public.archivar_producto(uuid)',
      'public.mover_stock(uuid,int,text,text,uuid,text,uuid,int)',
      'public.inventario_resumen()'
    ] loop
      if has_function_privilege('anon', s_t, 'execute') then
        failures := failures || ('S2 anon puede ejecutar ' || s_t);
      end if;
      if not has_function_privilege('authenticated', s_t, 'execute') then
        failures := failures || ('S2 authenticated no puede ejecutar ' || s_t);
      end if;
    end loop;
  exception when others then
    failures := failures || ('S2 error inesperado: ' || sqlerrm);
  end;

  -- S3: las 5 RPC son security definer con search_path fijado; mover_stock bloquea la fila.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('crear_producto', 'actualizar_producto', 'archivar_producto', 'mover_stock', 'inventario_resumen')
       and p.prosecdef and p.proconfig is not null and 'search_path=public' = any (p.proconfig);
    if s_n <> 5 then
      failures := failures || ('S3 esperaba 5 RPC security definer con search_path=public, hay ' || s_n);
    end if;
    if not exists (
      select 1 from pg_proc p
      where p.pronamespace = 'public'::regnamespace and p.proname = 'mover_stock' and p.prosrc ilike '%for update%'
    ) then
      failures := failures || 'S3 mover_stock no bloquea la fila con for update';
    end if;
  exception when others then
    failures := failures || ('S3 error inesperado: ' || sqlerrm);
  end;

  -- S4: crear producto con stock inicial genera un movimiento de alta; sin stock no genera ninguno.
  checks := checks + 1;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    s_p1 := public.crear_producto('Amoxicilina 500', 'frasco', 5);
    s_p2 := public.crear_producto('Gasas', 'unidad', 0);
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_p1;
    if s_row.clinica_id is distinct from s_c or s_row.cantidad is distinct from 5 or s_row.minimo is distinct from 2
       or s_row.categoria is distinct from 'medicamento' or s_row.creado_por is distinct from s_vet_admin then
      failures := failures || format('S4 producto mal creado: clinica=%s cantidad=%s minimo=%s categoria=%s', s_row.clinica_id, s_row.cantidad, s_row.minimo, s_row.categoria);
    end if;
    select count(*) into s_n from public.movimientos_inventario where producto_id = s_p1;
    select * into s_row from public.movimientos_inventario where producto_id = s_p1 limit 1;
    if s_n <> 1 or s_row.motivo is distinct from 'alta' or s_row.origen is distinct from 'alta'
       or s_row.delta is distinct from 5 or s_row.cantidad_resultante is distinct from 5
       or s_row.veterinario_id is distinct from s_vet_admin then
      failures := failures || format('S4 movimiento de alta incorrecto: n=%s motivo=%s origen=%s delta=%s resultante=%s', s_n, s_row.motivo, s_row.origen, s_row.delta, s_row.cantidad_resultante);
    end if;
    select count(*) into s_n from public.movimientos_inventario where producto_id = s_p2;
    if s_n <> 0 then
      failures := failures || 'S4 un producto con cantidad 0 no debía generar movimiento';
    end if;
  exception when others then
    failures := failures || ('S4 error inesperado: ' || sqlerrm);
  end;

  -- S5: el nombre activo es único por clínica sin distinguir mayúsculas ni espacios.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n2 from public.productos where clinica_id = s_c;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.crear_producto('  AMOXICILINA 500 ', 'frasco', 1);
      failures := failures || 'S5 el nombre duplicado debía fallar con unique_violation';
    exception
      when unique_violation then null;
      when others then failures := failures || ('S5 error inesperado en duplicado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n from public.productos where clinica_id = s_c;
    if s_n <> s_n2 then
      failures := failures || 'S5 el duplicado dejó un producto nuevo';
    end if;
  exception when others then
    failures := failures || ('S5 error inesperado: ' || sqlerrm);
  end;

  -- S6: validación de entrada de crear_producto (check_violation).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n2 from public.productos where clinica_id = s_c;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach s_sql in array array[
      'select public.crear_producto(''   '', ''frasco'', 1)',
      'select public.crear_producto(''Smoke S V1'', ''litro'', 1)',
      'select public.crear_producto(''Smoke S V2'', ''frasco'', -1)',
      'select public.crear_producto(''Smoke S V3'', ''frasco'', 1, -1)',
      'select public.crear_producto(''Smoke S V4'', ''frasco'', 1, 2, ''medicamento'', null, -5)'
    ] loop
      begin
        execute s_sql;
        failures := failures || ('S6 debía fallar con check_violation: ' || s_sql);
      exception
        when check_violation then null;
        when others then failures := failures || ('S6 error inesperado (' || s_sql || '): ' || sqlerrm);
      end;
    end loop;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n from public.productos where clinica_id = s_c;
    if s_n <> s_n2 then
      failures := failures || 'S6 una validación fallida dejó un producto nuevo';
    end if;
  exception when others then
    failures := failures || ('S6 error inesperado: ' || sqlerrm);
  end;

  -- S7: un CLIENTE no puede usar ninguna RPC de inventario.
  checks := checks + 1;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', cliente_c_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach s_sql in array array[
      'select public.crear_producto(''Smoke S Cliente'', ''unidad'', 1)',
      format('select * from public.mover_stock(%L, 1, ''compra'')', s_p1),
      'select * from public.inventario_resumen()'
    ] loop
      begin
        execute s_sql;
        failures := failures || ('S7 el CLIENTE no debía poder: ' || s_sql);
      exception
        when insufficient_privilege then null;
        when others then failures := failures || ('S7 error inesperado (' || s_sql || '): ' || sqlerrm);
      end;
    end loop;
  exception when others then
    failures := failures || ('S7 error inesperado: ' || sqlerrm);
  end;

  -- S8: aislamiento entre clínicas (con control positivo).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_otro, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into s_n from public.productos where clinica_id = s_c;
    select count(*) into s_n2 from public.movimientos_inventario where clinica_id = s_c;
    if s_n <> 0 or s_n2 <> 0 then
      failures := failures || format('S8 otra clínica ve productos=%s movimientos=%s de la clínica S', s_n, s_n2);
    end if;
    select count(*) into s_n from public.productos;
    if s_n <> 0 then
      failures := failures || ('S8 el veterinario de otra clínica ve ' || s_n || ' productos visibles');
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into s_n from public.productos where clinica_id = s_c;
    if s_n < 1 then
      failures := failures || 'S8 control positivo: el admin no ve sus propios productos';
    end if;
  exception when others then
    failures := failures || ('S8 error inesperado: ' || sqlerrm);
  end;

  -- S9: IDOR, un veterinario de otra clínica recibe IN002 sin fugar existencia.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n2 from public.movimientos_inventario where producto_id = s_p1;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_otro, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach s_sql in array array[
      format('select * from public.mover_stock(%L, 1, ''compra'')', s_p1),
      format('select public.actualizar_producto(%L, ''X'', ''otro'', null, 2, null, null)', s_p1),
      format('select public.archivar_producto(%L)', s_p1)
    ] loop
      begin
        execute s_sql;
        failures := failures || ('S9 debía fallar con IN002: ' || s_sql);
      exception
        when sqlstate 'IN002' then null;
        when others then failures := failures || ('S9 esperaba IN002 y llegó ' || sqlstate || ' (' || s_sql || ')');
      end;
    end loop;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_p1;
    select count(*) into s_n from public.movimientos_inventario where producto_id = s_p1;
    if s_row.cantidad is distinct from 5 or s_n <> s_n2 then
      failures := failures || format('S9 el IDOR modificó datos: cantidad=%s movimientos=%s (antes %s)', s_row.cantidad, s_n, s_n2);
    end if;
  exception when others then
    failures := failures || ('S9 error inesperado: ' || sqlerrm);
  end;

  -- S10: un colega no admin ajusta stock; queda registrado quién y cuánto quedó.
  checks := checks + 1;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into s_row from public.mover_stock(s_p1, -2, 'uso');
    s_mov := s_row.movimiento_id;
    if s_row.cantidad_nueva is distinct from 3 or s_mov is null then
      failures := failures || format('S10 mover_stock devolvió cantidad_nueva=%s movimiento=%s', s_row.cantidad_nueva, s_mov);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_p1;
    if s_row.cantidad is distinct from 3 then
      failures := failures || ('S10 cantidad esperada 3, hay ' || s_row.cantidad);
    end if;
    select * into s_row from public.movimientos_inventario where id = s_mov;
    if s_row.delta is distinct from -2 or s_row.cantidad_resultante is distinct from 3 or s_row.motivo is distinct from 'uso'
       or s_row.origen is distinct from 'ajuste' or s_row.veterinario_id is distinct from s_vet_col then
      failures := failures || format('S10 movimiento incorrecto: delta=%s resultante=%s motivo=%s origen=%s', s_row.delta, s_row.cantidad_resultante, s_row.motivo, s_row.origen);
    end if;
  exception when others then
    failures := failures || ('S10 error inesperado: ' || sqlerrm);
  end;

  -- S11: sin stock suficiente falla con IN001 y no cambia nada.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n2 from public.movimientos_inventario where producto_id = s_p1;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform * from public.mover_stock(s_p1, -10, 'uso');
      failures := failures || 'S11 mover_stock -10 con stock 3 debía fallar con IN001';
    exception
      when sqlstate 'IN001' then null;
      when others then failures := failures || ('S11 error inesperado: ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_p1;
    select count(*) into s_n from public.movimientos_inventario where producto_id = s_p1;
    if s_row.cantidad is distinct from 3 or s_n <> s_n2 then
      failures := failures || format('S11 el stock insuficiente cambió datos: cantidad=%s movimientos=%s (antes %s)', s_row.cantidad, s_n, s_n2);
    end if;
  exception when others then
    failures := failures || ('S11 error inesperado: ' || sqlerrm);
  end;

  -- S12: validación de mover_stock (check_violation).
  checks := checks + 1;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach s_sql in array array[
      format('select * from public.mover_stock(%L, 0, ''compra'')', s_p1),
      format('select * from public.mover_stock(%L, 100001, ''compra'')', s_p1),
      format('select * from public.mover_stock(%L, 1, ''robo'')', s_p1),
      format('select * from public.mover_stock(%L, 1, ''alta'')', s_p1),
      format('select * from public.mover_stock(%L, -1, ''venta'')', s_p1),
      format('select * from public.mover_stock(%L, 1, ''compra'', ''factura'')', s_p1),
      format('select * from public.mover_stock(%L, 1, ''deshacer'')', s_p1)
    ] loop
      begin
        execute s_sql;
        failures := failures || ('S12 debía fallar con check_violation: ' || s_sql);
      exception
        when check_violation then null;
        when others then failures := failures || ('S12 error inesperado (' || s_sql || '): ' || sqlerrm);
      end;
    end loop;
  exception when others then
    failures := failures || ('S12 error inesperado: ' || sqlerrm);
  end;

  -- S13: deshacer un ajuste (una sola vez, solo su inverso exacto, solo del mismo producto).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select id into s_mov_alta from public.movimientos_inventario where producto_id = s_p1 and motivo = 'alta';
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into s_row from public.mover_stock(s_p1, 2, 'deshacer', 'ajuste', null, null, s_mov);
    if s_row.cantidad_nueva is distinct from 5 then
      failures := failures || ('S13 deshacer debía dejar 5, dejó ' || s_row.cantidad_nueva);
    end if;
    select * into s_row from public.movimientos_inventario where id = s_row.movimiento_id;
    if s_row.deshace_id is distinct from s_mov then
      failures := failures || 'S13 el movimiento de deshacer no referencia al original';
    end if;
    begin
      perform * from public.mover_stock(s_p1, 2, 'deshacer', 'ajuste', null, null, s_mov);
      failures := failures || 'S13 deshacer dos veces debía fallar con IN003';
    exception
      when sqlstate 'IN003' then null;
      when others then failures := failures || ('S13 segundo deshacer: error inesperado: ' || sqlerrm);
    end;
    begin
      perform * from public.mover_stock(s_p1, 3, 'deshacer', 'ajuste', null, null, s_mov_alta);
      failures := failures || 'S13 deshacer con delta que no es el inverso debía fallar con check_violation';
    exception
      when check_violation then null;
      when others then failures := failures || ('S13 delta no inverso: error inesperado: ' || sqlerrm);
    end;
    select * into s_row from public.mover_stock(s_p2, 4, 'compra');
    s_mov2 := s_row.movimiento_id;
    begin
      perform * from public.mover_stock(s_p1, -4, 'deshacer', 'ajuste', null, null, s_mov2);
      failures := failures || 'S13 deshacer un movimiento de otro producto debía fallar con check_violation';
    exception
      when check_violation then null;
      when others then failures := failures || ('S13 otro producto: error inesperado: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('S13 error inesperado: ' || sqlerrm);
  end;

  -- S14: ninguna escritura directa sobre las tablas (ni el admin), solo vía RPC.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n2 from public.movimientos_inventario where clinica_id = s_c;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach s_sql in array array[
      format('update public.productos set cantidad = 99 where id = %L', s_p1),
      format('insert into public.productos (clinica_id, nombre, unidad, creado_por) values (%L, ''Smoke S Directo'', ''unidad'', %L)', s_c, s_vet_admin),
      format('update public.movimientos_inventario set delta = 1 where clinica_id = %L', s_c),
      format('delete from public.movimientos_inventario where clinica_id = %L', s_c),
      format('insert into public.movimientos_inventario (clinica_id, producto_id, delta, cantidad_resultante, motivo, veterinario_id) values (%L, %L, 1, 6, ''compra'', %L)', s_c, s_p1, s_vet_admin)
    ] loop
      begin
        execute s_sql;
        get diagnostics s_n = row_count;
        if s_n > 0 then
          failures := failures || ('S14 la escritura directa afectó filas: ' || s_sql);
        end if;
      exception
        when insufficient_privilege then null;
        when others then failures := failures || ('S14 error inesperado (' || s_sql || '): ' || sqlerrm);
      end;
    end loop;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_p1;
    select count(*) into s_n from public.movimientos_inventario where clinica_id = s_c;
    if s_row.cantidad is distinct from 5 or s_n <> s_n2 then
      failures := failures || format('S14 las escrituras directas dejaron rastro: cantidad=%s movimientos=%s (antes %s)', s_row.cantidad, s_n, s_n2);
    end if;
  exception when others then
    failures := failures || ('S14 error inesperado: ' || sqlerrm);
  end;

  -- S15: un movimiento no puede apuntar a un producto de otra clínica (FK compuesta).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    begin
      insert into public.movimientos_inventario (clinica_id, producto_id, delta, cantidad_resultante, motivo, veterinario_id)
      values (s_c_otro, s_p1, 1, 1, 'compra', s_vet_admin);
      failures := failures || 'S15 un movimiento con producto de otra clínica debía fallar con foreign_key_violation';
    exception
      when foreign_key_violation then null;
      when others then failures := failures || ('S15 error inesperado en el insert: ' || sqlerrm);
    end;
  exception when others then
    failures := failures || ('S15 error inesperado: ' || sqlerrm);
  end;

  -- S16: mínimo, precios y archivar son solo del administrador; nombre, categoría y vencimiento los edita cualquiera.
  checks := checks + 1;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach s_sql in array array[
      format('select public.actualizar_producto(%L, ''Amoxicilina 500'', ''medicamento'', null, 4, null, null)', s_p1),
      format('select public.actualizar_producto(%L, ''Amoxicilina 500'', ''medicamento'', null, 2, 85000, null)', s_p1),
      format('select public.archivar_producto(%L)', s_p1)
    ] loop
      begin
        execute s_sql;
        failures := failures || ('S16 el colega no admin no debía poder: ' || s_sql);
      exception
        when insufficient_privilege then null;
        when others then failures := failures || ('S16 error inesperado (' || s_sql || '): ' || sqlerrm);
      end;
    end loop;
    perform public.actualizar_producto(s_p1, 'Amoxicilina 500 mg', 'insumo', s_hoy + 60, 2, null, null);
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_p1;
    if s_row.minimo is distinct from 2 or s_row.precio_venta_cop is not null or s_row.archivado_at is not null then
      failures := failures || format('S16 los intentos denegados cambiaron datos: minimo=%s precio=%s', s_row.minimo, s_row.precio_venta_cop);
    end if;
    if s_row.nombre is distinct from 'Amoxicilina 500 mg' or s_row.categoria is distinct from 'insumo'
       or s_row.vencimiento is distinct from s_hoy + 60 then
      failures := failures || format('S16 la edición permitida no se aplicó: nombre=%s categoria=%s vencimiento=%s', s_row.nombre, s_row.categoria, s_row.vencimiento);
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.actualizar_producto(s_p1, 'Amoxicilina 500 mg', 'insumo', s_hoy + 60, 4, 85000, 40000);
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_p1;
    if s_row.minimo is distinct from 4 or s_row.precio_venta_cop is distinct from 85000 or s_row.costo_cop is distinct from 40000 then
      failures := failures || format('S16 el admin no pudo cambiar mínimo y precios: minimo=%s venta=%s costo=%s', s_row.minimo, s_row.precio_venta_cop, s_row.costo_cop);
    end if;
  exception when others then
    failures := failures || ('S16 error inesperado: ' || sqlerrm);
  end;

  -- S17: archivar (solo admin) saca el producto de operación, libera el nombre y conserva el historial.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n2 from public.movimientos_inventario where producto_id = s_p1;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.archivar_producto(s_p1);
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_p1;
    if s_row.archivado_at is null or s_row.archivado_por is distinct from s_vet_admin then
      failures := failures || 'S17 el producto no quedó archivado por el admin';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach s_sql in array array[
      format('select * from public.mover_stock(%L, 1, ''compra'')', s_p1),
      format('select public.actualizar_producto(%L, ''Otro'', ''otro'', null, 2, null, null)', s_p1)
    ] loop
      begin
        execute s_sql;
        failures := failures || ('S17 un producto archivado debía fallar con IN002: ' || s_sql);
      exception when others then
        if sqlstate is distinct from 'IN002' then
          failures := failures || ('S17 esperaba IN002 y llegó ' || sqlstate || ' (' || s_sql || ')');
        end if;
      end;
    end loop;
    s_p3 := public.crear_producto('Amoxicilina 500 mg', 'frasco', 1);
    select count(*) into s_n from public.movimientos_inventario where producto_id = s_p1;
    if s_n <> s_n2 then
      failures := failures || format('S17 el historial del producto archivado cambió: %s (antes %s)', s_n, s_n2);
    end if;
  exception when others then
    failures := failures || ('S17 error inesperado: ' || sqlerrm);
  end;

  -- S18: resumen de stock bajo / por vencer / vencidos (bordes incluidos).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_res, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.crear_producto('Smoke S A', 'unidad', 1, 2);
    perform public.crear_producto('Smoke S B', 'unidad', 2, 2);
    perform public.crear_producto('Smoke S C', 'unidad', 0, 0);
    perform public.crear_producto('Smoke S D', 'unidad', 0, 3);
    perform public.crear_producto('Smoke S E', 'unidad', 5, 1, 'medicamento', s_hoy + 30);
    perform public.crear_producto('Smoke S F', 'unidad', 5, 1, 'medicamento', s_hoy + 31);
    perform public.crear_producto('Smoke S G', 'unidad', 5, 1, 'medicamento', s_hoy);
    perform public.crear_producto('Smoke S H', 'unidad', 5, 1, 'medicamento', s_hoy - 1);
    s_pi := public.crear_producto('Smoke S I', 'unidad', 0, 5);
    perform public.archivar_producto(s_pi);
    select * into s_row from public.inventario_resumen();
    if s_row.bajos is distinct from 2 or s_row.por_vencer is distinct from 2 or s_row.vencidos is distinct from 1 then
      failures := failures || format('S18 resumen esperado 2/2/1, llegó bajos=%s por_vencer=%s vencidos=%s', s_row.bajos, s_row.por_vencer, s_row.vencidos);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_otro, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into s_row from public.inventario_resumen();
    if s_row.bajos is distinct from 0 or s_row.por_vencer is distinct from 0 or s_row.vencidos is distinct from 0 then
      failures := failures || format('S18 otra clínica ve resumen %s/%s/%s', s_row.bajos, s_row.por_vencer, s_row.vencidos);
    end if;
  exception when others then
    failures := failures || ('S18 error inesperado: ' || sqlerrm);
  end;

  -- S19: en solo lectura (D-14) el colega lee pero no escribe stock; el admin sí.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes
       set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null,
           prueba_pro_hasta = s_hoy - 17, prueba_clinica_hasta = s_hoy - 16, prueba_clinica_usada = true, beta_hasta = null
     where clinica_id = s_c;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    if public.puede_escribir() then
      failures := failures || 'S19 puede_escribir() debía ser false para el colega';
    end if;
    foreach s_sql in array array[
      'select public.crear_producto(''Smoke S Bloqueado'', ''unidad'', 1)',
      format('select * from public.mover_stock(%L, 1, ''compra'')', s_p3),
      format('select public.actualizar_producto(%L, ''Smoke S Renombrado'', ''medicamento'', null, 2, null, null)', s_p3)
    ] loop
      begin
        execute s_sql;
        failures := failures || ('S19 debía fallar con LP004: ' || s_sql);
      exception when others then
        if sqlstate is distinct from 'LP004' then
          failures := failures || ('S19 esperaba LP004 y llegó ' || sqlstate || ' (' || s_sql || ')');
        end if;
      end;
    end loop;
    select count(*) into s_n from public.productos where clinica_id = s_c;
    if s_n <= 0 then
      failures := failures || 'S19 el colega en solo lectura debía seguir leyendo productos';
    end if;
    select count(*) into s_n from public.inventario_resumen();
    if s_n <> 1 then
      failures := failures || 'S19 inventario_resumen() debía devolver una fila en solo lectura';
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into s_row from public.mover_stock(s_p3, 1, 'compra');
    if s_row.cantidad_nueva is distinct from 2 then
      failures := failures || ('S19 el admin debía poder mover stock (esperaba 2, llegó ' || coalesce(s_row.cantidad_nueva::text, 'null') || ')');
    end if;
  exception when others then
    failures := failures || ('S19 error inesperado: ' || sqlerrm);
  end;

  -- S20: un autor retirado de la clínica sigue visible para quien ve sus movimientos.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.perfiles set activo = false where id = s_vet_col;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    if not public.es_autor_en_mi_clinica(s_vet_col) then
      failures := failures || 'S20 es_autor_en_mi_clinica debía ser true para el autor retirado';
    end if;
    select count(*) into s_n from public.perfiles where id = s_vet_col and nombre = 'Smoke S Colega';
    if s_n <> 1 then
      failures := failures || ('S20 el admin debía ver al autor retirado (filas: ' || s_n || ')');
    end if;
  exception when others then
    failures := failures || ('S20 error inesperado: ' || sqlerrm);
  end;

  -- S21: conteo con la cantidad esperada correcta aplica el delta (CR-01).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    s_pc := public.crear_producto('Smoke S Conteo', 'unidad', 7);
    select * into s_row from public.mover_stock(s_pc, 3, 'conteo', 'ajuste', null, null, null, 7);
    if s_row.cantidad_nueva is distinct from 10 then
      failures := failures || ('S21 conteo con esperada correcta debía dejar 10, dejó ' || coalesce(s_row.cantidad_nueva::text, 'null'));
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_pc;
    if s_row.cantidad is distinct from 10 then
      failures := failures || ('S21 cantidad esperada 10, hay ' || s_row.cantidad);
    end if;
  exception when others then
    failures := failures || ('S21 error inesperado: ' || sqlerrm);
  end;

  -- S22: conteo con una cantidad esperada vieja falla con IN004 y no cambia nada (CR-01).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into s_n2 from public.movimientos_inventario where producto_id = s_pc;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform * from public.mover_stock(s_pc, -2, 'conteo', 'ajuste', null, null, null, 7);
      failures := failures || 'S22 conteo con esperada 7 (hay 10) debía fallar con IN004';
    exception
      when sqlstate 'IN004' then null;
      when others then failures := failures || ('S22 esperaba IN004 y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_pc;
    select count(*) into s_n from public.movimientos_inventario where producto_id = s_pc;
    if s_row.cantidad is distinct from 10 or s_n <> s_n2 then
      failures := failures || format('S22 el conteo rechazado cambió datos: cantidad=%s movimientos=%s (antes %s)', s_row.cantidad, s_n, s_n2);
    end if;
  exception when others then
    failures := failures || ('S22 error inesperado: ' || sqlerrm);
  end;

  -- S23: solo se deshacen ajustes; el movimiento de alta no se puede deshacer aunque sea el inverso exacto (WR-04).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select id into s_mov_alta from public.movimientos_inventario where producto_id = s_pc and origen = 'alta';
    select count(*) into s_n2 from public.movimientos_inventario where producto_id = s_pc;
    if s_mov_alta is null then
      failures := failures || 'S23 falta el movimiento de alta del producto de conteo';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', s_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform * from public.mover_stock(s_pc, -7, 'deshacer', 'ajuste', null, null, s_mov_alta);
      failures := failures || 'S23 deshacer un alta debía fallar con check_violation';
    exception
      when check_violation then null;
      when others then failures := failures || ('S23 esperaba check_violation y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into s_row from public.productos where id = s_pc;
    select count(*) into s_n from public.movimientos_inventario where producto_id = s_pc;
    if s_row.cantidad is distinct from 10 or s_n <> s_n2 then
      failures := failures || format('S23 el deshacer rechazado cambió datos: cantidad=%s movimientos=%s (antes %s)', s_row.cantidad, s_n, s_n2);
    end if;
  exception when others then
    failures := failures || ('S23 error inesperado: ' || sqlerrm);
  end;

  -------------------------------------------------------------------------
  -- ===== T: Facturación (Fase 7) =====
  -- T1..T23. Fixtures propios (t_*): nunca vet_a/vet_b ni los del bloque S, cuyos planes se mutan antes.
  -- Cada regreso a postgres limpia request.jwt.claims. Todo se revierte al final.
  -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);

  -- Setup T (no cuenta en checks): admin y otro admin (clínicas propias), plan beta en la clínica T y
  -- tres colegas invitados (cada código de invitación es de un solo uso), más clientes, mascotas,
  -- productos, un servicio, una cita completada y su consulta.
  begin
    t_hoy := public._hoy_bogota();
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values
      (t_vet_admin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-t-admin@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke T Admin', 'clinica_nombre', 'Smoke Clinica T Admin'),
       now(), now()),
      (t_vet_otro, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-t-otro@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke T Otro', 'clinica_nombre', 'Smoke Clinica T Otro'),
       now(), now());
    select clinica_id into t_c from public.perfiles where id = t_vet_admin;
    select clinica_id into t_c_otro from public.perfiles where id = t_vet_otro;
    perform public.asignar_plan(t_c, 'beta');

    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select g.codigo into t_cod from public.generar_invitacion_clinica() g;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (t_vet_col, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'smoke-t-col@vetapp.invalid',
            jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke T Colega', 'codigo_invitacion', t_cod),
            now(), now());

    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select g.codigo into t_cod from public.generar_invitacion_clinica() g;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (t_vet_col2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'smoke-t-col2@vetapp.invalid',
            jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke T Colega Dos', 'codigo_invitacion', t_cod),
            now(), now());

    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select g.codigo into t_cod from public.generar_invitacion_clinica() g;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (t_vet_q, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'smoke-t-q@vetapp.invalid',
            jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke T Cotizador', 'codigo_invitacion', t_cod),
            now(), now());

    insert into public.clientes (clinica_id, nombre, telefono, cedula)
      values (t_c, 'Smoke T Cliente', '3000000071', '1020304050') returning id into t_cli;
    insert into public.clientes (clinica_id, nombre, telefono)
      values (t_c, 'Smoke T Cliente Dos', '3000000072') returning id into t_cli2;
    insert into public.clientes (clinica_id, nombre, telefono)
      values (t_c_otro, 'Smoke T Cliente Otro', '3000000073') returning id into t_cli_otro;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (t_cli, t_c, 'Smoke T Luna', 'perro') returning id into t_m;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (t_cli2, t_c, 'Smoke T Tom', 'gato') returning id into t_m2;
    insert into public.mascotas (dueno_id, clinica_id, nombre, especie)
      values (t_cli_otro, t_c_otro, 'Smoke T Otra', 'perro') returning id into t_m_otro;
    insert into public.productos (clinica_id, nombre, unidad, cantidad, precio_venta_cop, creado_por)
      values (t_c, 'Amoxicilina T', 'frasco', 10, 85000, t_vet_admin) returning id into t_p1;
    insert into public.productos (clinica_id, nombre, unidad, cantidad, creado_por)
      values (t_c, 'Gasas T', 'unidad', 5, t_vet_admin) returning id into t_p2;
    insert into public.productos (clinica_id, nombre, unidad, cantidad, creado_por, archivado_at, archivado_por)
      values (t_c, 'Archivado T', 'unidad', 5, t_vet_admin, now(), t_vet_admin) returning id into t_p_arch;
    insert into public.productos (clinica_id, nombre, unidad, cantidad, creado_por)
      values (t_c_otro, 'Otro T', 'unidad', 5, t_vet_otro) returning id into t_p_otro;
    insert into public.clinica_servicios (clinica_id, nombre, precio_cop, creado_por)
      values (t_c, 'Consulta', 50000, t_vet_admin) returning id into t_s1;
    insert into public.clinica_servicios (clinica_id, nombre, precio_cop, creado_por)
      values (t_c_otro, 'Consulta Otra', 40000, t_vet_otro) returning id into t_s_otro;
    insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora, estado)
      values (t_c, t_cli, t_vet_col, now() - interval '2 hours', 'completada') returning id into t_cita;
    insert into public.cita_mascotas (cita_id, mascota_id, clinica_id) values (t_cita, t_m, t_c);
    insert into public.citas (clinica_id, cliente_id, veterinario_id, fecha_hora)
      values (t_c, t_cli2, t_vet_col, now() + interval '1 day') returning id into t_cita2;
    insert into public.cita_mascotas (cita_id, mascota_id, clinica_id) values (t_cita2, t_m2, t_c);
    insert into public.consultas (mascota_id, veterinario_id, diagnostico, tratamiento, cita_id)
      values (t_m, t_vet_col, 'T', 'T', t_cita) returning id into t_cons;
  exception when others then
    failures := failures || ('SETUPT error inesperado: ' || sqlerrm);
  end;

  -- T1: estructura (4 tablas con RLS, solo policies SELECT, constraints, índices y columnas nuevas).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    foreach t_t in array array['cobros', 'cobro_items', 'clinica_servicios', 'cobro_contadores'] loop
      if to_regclass('public.' || t_t) is null
         or not exists (select 1 from pg_class c where c.oid = to_regclass('public.' || t_t) and c.relrowsecurity) then
        failures := failures || ('T1 ' || t_t || ' no existe o no tiene RLS habilitado');
      end if;
      select count(*) into t_n from pg_policies p where p.schemaname = 'public' and p.tablename = t_t;
      select count(*) into t_n2 from pg_policies p where p.schemaname = 'public' and p.tablename = t_t and p.cmd = 'SELECT';
      if t_t = 'cobro_contadores' then
        if t_n <> 0 then
          failures := failures || ('T1 cobro_contadores no debe tener policies (hay ' || t_n || ')');
        end if;
      elsif t_n <> 1 or t_n2 <> 1 then
        failures := failures || ('T1 ' || t_t || ' debe tener exactamente una policy SELECT (hay ' || t_n || ')');
      end if;
    end loop;
    foreach t_t in array array[
      'cobros_numero_uq', 'cobros_clave_uq', 'cobros_estado_por_tipo', 'cobros_creado_por_perfil_fkey',
      'cobros_anulada_por_perfil_fkey', 'cobros_convertida_en_fkey', 'cobros_cotizacion_origen_fkey',
      'cobro_items_cobro_misma_clinica_fkey', 'clientes_cedula_formato', 'clinicas_nit_formato'
    ] loop
      if not exists (select 1 from pg_constraint where conname = t_t) then
        failures := failures || ('T1 falta la constraint ' || t_t);
      end if;
    end loop;
    foreach t_t in array array['cobros_cita_activa_uq', 'cobros_consulta_activa_uq', 'clinica_servicios_nombre_activo_uq'] loop
      if not exists (select 1 from pg_indexes where schemaname = 'public' and indexname = t_t) then
        failures := failures || ('T1 falta el índice ' || t_t);
      end if;
    end loop;
    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'clientes' and column_name = 'cedula')
       or not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'clinicas' and column_name = 'nit') then
      failures := failures || 'T1 faltan las columnas clientes.cedula o clinicas.nit'::text;
    end if;
  exception when others then
    failures := failures || ('T1 error inesperado: ' || sqlerrm);
  end;

  -- T2: privilegios (anon nada; authenticated sin escritura directa ni lectura de contadores; RPC solo
  -- authenticated; helpers privados para nadie).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    foreach t_t in array array['public.cobros', 'public.cobro_items', 'public.clinica_servicios', 'public.cobro_contadores'] loop
      if to_regclass(t_t) is null then
        failures := failures || ('T2 falta la tabla ' || t_t);
        continue;
      end if;
      if has_table_privilege('anon', t_t, 'SELECT') then
        failures := failures || ('T2 anon tiene SELECT sobre ' || t_t);
      end if;
      foreach t_p in array array['INSERT', 'UPDATE', 'DELETE'] loop
        if has_table_privilege('authenticated', t_t, t_p) then
          failures := failures || ('T2 authenticated tiene ' || t_p || ' sobre ' || t_t);
        end if;
      end loop;
    end loop;
    if to_regclass('public.cobro_contadores') is not null and has_table_privilege('authenticated', 'public.cobro_contadores', 'SELECT') then
      failures := failures || 'T2 authenticated tiene SELECT sobre cobro_contadores'::text;
    end if;
    foreach t_t in array array[
      'public.crear_cuenta_cobro(uuid,uuid,jsonb,uuid,uuid,uuid,uuid)',
      'public.crear_cotizacion(uuid,uuid,jsonb,uuid)',
      'public.marcar_cobro_pagado(uuid,text,date)',
      'public.anular_cobro(uuid,text)'
    ] loop
      if to_regprocedure(t_t) is null then
        failures := failures || ('T2 falta la RPC ' || t_t);
        continue;
      end if;
      if has_function_privilege('anon', t_t, 'execute') then
        failures := failures || ('T2 anon puede ejecutar ' || t_t);
      end if;
      if not has_function_privilege('authenticated', t_t, 'execute') then
        failures := failures || ('T2 authenticated no puede ejecutar ' || t_t);
      end if;
    end loop;
    foreach t_t in array array[
      'public._aplicar_movimiento_stock(uuid,uuid,int,text,uuid,text,uuid,boolean)',
      'public._total_items_cobro(uuid,jsonb)',
      'public._insertar_items_cobro(uuid,uuid,jsonb,boolean,text)',
      'public._numero_cobro(text,int)'
    ] loop
      if to_regprocedure(t_t) is null then
        failures := failures || ('T2 falta el helper ' || t_t);
        continue;
      end if;
      if has_function_privilege('anon', t_t, 'execute') or has_function_privilege('authenticated', t_t, 'execute') then
        failures := failures || ('T2 el helper privado es ejecutable por anon o authenticated: ' || t_t);
      end if;
    end loop;
  exception when others then
    failures := failures || ('T2 error inesperado: ' || sqlerrm);
  end;

  -- T3: las 4 RPC y los 3 helpers plpgsql son security definer con search_path fijado; formato del número.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into t_n from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('crear_cuenta_cobro', 'crear_cotizacion', 'marcar_cobro_pagado', 'anular_cobro',
                         '_aplicar_movimiento_stock', '_total_items_cobro', '_insertar_items_cobro')
       and p.prosecdef and p.proconfig is not null and 'search_path=public' = any (p.proconfig);
    if t_n <> 7 then
      failures := failures || ('T3 esperaba 7 funciones security definer con search_path=public, hay ' || t_n);
    end if;
    if public._numero_cobro('cuenta_cobro', 12) is distinct from 'CC-0012'
       or public._numero_cobro('cotizacion', 4) is distinct from 'COT-0004'
       or public._numero_cobro('cuenta_cobro', 12345) is distinct from 'CC-12345' then
      failures := failures || format('T3 formato de número incorrecto: %s / %s / %s',
        public._numero_cobro('cuenta_cobro', 12), public._numero_cobro('cotizacion', 4), public._numero_cobro('cuenta_cobro', 12345));
    end if;
  exception when others then
    failures := failures || ('T3 error inesperado: ' || sqlerrm);
  end;

  -- T4: emitir una CC: número 1, snapshots, total calculado en el servidor, nombres copiados de la BD,
  -- precio de línea sin tocar el precio base (D-07).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    t_clave := gen_random_uuid();
    t_items := jsonb_build_array(
      jsonb_build_object('tipo', 'producto', 'producto_id', t_p1, 'descripcion', 'Nombre falso', 'cantidad', 2, 'precio_unitario_cop', 80000),
      jsonb_build_object('tipo', 'producto', 'producto_id', t_p2, 'cantidad', 1, 'precio_unitario_cop', 0),
      jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'descripcion', 'X', 'cantidad', 1, 'precio_unitario_cop', 50000),
      jsonb_build_object('tipo', 'producto', 'producto_id', t_p1, 'cantidad', 1, 'precio_unitario_cop', 80000)
    );
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cuenta_cobro(t_clave, t_cli, t_items, t_m);
    t_cobro := t_row.id;
    if t_row.numero is distinct from 1 or t_row.ya_existia is distinct from false then
      failures := failures || format('T4 esperaba numero 1 sin ya_existia, llegó %s / %s', t_row.numero, t_row.ya_existia);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into t_row from public.cobros where id = t_cobro;
    if t_row.tipo is distinct from 'cuenta_cobro' or t_row.estado is distinct from 'pendiente' or t_row.fecha is distinct from t_hoy
       or t_row.cliente_nombre is distinct from 'Smoke T Cliente' or t_row.cliente_cedula is distinct from '1020304050'
       or t_row.mascota_nombre is distinct from 'Smoke T Luna' or t_row.creado_por is distinct from t_vet_col
       or t_row.total_cop is distinct from 290000 then
      failures := failures || format('T4 encabezado incorrecto: tipo=%s estado=%s fecha=%s cliente=%s cedula=%s mascota=%s total=%s',
        t_row.tipo, t_row.estado, t_row.fecha, t_row.cliente_nombre, t_row.cliente_cedula, t_row.mascota_nombre, t_row.total_cop);
    end if;
    select count(*), min(orden), max(orden) into t_n, t_n2, t_n3 from public.cobro_items where cobro_id = t_cobro;
    if t_n <> 4 or t_n2 is distinct from 1 or t_n3 is distinct from 4 then
      failures := failures || format('T4 esperaba 4 ítems con orden 1..4, hay %s (%s..%s)', t_n, t_n2, t_n3);
    end if;
    select count(*) into t_n from public.cobro_items
     where cobro_id = t_cobro and tipo = 'producto'
       and descripcion = case when producto_id = t_p1 then 'Amoxicilina T' when producto_id = t_p2 then 'Gasas T' end;
    select count(*) into t_n2 from public.cobro_items where cobro_id = t_cobro and descripcion = 'Nombre falso';
    if t_n <> 3 or t_n2 <> 0 then
      failures := failures || format('T4 las líneas de producto no copiaron el nombre de la BD (%s correctas, %s con texto del cliente)', t_n, t_n2);
    end if;
    select * into t_row from public.cobro_items where cobro_id = t_cobro and tipo = 'servicio';
    if t_row.descripcion is distinct from 'Consulta' or t_row.precio_unitario_cop is distinct from 50000 or t_row.servicio_id is distinct from t_s1 then
      failures := failures || format('T4 línea de servicio incorrecta: %s / %s', t_row.descripcion, t_row.precio_unitario_cop);
    end if;
    select precio_venta_cop into t_n from public.productos where id = t_p1;
    if t_n is distinct from 85000 then
      failures := failures || ('T4 el precio de línea cambió el precio base del producto: ' || coalesce(t_n::text, 'null'));
    end if;
  exception when others then
    failures := failures || ('T4 error inesperado: ' || sqlerrm);
  end;

  -- T5: descuento de stock agregado por producto, con movimientos origen factura en el libro.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select cantidad into t_n from public.productos where id = t_p1;
    select cantidad into t_n2 from public.productos where id = t_p2;
    if t_n is distinct from 7 or t_n2 is distinct from 4 then
      failures := failures || format('T5 stock esperado 7 y 4, hay %s y %s', t_n, t_n2);
    end if;
    select count(*) into t_n from public.movimientos_inventario where ref_id = t_cobro;
    select count(*) into t_n2 from public.movimientos_inventario
     where ref_id = t_cobro and origen = 'factura' and motivo = 'venta' and nota = 'CC-0001' and veterinario_id = t_vet_col
       and ((producto_id = t_p1 and delta = -3) or (producto_id = t_p2 and delta = -1));
    if t_n <> 2 or t_n2 <> 2 then
      failures := failures || format('T5 esperaba 2 movimientos de venta (uno por producto), hay %s (%s correctos)', t_n, t_n2);
    end if;
  exception when others then
    failures := failures || ('T5 error inesperado: ' || sqlerrm);
  end;

  -- T6: sin stock suficiente falla con IN001 (detail json) y no deja encabezado, ítems ni movimientos.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into t_n from public.cobros where clinica_id = t_c;
    select count(*) into t_n2 from public.cobro_items where clinica_id = t_c;
    select count(*) into t_n3 from public.movimientos_inventario where producto_id = t_p1;
    select cantidad into t_n4 from public.productos where id = t_p1;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform * from public.crear_cuenta_cobro(gen_random_uuid(), t_cli,
        jsonb_build_array(jsonb_build_object('tipo', 'producto', 'producto_id', t_p1, 'cantidad', 50, 'precio_unitario_cop', 85000)));
      failures := failures || 'T6 una CC con 50 unidades y stock 7 debía fallar con IN001'::text;
    exception
      when sqlstate 'IN001' then
        get stacked diagnostics t_sql = pg_exception_detail;
        begin
          t_json := t_sql::jsonb;
          if (t_json ->> 'quedan')::int is distinct from 7 or t_json ->> 'producto' is distinct from 'Amoxicilina T' then
            failures := failures || ('T6 detail de IN001 incorrecto: ' || t_sql);
          end if;
        exception when others then
          failures := failures || ('T6 el detail de IN001 no es json: ' || coalesce(t_sql, 'null'));
        end;
      when others then
        failures := failures || ('T6 esperaba IN001 y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select count(*) from public.cobros where clinica_id = t_c) <> t_n
       or (select count(*) from public.cobro_items where clinica_id = t_c) <> t_n2
       or (select count(*) from public.movimientos_inventario where producto_id = t_p1) <> t_n3
       or (select cantidad from public.productos where id = t_p1) is distinct from t_n4 then
      failures := failures || 'T6 el rechazo por stock dejó encabezado, ítems, movimientos o cambió la cantidad'::text;
    end if;
  exception when others then
    failures := failures || ('T6 error inesperado: ' || sqlerrm);
  end;

  -- T7: el rechazo no quemó número: la siguiente CC válida es la 2.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cuenta_cobro(gen_random_uuid(), t_cli,
      jsonb_build_array(jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 50000)));
    t_cobro2 := t_row.id;
    if t_row.numero is distinct from 2 then
      failures := failures || ('T7 esperaba la CC numero 2 (sin huecos), llegó ' || coalesce(t_row.numero::text, 'null'));
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
  exception when others then
    failures := failures || ('T7 error inesperado: ' || sqlerrm);
  end;

  -- T8: idempotencia (D-21): la misma clave devuelve la misma CC con ya_existia y no mueve stock otra vez.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into t_n from public.cobros where clinica_id = t_c;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cuenta_cobro(t_clave, t_cli, t_items, t_m);
    if t_row.id is distinct from t_cobro or t_row.numero is distinct from 1 or t_row.ya_existia is distinct from true then
      failures := failures || format('T8 el reintento devolvió id distinto o sin ya_existia: numero=%s ya_existia=%s', t_row.numero, t_row.ya_existia);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select cantidad from public.productos where id = t_p1) is distinct from 7
       or (select count(*) from public.movimientos_inventario where ref_id = t_cobro) <> 2
       or (select count(*) from public.cobros where clinica_id = t_c) <> t_n then
      failures := failures || 'T8 el reintento movió stock otra vez o creó otra CC'::text;
    end if;
  exception when others then
    failures := failures || ('T8 error inesperado: ' || sqlerrm);
  end;

  -- T9: producto archivado o de otra clínica -> IN002 y no se crea nada.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into t_n from public.cobros where clinica_id = t_c;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach t_t in array array[t_p_arch::text, t_p_otro::text] loop
      begin
        perform * from public.crear_cuenta_cobro(gen_random_uuid(), t_cli,
          jsonb_build_array(jsonb_build_object('tipo', 'producto', 'producto_id', t_t, 'cantidad', 1, 'precio_unitario_cop', 1000)));
        failures := failures || ('T9 producto no disponible debía fallar con IN002: ' || t_t);
      exception
        when sqlstate 'IN002' then null;
        when others then failures := failures || ('T9 esperaba IN002 y llegó ' || sqlstate || ': ' || sqlerrm);
      end;
    end loop;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select count(*) from public.cobros where clinica_id = t_c) <> t_n
       or exists (select 1 from public.movimientos_inventario where producto_id in (t_p_arch, t_p_otro)) then
      failures := failures || 'T9 el rechazo IN002 dejó una CC o un movimiento'::text;
    end if;
  exception when others then
    failures := failures || ('T9 error inesperado: ' || sqlerrm);
  end;

  -- T10: ids de otra clínica o inconsistentes -> check_violation, sin filtrar existencia y sin crear nada.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into t_n from public.cobros where clinica_id = t_c;
    t_json := jsonb_build_array(jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 50000));
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach t_sql in array array[
      format('select * from public.crear_cuenta_cobro(%L::uuid, %L::uuid, %L::jsonb)', gen_random_uuid(), t_cli_otro, t_json),
      format('select * from public.crear_cuenta_cobro(%L::uuid, %L::uuid, %L::jsonb, %L::uuid)', gen_random_uuid(), t_cli, t_json, t_m_otro),
      format('select * from public.crear_cuenta_cobro(%L::uuid, %L::uuid, %L::jsonb, %L::uuid)', gen_random_uuid(), t_cli, t_json, t_m2),
      format('select * from public.crear_cuenta_cobro(%L::uuid, %L::uuid, %L::jsonb, null, %L::uuid)', gen_random_uuid(), t_cli, t_json, t_cita2),
      format('select * from public.crear_cuenta_cobro(%L::uuid, %L::uuid, %L::jsonb)', gen_random_uuid(), t_cli,
        jsonb_build_array(jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s_otro, 'cantidad', 1, 'precio_unitario_cop', 40000)))
    ] loop
      begin
        execute t_sql;
        failures := failures || ('T10 debía fallar con check_violation: ' || t_sql);
      exception
        when check_violation then null;
        when others then failures := failures || ('T10 esperaba check_violation y llegó ' || sqlstate || ': ' || sqlerrm);
      end;
    end loop;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select count(*) from public.cobros where clinica_id = t_c) <> t_n then
      failures := failures || 'T10 un id ajeno dejó una CC creada'::text;
    end if;
  exception when others then
    failures := failures || ('T10 error inesperado: ' || sqlerrm);
  end;

  -- T11: validación de las líneas (vacías, 51, cantidades, precios, tipo, producto sin id, total 0, desbordamiento).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into t_n from public.cobros where clinica_id = t_c;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach t_json in array array[
      '[]'::jsonb,
      (select jsonb_agg(jsonb_build_object('tipo', 'otro', 'descripcion', 'Smoke T', 'cantidad', 1, 'precio_unitario_cop', 1000)) from generate_series(1, 51)),
      jsonb_build_array(jsonb_build_object('tipo', 'otro', 'descripcion', 'Smoke T', 'cantidad', 0, 'precio_unitario_cop', 1000)),
      jsonb_build_array(jsonb_build_object('tipo', 'otro', 'descripcion', 'Smoke T', 'cantidad', 1.5, 'precio_unitario_cop', 1000)),
      jsonb_build_array(jsonb_build_object('tipo', 'otro', 'descripcion', 'Smoke T', 'cantidad', 1, 'precio_unitario_cop', -1)),
      jsonb_build_array(jsonb_build_object('tipo', 'regalo', 'descripcion', 'Smoke T', 'cantidad', 1, 'precio_unitario_cop', 1000)),
      jsonb_build_array(jsonb_build_object('tipo', 'producto', 'cantidad', 1, 'precio_unitario_cop', 1000)),
      jsonb_build_array(
        jsonb_build_object('tipo', 'otro', 'descripcion', 'Smoke T', 'cantidad', 1, 'precio_unitario_cop', 0),
        jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 2, 'precio_unitario_cop', 0)),
      jsonb_build_array(jsonb_build_object('tipo', 'otro', 'descripcion', 'Smoke T', 'cantidad', 100000, 'precio_unitario_cop', 100000000))
    ] loop
      begin
        perform * from public.crear_cuenta_cobro(gen_random_uuid(), t_cli, t_json);
        failures := failures || ('T11 debía fallar con check_violation: ' || left(t_json::text, 120));
      exception
        when check_violation then null;
        when others then failures := failures || ('T11 esperaba check_violation y llegó ' || sqlstate || ': ' || sqlerrm);
      end;
    end loop;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select count(*) from public.cobros where clinica_id = t_c) <> t_n then
      failures := failures || 'T11 una línea inválida dejó una CC creada'::text;
    end if;
  exception when others then
    failures := failures || ('T11 error inesperado: ' || sqlerrm);
  end;

  -- T12: un CLIENTE no puede usar ninguna de las 4 RPC.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    t_json := jsonb_build_array(jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 50000));
    perform set_config('request.jwt.claims', json_build_object('sub', cliente_c_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach t_sql in array array[
      format('select * from public.crear_cuenta_cobro(%L::uuid, %L::uuid, %L::jsonb)', gen_random_uuid(), t_cli, t_json),
      format('select * from public.crear_cotizacion(%L::uuid, %L::uuid, %L::jsonb)', gen_random_uuid(), t_cli, t_json),
      format('select public.marcar_cobro_pagado(%L::uuid, ''efectivo'')', t_cobro2),
      format('select public.anular_cobro(%L::uuid, ''Smoke T cliente'')', t_cobro)
    ] loop
      begin
        execute t_sql;
        failures := failures || ('T12 el cliente pudo ejecutar: ' || t_sql);
      exception
        when insufficient_privilege then null;
        when others then failures := failures || ('T12 esperaba insufficient_privilege y llegó ' || sqlstate || ': ' || sqlerrm);
      end;
    end loop;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
  exception when others then
    failures := failures || ('T12 error inesperado: ' || sqlerrm);
  end;

  -- T13: aislamiento por clínica, con control positivo.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_otro, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into t_n from public.cobros where clinica_id = t_c;
    select count(*) into t_n2 from public.cobro_items where clinica_id = t_c;
    select count(*) into t_n3 from public.clinica_servicios where clinica_id = t_c;
    if t_n <> 0 or t_n2 <> 0 or t_n3 <> 0 then
      failures := failures || format('T13 otra clínica ve cobros=%s ítems=%s servicios=%s', t_n, t_n2, t_n3);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select count(*) into t_n from public.cobros where clinica_id = t_c;
    if t_n < 2 then
      failures := failures || ('T13 el admin debía ver al menos 2 cobros de su clínica, ve ' || t_n);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
  exception when others then
    failures := failures || ('T13 error inesperado: ' || sqlerrm);
  end;

  -- T14: ninguna escritura directa por PostgREST (ni siquiera el admin).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select total_cop into t_n2 from public.cobros where id = t_cobro;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    foreach t_sql in array array[
      format('insert into public.cobros (clinica_id, tipo, numero, estado, clave_idempotencia, fecha, cliente_nombre, total_cop, creado_por) values (%L, ''cuenta_cobro'', 999, ''pendiente'', %L, %L, ''Smoke T Directo'', 1000, %L)',
        t_c, gen_random_uuid(), t_hoy, t_vet_admin),
      format('update public.cobros set total_cop = 1 where id = %L', t_cobro),
      format('delete from public.cobro_items where cobro_id = %L', t_cobro),
      'update public.cobro_contadores set ultimo = 0',
      format('insert into public.clinica_servicios (clinica_id, nombre, precio_cop, creado_por) values (%L, ''Smoke T Directo'', 1, %L)', t_c, t_vet_admin)
    ] loop
      begin
        execute t_sql;
        get diagnostics t_n = row_count;
        if t_n <> 0 then
          failures := failures || ('T14 la escritura directa afectó ' || t_n || ' filas: ' || t_sql);
        end if;
      exception
        when insufficient_privilege then null;
        when others then failures := failures || ('T14 esperaba insufficient_privilege y llegó ' || sqlstate || ': ' || sqlerrm);
      end;
    end loop;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select total_cop from public.cobros where id = t_cobro) is distinct from t_n2
       or (select count(*) from public.cobro_items where cobro_id = t_cobro) <> 4 then
      failures := failures || 'T14 una escritura directa cambió la CC o sus ítems'::text;
    end if;
  exception when others then
    failures := failures || ('T14 error inesperado: ' || sqlerrm);
  end;

  -- T15: marcar pagada (método válido, fecha entre la emisión y hoy, idempotente; una cotización no se paga).
  -- La cotización creada aquí es la primera de la clínica: numero 1 en su propio contador, aunque ya existan 2 CC.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cotizacion(gen_random_uuid(), t_cli,
      jsonb_build_array(jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 50000)));
    t_cot2 := t_row.id;
    if t_row.numero is distinct from 1 then
      failures := failures || ('T15 la primera cotización debía ser la numero 1 (contador propio), llegó ' || coalesce(t_row.numero::text, 'null'));
    end if;
    foreach t_sql in array array[
      format('select public.marcar_cobro_pagado(%L::uuid, ''bitcoin'')', t_cobro2),
      format('select public.marcar_cobro_pagado(%L::uuid, ''efectivo'', %L::date)', t_cobro2, t_hoy + 1),
      format('select public.marcar_cobro_pagado(%L::uuid, ''efectivo'', %L::date)', t_cobro2, t_hoy - 1)
    ] loop
      begin
        execute t_sql;
        failures := failures || ('T15 debía fallar con check_violation: ' || t_sql);
      exception
        when check_violation then null;
        when others then failures := failures || ('T15 esperaba check_violation y llegó ' || sqlstate || ': ' || sqlerrm);
      end;
    end loop;
    perform public.marcar_cobro_pagado(t_cobro2, 'nequi');
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into t_row from public.cobros where id = t_cobro2;
    if t_row.estado is distinct from 'pagada' or t_row.metodo_pago is distinct from 'nequi'
       or t_row.pagada_el is distinct from t_hoy or t_row.pagado_por is distinct from t_vet_col then
      failures := failures || format('T15 pago incorrecto: estado=%s metodo=%s pagada_el=%s', t_row.estado, t_row.metodo_pago, t_row.pagada_el);
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.marcar_cobro_pagado(t_cobro2, 'efectivo');
    begin
      perform public.marcar_cobro_pagado(t_cot2, 'efectivo');
      failures := failures || 'T15 pagar una cotización debía fallar con BC001'::text;
    exception
      when sqlstate 'BC001' then null;
      when others then failures := failures || ('T15 esperaba BC001 y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select metodo_pago from public.cobros where id = t_cobro2) is distinct from 'nequi' then
      failures := failures || 'T15 el segundo marcar pagada cambió el método (debía ser idempotente)'::text;
    end if;
  exception when others then
    failures := failures || ('T15 error inesperado: ' || sqlerrm);
  end;

  -- T16: anular solo el admin o quien la emitió; el motivo necesita 3..200 caracteres.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col2, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.anular_cobro(t_cobro, 'Error de precio');
      failures := failures || 'T16 un colega no autor ni admin pudo anular'::text;
    exception
      when insufficient_privilege then null;
      when others then failures := failures || ('T16 esperaba insufficient_privilege y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select estado from public.cobros where id = t_cobro) is distinct from 'pendiente' then
      failures := failures || 'T16 el intento del colega cambió el estado'::text;
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.anular_cobro(t_cobro, '  ab ');
      failures := failures || 'T16 un motivo de 2 caracteres debía fallar con check_violation'::text;
    exception
      when check_violation then null;
      when others then failures := failures || ('T16 esperaba check_violation y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.anular_cobro(t_cobro2, 'Prueba admin');
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into t_row from public.cobros where id = t_cobro2;
    if t_row.estado is distinct from 'anulada' or t_row.anulada_por is distinct from t_vet_admin
       or t_row.metodo_pago is distinct from 'nequi' or t_row.motivo_anulacion is distinct from 'Prueba admin' then
      failures := failures || format('T16 el admin no anuló bien la CC pagada: estado=%s metodo=%s', t_row.estado, t_row.metodo_pago);
    end if;
  exception when others then
    failures := failures || ('T16 error inesperado: ' || sqlerrm);
  end;

  -- T17: anular devuelve el stock con movimientos deshacer enlazados (D-13), conserva el número.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.anular_cobro(t_cobro, 'Error de precio');
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into t_row from public.cobros where id = t_cobro;
    if t_row.estado is distinct from 'anulada' or t_row.anulada_por is distinct from t_vet_col or t_row.anulada_at is null
       or t_row.motivo_anulacion is distinct from 'Error de precio' or t_row.numero is distinct from 1 then
      failures := failures || format('T17 anulación incorrecta: estado=%s motivo=%s numero=%s', t_row.estado, t_row.motivo_anulacion, t_row.numero);
    end if;
    if (select cantidad from public.productos where id = t_p1) is distinct from 10
       or (select cantidad from public.productos where id = t_p2) is distinct from 5 then
      failures := failures || 'T17 el stock no volvió a 10 y 5'::text;
    end if;
    select count(*) into t_n from public.movimientos_inventario d
      join public.movimientos_inventario v on v.id = d.deshace_id
     where d.ref_id = t_cobro and d.motivo = 'deshacer' and d.origen = 'factura' and d.nota = 'Anulada CC-0001'
       and v.ref_id = t_cobro and v.motivo = 'venta' and v.producto_id = d.producto_id and d.delta = -v.delta;
    select count(*) into t_n2 from public.movimientos_inventario where ref_id = t_cobro;
    if t_n <> 2 or t_n2 <> 4 then
      failures := failures || format('T17 esperaba 2 movimientos deshacer enlazados (hay %s) y 4 en total (hay %s)', t_n, t_n2);
    end if;
  exception when others then
    failures := failures || ('T17 error inesperado: ' || sqlerrm);
  end;

  -- T18: doble anulación -> BC001 sin movimientos; anular funciona aunque el producto se archivó después (Pitfall 3).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into t_n2 from public.movimientos_inventario where ref_id = t_cobro;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      perform public.anular_cobro(t_cobro, 'Otra vez');
      failures := failures || 'T18 anular dos veces debía fallar con BC001'::text;
    exception
      when sqlstate 'BC001' then null;
      when others then failures := failures || ('T18 esperaba BC001 y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    select * into t_row from public.crear_cuenta_cobro(gen_random_uuid(), t_cli,
      jsonb_build_array(jsonb_build_object('tipo', 'producto', 'producto_id', t_p2, 'cantidad', 2, 'precio_unitario_cop', 3000)));
    t_cobro3 := t_row.id;
    if t_row.numero is distinct from 3 then
      failures := failures || ('T18 esperaba la CC numero 3, llegó ' || coalesce(t_row.numero::text, 'null'));
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select count(*) from public.movimientos_inventario where ref_id = t_cobro) <> t_n2 then
      failures := failures || 'T18 la doble anulación dejó movimientos nuevos'::text;
    end if;
    if (select cantidad from public.productos where id = t_p2) is distinct from 3 then
      failures := failures || 'T18 la CC 3 no descontó 2 gasas'::text;
    end if;
    update public.productos set archivado_at = now(), archivado_por = t_vet_admin where id = t_p2;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform public.anular_cobro(t_cobro3, 'Producto archivado');
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    if (select cantidad from public.productos where id = t_p2) is distinct from 5
       or (select estado from public.cobros where id = t_cobro3) is distinct from 'anulada' then
      failures := failures || 'T18 anular con el producto archivado no devolvió el stock'::text;
    end if;
  exception when others then
    failures := failures || ('T18 error inesperado: ' || sqlerrm);
  end;

  -- T19: una cotización no mueve stock (aunque pida más de lo que hay), vence en 15 días (D-23) y sigue
  -- rechazando productos archivados (D-14). El cotizador (t_vet_q) deja una cotización solo con servicio.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select count(*) into t_n2 from public.movimientos_inventario where producto_id = t_p1;
    select cantidad into t_n3 from public.productos where id = t_p1;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cotizacion(gen_random_uuid(), t_cli,
      jsonb_build_array(
        jsonb_build_object('tipo', 'producto', 'producto_id', t_p1, 'cantidad', 20, 'precio_unitario_cop', 85000),
        jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 50000)),
      t_m);
    t_cot3 := t_row.id;
    if t_row.numero is distinct from 2 or t_row.ya_existia is distinct from false then
      failures := failures || ('T19 esperaba la cotización numero 2 de su propio contador, llegó ' || coalesce(t_row.numero::text, 'null'));
    end if;
    begin
      perform * from public.crear_cotizacion(gen_random_uuid(), t_cli,
        jsonb_build_array(jsonb_build_object('tipo', 'producto', 'producto_id', t_p_arch, 'cantidad', 1, 'precio_unitario_cop', 1000)));
      failures := failures || 'T19 una cotización con un producto archivado debía fallar con IN002'::text;
    exception
      when sqlstate 'IN002' then null;
      when others then failures := failures || ('T19 esperaba IN002 y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_q, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    perform * from public.crear_cotizacion(gen_random_uuid(), t_cli2,
      jsonb_build_array(jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 45000)));
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into t_row from public.cobros where id = t_cot3;
    if t_row.tipo is distinct from 'cotizacion' or t_row.estado is distinct from 'abierta'
       or t_row.valida_hasta is distinct from t_hoy + 15 or t_row.total_cop is distinct from 1750000 then
      failures := failures || format('T19 cotización incorrecta: tipo=%s estado=%s valida_hasta=%s total=%s', t_row.tipo, t_row.estado, t_row.valida_hasta, t_row.total_cop);
    end if;
    if exists (select 1 from public.movimientos_inventario where ref_id = t_cot3)
       or (select count(*) from public.movimientos_inventario where producto_id = t_p1) <> t_n2
       or (select cantidad from public.productos where id = t_p1) is distinct from t_n3 then
      failures := failures || 'T19 la cotización movió stock'::text;
    end if;
    if (select count(*) from public.cobros where creado_por = t_vet_q and tipo = 'cotizacion') <> 1 then
      failures := failures || 'T19 falta la cotización del cotizador'::text;
    end if;
  exception when others then
    failures := failures || ('T19 error inesperado: ' || sqlerrm);
  end;

  -- T20: convertir una cotización (D-09): nueva CC con las líneas editadas, cotización convertida, stock al convertir;
  -- convertir dos veces -> BC002; el reintento de la conversión es idempotente; anular una convertida -> BC002.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cotizacion(gen_random_uuid(), t_cli,
      jsonb_build_array(
        jsonb_build_object('tipo', 'producto', 'producto_id', t_p1, 'cantidad', 2, 'precio_unitario_cop', 85000),
        jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 50000)),
      t_m);
    t_cot := t_row.id;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select ultimo into t_n from public.cobro_contadores where clinica_id = t_c and tipo = 'cuenta_cobro';
    select cantidad into t_n2 from public.productos where id = t_p1;
    t_clave2 := gen_random_uuid();
    t_json := jsonb_build_array(jsonb_build_object('tipo', 'producto', 'producto_id', t_p1, 'cantidad', 1, 'precio_unitario_cop', 70000));
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cuenta_cobro(t_clave2, t_cli, t_json, t_m, null, null, t_cot);
    t_cc_conv := t_row.id;
    if t_row.numero is distinct from t_n + 1 or t_row.ya_existia is distinct from false then
      failures := failures || format('T20 la conversión debía tomar la CC numero %s, llegó %s', t_n + 1, t_row.numero);
    end if;
    begin
      perform * from public.crear_cuenta_cobro(gen_random_uuid(), t_cli, t_json, t_m, null, null, t_cot);
      failures := failures || 'T20 convertir dos veces debía fallar con BC002'::text;
    exception
      when sqlstate 'BC002' then null;
      when others then failures := failures || ('T20 esperaba BC002 y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    select * into t_row from public.crear_cuenta_cobro(t_clave2, t_cli, t_json, t_m, null, null, t_cot);
    if t_row.id is distinct from t_cc_conv or t_row.ya_existia is distinct from true then
      failures := failures || 'T20 el reintento de la conversión no devolvió la misma CC con ya_existia'::text;
    end if;
    begin
      perform public.anular_cobro(t_cot, 'Ya no aplica');
      failures := failures || 'T20 anular una cotización convertida debía fallar con BC002'::text;
    exception
      when sqlstate 'BC002' then null;
      when others then failures := failures || ('T20 esperaba BC002 y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform public.anular_cobro(t_cot3, 'Cliente desistió');
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into t_row from public.cobros where id = t_cc_conv;
    if t_row.cotizacion_origen_id is distinct from t_cot or t_row.total_cop is distinct from 70000 or t_row.tipo is distinct from 'cuenta_cobro' then
      failures := failures || format('T20 CC convertida incorrecta: origen=%s total=%s', t_row.cotizacion_origen_id, t_row.total_cop);
    end if;
    select * into t_row from public.cobros where id = t_cot;
    if t_row.estado is distinct from 'convertida' or t_row.convertida_en_id is distinct from t_cc_conv then
      failures := failures || format('T20 la cotización quedó en %s / %s', t_row.estado, t_row.convertida_en_id);
    end if;
    if (select cantidad from public.productos where id = t_p1) is distinct from t_n2 - 1 then
      failures := failures || 'T20 la conversión no descontó 1 unidad (o descontó de más en el reintento)'::text;
    end if;
    if (select estado from public.cobros where id = t_cot3) is distinct from 'anulada'
       or exists (select 1 from public.movimientos_inventario where ref_id = t_cot3) then
      failures := failures || 'T20 anular una cotización abierta falló o creó movimientos'::text;
    end if;
  exception when others then
    failures := failures || ('T20 error inesperado: ' || sqlerrm);
  end;

  -- T21: una visita (cita o consulta) solo tiene una CC activa (BC003); al anularla se puede volver a cobrar.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    t_json := jsonb_build_array(jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 50000));
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cuenta_cobro(gen_random_uuid(), t_cli, t_json, null, t_cita);
    t_cc_cita := t_row.id;
    begin
      perform * from public.crear_cuenta_cobro(gen_random_uuid(), t_cli, t_json, null, t_cita);
      failures := failures || 'T21 cobrar dos veces la misma cita debía fallar con BC003'::text;
    exception
      when sqlstate 'BC003' then
        get stacked diagnostics t_sql = pg_exception_detail;
        begin
          if (t_sql::jsonb ->> 'numero') not like 'CC-%' then
            failures := failures || ('T21 detail de BC003 sin número: ' || t_sql);
          end if;
        exception when others then
          failures := failures || ('T21 el detail de BC003 no es json: ' || coalesce(t_sql, 'null'));
        end;
      when others then failures := failures || ('T21 esperaba BC003 y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    begin
      perform * from public.crear_cuenta_cobro(gen_random_uuid(), t_cli, t_json, null, null, t_cons);
      failures := failures || 'T21 cobrar la consulta de una cita ya cobrada debía fallar con BC003'::text;
    exception
      when sqlstate 'BC003' then null;
      when others then failures := failures || ('T21 esperaba BC003 (consulta) y llegó ' || sqlstate || ': ' || sqlerrm);
    end;
    perform public.anular_cobro(t_cc_cita, 'Se cobra con la consulta');
    select * into t_row from public.crear_cuenta_cobro(gen_random_uuid(), t_cli, t_json, null, null, t_cons);
    t_cc_cons := t_row.id;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select * into t_row from public.cobros where id = t_cc_cons;
    if t_row.cita_id is distinct from t_cita or t_row.consulta_id is distinct from t_cons
       or t_row.mascota_id is distinct from t_m or t_row.estado is distinct from 'pendiente' then
      failures := failures || format('T21 la CC de la consulta quedó con cita=%s consulta=%s mascota=%s', t_row.cita_id, t_row.consulta_id, t_row.mascota_id);
    end if;
  exception when others then
    failures := failures || ('T21 error inesperado: ' || sqlerrm);
  end;

  -- T22: en solo lectura el colega lee pero no crea, paga ni anula (LP004 desde la guarda); el admin sí escribe.
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.clinica_planes
       set plan = 'gratis', miembros_max = 1, fundador = false, pagado_hasta = null,
           prueba_pro_hasta = t_hoy - 17, prueba_clinica_hasta = t_hoy - 16, prueba_clinica_usada = true, beta_hasta = null
     where clinica_id = t_c;
    t_json := jsonb_build_array(jsonb_build_object('tipo', 'servicio', 'servicio_id', t_s1, 'cantidad', 1, 'precio_unitario_cop', 50000));
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_col, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    if public.puede_escribir() then
      failures := failures || 'T22 puede_escribir() debía ser false para el colega'::text;
    end if;
    foreach t_sql in array array[
      format('select * from public.crear_cuenta_cobro(%L::uuid, %L::uuid, %L::jsonb)', gen_random_uuid(), t_cli, t_json),
      format('select * from public.crear_cotizacion(%L::uuid, %L::uuid, %L::jsonb)', gen_random_uuid(), t_cli, t_json),
      format('select public.marcar_cobro_pagado(%L::uuid, ''efectivo'')', t_cc_cons),
      format('select public.anular_cobro(%L::uuid, ''Solo lectura'')', t_cc_cons)
    ] loop
      begin
        execute t_sql;
        failures := failures || ('T22 debía fallar con LP004: ' || t_sql);
      exception
        when sqlstate 'LP004' then null;
        when others then failures := failures || ('T22 esperaba LP004 y llegó ' || sqlstate || ' (' || t_sql || ')');
      end;
    end loop;
    select count(*) into t_n from public.cobros where clinica_id = t_c;
    if t_n <= 0 then
      failures := failures || 'T22 el colega en solo lectura debía seguir leyendo los cobros'::text;
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    select * into t_row from public.crear_cotizacion(gen_random_uuid(), t_cli, t_json);
    if t_row.id is null then
      failures := failures || 'T22 el admin debía poder crear una cotización'::text;
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
  exception when others then
    failures := failures || ('T22 error inesperado: ' || sqlerrm);
  end;

  -- T23: un autor retirado (solo cotizó) sigue visible; es_autor_en_mi_clinica conserva los 4 brazos previos (Pitfall 5).
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    update public.perfiles set activo = false where id = t_vet_q;
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_admin, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    if not public.es_autor_en_mi_clinica(t_vet_q) then
      failures := failures || 'T23 es_autor_en_mi_clinica debía ser true para el cotizador retirado'::text;
    end if;
    select count(*) into t_n from public.perfiles where id = t_vet_q and nombre = 'Smoke T Cotizador';
    if t_n <> 1 then
      failures := failures || ('T23 el admin debía ver al cotizador retirado (filas: ' || t_n || ')');
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    select p.prosrc into t_sql from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.proname = 'es_autor_en_mi_clinica';
    foreach t_t in array array['citas', 'consultas', 'dosis_aplicadas', 'movimientos_inventario', 'cobros', 'clinica_servicios'] loop
      if t_sql is null or position(t_t in t_sql) = 0 then
        failures := failures || ('T23 es_autor_en_mi_clinica perdió el brazo de ' || t_t);
      end if;
    end loop;
  exception when others then
    failures := failures || ('T23 error inesperado: ' || sqlerrm);
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
