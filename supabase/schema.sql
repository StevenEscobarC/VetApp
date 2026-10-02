-- VetApp: schema, trigger de perfiles y RLS.
-- Ejecutar completo en Supabase SQL Editor.

create extension if not exists "pgcrypto";

do $$ begin
  create type public.rol_perfil as enum ('VETERINARIO', 'CLIENTE');
exception when duplicate_object then null;
end $$;

create table if not exists public.clinicas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(trim(nombre)) > 0),
  ciudad text not null default '',
  direccion text not null default '',
  telefono text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null default '',
  rol public.rol_perfil not null,
  clinica_id uuid references public.clinicas(id) on delete set null,
  telefono text not null default '',
  created_at timestamptz not null default now(),
  constraint veterinario_requiere_clinica check (rol = 'CLIENTE' or clinica_id is not null)
);

-- Clientes: dueños de mascotas registrados por el veterinario; no tienen cuenta (sin fila en auth.users ni perfiles).
create table if not exists public.clientes (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  telefono text not null default '',
  email text,
  direccion text not null default '',
  notas text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clientes_id_clinica_id_key unique (id, clinica_id)
);

create or replace function public.tocar_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists clientes_tocar_updated_at on public.clientes;
create trigger clientes_tocar_updated_at before update on public.clientes
for each row execute procedure public.tocar_updated_at();

-- Mascotas: pertenecen a un cliente de la misma clínica; solo el veterinario de esa clínica las gestiona.
create table if not exists public.mascotas (
  id uuid primary key default gen_random_uuid(),
  dueno_id uuid not null,
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  especie text not null,
  raza text not null default '',
  fecha_nacimiento date,
  created_at timestamptz not null default now(),
  constraint mascotas_dueno_misma_clinica_fkey foreign key (dueno_id, clinica_id)
    references public.clientes(id, clinica_id) on delete cascade
);

create index if not exists perfiles_clinica_id_idx on public.perfiles(clinica_id);
create index if not exists clientes_clinica_id_idx on public.clientes(clinica_id);
create index if not exists mascotas_dueno_id_idx on public.mascotas(dueno_id);
create index if not exists mascotas_clinica_id_idx on public.mascotas(clinica_id);

-- Redefinido en el bloque Fase 4.1 al final (códigos de invitación, rol_clinica).
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  metadata jsonb := new.raw_user_meta_data;
  clinic_id uuid;
begin
  if metadata->>'rol' = 'VETERINARIO' then
    insert into public.clinicas(nombre, ciudad, direccion, telefono)
    values (
      coalesce(nullif(trim(metadata->>'clinica_nombre'), ''), 'Clínica sin nombre'),
      coalesce(metadata->>'clinica_ciudad', ''),
      coalesce(metadata->>'clinica_direccion', ''),
      coalesce(metadata->>'clinica_telefono', '')
    ) returning id into clinic_id;
  end if;

  insert into public.perfiles(id, nombre, rol, clinica_id, telefono)
  values (
    new.id,
    coalesce(metadata->>'nombre', ''),
    coalesce(metadata->>'rol', 'CLIENTE')::public.rol_perfil,
    clinic_id,
    coalesce(metadata->>'telefono', '')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.crear_perfil_nuevo_usuario();

create or replace function public.mi_perfil()
returns public.perfiles
language sql stable security definer set search_path = public
as $$ select * from public.perfiles where id = auth.uid() $$;

-- es_veterinario y mi_clinica_id: redefinidos en el bloque Fase 4.1 al final (filtran por activo).
create or replace function public.es_veterinario()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.perfiles where id = auth.uid() and rol = 'VETERINARIO') $$;

create or replace function public.mi_clinica_id()
returns uuid language sql stable security definer set search_path = public
as $$ select clinica_id from public.perfiles where id = auth.uid() $$;

grant execute on function public.mi_perfil() to authenticated;
grant execute on function public.es_veterinario() to authenticated;
grant execute on function public.mi_clinica_id() to authenticated;

do $$ declare table_name text; begin
  foreach table_name in array array['clinicas', 'perfiles', 'clientes', 'mascotas'] loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end $$;

-- Clinicas: solo veterinarios de la clínica pueden leerla; no hay acceso cliente.
drop policy if exists clinicas_select on public.clinicas;
create policy clinicas_select on public.clinicas for select to authenticated
using (public.es_veterinario() and id = public.mi_clinica_id());

-- Perfiles: cada usuario ve su perfil; veterinarios ven perfiles de su clínica.
drop policy if exists perfiles_select on public.perfiles;
create policy perfiles_select on public.perfiles for select to authenticated
using (id = auth.uid() or (public.es_veterinario() and clinica_id = public.mi_clinica_id()));

-- Cada usuario edita solo su perfil y NUNCA su rol ni su clínica (evita auto-escalación de privilegios).
drop policy if exists perfiles_update on public.perfiles;
create policy perfiles_update on public.perfiles for update to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and rol = (select p.rol from public.perfiles p where p.id = auth.uid())
  and clinica_id is not distinct from (select p.clinica_id from public.perfiles p where p.id = auth.uid())
);

-- El trigger crea perfiles. El cliente nunca puede crear otro perfil o cambiar rol.
drop policy if exists perfiles_insert on public.perfiles;
create policy perfiles_insert on public.perfiles for insert to authenticated
with check (id = auth.uid() and rol = 'CLIENTE' and clinica_id is null);

-- Clientes: solo el veterinario de la clínica dueña.
drop policy if exists clientes_select on public.clientes;
create policy clientes_select on public.clientes for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists clientes_insert on public.clientes;
create policy clientes_insert on public.clientes for insert to authenticated
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists clientes_update on public.clientes;
create policy clientes_update on public.clientes for update to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id())
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists clientes_delete on public.clientes;
create policy clientes_delete on public.clientes for delete to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

-- Mascotas: solo el veterinario de la clínica (los dueños no se autentican).
drop policy if exists mascotas_select on public.mascotas;
create policy mascotas_select on public.mascotas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists mascotas_insert on public.mascotas;
create policy mascotas_insert on public.mascotas for insert to authenticated
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists mascotas_update on public.mascotas;
create policy mascotas_update on public.mascotas for update to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id())
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists mascotas_delete on public.mascotas;
create policy mascotas_delete on public.mascotas for delete to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

-- ===== Fase 2: Clientes y Pacientes (delta idempotente; se puede re-ejecutar el archivo completo) =====

-- CLI-05 / D-07: vinculación de cuenta cliente<->perfiles, iniciada por el veterinario
-- desde la ficha del cliente. El lado CLIENTE (reclamar el código) se construye en la
-- Fase 9 (DIR-06); aquí solo viven las columnas y la generación del código.
alter table public.clientes
  add column if not exists perfiles_id uuid references auth.users(id) on delete set null,
  add column if not exists codigo_vinculacion text,
  add column if not exists codigo_expira_en timestamptz;

do $$ begin
  alter table public.clientes
    add constraint clientes_codigo_vinculacion_formato
    check (codigo_vinculacion is null or codigo_vinculacion ~ '^[0-9]{6}$');
exception when duplicate_object then null;
end $$;

create index if not exists clientes_perfiles_id_idx on public.clientes(perfiles_id) where perfiles_id is not null;
-- Unicidad global (no solo por clínica): evita que el mismo código coincida con dos
-- clientes distintos cuando la RPC de reclamo de la Fase 9 lo busque entre clínicas.
create unique index if not exists clientes_codigo_vinculacion_key on public.clientes(codigo_vinculacion) where codigo_vinculacion is not null;

-- No se agrega política nueva sobre clientes: la política de update ya existente
-- (clientes_update, vet-only) cubre la escritura de estas columnas nuevas.

-- PAT-03: ruta del objeto en el bucket privado mascota-fotos -- nunca una URL firmada
-- (las URLs firmadas expiran; la ruta no).
alter table public.mascotas add column if not exists foto_path text;

