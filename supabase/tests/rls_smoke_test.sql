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
