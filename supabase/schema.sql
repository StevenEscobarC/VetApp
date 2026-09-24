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

-- El vinculo permite aplicar aislamiento por clinica a las mascotas.
create table if not exists public.mascotas (
  id uuid primary key default gen_random_uuid(),
  dueno_id uuid not null references public.perfiles(id) on delete cascade,
  clinica_id uuid references public.clinicas(id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  especie text not null,
  raza text not null default '',
  fecha_nacimiento date,
  created_at timestamptz not null default now()
);

create index if not exists perfiles_clinica_id_idx on public.perfiles(clinica_id);
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
  foreach table_name in array array['clinicas', 'perfiles', 'mascotas'] loop
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

drop policy if exists perfiles_update on public.perfiles;
create policy perfiles_update on public.perfiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

-- El trigger crea perfiles. El cliente nunca puede crear otro perfil o cambiar rol.
drop policy if exists perfiles_insert on public.perfiles;
create policy perfiles_insert on public.perfiles for insert to authenticated
with check (id = auth.uid() and rol = 'CLIENTE' and clinica_id is null);

-- Mascotas: cliente solo las propias; veterinario solo las de su clínica.
drop policy if exists mascotas_select on public.mascotas;
create policy mascotas_select on public.mascotas for select to authenticated
using (dueno_id = auth.uid() or (public.es_veterinario() and clinica_id = public.mi_clinica_id()));

drop policy if exists mascotas_insert on public.mascotas;
create policy mascotas_insert on public.mascotas for insert to authenticated
with check (
  dueno_id = auth.uid()
  and (clinica_id is null or clinica_id = public.mi_clinica_id())
);

drop policy if exists mascotas_update on public.mascotas;
create policy mascotas_update on public.mascotas for update to authenticated
using (dueno_id = auth.uid())
with check (dueno_id = auth.uid());

drop policy if exists mascotas_delete on public.mascotas;
create policy mascotas_delete on public.mascotas for delete to authenticated
using (dueno_id = auth.uid());