-- PAT-05: historial de peso -- tabla propia de solo-inserción, nunca un campo mutable
-- en mascotas (evita el mismo antipatrón ya señalado para dosis de vacunación).
create table if not exists public.mascota_pesos (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  peso_kg numeric(6,2) not null check (peso_kg > 0),
  registrado_en timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists mascota_pesos_mascota_id_idx
  on public.mascota_pesos(mascota_id, registrado_en desc);

alter table public.mascota_pesos enable row level security;

drop policy if exists mascota_pesos_select on public.mascota_pesos;
create policy mascota_pesos_select on public.mascota_pesos for select to authenticated
using (
  public.es_veterinario()
  and exists (
    select 1 from public.mascotas m
    where m.id = mascota_pesos.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
);

drop policy if exists mascota_pesos_insert on public.mascota_pesos;
create policy mascota_pesos_insert on public.mascota_pesos for insert to authenticated
with check (
  public.es_veterinario()
  and exists (
    select 1 from public.mascotas m
    where m.id = mascota_pesos.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
);

-- Sin política de update/delete: el historial de peso es de solo-inserción (append-only);
-- cada visita agrega una fila nueva, las correcciones se hacen con otra fila, no editando.

-- CLI-01/D-02: alta combinada cliente+mascota en una sola llamada atómica. security
-- invoker: la función corre como el veterinario que llama, así que la RLS de
-- clientes/mascotas/mascota_pesos sigue aplicando dentro -- esto es defensa en
-- profundidad, no un bypass.
create or replace function public.registrar_cliente_con_mascota(
  cliente_nombre text,
  cliente_telefono text,
  mascota_nombre text,
  mascota_especie text,
  mascota_raza text default '',
  mascota_fecha_nacimiento date default null,
  mascota_peso_kg numeric default null
)
returns table (cliente_id uuid, mascota_id uuid)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_cliente_id uuid;
  v_mascota_id uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede registrar clientes.' using errcode = 'insufficient_privilege';
  end if;

  insert into public.clientes (clinica_id, nombre, telefono)
  values (v_clinica_id, trim(cliente_nombre), trim(cliente_telefono))
  returning id into v_cliente_id;

  insert into public.mascotas (dueno_id, clinica_id, nombre, especie, raza, fecha_nacimiento)
  values (v_cliente_id, v_clinica_id, trim(mascota_nombre), mascota_especie,
          coalesce(trim(mascota_raza), ''), mascota_fecha_nacimiento)
  returning id into v_mascota_id;

  if mascota_peso_kg is not null then
    insert into public.mascota_pesos (mascota_id, peso_kg) values (v_mascota_id, mascota_peso_kg);
  end if;

  return query select v_cliente_id, v_mascota_id;
end;
$$;

revoke all on function public.registrar_cliente_con_mascota(text, text, text, text, text, date, numeric) from public, anon;
grant execute on function public.registrar_cliente_con_mascota(text, text, text, text, text, date, numeric) to authenticated;

-- PAT-01/D-03: alta de mascota para un cliente ya existente de la misma clínica. La FK
-- compuesta (dueno_id, clinica_id) -> clientes(id, clinica_id) rechaza un dueño de otra
-- clínica (foreign_key_violation) aunque el veterinario fuerce clinica_id a la propia.
create or replace function public.registrar_mascota(
  mascota_dueno_id uuid,
  mascota_nombre text,
  mascota_especie text,
  mascota_raza text default '',
  mascota_fecha_nacimiento date default null,
  mascota_peso_kg numeric default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_mascota_id uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede registrar mascotas.' using errcode = 'insufficient_privilege';
  end if;

  insert into public.mascotas (dueno_id, clinica_id, nombre, especie, raza, fecha_nacimiento)
  values (mascota_dueno_id, v_clinica_id, trim(mascota_nombre), mascota_especie,
          coalesce(trim(mascota_raza), ''), mascota_fecha_nacimiento)
  returning id into v_mascota_id;

  if mascota_peso_kg is not null then
    insert into public.mascota_pesos (mascota_id, peso_kg) values (v_mascota_id, mascota_peso_kg);
  end if;

  return v_mascota_id;
end;
$$;

revoke all on function public.registrar_mascota(uuid, text, text, text, date, numeric) from public, anon;
grant execute on function public.registrar_mascota(uuid, text, text, text, date, numeric) to authenticated;

-- CLI-05/D-07: genera (o devuelve, si sigue vigente) un código de 6 dígitos que el
-- veterinario muestra/lee al dueño para vincular su futura cuenta CLIENTE. gen_random_uuid()
-- es una función núcleo de Postgres (pg_catalog) desde la versión 13, así que resuelve sin
-- problema aunque search_path = public no incluya el esquema `extensions` donde Supabase
-- mantiene pgcrypto -- por eso no se usa ninguna otra función de pgcrypto aquí.
-- Variables locales con prefijo v_ para nunca chocar con las columnas OUT
-- codigo/expira_en/reemplazo_expirado.
create or replace function public.generar_codigo_vinculacion(p_cliente_id uuid)
returns table (codigo text, expira_en timestamptz, reemplazo_expirado boolean)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_cliente public.clientes;
  v_codigo text;
  v_expira timestamptz;
  v_intento int := 0;
begin
  if not public.es_veterinario() then
    raise exception 'Solo un veterinario puede generar un código de vinculación.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_cliente from public.clientes where id = p_cliente_id for update;

  if v_cliente is null then
    raise exception 'Cliente no encontrado' using errcode = 'no_data_found';
  end if;

  if v_cliente.perfiles_id is not null then
    raise exception 'El cliente ya tiene una cuenta vinculada';
  end if;

  if v_cliente.codigo_vinculacion is not null and v_cliente.codigo_expira_en > now() then
    return query select v_cliente.codigo_vinculacion, v_cliente.codigo_expira_en, false;
    return;
  end if;

  loop
    v_intento := v_intento + 1;
    v_codigo := lpad((('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::bigint % 1000000)::text, 6, '0');
    v_expira := now() + interval '24 hours';

    begin
      update public.clientes
      set codigo_vinculacion = v_codigo, codigo_expira_en = v_expira
      where id = p_cliente_id;
      exit;
    exception when unique_violation then
      if v_intento >= 5 then
        raise;
      end if;
    end;
  end loop;

  return query select v_codigo, v_expira, (v_cliente.codigo_vinculacion is not null);
end;
$$;

revoke all on function public.generar_codigo_vinculacion(uuid) from public, anon;
grant execute on function public.generar_codigo_vinculacion(uuid) to authenticated;

-- PAT-03: bucket privado para fotos de mascotas. Ruta: {clinica_id}/{mascota_id}/{timestamp}.jpg
-- -- storage.foldername(name) separa la ruta por '/'; el elemento [1] es clinica_id.
insert into storage.buckets (id, name, public)
values ('mascota-fotos', 'mascota-fotos', false)
on conflict (id) do nothing;

drop policy if exists mascota_fotos_select on storage.objects;
create policy mascota_fotos_select on storage.objects for select to authenticated
using (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
);

drop policy if exists mascota_fotos_insert on storage.objects;
create policy mascota_fotos_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
);

drop policy if exists mascota_fotos_update on storage.objects;
create policy mascota_fotos_update on storage.objects for update to authenticated
using (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
)
with check (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
);

drop policy if exists mascota_fotos_delete on storage.objects;
create policy mascota_fotos_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
);

-- Nota: reclamar_codigo_cliente (el lado CLIENTE, security definer, que consume el
-- código generado arriba) ya está diseñado en 02-RESEARCH.md pero se construye en la
-- Fase 9 (DIR-06) -- no se crea todavía en este archivo.

-- ===== Fase 3: Historia Clínica (delta idempotente; se puede re-ejecutar el archivo completo) =====

-- HIST-01/04: historia clínica -- append-only, misma filosofía que mascota_pesos.
-- Examen físico como columnas planas (no jsonb): forma fija conocida (5 campos),
-- nunca dinámica; permite check() de validación y selects directos, igual que
-- el resto del schema. Sin campo corrige_a (D-01): una corrección es siempre una
-- fila nueva, sin vínculo formal con la entrada que corrige.
create table if not exists public.consultas (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  -- veterinario_id referencia auth.users(id) directamente (igual que perfiles.id),
  -- on delete cascade para mantener la misma convención del resto del schema --
  -- si en el futuro se construye borrado de cuenta de veterinario, revisar si
  -- cascade sigue siendo correcto para un registro clínico/legal (ver A2 en
  -- 03-RESEARCH.md); hoy no existe esa funcionalidad, así que el riesgo es teórico.
  -- Redefinido en el bloque Fase 4.1 al final: la FK pasa a on delete restrict.
  veterinario_id uuid not null references auth.users(id) on delete cascade,
  fecha timestamptz not null default now(),

  anamnesis text,

  -- Examen físico (D-03: todos opcionales; el peso también alimenta mascota_pesos, ver RPC).
  peso_kg numeric(6,2) check (peso_kg is null or peso_kg > 0),
  temperatura_c numeric(4,1) check (temperatura_c is null or temperatura_c > 0),
  frecuencia_cardiaca integer check (frecuencia_cardiaca is null or frecuencia_cardiaca > 0),
  frecuencia_respiratoria integer check (frecuencia_respiratoria is null or frecuencia_respiratoria > 0),
  mucosas text,

  diagnostico text not null check (length(trim(diagnostico)) > 0),
  tratamiento text not null check (length(trim(tratamiento)) > 0),
  evolucion text,

  created_at timestamptz not null default now()
);

create index if not exists consultas_mascota_id_idx
  on public.consultas(mascota_id, fecha desc);

alter table public.consultas enable row level security;

drop policy if exists consultas_select on public.consultas;
create policy consultas_select on public.consultas for select to authenticated
using (
  public.es_veterinario()
  and exists (
    select 1 from public.mascotas m
    where m.id = consultas.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
);

-- consultas_insert vive en la sección Fase 4 (HI-01/ME-04): además de la mascota de
-- la clínica valida consultas.cita_id, que depende de citas/cita_mascotas. No se crea
-- aquí para que al re-pegar el archivo nunca exista, ni por un instante, una versión
-- más débil de la política.

-- Sin política update/delete: la historia clínica es de solo-append (HIST-04) --
-- una corrección se registra como una fila nueva, nunca editando ni borrando.

-- registrar_consulta se redefine en la sección Fase 4 (agrega p_cita_id).

-- ===== Fase 4: Agenda y Citas (delta idempotente; se puede re-ejecutar el archivo completo) =====

-- Pitfall 7: la FK compuesta cita_mascotas -> mascotas(id, clinica_id) necesita una
-- unique sobre (id, clinica_id) en mascotas. Se consulta pg_constraint (por nombre Y
-- tabla) en vez de tragarse duplicate_object/duplicate_table, para no ocultar el caso
-- en que otra relación ya use ese nombre (LO-06).
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'mascotas_id_clinica_id_key'
      and conrelid = 'public.mascotas'::regclass
  ) then
    alter table public.mascotas
      add constraint mascotas_id_clinica_id_key unique (id, clinica_id);
  end if;
end;
$$;

-- AGND-01/02: citas. estado es text + check (no enum, D-10); 'solicitada' queda
-- reservado para la Fase 9. Sin exclusion constraint de solapes: D-09 solo advierte
-- en la app.
create table if not exists public.citas (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  cliente_id uuid not null,
  -- HI-02: on delete restrict (no cascade). Borrar la cuenta de un veterinario no
  -- puede borrar en silencio la agenda de la clínica (cancelar nunca es borrar; D-20
  -- solo permite la cascada desde el cliente). La FK se (re)crea en el bloque
  -- idempotente de abajo para las bases ya desplegadas con on delete cascade.
  veterinario_id uuid not null,
  fecha_hora timestamptz not null,
  duracion_min integer not null default 30
    constraint citas_duracion_check check (duracion_min between 5 and 480),
  modalidad text not null default 'consultorio'
    constraint citas_modalidad_check check (modalidad in ('consultorio', 'domicilio')),
  direccion text not null default '',
  motivo text not null default 'Consulta general'
    constraint citas_motivo_check check (length(trim(motivo)) > 0),
  notas text not null default '',
  estado text not null default 'pendiente',
  recordatorio_enviado_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint citas_estado_check check (
    estado in ('solicitada', 'pendiente', 'confirmada', 'completada', 'cancelada', 'no_asistio')
  ),
  constraint citas_id_clinica_id_key unique (id, clinica_id),
  -- D-20: borrar un cliente borra sus citas en cascada.
  constraint citas_cliente_misma_clinica_fkey foreign key (cliente_id, clinica_id)
    references public.clientes(id, clinica_id) on delete cascade,
  constraint citas_domicilio_requiere_direccion check (
    modalidad <> 'domicilio' or length(trim(direccion)) > 0
  )
);

create index if not exists citas_clinica_fecha_idx
  on public.citas(clinica_id, fecha_hora);

-- HI-02 (delta idempotente): citas.veterinario_id -> auth.users con on delete restrict.
-- Elimina cualquier FK citas -> auth.users que no sea restrict (la original era
-- cascade) y crea citas_veterinario_id_fkey si falta. Re-ejecutable sobre datos vivos.
do $$
declare
  v_con record;
begin
  for v_con in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.citas'::regclass
      and c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
      and c.confdeltype <> 'r'
  loop
    execute format('alter table public.citas drop constraint %I', v_con.conname);
  end loop;

  if not exists (
    select 1 from pg_constraint
    where conname = 'citas_veterinario_id_fkey'
      and conrelid = 'public.citas'::regclass
  ) then
    alter table public.citas
      add constraint citas_veterinario_id_fkey foreign key (veterinario_id)
      references auth.users(id) on delete restrict;
  end if;
end;
$$;

drop trigger if exists citas_tocar_updated_at on public.citas;
create trigger citas_tocar_updated_at before update on public.citas
for each row execute procedure public.tocar_updated_at();

-- D-03: tabla puente; una cita puede cubrir varias mascotas del mismo cliente.
create table if not exists public.cita_mascotas (
  cita_id uuid not null,
  mascota_id uuid not null,
  clinica_id uuid not null,
  primary key (cita_id, mascota_id),
  constraint cita_mascotas_cita_fkey foreign key (cita_id, clinica_id)
    references public.citas(id, clinica_id) on delete cascade,
  constraint cita_mascotas_mascota_fkey foreign key (mascota_id, clinica_id)
    references public.mascotas(id, clinica_id) on delete cascade
);

create index if not exists cita_mascotas_mascota_idx
  on public.cita_mascotas(mascota_id);

-- D-18/D-19: vínculo consulta -> cita; una consulta por (cita, mascota).
alter table public.consultas
  add column if not exists cita_id uuid references public.citas(id) on delete set null;

create unique index if not exists consultas_cita_mascota_key
  on public.consultas(cita_id, mascota_id) where cita_id is not null;

alter table public.citas enable row level security;
alter table public.cita_mascotas enable row level security;

drop policy if exists citas_select on public.citas;
create policy citas_select on public.citas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

-- HI-01: un veterinario solo crea citas pendientes/confirmadas ('solicitada' es de la
-- Fase 9; una cita no nace completada/cancelada/no_asistio).
drop policy if exists citas_insert on public.citas;
create policy citas_insert on public.citas for insert to authenticated
with check (
  public.es_veterinario()
  and clinica_id = public.mi_clinica_id()
  and veterinario_id = auth.uid()
  and estado in ('pendiente', 'confirmada')
);

drop policy if exists citas_update on public.citas;
create policy citas_update on public.citas for update to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id())
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

-- HI-01: guarda de update directo (PostgREST) -- las mismas reglas que la app y las
-- RPC, para que un update directo no pueda saltárselas. Una policy no ve OLD, por eso
-- es un trigger BEFORE UPDATE (aplica a cualquier rol, también a las RPC).
--  * cliente_id / clinica_id / veterinario_id son inmutables.
--  * Datos de la cita (fecha, duración, modalidad, dirección, motivo, notas) solo se
--    editan si estaba solicitada/pendiente/confirmada (igual que actualizar_cita).
--  * recordatorio_enviado_at se puede marcar/desmarcar siempre.
--  * Transiciones de estado permitidas (exactamente las que hace la app, incl. "Deshacer"):
--      solicitada  -> pendiente | confirmada | cancelada        (Fase 9: aceptar/rechazar)
--      pendiente   -> confirmada | completada | cancelada | no_asistio
--      confirmada  -> pendiente | completada | cancelada | no_asistio
--      cancelada / no_asistio -> pendiente                      ("Reabrir cita", siempre)
--      cancelada / no_asistio -> confirmada                     (solo "Deshacer", ver ventana)
--      completada  -> pendiente | confirmada                    (solo "Deshacer", ver ventana)
--    Nunca: -> solicitada; cancelada/no_asistio -> completada (ME-04); terminal -> terminal.
--    "Ventana de deshacer": la reversión solo se acepta si la cita cambió hace menos de
--    10 minutos (old.updated_at); el snackbar de la app dura 6 s.
create or replace function public.citas_validar_update()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_en_ventana boolean;
begin
  v_en_ventana := old.updated_at >= now() - interval '10 minutes';

  if new.cliente_id is distinct from old.cliente_id
     or new.clinica_id is distinct from old.clinica_id
     or new.veterinario_id is distinct from old.veterinario_id then
    raise exception 'No se puede cambiar el cliente, la clínica ni el veterinario de una cita.'
      using errcode = 'check_violation';
  end if;

  if old.estado not in ('solicitada', 'pendiente', 'confirmada') and (
       new.fecha_hora is distinct from old.fecha_hora
       or new.duracion_min is distinct from old.duracion_min
       or new.modalidad is distinct from old.modalidad
       or new.direccion is distinct from old.direccion
       or new.motivo is distinct from old.motivo
       or new.notas is distinct from old.notas
     ) then
    raise exception 'Solo se pueden editar citas pendientes o confirmadas.'
      using errcode = 'check_violation';
  end if;

  if new.estado is distinct from old.estado and not (
       (old.estado = 'solicitada' and new.estado in ('pendiente', 'confirmada', 'cancelada'))
    or (old.estado = 'pendiente' and new.estado in ('confirmada', 'completada', 'cancelada', 'no_asistio'))
    or (old.estado = 'confirmada' and new.estado in ('pendiente', 'completada', 'cancelada', 'no_asistio'))
    or (old.estado in ('cancelada', 'no_asistio') and new.estado = 'pendiente')
    or (old.estado in ('cancelada', 'no_asistio') and new.estado = 'confirmada' and v_en_ventana)
    or (old.estado = 'completada' and new.estado in ('pendiente', 'confirmada') and v_en_ventana)
  ) then
    raise exception 'Cambio de estado no permitido: % -> %.', old.estado, new.estado
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists citas_validar_update on public.citas;
create trigger citas_validar_update before update on public.citas
for each row execute procedure public.citas_validar_update();

-- Sin política delete en citas: cancelar es un cambio de estado, nunca un borrado.
-- (Solo se borran en cascada al borrar el cliente, D-20.)

drop policy if exists cita_mascotas_select on public.cita_mascotas;
create policy cita_mascotas_select on public.cita_mascotas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

-- HI-01: el insert directo exige la misma guarda que crear_cita/actualizar_cita: la
-- mascota es del cliente de la cita, y la cita sigue pendiente/confirmada.
drop policy if exists cita_mascotas_insert on public.cita_mascotas;
create policy cita_mascotas_insert on public.cita_mascotas for insert to authenticated
with check (
  public.es_veterinario()
  and clinica_id = public.mi_clinica_id()
  and exists (
    select 1
    from public.citas c
    join public.mascotas m on m.id = cita_mascotas.mascota_id
    where c.id = cita_mascotas.cita_id
      and c.clinica_id = cita_mascotas.clinica_id
      and m.clinica_id = cita_mascotas.clinica_id
      and m.dueno_id = c.cliente_id
      and c.estado in ('pendiente', 'confirmada')
  )
);

drop policy if exists cita_mascotas_delete on public.cita_mascotas;
create policy cita_mascotas_delete on public.cita_mascotas for delete to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

-- Sin política update en cita_mascotas ni ninguna política para CLIENTE
-- (la Fase 9 / DIR-05 agrega la suya).

-- HI-01/ME-04: consultas_insert (antes en la Fase 3) vive aquí porque ahora
-- valida consultas.cita_id. La FK consultas.cita_id -> citas(id) es de una sola
-- columna y las FK ignoran RLS, así que sin esto un insert directo podía ligar la
-- consulta a una cita de OTRA clínica o a una cita donde la mascota no está.
drop policy if exists consultas_insert on public.consultas;
create policy consultas_insert on public.consultas for insert to authenticated
with check (
  public.es_veterinario()
  and veterinario_id = auth.uid()
  and exists (
    select 1 from public.mascotas m
    where m.id = consultas.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
  and (
    consultas.cita_id is null
    or exists (
      select 1
      from public.cita_mascotas cm
      join public.citas c on c.id = cm.cita_id and c.clinica_id = cm.clinica_id
      where cm.cita_id = consultas.cita_id
        and cm.mascota_id = consultas.mascota_id
        and cm.clinica_id = public.mi_clinica_id()
        -- ME-04: una cita cancelada / no_asistio / solicitada no recibe consultas.
        and c.estado in ('pendiente', 'confirmada', 'completada')
    )
  )
);

-- AGND-01/D-03: crea la cita y sus mascotas en una sola transacción.
create or replace function public.crear_cita(
  p_cliente_id uuid,
  p_mascota_ids uuid[],
  p_fecha_hora timestamptz,
  p_duracion_min integer default 30,
  p_modalidad text default 'consultorio',
  p_direccion text default '',
  p_motivo text default 'Consulta general',
  p_notas text default ''
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_cita_id uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede crear citas.'
      using errcode = 'insufficient_privilege';
  end if;

  if p_mascota_ids is null or coalesce(array_length(p_mascota_ids, 1), 0) = 0 then
    raise exception 'Elige al menos una mascota.' using errcode = 'check_violation';
  end if;

  -- Misma guarda de dueño: todas las mascotas deben ser del cliente y de la clínica.
  if exists (
    select 1
    from unnest(p_mascota_ids) as x(id)
    where not exists (
      select 1 from public.mascotas m
      where m.id = x.id and m.dueno_id = p_cliente_id and m.clinica_id = v_clinica_id
    )
  ) or not exists (
    select 1 from public.clientes c
    where c.id = p_cliente_id and c.clinica_id = v_clinica_id
  ) then
    raise exception 'El cliente o la mascota no existe en tu clínica.'
      using errcode = 'foreign_key_violation';
  end if;

  insert into public.citas (
    clinica_id, cliente_id, veterinario_id, fecha_hora, duracion_min,
    modalidad, direccion, motivo, notas
  ) values (
    v_clinica_id, p_cliente_id, auth.uid(), p_fecha_hora, p_duracion_min,
    p_modalidad, trim(p_direccion), trim(p_motivo), trim(p_notas)
  ) returning id into v_cita_id;

  insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
  select v_cita_id, d.id, v_clinica_id
  from (select distinct unnest(p_mascota_ids) as id) d;

  return v_cita_id;
end;
$$;

revoke all on function public.crear_cita(
  uuid, uuid[], timestamptz, integer, text, text, text, text
) from public, anon;
grant execute on function public.crear_cita(
  uuid, uuid[], timestamptz, integer, text, text, text, text
) to authenticated;

-- AGND-02: edita una cita pendiente/confirmada (el cliente no cambia al editar).
create or replace function public.actualizar_cita(
  p_cita_id uuid,
  p_mascota_ids uuid[],
  p_fecha_hora timestamptz,
  p_duracion_min integer default 30,
  p_modalidad text default 'consultorio',
  p_direccion text default '',
  p_motivo text default 'Consulta general',
  p_notas text default ''
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_cliente_id uuid;
  v_estado text;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede editar citas.'
      using errcode = 'insufficient_privilege';
  end if;

  select c.cliente_id, c.estado into v_cliente_id, v_estado
  from public.citas c
  where c.id = p_cita_id and c.clinica_id = v_clinica_id;

  if not found then
    raise exception 'La cita no existe en tu clínica.' using errcode = 'foreign_key_violation';
  end if;

  if v_estado not in ('pendiente', 'confirmada') then
    raise exception 'Solo se pueden editar citas pendientes o confirmadas.'
      using errcode = 'check_violation';
  end if;

  if p_mascota_ids is null or coalesce(array_length(p_mascota_ids, 1), 0) = 0 then
    raise exception 'Elige al menos una mascota.' using errcode = 'check_violation';
  end if;

  if exists (
    select 1
    from unnest(p_mascota_ids) as x(id)
    where not exists (
      select 1 from public.mascotas m
      where m.id = x.id and m.dueno_id = v_cliente_id and m.clinica_id = v_clinica_id
    )
  ) then
    raise exception 'El cliente o la mascota no existe en tu clínica.'
      using errcode = 'foreign_key_violation';
  end if;

  if exists (
    select 1
    from public.cita_mascotas cm
    join public.consultas co
      on co.cita_id = cm.cita_id and co.mascota_id = cm.mascota_id
    where cm.cita_id = p_cita_id
      and cm.mascota_id <> all (p_mascota_ids)
  ) then
    raise exception 'No puedes quitar una mascota que ya tiene consulta registrada en esta cita.'
      using errcode = 'check_violation';
  end if;

  update public.citas set
    fecha_hora = p_fecha_hora,
    duracion_min = p_duracion_min,
    modalidad = p_modalidad,
    direccion = trim(p_direccion),
    motivo = trim(p_motivo),
    notas = trim(p_notas)
  where id = p_cita_id and clinica_id = v_clinica_id;

  delete from public.cita_mascotas
  where cita_id = p_cita_id and mascota_id <> all (p_mascota_ids);

  insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
  select p_cita_id, d.id, v_clinica_id
  from (select distinct unnest(p_mascota_ids) as id) d
  on conflict (cita_id, mascota_id) do nothing;
end;
$$;

revoke all on function public.actualizar_cita(
  uuid, uuid[], timestamptz, integer, text, text, text, text
) from public, anon;
grant execute on function public.actualizar_cita(
  uuid, uuid[], timestamptz, integer, text, text, text, text
) to authenticated;

-- HIST-01 + AGND-06: registrar_consulta gana p_cita_id (último parámetro, default null).
-- Se elimina la firma de 10 argumentos para evitar ambigüedad de sobrecarga en PostgREST.
drop function if exists public.registrar_consulta(
  uuid, text, text, text, text, numeric, numeric, integer, integer, text
);

create or replace function public.registrar_consulta(
  p_mascota_id uuid,
  p_diagnostico text,
  p_tratamiento text,
  p_anamnesis text default null,
  p_evolucion text default null,
  p_peso_kg numeric default null,
  p_temperatura_c numeric default null,
  p_frecuencia_cardiaca integer default null,
  p_frecuencia_respiratoria integer default null,
  p_mucosas text default null,
  p_cita_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_consulta_id uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede registrar consultas.'
      using errcode = 'insufficient_privilege';
  end if;

  if not exists (
    select 1 from public.mascotas m where m.id = p_mascota_id and m.clinica_id = v_clinica_id
  ) then
    raise exception 'La mascota no existe en tu clínica.' using errcode = 'foreign_key_violation';
  end if;

  if p_cita_id is not null and not exists (
    select 1
    from public.cita_mascotas cm
    join public.citas c on c.id = cm.cita_id
    where cm.cita_id = p_cita_id
      and cm.mascota_id = p_mascota_id
      and c.clinica_id = v_clinica_id
  ) then
    raise exception 'La mascota no pertenece a esta cita.' using errcode = 'foreign_key_violation';
  end if;

  -- ME-04: solo citas pendientes, confirmadas o completadas admiten consultas.
  if p_cita_id is not null and exists (
    select 1 from public.citas c
    where c.id = p_cita_id
      and c.estado not in ('pendiente', 'confirmada', 'completada')
  ) then
    raise exception 'Esta cita no admite consultas (está cancelada, no asistió o es solo una solicitud).'
      using errcode = 'check_violation';
  end if;

  insert into public.consultas (
    mascota_id, veterinario_id, anamnesis, peso_kg, temperatura_c,
    frecuencia_cardiaca, frecuencia_respiratoria, mucosas, diagnostico, tratamiento,
    evolucion, cita_id
  ) values (
    p_mascota_id, auth.uid(), nullif(trim(p_anamnesis), ''), p_peso_kg, p_temperatura_c,
    p_frecuencia_cardiaca, p_frecuencia_respiratoria, nullif(trim(p_mucosas), ''),
    trim(p_diagnostico), trim(p_tratamiento), nullif(trim(p_evolucion), ''), p_cita_id
  ) returning id into v_consulta_id;

  if p_peso_kg is not null then
    insert into public.mascota_pesos (mascota_id, peso_kg) values (p_mascota_id, p_peso_kg);
  end if;

  return v_consulta_id;
end;
$$;

revoke all on function public.registrar_consulta(
  uuid, text, text, text, text, numeric, numeric, integer, integer, text, uuid
) from public, anon;
grant execute on function public.registrar_consulta(
  uuid, text, text, text, text, numeric, numeric, integer, integer, text, uuid
) to authenticated;

-- =============================================================================
-- Hardening: Supabase security advisor 0028/0029 (2026-10-01)
-- Las funciones auxiliares de RLS son security definer y por defecto PUBLIC/anon
-- las podía ejecutar vía /rest/v1/rpc. Todas las políticas son `to authenticated`,
-- así que anon no las necesita. crear_perfil_nuevo_usuario() es solo función de
-- trigger: disparar un trigger no requiere EXECUTE, así que nadie de la API la
-- necesita. Idempotente.
-- =============================================================================
revoke execute on function public.mi_perfil() from public, anon;
revoke execute on function public.es_veterinario() from public, anon;
revoke execute on function public.mi_clinica_id() from public, anon;
grant execute on function public.mi_perfil() to authenticated;
grant execute on function public.es_veterinario() to authenticated;
grant execute on function public.mi_clinica_id() to authenticated;
revoke execute on function public.crear_perfil_nuevo_usuario() from public, anon, authenticated;

-- ===== Fase 4.1: Equipo de la clínica (delta idempotente) =====
-- Membresía (rol_clinica/activo/matricula), códigos de invitación, retiro de miembros,
-- citas por veterinario y visibilidad de autoría. Se re-ejecuta completo sin error.
-- Orden: columnas primero (las funciones `language sql` se validan al crearlas).

-- 1. Columnas de membresía en perfiles.
alter table public.perfiles add column if not exists rol_clinica text;
alter table public.perfiles add column if not exists activo boolean not null default true;
alter table public.perfiles add column if not exists matricula text;

do $$ begin
  alter table public.perfiles
    add constraint perfiles_rol_clinica_valido
    check (rol_clinica is null or rol_clinica in ('admin', 'veterinario'));
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.perfiles
    add constraint perfiles_matricula_longitud
    check (matricula is null or char_length(matricula) <= 30);
exception when duplicate_object then null;
end $$;

-- 2. D-04: todo veterinario existente pasa a ser admin de la clínica que ya tiene; no se mueven datos.
update public.perfiles set rol_clinica = 'admin' where rol = 'VETERINARIO' and rol_clinica is null;

do $$ begin
  alter table public.perfiles
    add constraint perfiles_vet_requiere_rol_clinica
    check (rol = 'CLIENTE' or rol_clinica is not null);
exception when duplicate_object then null;
end $$;

-- 3. Helpers: ahora filtran por `activo`, así que un veterinario retirado pierde acceso
-- en la siguiente consulta aunque su JWT siga vigente (T6): todas las políticas existentes
-- dependen de es_veterinario() / mi_clinica_id().
create or replace function public.es_veterinario()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.perfiles
  where id = auth.uid() and rol = 'VETERINARIO' and activo
) $$;

create or replace function public.mi_clinica_id()
returns uuid language sql stable security definer set search_path = public
as $$ select clinica_id from public.perfiles where id = auth.uid() and activo $$;

create or replace function public.es_admin_clinica()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.perfiles
  where id = auth.uid() and rol = 'VETERINARIO' and rol_clinica = 'admin' and activo
) $$;

-- p_id es veterinario activo de MI clínica (la del llamador).
create or replace function public.es_miembro_activo(p_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (
  select 1 from public.perfiles
  where id = p_id and rol = 'VETERINARIO' and activo
    and clinica_id is not null and clinica_id = public.mi_clinica_id()
) $$;

-- D-13: p_id es autor de citas/consultas en mi clínica (aunque ya no sea miembro).
-- Fase 5: incluye dosis_aplicadas (D-09) -- ver redefinición al final del archivo.
create or replace function public.es_autor_en_mi_clinica(p_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select
  exists (
    select 1 from public.citas c
    where c.clinica_id = public.mi_clinica_id() and c.veterinario_id = p_id
  )
  or exists (
    select 1 from public.consultas co
    join public.mascotas m on m.id = co.mascota_id
    where co.veterinario_id = p_id and m.clinica_id = public.mi_clinica_id()
  )
$$;

drop policy if exists perfiles_select on public.perfiles;
create policy perfiles_select on public.perfiles for select to authenticated
using (
  id = auth.uid()
  or (
    public.es_veterinario()
    and (clinica_id = public.mi_clinica_id() or public.es_autor_en_mi_clinica(id))
  )
);

-- 4. Invitaciones: un código vigente por clínica; solo escriben las RPC definer.
create table if not exists public.clinica_invitaciones (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  codigo text not null unique
    check (codigo ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$'),
  creada_por uuid references auth.users(id) on delete set null,
  expira_en timestamptz not null,
  usada_por uuid references auth.users(id) on delete set null,
  usada_en timestamptz,
  revocada boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists clinica_invitaciones_clinica_id_idx
  on public.clinica_invitaciones(clinica_id);

alter table public.clinica_invitaciones enable row level security;

drop policy if exists clinica_invitaciones_select on public.clinica_invitaciones;
create policy clinica_invitaciones_select on public.clinica_invitaciones for select to authenticated
using (public.es_admin_clinica() and clinica_id = public.mi_clinica_id());

-- Sin políticas de insert/update/delete: solo las RPC security definer escriben.
revoke all on public.clinica_invitaciones from anon;

-- 5. Consumo de un código (solo lo llaman el trigger de signup y unirse_a_clinica; T10).
-- `for update` serializa el uso concurrente del mismo código (T3).
create or replace function public.consumir_invitacion(p_codigo text, p_usuario uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_codigo text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
  v_inv public.clinica_invitaciones;
begin
  select * into v_inv from public.clinica_invitaciones where codigo = v_codigo for update;

  if not found or v_inv.revocada then
    raise exception 'Ese código no es válido. Revísalo e inténtalo de nuevo.' using errcode = 'P0001';
  end if;

  if v_inv.usada_por is not null then
    raise exception 'Ese código ya fue utilizado. Pídele al administrador uno nuevo.' using errcode = 'P0001';
  end if;

  if v_inv.expira_en <= now() then
    raise exception 'Ese código ya venció. Pídele al administrador uno nuevo.' using errcode = 'P0001';
  end if;

  update public.clinica_invitaciones
  set usada_por = p_usuario, usada_en = now()
  where id = v_inv.id;

  return v_inv.clinica_id;
end;
$$;

revoke execute on function public.consumir_invitacion(text, uuid) from public, anon, authenticated;

-- 6. Trigger de signup endurecido (T2): lee SOLO rol, nombre, telefono, clinica_* y
-- codigo_invitacion de la metadata; jamás clinica_id, rol_clinica, activo ni matricula.
-- Un error del código aborta el alta y Auth responde con su 500 genérico (Pitfall 3).
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_rol public.rol_perfil := coalesce(metadata->>'rol', 'CLIENTE')::public.rol_perfil;
  v_codigo text := nullif(trim(coalesce(metadata->>'codigo_invitacion', '')), '');
  v_clinica uuid;
  v_rol_clinica text;
begin
  if v_rol = 'VETERINARIO' then
    if v_codigo is not null then
      v_clinica := public.consumir_invitacion(v_codigo, new.id);
      v_rol_clinica := 'veterinario';
    else
      insert into public.clinicas(nombre, ciudad, direccion, telefono)
      values (
        coalesce(nullif(trim(metadata->>'clinica_nombre'), ''), 'Clínica sin nombre'),
        coalesce(metadata->>'clinica_ciudad', ''),
        coalesce(metadata->>'clinica_direccion', ''),
        coalesce(metadata->>'clinica_telefono', '')
      ) returning id into v_clinica;
      v_rol_clinica := 'admin';
    end if;
  end if;

  insert into public.perfiles(id, nombre, rol, clinica_id, telefono, rol_clinica, activo)
  values (
    new.id,
    coalesce(metadata->>'nombre', ''),
    v_rol,
    v_clinica,
    coalesce(metadata->>'telefono', ''),
    v_rol_clinica,
    true
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.crear_perfil_nuevo_usuario();

-- 7. RPC de gestión del equipo. Todas security definer con search_path fijo (T11); cada
-- una verifica es_admin_clinica() y que el objetivo sea de mi_clinica_id() (T4).

-- Un solo código vigente por clínica: genera uno nuevo y revoca el anterior.
-- Código de 8 caracteres de un alfabeto de 31 símbolos (sin I, L, O, 0, 1) derivado de
-- bytes de gen_random_uuid() (CSPRNG); se saltan los bytes 6 y 8 (bits fijos de versión/variante).
create or replace function public.generar_invitacion_clinica()
returns table (id uuid, codigo text, expira_en timestamptz)
language plpgsql
security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_alfabeto constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_codigo text;
  v_bytes bytea;
  v_i integer;
  v_expira timestamptz;
  v_id uuid;
  v_intento integer := 0;
begin
  if not public.es_admin_clinica() or v_clinica is null then
    raise exception 'Solo un administrador puede hacer esto.' using errcode = '42501';
  end if;

  update public.clinica_invitaciones ci
  set revocada = true
  where ci.clinica_id = v_clinica
    and ci.usada_por is null
    and not ci.revocada
    and ci.expira_en > now();

  loop
    v_intento := v_intento + 1;
    v_bytes := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    v_codigo := '';
    v_i := 0;
    while length(v_codigo) < 8 loop
      if v_i not in (6, 8) then
        v_codigo := v_codigo || substr(v_alfabeto, (get_byte(v_bytes, v_i) % 31) + 1, 1);
      end if;
      v_i := v_i + 1;
    end loop;
    v_expira := now() + interval '72 hours';

    begin
      insert into public.clinica_invitaciones as ci (clinica_id, codigo, creada_por, expira_en)
      values (v_clinica, v_codigo, auth.uid(), v_expira)
      returning ci.id into v_id;
      exit;
    exception when unique_violation then
      if v_intento >= 5 then
        raise;
      end if;
    end;
  end loop;

  return query select v_id, v_codigo, v_expira;
end;
$$;

create or replace function public.revocar_invitacion(p_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_inv public.clinica_invitaciones;
begin
  if not public.es_admin_clinica() then
    raise exception 'Solo un administrador puede hacer esto.' using errcode = '42501';
  end if;

  select * into v_inv from public.clinica_invitaciones where id = p_id for update;

  if not found or v_inv.clinica_id is distinct from public.mi_clinica_id() then
    raise exception 'La invitación no existe en tu clínica.' using errcode = '23503';
  end if;

  if v_inv.usada_por is not null then
    raise exception 'Esa invitación ya fue utilizada.' using errcode = 'check_violation';
  end if;

  update public.clinica_invitaciones set revocada = true where id = p_id;
end;
$$;

-- D-05/D-14/D-15: retira (activo=false, nunca borra) a un miembro. Bloquea a todos los
-- veterinarios activos de la clínica ANTES de contar admins (T5, orden por id para evitar
-- deadlocks). Sus citas futuras abiertas pasan al destino elegido o, si no hay, al admin
-- que retira (o al admin activo más antiguo si es auto-retiro).
create or replace function public.retirar_miembro(p_miembro uuid, p_reasignar_a uuid default null)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_target public.perfiles;
  v_otros_admins integer;
  v_dest uuid;
  v_movidas integer;
begin
  if not public.es_admin_clinica() or v_clinica is null then
    raise exception 'Solo un administrador puede hacer esto.' using errcode = '42501';
  end if;

  perform 1 from public.perfiles
  where clinica_id = v_clinica and rol = 'VETERINARIO' and activo
  order by id
  for update;

  select * into v_target from public.perfiles
  where id = p_miembro and rol = 'VETERINARIO' and activo and clinica_id = v_clinica;

  if not found then
    raise exception 'Ese veterinario ya no está en tu clínica.' using errcode = '23503';
  end if;

  select count(*) into v_otros_admins from public.perfiles
  where clinica_id = v_clinica and rol = 'VETERINARIO' and activo
    and rol_clinica = 'admin' and id <> p_miembro;

  if v_target.rol_clinica = 'admin' and v_otros_admins = 0 then
    raise exception 'La clínica debe tener al menos un administrador.' using errcode = 'P0001';
  end if;

  v_dest := p_reasignar_a;
  if v_dest is null then
    if p_miembro = auth.uid() then
      select p.id into v_dest from public.perfiles p
      where p.clinica_id = v_clinica and p.rol = 'VETERINARIO' and p.activo
        and p.rol_clinica = 'admin' and p.id <> p_miembro
      order by p.created_at, p.id
      limit 1;
    else
      v_dest := auth.uid();
    end if;
  end if;

  if v_dest is null or v_dest = p_miembro or not public.es_miembro_activo(v_dest) then
    raise exception 'Ese veterinario ya no está en tu clínica.' using errcode = '23503';
  end if;

  update public.citas
  set veterinario_id = v_dest
  where clinica_id = v_clinica
    and veterinario_id = p_miembro
    and estado in ('pendiente', 'confirmada')
    and fecha_hora >= now();
  get diagnostics v_movidas = row_count;

  update public.perfiles set activo = false where id = p_miembro;

  return v_movidas;
end;
$$;

create or replace function public.cambiar_rol_miembro(p_miembro uuid, p_rol text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_target public.perfiles;
  v_otros_admins integer;
begin
  if not public.es_admin_clinica() or v_clinica is null then
    raise exception 'Solo un administrador puede hacer esto.' using errcode = '42501';
  end if;

  if p_rol is null or p_rol not in ('admin', 'veterinario') then
    raise exception 'Rol no válido.' using errcode = 'check_violation';
  end if;

  perform 1 from public.perfiles
  where clinica_id = v_clinica and rol = 'VETERINARIO' and activo
  order by id
  for update;

  select * into v_target from public.perfiles
  where id = p_miembro and rol = 'VETERINARIO' and activo and clinica_id = v_clinica;

  if not found then
    raise exception 'Ese veterinario ya no está en tu clínica.' using errcode = '23503';
  end if;

  select count(*) into v_otros_admins from public.perfiles
  where clinica_id = v_clinica and rol = 'VETERINARIO' and activo
    and rol_clinica = 'admin' and id <> p_miembro;

  if v_target.rol_clinica = 'admin' and p_rol = 'veterinario' and v_otros_admins = 0 then
    raise exception 'La clínica debe tener al menos un administrador.' using errcode = 'P0001';
  end if;

  update public.perfiles set rol_clinica = p_rol where id = p_miembro;
end;
$$;

-- D-05: un veterinario retirado abre su propia clínica (queda como admin).
-- Lee perfiles directamente: los helpers ya lo tratan como sin clínica.
create or replace function public.crear_mi_clinica(p_nombre text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_perfil public.perfiles;
  v_nombre text := trim(coalesce(p_nombre, ''));
  v_clinica uuid;
begin
  select * into v_perfil from public.perfiles where id = auth.uid() for update;

  if not found or v_perfil.rol <> 'VETERINARIO' then
    raise exception 'Solo un veterinario puede hacer esto.' using errcode = '42501';
  end if;

  if v_perfil.activo then
    raise exception 'Ya perteneces a una clínica activa.' using errcode = 'P0001';
  end if;

  if char_length(v_nombre) < 1 or char_length(v_nombre) > 120 then
    raise exception 'El nombre de la clínica debe tener entre 1 y 120 caracteres.'
      using errcode = 'check_violation';
  end if;

  insert into public.clinicas(nombre) values (v_nombre) returning id into v_clinica;

  update public.perfiles
  set clinica_id = v_clinica, rol_clinica = 'admin', activo = true
  where id = auth.uid();

  return v_clinica;
end;
$$;

-- D-12: una cuenta = una clínica (un solo perfiles.clinica_id). Un veterinario activo solo
-- puede unirse a otra clínica si la suya está vacía (él es el único perfil y no tiene
-- clientes; mascotas/citas/consultas cuelgan de clientes); entonces la clínica vacía se
-- elimina. No existe validación anónima de códigos (D-17).
create or replace function public.unirse_a_clinica(p_codigo text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_perfil public.perfiles;
  v_vieja uuid;
  v_vacia boolean := false;
  v_nueva uuid;
begin
  select * into v_perfil from public.perfiles where id = auth.uid() for update;

  if not found or v_perfil.rol <> 'VETERINARIO' then
    raise exception 'Solo un veterinario puede hacer esto.' using errcode = '42501';
  end if;

  v_vieja := v_perfil.clinica_id;

  if v_perfil.activo then
    if (select count(*) from public.perfiles where clinica_id = v_vieja) > 1
       or exists (select 1 from public.clientes where clinica_id = v_vieja) then
      raise exception 'Tu clínica ya tiene datos; no se pueden fusionar clínicas. Regístrate con otro correo para unirte.'
        using errcode = 'P0001';
    end if;
    v_vacia := true;
  end if;

  v_nueva := public.consumir_invitacion(p_codigo, auth.uid());

  update public.perfiles
  set clinica_id = v_nueva, rol_clinica = 'veterinario', activo = true
  where id = auth.uid();

  if v_vacia and v_vieja is not null and v_vieja <> v_nueva then
    delete from public.clinicas where id = v_vieja;
  end if;

  return v_nueva;
end;
$$;

-- 8. Citas por veterinario (D-07, T8). Se eliminan las firmas de 8 argumentos antes de
-- redefinir con p_veterinario_id para evitar sobrecargas ambiguas en PostgREST.
drop function if exists public.crear_cita(uuid, uuid[], timestamptz, integer, text, text, text, text);
drop function if exists public.actualizar_cita(uuid, uuid[], timestamptz, integer, text, text, text, text);

create or replace function public.crear_cita(
  p_cliente_id uuid,
  p_mascota_ids uuid[],
  p_fecha_hora timestamptz,
  p_duracion_min integer default 30,
  p_modalidad text default 'consultorio',
  p_direccion text default '',
  p_motivo text default 'Consulta general',
  p_notas text default '',
  p_veterinario_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_vet uuid := coalesce(p_veterinario_id, auth.uid());
  v_cita_id uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede crear citas.'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.es_miembro_activo(v_vet) then
    raise exception 'Ese veterinario ya no está en tu clínica.' using errcode = '23503';
  end if;

  if p_mascota_ids is null or coalesce(array_length(p_mascota_ids, 1), 0) = 0 then
    raise exception 'Elige al menos una mascota.' using errcode = 'check_violation';
  end if;

  -- Misma guarda de dueño: todas las mascotas deben ser del cliente y de la clínica.
  if exists (
    select 1
    from unnest(p_mascota_ids) as x(id)
    where not exists (
      select 1 from public.mascotas m
      where m.id = x.id and m.dueno_id = p_cliente_id and m.clinica_id = v_clinica_id
    )
  ) or not exists (
    select 1 from public.clientes c
    where c.id = p_cliente_id and c.clinica_id = v_clinica_id
  ) then
    raise exception 'El cliente o la mascota no existe en tu clínica.'
      using errcode = 'foreign_key_violation';
  end if;

  insert into public.citas (
    clinica_id, cliente_id, veterinario_id, fecha_hora, duracion_min,
    modalidad, direccion, motivo, notas
  ) values (
    v_clinica_id, p_cliente_id, v_vet, p_fecha_hora, p_duracion_min,
    p_modalidad, trim(p_direccion), trim(p_motivo), trim(p_notas)
  ) returning id into v_cita_id;

  insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
  select v_cita_id, d.id, v_clinica_id
  from (select distinct unnest(p_mascota_ids) as id) d;

  return v_cita_id;
end;
$$;

-- p_veterinario_id null o igual al veterinario actual de la cita = sin cambio (no se
-- revisa membresía): así editar una cita abierta de un veterinario ya retirado sigue
-- funcionando. Solo un id DISTINTO se valida con es_miembro_activo y se escribe.
create or replace function public.actualizar_cita(
  p_cita_id uuid,
  p_mascota_ids uuid[],
  p_fecha_hora timestamptz,
  p_duracion_min integer default 30,
  p_modalidad text default 'consultorio',
  p_direccion text default '',
  p_motivo text default 'Consulta general',
  p_notas text default '',
  p_veterinario_id uuid default null
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_cliente_id uuid;
  v_estado text;
  v_vet_actual uuid;
  v_vet_nuevo uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede editar citas.'
      using errcode = 'insufficient_privilege';
  end if;

  select c.cliente_id, c.estado, c.veterinario_id into v_cliente_id, v_estado, v_vet_actual
  from public.citas c
  where c.id = p_cita_id and c.clinica_id = v_clinica_id;

  if not found then
    raise exception 'La cita no existe en tu clínica.' using errcode = 'foreign_key_violation';
  end if;

  if v_estado not in ('pendiente', 'confirmada') then
    raise exception 'Solo se pueden editar citas pendientes o confirmadas.'
      using errcode = 'check_violation';
  end if;

  if p_mascota_ids is null or coalesce(array_length(p_mascota_ids, 1), 0) = 0 then
    raise exception 'Elige al menos una mascota.' using errcode = 'check_violation';
  end if;

  if p_veterinario_id is not null and p_veterinario_id <> v_vet_actual then
    if not public.es_miembro_activo(p_veterinario_id) then
      raise exception 'Ese veterinario ya no está en tu clínica.' using errcode = '23503';
    end if;
    v_vet_nuevo := p_veterinario_id;
  end if;

  if exists (
    select 1
    from unnest(p_mascota_ids) as x(id)
    where not exists (
      select 1 from public.mascotas m
      where m.id = x.id and m.dueno_id = v_cliente_id and m.clinica_id = v_clinica_id
    )
  ) then
    raise exception 'El cliente o la mascota no existe en tu clínica.'
      using errcode = 'foreign_key_violation';
  end if;

  if exists (
    select 1
    from public.cita_mascotas cm
    join public.consultas co
      on co.cita_id = cm.cita_id and co.mascota_id = cm.mascota_id
    where cm.cita_id = p_cita_id
      and cm.mascota_id <> all (p_mascota_ids)
  ) then
    raise exception 'No puedes quitar una mascota que ya tiene consulta registrada en esta cita.'
      using errcode = 'check_violation';
  end if;

  update public.citas set
    fecha_hora = p_fecha_hora,
    duracion_min = p_duracion_min,
    modalidad = p_modalidad,
    direccion = trim(p_direccion),
    motivo = trim(p_motivo),
    notas = trim(p_notas),
    veterinario_id = coalesce(v_vet_nuevo, veterinario_id)
  where id = p_cita_id and clinica_id = v_clinica_id;

  delete from public.cita_mascotas
  where cita_id = p_cita_id and mascota_id <> all (p_mascota_ids);

  insert into public.cita_mascotas (cita_id, mascota_id, clinica_id)
  select p_cita_id, d.id, v_clinica_id
  from (select distinct unnest(p_mascota_ids) as id) d
  on conflict (cita_id, mascota_id) do nothing;
end;
$$;

-- citas_insert: el veterinario asignado puede ser cualquier miembro activo de la clínica.
drop policy if exists citas_insert on public.citas;
create policy citas_insert on public.citas for insert to authenticated
with check (
  public.es_veterinario()
  and clinica_id = public.mi_clinica_id()
  and public.es_miembro_activo(veterinario_id)
  and estado in ('pendiente', 'confirmada')
);

-- citas_update NO exige es_miembro_activo en with check: una cita pasada de un veterinario
-- retirado debe seguir aceptando cambios de estado. La reasignación se valida en el trigger.
-- cliente_id y clinica_id siguen inmutables; veterinario_id solo cambia en citas abiertas y
-- hacia un miembro activo (el error de no-miembro usa check_violation como el resto del trigger).
create or replace function public.citas_validar_update()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_en_ventana boolean;
begin
  v_en_ventana := old.updated_at >= now() - interval '10 minutes';

  if new.cliente_id is distinct from old.cliente_id
     or new.clinica_id is distinct from old.clinica_id then
    raise exception 'No se puede cambiar el cliente ni la clínica de una cita.'
      using errcode = 'check_violation';
  end if;

  if new.veterinario_id is distinct from old.veterinario_id then
    if old.estado not in ('solicitada', 'pendiente', 'confirmada') then
      raise exception 'Solo se pueden reasignar citas pendientes o confirmadas.'
        using errcode = 'check_violation';
    end if;
    if not public.es_miembro_activo(new.veterinario_id) then
      raise exception 'Ese veterinario ya no está en tu clínica.'
        using errcode = 'check_violation';
    end if;
  end if;

  if old.estado not in ('solicitada', 'pendiente', 'confirmada') and (
       new.fecha_hora is distinct from old.fecha_hora
       or new.duracion_min is distinct from old.duracion_min
       or new.modalidad is distinct from old.modalidad
       or new.direccion is distinct from old.direccion
       or new.motivo is distinct from old.motivo
       or new.notas is distinct from old.notas
     ) then
    raise exception 'Solo se pueden editar citas pendientes o confirmadas.'
      using errcode = 'check_violation';
  end if;

  if new.estado is distinct from old.estado and not (
       (old.estado = 'solicitada' and new.estado in ('pendiente', 'confirmada', 'cancelada'))
    or (old.estado = 'pendiente' and new.estado in ('confirmada', 'completada', 'cancelada', 'no_asistio'))
    or (old.estado = 'confirmada' and new.estado in ('pendiente', 'completada', 'cancelada', 'no_asistio'))
    or (old.estado in ('cancelada', 'no_asistio') and new.estado = 'pendiente')
    or (old.estado in ('cancelada', 'no_asistio') and new.estado = 'confirmada' and v_en_ventana)
    or (old.estado = 'completada' and new.estado in ('pendiente', 'confirmada') and v_en_ventana)
  ) then
    raise exception 'Cambio de estado no permitido: % -> %.', old.estado, new.estado
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists citas_validar_update on public.citas;
create trigger citas_validar_update before update on public.citas
for each row execute procedure public.citas_validar_update();

-- Embed de PostgREST para el nombre del veterinario asignado. citas.veterinario_id sigue
-- not null (D-17) y mantiene su FK a auth.users on delete restrict.
do $$ begin
  alter table public.citas
    add constraint citas_veterinario_perfil_fkey foreign key (veterinario_id)
    references public.perfiles(id) on delete restrict;
exception when duplicate_object then null;
end $$;

-- 9. Consultas (D-06, T7): el registro legal no se borra en cascada con la cuenta del autor.
do $$
declare
  v_con record;
begin
  for v_con in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.consultas'::regclass
      and c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
      and c.confdeltype = 'c'
      and c.conkey = array[(
        select a.attnum from pg_attribute a
        where a.attrelid = 'public.consultas'::regclass and a.attname = 'veterinario_id'
      )]
  loop
    execute format('alter table public.consultas drop constraint %I', v_con.conname);
  end loop;

  if not exists (
    select 1 from pg_constraint
    where conname = 'consultas_veterinario_id_fkey'
      and conrelid = 'public.consultas'::regclass
  ) then
    alter table public.consultas
      add constraint consultas_veterinario_id_fkey foreign key (veterinario_id)
      references auth.users(id) on delete restrict;
  end if;
end;
$$;

do $$ begin
  alter table public.consultas
    add constraint consultas_veterinario_perfil_fkey foreign key (veterinario_id)
    references public.perfiles(id) on delete restrict;
exception when duplicate_object then null;
end $$;

-- 10. Privilegios por columna (T1): un usuario autenticado solo edita nombre, telefono y
-- matricula de su perfil. rol, clinica_id, rol_clinica y activo cambian únicamente vía RPC
-- definer. Las columnas futuras de perfiles quedan NO actualizables por defecto.
revoke update on public.perfiles from authenticated;
revoke update on public.perfiles from anon;
grant update (nombre, telefono, matricula) on public.perfiles to authenticated;

-- 11. Grants de las funciones nuevas (consumir_invitacion queda sin grant alguno).
revoke all on function public.es_admin_clinica() from public, anon;
revoke all on function public.es_miembro_activo(uuid) from public, anon;
revoke all on function public.es_autor_en_mi_clinica(uuid) from public, anon;
revoke all on function public.generar_invitacion_clinica() from public, anon;
revoke all on function public.revocar_invitacion(uuid) from public, anon;
revoke all on function public.retirar_miembro(uuid, uuid) from public, anon;
revoke all on function public.cambiar_rol_miembro(uuid, text) from public, anon;
revoke all on function public.crear_mi_clinica(text) from public, anon;
revoke all on function public.unirse_a_clinica(text) from public, anon;
revoke all on function public.crear_cita(
  uuid, uuid[], timestamptz, integer, text, text, text, text, uuid
) from public, anon;
revoke all on function public.actualizar_cita(
  uuid, uuid[], timestamptz, integer, text, text, text, text, uuid
) from public, anon;

grant execute on function public.es_admin_clinica() to authenticated;
grant execute on function public.es_miembro_activo(uuid) to authenticated;
grant execute on function public.es_autor_en_mi_clinica(uuid) to authenticated;
grant execute on function public.generar_invitacion_clinica() to authenticated;
grant execute on function public.revocar_invitacion(uuid) to authenticated;
grant execute on function public.retirar_miembro(uuid, uuid) to authenticated;
grant execute on function public.cambiar_rol_miembro(uuid, text) to authenticated;
grant execute on function public.crear_mi_clinica(text) to authenticated;
grant execute on function public.unirse_a_clinica(text) to authenticated;
grant execute on function public.crear_cita(
  uuid, uuid[], timestamptz, integer, text, text, text, text, uuid
) to authenticated;
grant execute on function public.actualizar_cita(
  uuid, uuid[], timestamptz, integer, text, text, text, text, uuid
) to authenticated;

-- Re-afirmar (el bloque superior recrea las versiones antiguas en cada re-ejecución).
revoke execute on function public.es_veterinario() from public, anon;
revoke execute on function public.mi_clinica_id() from public, anon;
grant execute on function public.es_veterinario() to authenticated;
grant execute on function public.mi_clinica_id() to authenticated;
revoke execute on function public.crear_perfil_nuevo_usuario() from public, anon, authenticated;
revoke execute on function public.consumir_invitacion(text, uuid) from public, anon, authenticated;

-- ===== Fase 5: Vacunación y desparasitación (delta idempotente) =====
-- Re-ejecutable. Va DESPUÉS del bloque 4.1 para que la redefinición de
-- es_autor_en_mi_clinica gane en cada re-pegado (Pitfall 2). Las tablas van antes que las
-- funciones porque las funciones `language sql` validan sus referencias al crearse.

-- 1. Catálogo de protocolos (D-01): filas globales (clinica_id null) = semillas colombianas;
-- una fila de clínica con el mismo `codigo` es un override. Escrituras solo vía RPC (D-24).
create table if not exists public.protocolos_vacunacion (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid null references public.clinicas(id) on delete cascade,
  codigo text not null check (codigo ~ '^[a-z0-9_:-]{2,64}$'),
  nombre text not null check (char_length(trim(nombre)) between 1 and 80),
  tipo text not null check (tipo in ('vacuna', 'desparasitacion_interna', 'desparasitacion_externa')),
  especies text[] not null check (especies <@ array['perro', 'gato', 'otro'] and cardinality(especies) > 0),
  edad_min_dias int null,
  dosis_serie int not null default 1 check (dosis_serie between 1 and 6),
  intervalo_serie_dias int null check (intervalo_serie_dias is null or intervalo_serie_dias > 0),
  intervalo_refuerzo_dias int null check (intervalo_refuerzo_dias is null or intervalo_refuerzo_dias > 0),
  opciones_duracion_dias int[] not null default '{}',
  intervalos_por_edad jsonb null,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists protocolos_vacunacion_clinica_codigo_uq
  on public.protocolos_vacunacion (coalesce(clinica_id, '00000000-0000-0000-0000-000000000000'::uuid), codigo);

drop trigger if exists protocolos_vacunacion_tocar_updated_at on public.protocolos_vacunacion;
create trigger protocolos_vacunacion_tocar_updated_at before update on public.protocolos_vacunacion
for each row execute procedure public.tocar_updated_at();

-- 2. Dosis aplicadas.
-- Solo-append (HIST-04, D-08): sin políticas insert/update/delete; escritura solo por
-- registrar_dosis/anular_dosis. Sin columna de próxima dosis (D-02, Pitfall 7).
create table if not exists public.dosis_aplicadas (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null,
  clinica_id uuid not null,
  veterinario_id uuid not null references auth.users(id) on delete restrict,
  cita_id uuid null references public.citas(id) on delete set null,
  codigo_protocolo text not null,
  biologico_nombre text not null,
  tipo text not null check (tipo in ('vacuna', 'desparasitacion_interna', 'desparasitacion_externa')),
  fecha_aplicacion date not null,
  duracion_elegida_dias int null check (duracion_elegida_dias is null or duracion_elegida_dias > 0),
  sin_refuerzo boolean not null default false,
  es_refuerzo boolean not null default false,
  inicia_serie boolean not null default false,
  externa boolean not null default false,
  clinica_externa text null check (clinica_externa is null or char_length(clinica_externa) <= 80),
  producto text null check (producto is null or char_length(producto) <= 80),
  lote text null check (lote is null or char_length(lote) <= 40),
  observaciones text null check (observaciones is null or char_length(observaciones) <= 500),
  anulada boolean not null default false,
  motivo_anulacion text null check (motivo_anulacion is null or char_length(motivo_anulacion) <= 120),
  anulada_at timestamptz null,
  anulada_por uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint dosis_anulacion_consistente check (anulada = (motivo_anulacion is not null))
);

do $$ begin
  alter table public.dosis_aplicadas
    add constraint dosis_mascota_misma_clinica_fkey foreign key (mascota_id, clinica_id)
    references public.mascotas(id, clinica_id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.dosis_aplicadas
    add constraint dosis_veterinario_perfil_fkey foreign key (veterinario_id)
    references public.perfiles(id) on delete restrict;
exception when duplicate_object then null;
end $$;

create index if not exists dosis_aplicadas_mascota_codigo_fecha_idx
  on public.dosis_aplicadas (mascota_id, codigo_protocolo, fecha_aplicacion);
create index if not exists dosis_aplicadas_clinica_idx
  on public.dosis_aplicadas (clinica_id);
create index if not exists dosis_aplicadas_cita_idx
  on public.dosis_aplicadas (cita_id) where cita_id is not null;

-- 3. Gestión de alertas (descartar / posponer / recordado). Una fila solo existe si el
-- veterinario gestionó la última dosis; una dosis nueva no tiene fila (la gestión previa
-- deja de aplicar sola).
create table if not exists public.vacuna_alertas (
  dosis_ref_id uuid primary key references public.dosis_aplicadas(id) on delete cascade,
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  descartada_at timestamptz null,
  motivo_descarte text null check (motivo_descarte is null or char_length(motivo_descarte) <= 120),
  pospuesta_hasta date null,
  recordatorio_enviado_at timestamptz null,
  updated_at timestamptz not null default now()
);

drop trigger if exists vacuna_alertas_tocar_updated_at on public.vacuna_alertas;
create trigger vacuna_alertas_tocar_updated_at before update on public.vacuna_alertas
for each row execute procedure public.tocar_updated_at();

-- 4. Enlaces públicos del carné (un token vigente por mascota).
create table if not exists public.carne_enlaces (
  mascota_id uuid primary key,
  clinica_id uuid not null,
  token text not null unique check (token ~ '^[0-9a-f]{64}$'),
  activo boolean not null default true,
  creado_at timestamptz not null default now(),
  regenerado_at timestamptz null
);

do $$ begin
  alter table public.carne_enlaces
    add constraint carne_enlaces_mascota_misma_clinica_fkey foreign key (mascota_id, clinica_id)
    references public.mascotas(id, clinica_id) on delete cascade;
exception when duplicate_object then null;
end $$;

-- RLS: solo lectura para veterinarios de la clínica; ninguna política de escritura.
alter table public.protocolos_vacunacion enable row level security;
alter table public.dosis_aplicadas enable row level security;
alter table public.vacuna_alertas enable row level security;
alter table public.carne_enlaces enable row level security;

drop policy if exists protocolos_vacunacion_select on public.protocolos_vacunacion;
create policy protocolos_vacunacion_select on public.protocolos_vacunacion for select to authenticated
using (public.es_veterinario() and (clinica_id is null or clinica_id = public.mi_clinica_id()));

drop policy if exists dosis_aplicadas_select on public.dosis_aplicadas;
create policy dosis_aplicadas_select on public.dosis_aplicadas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists vacuna_alertas_select on public.vacuna_alertas;
create policy vacuna_alertas_select on public.vacuna_alertas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists carne_enlaces_select on public.carne_enlaces;
create policy carne_enlaces_select on public.carne_enlaces for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

revoke all on table public.protocolos_vacunacion from anon;
revoke all on table public.dosis_aplicadas from anon;
revoke all on table public.vacuna_alertas from anon;
revoke all on table public.carne_enlaces from anon;
revoke insert, update, delete, truncate on table public.protocolos_vacunacion from authenticated;
revoke insert, update, delete, truncate on table public.dosis_aplicadas from authenticated;
revoke insert, update, delete, truncate on table public.vacuna_alertas from authenticated;
revoke insert, update, delete, truncate on table public.carne_enlaces from authenticated;

-- 5. Semillas colombianas (D-01). Valencia (quíntuple/séxtuple/óctuple) va como texto libre
-- en `producto`, no como protocolos separados.
insert into public.protocolos_vacunacion
  (clinica_id, codigo, nombre, tipo, especies, edad_min_dias, dosis_serie,
   intervalo_serie_dias, intervalo_refuerzo_dias, opciones_duracion_dias, intervalos_por_edad)
values
  (null, 'puppy_dp', 'Puppy DP', 'vacuna', array['perro'], 42, 1, null, null, '{}', null),
  (null, 'polivalente', 'Polivalente', 'vacuna', array['perro'], 56, 3, 21, 365, '{}', null),
  (null, 'leptospirosis', 'Leptospirosis', 'vacuna', array['perro'], 56, 2, 21, 365, '{}', null),
  (null, 'bordetella', 'Bordetella', 'vacuna', array['perro'], 56, 1, null, 365, '{}', null),
  (null, 'antirrabica', 'Antirrábica', 'vacuna', array['perro', 'gato'], 84, 1, null, 365, '{365,1095}', null),
  (null, 'triple_felina', 'Triple felina', 'vacuna', array['gato'], 56, 3, 21, 365, '{}', null),
  (null, 'leucemia_felina', 'Leucemia felina', 'vacuna', array['gato'], 56, 2, 21, 365, '{}', null),
  (null, 'desp_interna', 'Desparasitación interna', 'desparasitacion_interna', array['perro', 'gato'], 14, 1, null, 90, '{}',
    '[{"hasta_dias":56,"intervalo":15},{"hasta_dias":180,"intervalo":30},{"intervalo":90}]'::jsonb),
  (null, 'desp_externa', 'Desparasitación externa', 'desparasitacion_externa', array['perro', 'gato'], 56, 1, null, 30, '{30,35,84}', null)
on conflict do nothing;

-- 6. Helpers.
create or replace function public._hoy_bogota()
returns date language sql stable set search_path = public
as $$ select (now() at time zone 'America/Bogota')::date $$;

-- D-20: "Nombre I." (primera palabra + inicial de la segunda); una sola palabra => esa palabra.
create or replace function public._nombre_corto(p_nombre text)
returns text language sql immutable set search_path = public
as $$
  select case
    when cardinality(w.p) < 2 then coalesce(w.p[1], '')
    else w.p[1] || ' ' || upper(left(w.p[2], 1)) || '.'
  end
  from (select regexp_split_to_array(btrim(coalesce(p_nombre, '')), '\s+') as p) w
$$;

-- D-09: p_id es autor de citas/consultas/dosis en mi clínica (aunque ya no sea miembro).
-- Redefinición de la versión 4.1 con el OR de dosis_aplicadas.
create or replace function public.es_autor_en_mi_clinica(p_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select
  exists (
    select 1 from public.citas c
    where c.clinica_id = public.mi_clinica_id() and c.veterinario_id = p_id
  )
  or exists (
    select 1 from public.consultas co
    join public.mascotas m on m.id = co.mascota_id
    where co.veterinario_id = p_id and m.clinica_id = public.mi_clinica_id()
  )
  or exists (
    select 1 from public.dosis_aplicadas d where d.clinica_id = public.mi_clinica_id() and d.veterinario_id = p_id
  )
$$;

revoke all on function public.es_autor_en_mi_clinica(uuid) from public, anon;
grant execute on function public.es_autor_en_mi_clinica(uuid) to authenticated;

-- 7. Derivación (ÚNICA fuente del cálculo, D-02, VAC-02): app, alertas y carné público
-- llaman aquí; p_hoy es parámetro para pruebas deterministas.
-- Posición de cada dosis válida dentro de su serie. Serie = suma corrida de inicia_serie por
-- (mascota, codigo). Protocolo efectivo: fila de la clínica con ese codigo, si no la global
-- (se ignora `activo` para que un protocolo desactivado siga calculando dosis ya puestas).
create or replace function public._dosis_posiciones(p_clinica uuid, p_mascota uuid)
returns table (
  dosis_id uuid, mascota_id uuid, codigo_protocolo text, fecha_aplicacion date,
  posicion int, dosis_serie int, etiqueta_dosis text, es_ultima boolean
)
language sql stable security definer set search_path = public
as $$
  with v as (
    select d.id, d.mascota_id, d.codigo_protocolo, d.fecha_aplicacion, d.created_at,
           d.es_refuerzo, d.inicia_serie, coalesce(pr.dosis_serie, 1) as dosis_serie
    from public.dosis_aplicadas d
    left join lateral (
      select pv.dosis_serie
      from public.protocolos_vacunacion pv
      where pv.codigo = d.codigo_protocolo
        and (pv.clinica_id = p_clinica or pv.clinica_id is null)
      order by (pv.clinica_id is null)
      limit 1
    ) pr on true
    where d.clinica_id = p_clinica
      and not d.anulada
      and (p_mascota is null or d.mascota_id = p_mascota)
  ),
  s as (
    select v.*,
           sum(case when v.inicia_serie then 1 else 0 end) over (
             partition by v.mascota_id, v.codigo_protocolo
             order by v.fecha_aplicacion, v.created_at, v.id
           ) as serie_idx
    from v
  ),
  n as (
    select s.*,
           row_number() over (
             partition by s.mascota_id, s.codigo_protocolo, s.serie_idx
             order by s.fecha_aplicacion, s.created_at, s.id
           )::int as nn
    from s
  )
  select
    n.id,
    n.mascota_id,
    n.codigo_protocolo,
    n.fecha_aplicacion,
    (case when n.es_refuerzo or n.nn > n.dosis_serie then n.dosis_serie else n.nn end)::int,
    n.dosis_serie,
    case
      when n.dosis_serie > 1 and not n.es_refuerzo and n.nn <= n.dosis_serie
        then 'Dosis ' || n.nn || ' de ' || n.dosis_serie
      when n.dosis_serie = 1 and n.nn = 1 and not n.es_refuerzo then 'Primera dosis'
      else 'Refuerzo'
    end,
    (row_number() over (
       partition by n.mascota_id, n.codigo_protocolo
       order by n.fecha_aplicacion desc, n.created_at desc, n.id desc
     ) = 1)
  from n
$$;

-- Una fila por (mascota, codigo) con >= 1 dosis válida (D-21: sin filas "nunca vacunada").
-- IMPORTANTE: los CASE de intervalo/ventana/estado se copian en previsualizar_dosis; si se
-- cambia uno hay que cambiar el otro.
create or replace function public._carne_filas(p_clinica uuid, p_mascota uuid, p_hoy date)
returns table (
  mascota_id uuid, codigo_protocolo text, biologico_nombre text, tipo text,
  ultima_dosis_id uuid, ultima_fecha date, posicion int, dosis_serie int,
  proxima_fecha date, etiqueta_proxima text, estado text, dias_vencida int,
  ventana_dias int, sugerir_reiniciar boolean
)
language sql stable security definer set search_path = public
as $$
  with u as (
    select po.dosis_id, po.mascota_id, po.codigo_protocolo, po.fecha_aplicacion,
           po.posicion, po.dosis_serie,
           d.biologico_nombre, d.tipo, d.sin_refuerzo, d.duracion_elegida_dias,
           m.fecha_nacimiento, pr.intervalo_serie_dias, pr.intervalo_refuerzo_dias,
           pr.intervalos_por_edad
    from public._dosis_posiciones(p_clinica, p_mascota) po
    join public.dosis_aplicadas d on d.id = po.dosis_id
    join public.mascotas m on m.id = d.mascota_id
    left join lateral (
      select pv.intervalo_serie_dias, pv.intervalo_refuerzo_dias, pv.intervalos_por_edad
      from public.protocolos_vacunacion pv
      where pv.codigo = d.codigo_protocolo
        and (pv.clinica_id = p_clinica or pv.clinica_id is null)
      order by (pv.clinica_id is null)
      limit 1
    ) pr on true
    where po.es_ultima
  ),
  iv as (
    select u.*,
      case
        when u.posicion < u.dosis_serie then u.intervalo_serie_dias
        when u.sin_refuerzo then null
        else coalesce(
          u.duracion_elegida_dias,
          (select (t.b ->> 'intervalo')::int
             from jsonb_array_elements(u.intervalos_por_edad) with ordinality as t(b, ord)
            where case
                    when u.fecha_nacimiento is null
                      then t.ord = jsonb_array_length(u.intervalos_por_edad)
                    else (t.b ->> 'hasta_dias') is null
                         or (u.fecha_aplicacion - u.fecha_nacimiento) <= (t.b ->> 'hasta_dias')::int
                  end
            order by t.ord
            limit 1),
          u.intervalo_refuerzo_dias
        )
      end as intervalo
    from u
  ),
  c as (
    select iv.*,
      case when iv.intervalo is null then null else iv.fecha_aplicacion + iv.intervalo end as prox,
      case
        when iv.tipo like 'desparasitacion%' then 5
        when iv.posicion < iv.dosis_serie then 3
        else 14
      end as ventana
    from iv
  )
  select
    c.mascota_id,
    c.codigo_protocolo,
    c.biologico_nombre,
    c.tipo,
    c.dosis_id,
    c.fecha_aplicacion,
    c.posicion,
    c.dosis_serie,
    c.prox,
    case
      when c.posicion < c.dosis_serie then 'Dosis ' || (c.posicion + 1) || ' de ' || c.dosis_serie
      else 'Refuerzo'
    end,
    case
      when c.prox is null then 'completo'
      when p_hoy > c.prox then 'vencida'
      when p_hoy >= c.prox - c.ventana then 'proxima'
      else 'al_dia'
    end,
    case when c.prox is null then 0 else greatest(p_hoy - c.prox, 0) end,
    c.ventana,
    (c.posicion < c.dosis_serie and p_hoy - c.fecha_aplicacion > 42)
  from c
$$;

revoke all on function public._dosis_posiciones(uuid, uuid) from public, anon, authenticated;
grant execute on function public._dosis_posiciones(uuid, uuid) to service_role;
revoke all on function public._carne_filas(uuid, uuid, date) from public, anon, authenticated;
grant execute on function public._carne_filas(uuid, uuid, date) to service_role;

-- 8. RPCs del catálogo (D-01, D-24). Escrituras solo por aquí; el admin de clínica
-- (un veterinario independiente siempre lo es desde 4.1 D-04) es el único que escribe.
drop function if exists public.protocolos_efectivos(text, boolean);
create or replace function public.protocolos_efectivos(
  p_especie text default null,
  p_incluir_inactivos boolean default false
)
returns table (
  codigo text, nombre text, tipo text, especies text[], edad_min_dias int,
  dosis_serie int, intervalo_serie_dias int, intervalo_refuerzo_dias int,
  opciones_duracion_dias int[], personalizado boolean, es_semilla boolean, activo boolean
)
language plpgsql stable security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
begin
  if not public.es_veterinario() then
    raise exception 'Solo un veterinario puede ver el catálogo de protocolos.' using errcode = 'insufficient_privilege';
  end if;

  return query
  select e.codigo, e.nombre, e.tipo, e.especies, e.edad_min_dias, e.dosis_serie,
         e.intervalo_serie_dias, e.intervalo_refuerzo_dias, e.opciones_duracion_dias,
         e.pers, e.sem, e.activo
  from (
    select distinct on (pv.codigo)
           pv.codigo, pv.nombre, pv.tipo, pv.especies, pv.edad_min_dias, pv.dosis_serie,
           pv.intervalo_serie_dias, pv.intervalo_refuerzo_dias, pv.opciones_duracion_dias,
           pv.activo,
           (pv.clinica_id is not null) as pers,
           exists (
             select 1 from public.protocolos_vacunacion g
             where g.clinica_id is null and g.codigo = pv.codigo
           ) as sem
    from public.protocolos_vacunacion pv
    where pv.clinica_id = v_clinica or pv.clinica_id is null
    order by pv.codigo, (pv.clinica_id is null)
  ) e
  where (p_incluir_inactivos or e.activo)
    and (p_especie is null or p_especie = any (e.especies))
  order by e.tipo, e.nombre;
end;
$$;

drop function if exists public.guardar_protocolo(text, text, text, text[], int, int, int, int[]);
create or replace function public.guardar_protocolo(
  p_codigo text,
  p_nombre text,
  p_tipo text,
  p_especies text[],
  p_dosis_serie int,
  p_intervalo_serie_dias int,
  p_intervalo_refuerzo_dias int,
  p_opciones_duracion_dias int[]
)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_nombre text := trim(coalesce(p_nombre, ''));
  v_codigo text;
  v_slug text;
  v_seed public.protocolos_vacunacion;
  v_opciones int[] := coalesce(p_opciones_duracion_dias, '{}');
begin
  if not public.es_veterinario() or not public.es_admin_clinica() then
    raise exception 'Solo el administrador de la clínica puede modificar el catálogo de protocolos.' using errcode = 'insufficient_privilege';
  end if;

  if char_length(v_nombre) not between 1 and 80 then
    raise exception 'El nombre debe tener entre 1 y 80 caracteres.' using errcode = 'check_violation';
  end if;
  if p_tipo is null or p_tipo not in ('vacuna', 'desparasitacion_interna', 'desparasitacion_externa') then
    raise exception 'Tipo de protocolo inválido.' using errcode = 'check_violation';
  end if;
  if p_especies is null or cardinality(p_especies) = 0
     or not (p_especies <@ array['perro', 'gato', 'otro']) then
    raise exception 'Especies inválidas.' using errcode = 'check_violation';
  end if;
  if p_dosis_serie is null or p_dosis_serie not between 1 and 6 then
    raise exception 'La serie debe tener entre 1 y 6 dosis.' using errcode = 'check_violation';
  end if;
  if p_intervalo_serie_dias is not null and p_intervalo_serie_dias <= 0 then
    raise exception 'El intervalo de la serie debe ser positivo.' using errcode = 'check_violation';
  end if;
  if p_dosis_serie > 1 and p_intervalo_serie_dias is null then
    raise exception 'Una serie de varias dosis requiere intervalo entre dosis.' using errcode = 'check_violation';
  end if;
  if p_intervalo_refuerzo_dias is not null and p_intervalo_refuerzo_dias <= 0 then
    raise exception 'El intervalo de refuerzo debe ser positivo.' using errcode = 'check_violation';
  end if;
  if exists (select 1 from unnest(v_opciones) o where o is null or o <= 0) then
    raise exception 'Las opciones de duración deben ser positivas.' using errcode = 'check_violation';
  end if;

  if p_codigo is null then
    v_slug := trim(both '-' from regexp_replace(lower(v_nombre), '[^a-z0-9]+', '-', 'g'));
    if v_slug = '' then
      raise exception 'El nombre debe tener letras o números.' using errcode = 'check_violation';
    end if;
    v_codigo := 'custom:' || left(v_slug, 50);
    if exists (
      select 1 from public.protocolos_vacunacion
      where clinica_id = v_clinica and codigo = v_codigo
    ) then
      raise exception 'Ya existe un protocolo con ese nombre.' using errcode = 'check_violation';
    end if;
    insert into public.protocolos_vacunacion
      (clinica_id, codigo, nombre, tipo, especies, dosis_serie, intervalo_serie_dias,
       intervalo_refuerzo_dias, opciones_duracion_dias)
    values
      (v_clinica, v_codigo, v_nombre, p_tipo, p_especies, p_dosis_serie, p_intervalo_serie_dias,
       p_intervalo_refuerzo_dias, v_opciones);
    return v_codigo;
  end if;

  select * into v_seed from public.protocolos_vacunacion
  where clinica_id is null and codigo = p_codigo;

  if found then
    -- Override de una semilla: copia edad_min_dias e intervalos_por_edad de la semilla.
    insert into public.protocolos_vacunacion
      (clinica_id, codigo, nombre, tipo, especies, edad_min_dias, dosis_serie,
       intervalo_serie_dias, intervalo_refuerzo_dias, opciones_duracion_dias, intervalos_por_edad)
    values
      (v_clinica, p_codigo, v_nombre, p_tipo, p_especies, v_seed.edad_min_dias, p_dosis_serie,
       p_intervalo_serie_dias, p_intervalo_refuerzo_dias, v_opciones, v_seed.intervalos_por_edad)
    on conflict ((coalesce(clinica_id, '00000000-0000-0000-0000-000000000000'::uuid)), codigo)
    do update set
      nombre = excluded.nombre,
      tipo = excluded.tipo,
      especies = excluded.especies,
      dosis_serie = excluded.dosis_serie,
      intervalo_serie_dias = excluded.intervalo_serie_dias,
      intervalo_refuerzo_dias = excluded.intervalo_refuerzo_dias,
      opciones_duracion_dias = excluded.opciones_duracion_dias;
    return p_codigo;
  end if;

  update public.protocolos_vacunacion
  set nombre = v_nombre, tipo = p_tipo, especies = p_especies, dosis_serie = p_dosis_serie,
      intervalo_serie_dias = p_intervalo_serie_dias,
      intervalo_refuerzo_dias = p_intervalo_refuerzo_dias,
      opciones_duracion_dias = v_opciones
  where clinica_id = v_clinica and codigo = p_codigo;

  if not found then
    raise exception 'Protocolo no encontrado.' using errcode = 'no_data_found';
  end if;
  return p_codigo;
end;
$$;

drop function if exists public.restablecer_protocolo(text);
create or replace function public.restablecer_protocolo(p_codigo text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
begin
  if not public.es_veterinario() or not public.es_admin_clinica() then
    raise exception 'Solo el administrador de la clínica puede restablecer protocolos.' using errcode = 'insufficient_privilege';
  end if;
  if not exists (
    select 1 from public.protocolos_vacunacion where clinica_id is null and codigo = p_codigo
  ) then
    raise exception 'Solo se pueden restablecer protocolos predefinidos.' using errcode = 'check_violation';
  end if;
  delete from public.protocolos_vacunacion where clinica_id = v_clinica and codigo = p_codigo;
end;
$$;

drop function if exists public.desactivar_protocolo(text);
create or replace function public.desactivar_protocolo(p_codigo text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
begin
  if not public.es_veterinario() or not public.es_admin_clinica() then
    raise exception 'Solo el administrador de la clínica puede desactivar protocolos.' using errcode = 'insufficient_privilege';
  end if;
  if exists (
    select 1 from public.protocolos_vacunacion where clinica_id is null and codigo = p_codigo
  ) then
    raise exception 'Los protocolos predefinidos no se desactivan.' using errcode = 'check_violation';
  end if;
  update public.protocolos_vacunacion set activo = false
  where clinica_id = v_clinica and codigo = p_codigo;
  if not found then
    raise exception 'Solo se pueden desactivar protocolos propios de la clínica.' using errcode = 'check_violation';
  end if;
end;
$$;

-- 9. Registro y anulación de dosis (D-03..D-09, D-22, D-24). Solo-append: la corrección es
-- anular_dosis con motivo obligatorio, una sola vez.
drop function if exists public.registrar_dosis(
  uuid, text, text, date, int, boolean, boolean, boolean, boolean, text, text, text, text, uuid, boolean
);
create or replace function public.registrar_dosis(
  p_mascota_id uuid,
  p_codigo_protocolo text,
  p_biologico_nombre text,
  p_fecha_aplicacion date,
  p_duracion_elegida_dias int default null,
  p_sin_refuerzo boolean default false,
  p_es_refuerzo boolean default false,
  p_inicia_serie boolean default false,
  p_externa boolean default false,
  p_clinica_externa text default null,
  p_producto text default null,
  p_lote text default null,
  p_observaciones text default null,
  p_cita_id uuid default null,
  p_guardar_en_catalogo boolean default false
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_hoy date := public._hoy_bogota();
  v_mascota public.mascotas;
  v_proto public.protocolos_vacunacion;
  v_codigo text := trim(coalesce(p_codigo_protocolo, ''));
  v_nombre text;
  v_tipo text;
  v_opciones int[];
  v_slug text;
  v_id uuid;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede registrar dosis.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_mascota from public.mascotas
  where id = p_mascota_id and clinica_id = v_clinica;
  if not found then
    raise exception 'La mascota no pertenece a tu clínica.' using errcode = 'insufficient_privilege';
  end if;

  if p_fecha_aplicacion is null or p_fecha_aplicacion > v_hoy then
    raise exception 'La fecha de aplicación no puede ser futura.' using errcode = 'check_violation';
  end if;
  if v_mascota.fecha_nacimiento is not null and p_fecha_aplicacion < v_mascota.fecha_nacimiento then
    raise exception 'La fecha de aplicación es anterior al nacimiento de la mascota.' using errcode = 'check_violation';
  end if;

  if v_codigo = '' or char_length(v_codigo) > 64 then
    raise exception 'Código de protocolo inválido.' using errcode = 'check_violation';
  end if;

  if v_codigo like 'otro:%' then
    v_nombre := nullif(trim(coalesce(p_biologico_nombre, '')), '');
    if v_nombre is null or char_length(v_nombre) > 80 then
      raise exception 'El nombre del biológico es obligatorio (máx. 80 caracteres).' using errcode = 'check_violation';
    end if;
    v_tipo := 'vacuna';
    v_opciones := array[21, 30, 90, 180, 365];
  else
    select * into v_proto from public.protocolos_vacunacion pv
    where pv.codigo = v_codigo
      and (pv.clinica_id = v_clinica or pv.clinica_id is null)
      and pv.activo
    order by (pv.clinica_id is null)
    limit 1;
    if not found then
      raise exception 'El protocolo no existe en el catálogo.' using errcode = 'foreign_key_violation';
    end if;
    v_nombre := v_proto.nombre;
    v_tipo := v_proto.tipo;
    v_opciones := v_proto.opciones_duracion_dias;
  end if;

  if p_duracion_elegida_dias is not null and not (p_duracion_elegida_dias = any (v_opciones)) then
    raise exception 'Duración no permitida para este protocolo.' using errcode = 'check_violation';
  end if;

  -- D-04/D-24: guardar un "Otro" como protocolo propio exige ser admin de la clínica.
  if p_guardar_en_catalogo and v_codigo like 'otro:%' then
    if not public.es_admin_clinica() then
      raise exception 'Solo el administrador de la clínica puede guardar protocolos en el catálogo.' using errcode = 'insufficient_privilege';
    end if;
    v_slug := trim(both '-' from regexp_replace(lower(v_nombre), '[^a-z0-9]+', '-', 'g'));
    if v_slug = '' then
      raise exception 'El nombre debe tener letras o números.' using errcode = 'check_violation';
    end if;
    v_codigo := 'custom:' || left(v_slug, 50);
    insert into public.protocolos_vacunacion
      (clinica_id, codigo, nombre, tipo, especies, dosis_serie, intervalo_refuerzo_dias)
    values
      (v_clinica, v_codigo, v_nombre, 'vacuna', array[v_mascota.especie], 1,
       case when p_sin_refuerzo then null else p_duracion_elegida_dias end)
    on conflict do nothing;
  end if;

  -- D-22: la cita debe ser de la clínica y cubrir a esta mascota.
  if p_cita_id is not null and not exists (
    select 1
    from public.citas c
    join public.cita_mascotas cm on cm.cita_id = c.id and cm.clinica_id = c.clinica_id
    where c.id = p_cita_id and c.clinica_id = v_clinica and cm.mascota_id = p_mascota_id
  ) then
    raise exception 'La cita no corresponde a esta mascota.' using errcode = 'foreign_key_violation';
  end if;

  insert into public.dosis_aplicadas (
    mascota_id, clinica_id, veterinario_id, cita_id, codigo_protocolo, biologico_nombre, tipo,
    fecha_aplicacion, duracion_elegida_dias, sin_refuerzo, es_refuerzo, inicia_serie, externa,
    clinica_externa, producto, lote, observaciones
  ) values (
    p_mascota_id, v_clinica, auth.uid(), p_cita_id, v_codigo, v_nombre, v_tipo,
    p_fecha_aplicacion, p_duracion_elegida_dias, coalesce(p_sin_refuerzo, false),
    coalesce(p_es_refuerzo, false), coalesce(p_inicia_serie, false), coalesce(p_externa, false),
    nullif(trim(coalesce(p_clinica_externa, '')), ''), nullif(trim(coalesce(p_producto, '')), ''),
    nullif(trim(coalesce(p_lote, '')), ''), nullif(trim(coalesce(p_observaciones, '')), '')
  )
  returning id into v_id;

  -- No se toca vacuna_alertas: la nueva última dosis no tiene fila de gestión, así que un
  -- descartar/posponer previo deja de aplicar solo.
  return v_id;
end;
$$;

drop function if exists public.anular_dosis(uuid, text);
create or replace function public.anular_dosis(p_dosis_id uuid, p_motivo text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_dosis public.dosis_aplicadas;
  v_motivo text := nullif(trim(coalesce(p_motivo, '')), '');
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede anular dosis.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_dosis from public.dosis_aplicadas
  where id = p_dosis_id and clinica_id = v_clinica
  for update;
  if not found then
    raise exception 'La dosis no pertenece a tu clínica.' using errcode = 'insufficient_privilege';
  end if;

  if v_motivo is null or char_length(v_motivo) > 120 then
    raise exception 'El motivo es obligatorio (máx. 120 caracteres).' using errcode = 'check_violation';
  end if;
  if v_dosis.anulada then
    raise exception 'La dosis ya fue anulada.' using errcode = 'check_violation';
  end if;

  update public.dosis_aplicadas
  set anulada = true, motivo_anulacion = v_motivo, anulada_at = now(), anulada_por = auth.uid()
  where id = p_dosis_id;
end;
$$;

-- 10. Previsualización (sin insertar): mismos CASE que _carne_filas -- si se cambia uno hay
-- que cambiar el otro. La dosis hipotética se ubica por fecha como lo haría el insert real.
drop function if exists public.previsualizar_dosis(uuid, text, date, int, boolean, boolean, boolean);
create or replace function public.previsualizar_dosis(
  p_mascota_id uuid,
  p_codigo_protocolo text,
  p_fecha_aplicacion date,
  p_duracion_elegida_dias int default null,
  p_sin_refuerzo boolean default false,
  p_es_refuerzo boolean default false,
  p_inicia_serie boolean default false
)
returns table (
  posicion int, dosis_serie int, etiqueta_dosis text, proxima_fecha date,
  etiqueta_proxima text, sugerir_reiniciar boolean
)
language plpgsql stable security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
  v_mascota public.mascotas;
  v_proto public.protocolos_vacunacion;
  v_serie int := 1;
  v_n int;
  v_pos int;
  v_intervalo int;
  v_prox date;
  v_reiniciar boolean := false;
  v_prev record;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede previsualizar dosis.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_mascota from public.mascotas
  where id = p_mascota_id and clinica_id = v_clinica;
  if not found then
    raise exception 'La mascota no pertenece a tu clínica.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_proto from public.protocolos_vacunacion pv
  where pv.codigo = p_codigo_protocolo and (pv.clinica_id = v_clinica or pv.clinica_id is null)
  order by (pv.clinica_id is null)
  limit 1;
  if found then
    v_serie := v_proto.dosis_serie;
  end if;

  -- n = lugar de la dosis hipotética dentro de su serie.
  select x.nn into v_n
  from (
    select s.hyp,
           row_number() over (
             partition by s.serie_idx order by s.fecha_aplicacion, s.created_at, s.hyp
           )::int as nn
    from (
      select d.fecha_aplicacion, d.created_at, d.hyp,
             sum(case when d.inicia_serie then 1 else 0 end) over (
               order by d.fecha_aplicacion, d.created_at, d.hyp
             ) as serie_idx
      from (
        select da.fecha_aplicacion, da.created_at, da.inicia_serie, false as hyp
        from public.dosis_aplicadas da
        where da.mascota_id = p_mascota_id and da.clinica_id = v_clinica
          and da.codigo_protocolo = p_codigo_protocolo and not da.anulada
        union all
        select p_fecha_aplicacion, now(), coalesce(p_inicia_serie, false), true
      ) d
    ) s
  ) x
  where x.hyp;

  v_pos := case when coalesce(p_es_refuerzo, false) or v_n > v_serie then v_serie else v_n end;

  v_intervalo := case
    when v_pos < v_serie then v_proto.intervalo_serie_dias
    when coalesce(p_sin_refuerzo, false) then null
    else coalesce(
      p_duracion_elegida_dias,
      (select (t.b ->> 'intervalo')::int
         from jsonb_array_elements(v_proto.intervalos_por_edad) with ordinality as t(b, ord)
        where case
                when v_mascota.fecha_nacimiento is null
                  then t.ord = jsonb_array_length(v_proto.intervalos_por_edad)
                else (t.b ->> 'hasta_dias') is null
                     or (p_fecha_aplicacion - v_mascota.fecha_nacimiento) <= (t.b ->> 'hasta_dias')::int
              end
        order by t.ord
        limit 1),
      v_proto.intervalo_refuerzo_dias
    )
  end;
  v_prox := case when v_intervalo is null then null else p_fecha_aplicacion + v_intervalo end;

  select po.posicion as pos, po.dosis_serie as serie, po.fecha_aplicacion as fecha into v_prev
  from public._dosis_posiciones(v_clinica, p_mascota_id) po
  where po.codigo_protocolo = p_codigo_protocolo and po.es_ultima;
  if found then
    v_reiniciar := v_prev.pos < v_prev.serie and p_fecha_aplicacion - v_prev.fecha > 42;
  end if;

  return query select
    v_pos,
    v_serie,
    case
      when v_serie > 1 and not coalesce(p_es_refuerzo, false) and v_n <= v_serie
        then 'Dosis ' || v_n || ' de ' || v_serie
      when v_serie = 1 and v_n = 1 and not coalesce(p_es_refuerzo, false) then 'Primera dosis'
      else 'Refuerzo'
    end,
    v_prox,
    case
      when v_pos < v_serie then 'Dosis ' || (v_pos + 1) || ' de ' || v_serie
      else 'Refuerzo'
    end,
    v_reiniciar;
end;
$$;

-- 11. Carné completo de una mascota (veterinario). Todo valor derivado sale de _carne_filas
-- / _dosis_posiciones.
drop function if exists public.carne_de_mascota(uuid);
create or replace function public.carne_de_mascota(p_mascota_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_hoy date := public._hoy_bogota();
  v_mascota public.mascotas;
  v_cliente public.clientes;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede ver el carné.' using errcode = 'insufficient_privilege';
  end if;

  select * into v_mascota from public.mascotas
  where id = p_mascota_id and clinica_id = v_clinica;
  if not found then
    raise exception 'La mascota no pertenece a tu clínica.' using errcode = 'insufficient_privilege';
  end if;
  select * into v_cliente from public.clientes where id = v_mascota.dueno_id;

  return jsonb_build_object(
    'hoy', v_hoy,
    'mascota', jsonb_build_object(
      'id', v_mascota.id, 'nombre', v_mascota.nombre, 'especie', v_mascota.especie,
      'raza', v_mascota.raza, 'fecha_nacimiento', v_mascota.fecha_nacimiento,
      'foto_path', v_mascota.foto_path
    ),
    'dueno', jsonb_build_object('nombre', v_cliente.nombre, 'telefono', v_cliente.telefono),
    'clinica', (
      select jsonb_build_object(
        'nombre', cl.nombre, 'ciudad', cl.ciudad, 'direccion', cl.direccion, 'telefono', cl.telefono
      )
      from public.clinicas cl where cl.id = v_clinica
    ),
    'biologicos', coalesce((
      select jsonb_agg(to_jsonb(f) - 'mascota_id' order by f.biologico_nombre)
      from public._carne_filas(v_clinica, p_mascota_id, v_hoy) f
    ), '[]'::jsonb),
    'dosis', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', d.id,
          'codigo_protocolo', d.codigo_protocolo,
          'biologico_nombre', d.biologico_nombre,
          'tipo', d.tipo,
          'fecha_aplicacion', d.fecha_aplicacion,
          'etiqueta_dosis', po.etiqueta_dosis,
          'es_ultima', coalesce(po.es_ultima, false),
          'producto', d.producto,
          'lote', d.lote,
          'observaciones', d.observaciones,
          'externa', d.externa,
          'clinica_externa', d.clinica_externa,
          'es_refuerzo', d.es_refuerzo,
          'cita_id', d.cita_id,
          'anulada', d.anulada,
          'motivo_anulacion', d.motivo_anulacion,
          'anulada_at', d.anulada_at,
          'veterinario', jsonb_build_object(
            'nombre', pf.nombre, 'matricula', pf.matricula, 'activo', pf.activo
          )
        )
        order by d.fecha_aplicacion desc, d.created_at desc
      )
      from public.dosis_aplicadas d
      left join public._dosis_posiciones(v_clinica, p_mascota_id) po on po.dosis_id = d.id
      left join public.perfiles pf on pf.id = d.veterinario_id
      where d.mascota_id = p_mascota_id and d.clinica_id = v_clinica
    ), '[]'::jsonb)
  );
end;
$$;

-- 12. Alertas de la clínica (D-10, D-13, D-14): clínica completa, sin filtrar por veterinario.
drop function if exists public.vacunas_pendientes();
create or replace function public.vacunas_pendientes()
returns table (
  mascota_id uuid, mascota_nombre text, mascota_especie text, mascota_foto_path text,
  cliente_id uuid, cliente_nombre text, cliente_telefono text, codigo_protocolo text,
  biologico_nombre text, tipo text, ultima_dosis_id uuid, posicion int, dosis_serie int,
  etiqueta_proxima text, proxima_fecha date, estado text, dias_vencida int,
  recordatorio_enviado_at timestamptz
)
language plpgsql stable security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
  v_hoy date := public._hoy_bogota();
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede ver las alertas de vacunación.' using errcode = 'insufficient_privilege';
  end if;

  return query
  select f.mascota_id, m.nombre, m.especie, m.foto_path, c.id, c.nombre, c.telefono,
         f.codigo_protocolo, f.biologico_nombre, f.tipo, f.ultima_dosis_id, f.posicion,
         f.dosis_serie, f.etiqueta_proxima, f.proxima_fecha, f.estado, f.dias_vencida,
         a.recordatorio_enviado_at
  from public._carne_filas(v_clinica, null, v_hoy) f
  join public.mascotas m on m.id = f.mascota_id
  join public.clientes c on c.id = m.dueno_id
  left join public.vacuna_alertas a on a.dosis_ref_id = f.ultima_dosis_id
  where f.estado in ('vencida', 'proxima')
    and f.dias_vencida <= 180
    and (
      a.dosis_ref_id is null
      or (a.descartada_at is null and (a.pospuesta_hasta is null or a.pospuesta_hasta <= v_hoy))
    )
  order by (f.estado <> 'vencida'), f.dias_vencida desc, f.proxima_fecha asc;
end;
$$;

drop function if exists public.vacunas_resumen();
create or replace function public.vacunas_resumen()
returns table (vencidas int, proximas int, ocultas_antiguas int)
language plpgsql stable security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
  v_hoy date := public._hoy_bogota();
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede ver el resumen de vacunación.' using errcode = 'insufficient_privilege';
  end if;

  return query
  select
    (count(*) filter (
       where f.estado = 'vencida' and f.dias_vencida <= 180
         and (a.dosis_ref_id is null
              or (a.descartada_at is null and (a.pospuesta_hasta is null or a.pospuesta_hasta <= v_hoy)))
     ))::int,
    (count(*) filter (
       where f.estado = 'proxima'
         and (a.dosis_ref_id is null
              or (a.descartada_at is null and (a.pospuesta_hasta is null or a.pospuesta_hasta <= v_hoy)))
     ))::int,
    (count(*) filter (
       where f.estado = 'vencida' and f.dias_vencida > 180 and a.descartada_at is null
     ))::int
  from public._carne_filas(v_clinica, null, v_hoy) f
  left join public.vacuna_alertas a on a.dosis_ref_id = f.ultima_dosis_id;
end;
$$;

-- Insignias por mascota: espejo del carné (ignora gestión de alertas y el corte de 180 días).
drop function if exists public.vacunas_resumen_mascotas();
create or replace function public.vacunas_resumen_mascotas()
returns table (mascota_id uuid, vencidas int, proximas int)
language plpgsql stable security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
  v_hoy date := public._hoy_bogota();
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede ver el resumen de vacunación.' using errcode = 'insufficient_privilege';
  end if;

  return query
  select f.mascota_id,
         (count(*) filter (where f.estado = 'vencida'))::int,
         (count(*) filter (where f.estado = 'proxima'))::int
  from public._carne_filas(v_clinica, null, v_hoy) f
  group by f.mascota_id
  having count(*) filter (where f.estado in ('vencida', 'proxima')) > 0;
end;
$$;

drop function if exists public.gestionar_alerta_vacuna(uuid, text, text, int);
create or replace function public.gestionar_alerta_vacuna(
  p_dosis_ref_id uuid,
  p_accion text,
  p_motivo text default null,
  p_dias int default null
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_dosis_clinica uuid;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede gestionar alertas.' using errcode = 'insufficient_privilege';
  end if;

  select clinica_id into v_dosis_clinica from public.dosis_aplicadas
  where id = p_dosis_ref_id and clinica_id = v_clinica;
  if not found then
    raise exception 'La dosis no pertenece a tu clínica.' using errcode = 'insufficient_privilege';
  end if;

  if p_accion is null or p_accion not in ('descartar', 'posponer', 'recordado', 'restaurar') then
    raise exception 'Acción de alerta inválida.' using errcode = 'check_violation';
  end if;

  if p_accion = 'descartar' then
    insert into public.vacuna_alertas (dosis_ref_id, clinica_id, descartada_at, motivo_descarte)
    values (p_dosis_ref_id, v_clinica, now(), nullif(trim(coalesce(p_motivo, '')), ''))
    on conflict (dosis_ref_id) do update
      set descartada_at = now(), motivo_descarte = excluded.motivo_descarte;
  elsif p_accion = 'posponer' then
    if p_dias is null or p_dias not in (7, 15, 30) then
      raise exception 'Posponer admite 7, 15 o 30 días.' using errcode = 'check_violation';
    end if;
    insert into public.vacuna_alertas (dosis_ref_id, clinica_id, pospuesta_hasta)
    values (p_dosis_ref_id, v_clinica, public._hoy_bogota() + p_dias)
    on conflict (dosis_ref_id) do update set pospuesta_hasta = excluded.pospuesta_hasta;
  elsif p_accion = 'recordado' then
    insert into public.vacuna_alertas (dosis_ref_id, clinica_id, recordatorio_enviado_at)
    values (p_dosis_ref_id, v_clinica, now())
    on conflict (dosis_ref_id) do update set recordatorio_enviado_at = excluded.recordatorio_enviado_at;
  else
    insert into public.vacuna_alertas (dosis_ref_id, clinica_id)
    values (p_dosis_ref_id, v_clinica)
    on conflict (dosis_ref_id) do update
      set descartada_at = null, motivo_descarte = null, pospuesta_hasta = null;
  end if;
end;
$$;

-- 13. Enlaces públicos del carné (D-16). Token de 64 hex con dos gen_random_uuid() (sin
-- pgcrypto); reintento ante unique_violation como generar_codigo_vinculacion.
drop function if exists public.obtener_o_crear_enlace_carne(uuid);
create or replace function public.obtener_o_crear_enlace_carne(p_mascota_id uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_token text;
  v_intento int := 0;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede compartir el carné.' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.mascotas where id = p_mascota_id and clinica_id = v_clinica) then
    raise exception 'La mascota no pertenece a tu clínica.' using errcode = 'insufficient_privilege';
  end if;

  select ce.token into v_token from public.carne_enlaces ce
  where ce.mascota_id = p_mascota_id and ce.clinica_id = v_clinica and ce.activo;
  if v_token is not null then
    return v_token;
  end if;

  loop
    v_intento := v_intento + 1;
    begin
      insert into public.carne_enlaces (mascota_id, clinica_id, token)
      values (p_mascota_id, v_clinica,
              replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
      on conflict (mascota_id) do update
        set token = excluded.token, activo = true, regenerado_at = now()
      returning token into v_token;
      exit;
    exception when unique_violation then
      if v_intento >= 5 then
        raise;
      end if;
    end;
  end loop;
  return v_token;
end;
$$;

drop function if exists public.regenerar_enlace_carne(uuid);
create or replace function public.regenerar_enlace_carne(p_mascota_id uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_token text;
  v_intento int := 0;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede compartir el carné.' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.mascotas where id = p_mascota_id and clinica_id = v_clinica) then
    raise exception 'La mascota no pertenece a tu clínica.' using errcode = 'insufficient_privilege';
  end if;

  loop
    v_intento := v_intento + 1;
    begin
      insert into public.carne_enlaces (mascota_id, clinica_id, token)
      values (p_mascota_id, v_clinica,
              replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
      on conflict (mascota_id) do update
        set token = excluded.token, activo = true, regenerado_at = now()
      returning token into v_token;
      exit;
    exception when unique_violation then
      if v_intento >= 5 then
        raise;
      end if;
    end;
  end loop;
  return v_token;
end;
$$;

-- 14. Carné público (VAC-04). Solo la Edge Function `carne` (service_role) la ejecuta; anon
-- nunca (D-25). Token malformado/desconocido/inactivo => null indistinguible. Salida limitada
-- a D-15/D-20/D-23: sin ids, sin contacto del dueño, sin anuladas ni notas internas.
drop function if exists public.carne_publico(text);
create or replace function public.carne_publico(p_token text)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_hoy date := public._hoy_bogota();
  v_enlace public.carne_enlaces;
  v_mascota public.mascotas;
  v_cliente public.clientes;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return null;
  end if;

  select * into v_enlace from public.carne_enlaces where token = p_token and activo;
  if not found then
    return null;
  end if;

  select * into v_mascota from public.mascotas
  where id = v_enlace.mascota_id and clinica_id = v_enlace.clinica_id;
  if not found then
    return null;
  end if;
  select * into v_cliente from public.clientes where id = v_mascota.dueno_id;

  return jsonb_build_object(
    'hoy', v_hoy,
    'mascota', jsonb_build_object(
      'nombre', v_mascota.nombre, 'especie', v_mascota.especie, 'raza', v_mascota.raza,
      'fecha_nacimiento', v_mascota.fecha_nacimiento, 'foto_path', v_mascota.foto_path
    ),
    'propietario', public._nombre_corto(v_cliente.nombre),
    'clinica', (
      select jsonb_build_object(
        'nombre', cl.nombre, 'ciudad', cl.ciudad, 'direccion', cl.direccion, 'telefono', cl.telefono
      )
      from public.clinicas cl where cl.id = v_enlace.clinica_id
    ),
    'biologicos', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'biologico_nombre', f.biologico_nombre,
          'tipo', f.tipo,
          'ultima_fecha', f.ultima_fecha,
          'posicion', f.posicion,
          'dosis_serie', f.dosis_serie,
          'proxima_fecha', f.proxima_fecha,
          'etiqueta_proxima', f.etiqueta_proxima,
          'estado', f.estado
        )
        order by f.biologico_nombre
      )
      from public._carne_filas(v_enlace.clinica_id, v_enlace.mascota_id, v_hoy) f
    ), '[]'::jsonb),
    'dosis', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'biologico_nombre', d.biologico_nombre,
          'tipo', d.tipo,
          'fecha_aplicacion', d.fecha_aplicacion,
          'etiqueta_dosis', po.etiqueta_dosis,
          'es_ultima', po.es_ultima,
          'producto', d.producto,
          'lote', d.lote,
          'externa', d.externa,
          'clinica_externa', d.clinica_externa,
          'veterinario', case
            when d.externa then null
            else jsonb_build_object('nombre', pf.nombre, 'matricula', pf.matricula)
          end
        )
        order by d.fecha_aplicacion desc, d.created_at desc
      )
      from public.dosis_aplicadas d
      join public._dosis_posiciones(v_enlace.clinica_id, v_enlace.mascota_id) po on po.dosis_id = d.id
      left join public.perfiles pf on pf.id = d.veterinario_id
      where d.mascota_id = v_enlace.mascota_id
        and d.clinica_id = v_enlace.clinica_id
        and not d.anulada
    ), '[]'::jsonb)
  );
end;
$$;

-- 15. Grants.
revoke all on function public.protocolos_efectivos(text, boolean) from public, anon;
revoke all on function public.guardar_protocolo(text, text, text, text[], int, int, int, int[]) from public, anon;
revoke all on function public.restablecer_protocolo(text) from public, anon;
revoke all on function public.desactivar_protocolo(text) from public, anon;
revoke all on function public.registrar_dosis(
  uuid, text, text, date, int, boolean, boolean, boolean, boolean, text, text, text, text, uuid, boolean
) from public, anon;
revoke all on function public.anular_dosis(uuid, text) from public, anon;
revoke all on function public.previsualizar_dosis(uuid, text, date, int, boolean, boolean, boolean) from public, anon;
revoke all on function public.carne_de_mascota(uuid) from public, anon;
revoke all on function public.vacunas_pendientes() from public, anon;
revoke all on function public.vacunas_resumen() from public, anon;
revoke all on function public.vacunas_resumen_mascotas() from public, anon;
revoke all on function public.gestionar_alerta_vacuna(uuid, text, text, int) from public, anon;
revoke all on function public.obtener_o_crear_enlace_carne(uuid) from public, anon;
revoke all on function public.regenerar_enlace_carne(uuid) from public, anon;

grant execute on function public.protocolos_efectivos(text, boolean) to authenticated;
grant execute on function public.guardar_protocolo(text, text, text, text[], int, int, int, int[]) to authenticated;
grant execute on function public.restablecer_protocolo(text) to authenticated;
grant execute on function public.desactivar_protocolo(text) to authenticated;
grant execute on function public.registrar_dosis(
  uuid, text, text, date, int, boolean, boolean, boolean, boolean, text, text, text, text, uuid, boolean
) to authenticated;
grant execute on function public.anular_dosis(uuid, text) to authenticated;
grant execute on function public.previsualizar_dosis(uuid, text, date, int, boolean, boolean, boolean) to authenticated;
grant execute on function public.carne_de_mascota(uuid) to authenticated;
grant execute on function public.vacunas_pendientes() to authenticated;
grant execute on function public.vacunas_resumen() to authenticated;
grant execute on function public.vacunas_resumen_mascotas() to authenticated;
grant execute on function public.gestionar_alerta_vacuna(uuid, text, text, int) to authenticated;
grant execute on function public.obtener_o_crear_enlace_carne(uuid) to authenticated;
grant execute on function public.regenerar_enlace_carne(uuid) to authenticated;

-- Solo la Edge Function `carne` (service_role) la ejecuta; anon nunca (D-25, VAC-04).
revoke all on function public.carne_publico(text) from public, anon, authenticated;
grant execute on function public.carne_publico(text) to service_role;

-- Re-afirmar el helper de autoría (D-09) al cierre del bloque.
revoke all on function public.es_autor_en_mi_clinica(uuid) from public, anon;
grant execute on function public.es_autor_en_mi_clinica(uuid) to authenticated;

notify pgrst, 'reload schema';
