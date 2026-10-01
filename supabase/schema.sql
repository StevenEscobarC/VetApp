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

drop policy if exists consultas_insert on public.consultas;
create policy consultas_insert on public.consultas for insert to authenticated
with check (
  public.es_veterinario()
  and veterinario_id = auth.uid()
  and exists (
    select 1 from public.mascotas m
    where m.id = consultas.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
);

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

drop policy if exists citas_insert on public.citas;
create policy citas_insert on public.citas for insert to authenticated
with check (
  public.es_veterinario()
  and clinica_id = public.mi_clinica_id()
  and veterinario_id = auth.uid()
);

drop policy if exists citas_update on public.citas;
create policy citas_update on public.citas for update to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id())
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

-- Sin política delete en citas: cancelar es un cambio de estado, nunca un borrado.
-- (Solo se borran en cascada al borrar el cliente, D-20.)

drop policy if exists cita_mascotas_select on public.cita_mascotas;
create policy cita_mascotas_select on public.cita_mascotas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists cita_mascotas_insert on public.cita_mascotas;
create policy cita_mascotas_insert on public.cita_mascotas for insert to authenticated
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists cita_mascotas_delete on public.cita_mascotas;
create policy cita_mascotas_delete on public.cita_mascotas for delete to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

-- Sin política update en cita_mascotas ni ninguna política para CLIENTE
-- (la Fase 9 / DIR-05 agrega la suya).

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
