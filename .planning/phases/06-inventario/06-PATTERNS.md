# Phase 6: Inventario - Pattern Map

**Mapped:** 2026-10-31
**Files analyzed:** 41 (nuevos o modificados)
**Analogs found:** 38 / 41 (3 sin analogo directo, ver "No Analog Found")

Fuentes leidas: `06-CONTEXT.md` (D-01..D-16), `06-RESEARCH.md`, `06-UI-SPEC.md`, skill `arquitecto-vetapp`, y los analogos de Fase 5 (`vaccination`), Fase 5.1 (`plan`) y Fase 4/2 (`clients`, `patients`, `appointments`). Todas las rutas son relativas a `C:\Trabajo\VetApp`.

## Hallazgos que el planner debe asumir (verificados en el codigo)

1. **`parsearFecha` rechaza fechas futuras** (`lib/core/utils/formato.dart` lineas 49-53, "La fecha no puede ser futura"). El vencimiento del producto es casi siempre futuro: no se puede reutilizar tal cual. Hace falta una variante (p. ej. parametro `permitirFuturo: true` o `parsearFechaLibre`) con test en `test/formato_test.dart`.
2. **`AppTextField` no expone** `textInputAction`, `textAlign`, `prefixText`/`prefix`, `enabled`, `focusNode`, `onFieldSubmitted` ni seleccion al enfocar (`lib/core/widgets/inputs/app_text_field.dart` lineas 10-82). El UI-SPEC pide teclado "next/done", campo centrado en `AjusteSheet`, prefijo "$" y select-all. Contradice "no se toca `lib/core/widgets`": o se extiende `AppTextField` de forma retrocompatible (parametros opcionales) con una tarea explicita, o se recortan esos detalles. Decision del planner.
3. **No existe `formatearCop`/`parsearCop`/`formatearMiles`** (`formato.dart` solo tiene fecha, peso, edad). Tarea explicita + tests (RESEARCH Pitfall 8).
4. **`mover_stock` y demas RPC son `security definer`** (como `registrar_dosis`, schema.sql 2445-2569), NO `security invoker` como dice el skill/brief para `crear_cita`. Divergencia consciente (RESEARCH Pitfall 4); registrarla como decision del plan.
5. **Tests que montan Inicio/Mas/router** y deben recibir `inventarioRepositoryProvider.overrideWithValue(FakeInventarioRepository())`: `test/inicio_screen_test.dart`, `router_equipo_test.dart`, `router_vacunas_cross_shell_test.dart`, `plan_refresco_test.dart`, `mi_plan_screen_test.dart`, `datos_clinica_screen_test.dart`, `equipo_screen_test.dart`, `mi_perfil_screen_test.dart`, `protocolos_screen_test.dart` (grep de `InicioScreen|MasScreen|routerProvider|VetApp()` confirma exactamente estos 9). `supabaseClientProvider` llama `Supabase.instance.client`, que no esta inicializado en pruebas.
6. **R44 actual** (`rls_smoke_test.sql` lineas 4270-4302) exige `cardinality(r_arr) <> 7` con dos arrays literales; hay que pasarlo a 9 con `'movimientos_inventario','productos'`. Cabecera del smoke (linea 36) dice "Total esperado: 238".
7. **`es_autor_en_mi_clinica` vigente** es la version de `schema.sql` 2062-2077 (la de 1119-1131 queda pisada). Se redefine una tercera vez al final del bloque Fase 6.
8. **Hint de FK para el embed del autor**: Fase 5 nombra la FK explicitamente (`dosis_veterinario_perfil_fkey`, 1947-1952) y la sonda `probe_embed` la valida. Para movimientos, nombrar la FK (`movimientos_veterinario_perfil_fkey`) en un bloque `do $$ ... exception when duplicate_object` en vez de depender del nombre autogenerado `movimientos_inventario_veterinario_id_fkey`.

---

## File Classification

### Backend (SQL / scripts)

| Archivo nuevo/modificado | Rol | Data Flow | Analogo mas cercano | Calidad |
|---|---|---|---|---|
| `supabase/schema.sql` (bloque Fase 6: `productos`, `movimientos_inventario`) | migration/model | CRUD solo-append | `dosis_aplicadas` (1913-1959) + RLS/revokes (1995-2024) | exact |
| `supabase/schema.sql` RPC `mover_stock`, `crear_producto`, `actualizar_producto`, `archivar_producto` | service (RPC definer) | request-response, transaccional | `registrar_dosis` / `anular_dosis` (2445-2603) | exact |
| `supabase/schema.sql` RPC `inventario_resumen` | service (RPC stable) | request-response | `vacunas_resumen` (2844-2875) | exact |
| `supabase/schema.sql` guard en 2 tablas + redefinir `es_autor_en_mi_clinica` + grants | config/security | event-driven (trigger) | `guard_solo_lectura` (3745-3799), `es_autor_en_mi_clinica` (2062-2080), grants (3127-3168) | exact |
| `supabase/tests/rls_smoke_test.sql` (bloque S + edicion R44 + cabecera + vars `s_*`) | test | request-response | bloque Q (2036-2706) y R30/R44 (3854-3908, 4270-4302) | exact |
| `supabase/tests/verify_live_schema.sh` (tablas, RPC, sonda de embed) | test/script | request-response | lineas 73-82, 109, 251-276 | exact |

### Dart - dominio y datos

| Archivo | Rol | Data Flow | Analogo | Calidad |
|---|---|---|---|---|
| `lib/features/inventory/domain/entities/producto.dart` (reescribir) | model | transform | stub actual + `PendienteVacuna.desdeFila` (`carne.dart` 280-342) | role-match |
| `lib/features/inventory/domain/entities/movimiento_stock.dart` | model | transform | `Consulta` + `consultaDesdeFila` con autor embebido (`supabase_consulta_repository.dart` 136-157) | role-match |
| `lib/features/inventory/domain/entities/resumen_inventario.dart` (o dentro de `producto.dart`) | model | transform | `ResumenVacunas` (`carne.dart` 344-354) | exact |
| `lib/features/inventory/domain/inventario_failure.dart` | model/error | request-response | `lib/features/vaccination/domain/vacuna_failure.dart` | exact |
| `lib/features/inventory/domain/pedido_whatsapp.dart` | utility (dominio puro) | transform | `lib/features/vaccination/domain/whatsapp_vacunas.dart` | exact |
| `lib/features/inventory/domain/stock.dart` (constantes 30/10/2) | utility | - | `lib/features/vaccination/domain/duraciones.dart` | role-match |
| `lib/features/inventory/data/repositories/supabase_inventario_repository.dart` | service/repo | CRUD + RPC | `supabase_vacuna_repository.dart` | exact |
| `lib/core/utils/formato.dart` (+ `formatearCop`, `parsearCop`, `formatearMiles`, variante de fecha) | utility | transform | funciones existentes del mismo archivo | exact |

### Dart - providers, rutas

| Archivo | Rol | Data Flow | Analogo | Calidad |
|---|---|---|---|---|
| `.../presentation/providers/inventario_providers.dart` (repo, `productosProvider`, `resumenInventarioProvider`, `movimientosProvider.family`, `InventarioActions`, `invalidarInventario`) | provider | CRUD / request-response | `vacuna_providers.dart` + `alertas_providers.dart` + `invalidar_vacunas.dart` + `anular_dosis_providers.dart` | exact |
| `.../presentation/inventario_routes.dart` | route | request-response | `lib/features/vaccination/presentation/vacunacion_routes.dart` | exact |
| `lib/core/router/app_router.dart` (modificar: import + `...inventarioRoutes`) | route/config | request-response | linea 92 `...vacunacionRoutes` | exact |

### Dart - pantallas y widgets

| Archivo | Rol | Data Flow | Analogo | Calidad |
|---|---|---|---|---|
| `screens/inventario_screen.dart` | component (lista + busqueda + filtros + FAB) | CRUD lectura, filtro local | `vacunas_pendientes_screen.dart` (filtros/skeleton/error) + `clientes_list_screen.dart` (buscador, FAB, candado) | role-match (combinar) |
| `screens/producto_form_screen.dart` (crear/editar) | component | CRUD escritura | `mascota_form_screen.dart` (catch + `manejarLimitePlan`) + `consulta_form_screen.dart` ("Agregar mas detalles") | role-match |
| `screens/producto_detail_screen.dart` | component | CRUD lectura + acciones | `mascota_detail_screen.dart` (asegurarEscritura/candado) + `carne_screen.dart` | role-match |
| `widgets/ajuste_sheet.dart` | component (hoja modal) | request-response | `anular_dosis_sheet.dart` | exact |
| `widgets/producto_fila.dart`, `widgets/ajuste_rapido_botones.dart` | component | request-response | `pendiente_tile.dart` (fila con acciones y snackbar "Deshacer") + `ControlEscritura` | role-match |
| `widgets/insignia_stock.dart` | component (pill) | transform | `lib/core/widgets/status/dosis_estado_chip.dart` | exact (misma anatomia) |
| `widgets/stock_bajo_card.dart` | component | request-response | `vacunas_pendientes_card.dart` | role-match (difiere: se oculta con 0/carga/error) |
| `widgets/resumen_bajos_strip.dart` | component | transform | `PlanBanner` / contenedor `warningBg` | partial |
| `widgets/movimiento_tile.dart` | component | transform | `dosis_card.dart` | role-match |
| `lib/features/home/presentation/screens/inicio_screen.dart` (modificar) | component | request-response | linea 89 `VacunasPendientesCard` | exact |
| `lib/features/home/presentation/screens/mas_screen.dart` (modificar) | component | request-response | fila "Equipo" (69-94) | exact |

### Tests

| Archivo | Rol | Analogo | Calidad |
|---|---|---|---|
| `test/helpers/fake_inventario.dart` | test helper | `test/helpers/fake_vacunas.dart` | exact |
| `test/producto_test.dart`, `test/pedido_stock_test.dart`, `test/formato_test.dart` (extender) | unit | `test/vacuna_mapeo_test.dart`, `test/whatsapp_vacunas_test.dart`, `test/formato_test.dart` | exact |
| `test/supabase_inventario_repository_test.dart` | unit | `test/supabase_vacuna_repository_test.dart` | exact |
| `test/inventario_invalidacion_test.dart` | unit (providers) | `test/vacunas_invalidacion_test.dart` | exact |
| `test/inventario_screen_test.dart`, `test/producto_form_screen_test.dart`, `test/ajuste_rapido_test.dart`, `test/stock_bajo_card_test.dart` | widget | `test/vacunas_pendientes_screen_test.dart`, `test/registrar_dosis_screen_test.dart`, `test/inicio_screen_test.dart` | role-match |
| `test/router_inventario_cross_shell_test.dart` | widget/router | `test/router_vacunas_cross_shell_test.dart` | exact |
| `test/inicio_screen_test.dart` (extender) | widget | mismo archivo (test de tarjeta Vacunas) | exact |

---

## Pattern Assignments

### `supabase/schema.sql` - tablas `productos` y `movimientos_inventario` (migration, CRUD solo-append)

**Analog:** `supabase/schema.sql` bloque Fase 5, `dosis_aplicadas` (lineas 1913-1959), RLS/revokes (1995-2024).

**Ubicacion:** al final del archivo, DESPUES del bloque 5.1 (cierra en 4165-4173) y ANTES de `notify pgrst, 'reload schema';` (linea 4175). Las funciones `language sql` validan referencias al crearse: tablas primero, `es_autor_en_mi_clinica` al final del bloque.

**Tabla + FK compuesta + FK a perfiles con nombre** (schema.sql 1913-1952; replicar el estilo, con los CHECK de RESEARCH Pattern 1):
```sql
create table if not exists public.dosis_aplicadas (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null,
  clinica_id uuid not null,
  veterinario_id uuid not null references auth.users(id) on delete restrict,
  ...
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

create index if not exists dosis_aplicadas_clinica_idx
  on public.dosis_aplicadas (clinica_id);
```
Para Fase 6: `productos` con `unique (id, clinica_id)` (patron de integridad entre tenants), `movimientos_inventario` con FK compuesta `(producto_id, clinica_id) -> productos(id, clinica_id)` en bloque `do $$` y FK `veterinario_id -> perfiles(id)` nombrada `movimientos_veterinario_perfil_fkey`. Constraints con nombre (`productos_cantidad_no_negativa`). Triggers `updated_at` de `productos`:
```sql
-- schema.sql 1974-1976
drop trigger if exists vacuna_alertas_tocar_updated_at on public.vacuna_alertas;
create trigger vacuna_alertas_tocar_updated_at before update on public.vacuna_alertas
for each row execute procedure public.tocar_updated_at();
```

**RLS solo SELECT + revokes** (schema.sql 1995-2024):
```sql
alter table public.dosis_aplicadas enable row level security;

drop policy if exists dosis_aplicadas_select on public.dosis_aplicadas;
create policy dosis_aplicadas_select on public.dosis_aplicadas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

revoke all on table public.dosis_aplicadas from anon;
revoke insert, update, delete, truncate on table public.dosis_aplicadas from authenticated;
```
Aplicar identico a `productos` y `movimientos_inventario` (sin politicas ni grants de escritura).

---

### `supabase/schema.sql` - RPC `mover_stock`, `crear_producto`, `actualizar_producto`, `archivar_producto` (service, request-response transaccional)

**Analog:** `registrar_dosis` (2442-2569) y `anular_dosis` (2571-2603).

**Cabecera `drop function if exists` + `create or replace` definer + guardia de rol** (2442-2479):
```sql
drop function if exists public.registrar_dosis(
  uuid, text, text, date, int, boolean, boolean, boolean, boolean, text, text, text, text, uuid, boolean
);
create or replace function public.registrar_dosis( ... )
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_clinica uuid := public.mi_clinica_id();
  v_hoy date := public._hoy_bogota();
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede registrar dosis.' using errcode = 'insufficient_privilege';
  end if;
```
**Bloqueo de fila + chequeo de pertenencia a la clinica** (anular_dosis 2585-2590) - copiar para `mover_stock` (`for update`, respuesta uniforme `IN002` para "no existe" y "de otra clinica"):
```sql
  select * into v_dosis from public.dosis_aplicadas
  where id = p_dosis_id and clinica_id = v_clinica
  for update;
  if not found then
    raise exception 'La dosis no pertenece a tu clínica.' using errcode = 'insufficient_privilege';
  end if;
```
**Solo admin dentro de la RPC** (registrar_dosis 2524-2528) - copiar para `archivar_producto` y para cambios de `minimo`/precios en `actualizar_producto`:
```sql
    if not public.es_admin_clinica() then
      raise exception 'Solo el administrador de la clínica puede guardar protocolos en el catálogo.' using errcode = 'insufficient_privilege';
    end if;
```
**Autoria**: `auth.uid()` en el INSERT, nunca parametro (registrar_dosis 2557). Codigos propios `IN001`/`IN002` siguen el estilo `LP00x`. Cuerpo de `mover_stock` prescrito en RESEARCH Pattern 2 (usa `#variable_conflict use_column`, OUT `cantidad_nueva`).

**Grants** (schema.sql 3127-3160; replicar por funcion con la firma exacta):
```sql
revoke all on function public.anular_dosis(uuid, text) from public, anon;
grant execute on function public.anular_dosis(uuid, text) to authenticated;
```
`mover_stock` NO debe aceptar `origen <> 'ajuste'` desde el cliente en Fase 6 (RESEARCH, tabla de amenazas).

---

### `supabase/schema.sql` - RPC `inventario_resumen` (service, request-response, stable)

**Analog:** `vacunas_resumen` (schema.sql 2843-2875).
```sql
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
    (count(*) filter (where ...))::int,
    ...
  from ...;
end;
$$;
```
Reemplazar el `from` por `public.productos where clinica_id = v_clinica and archivado_at is null`; `bajos = count(*) filter (where cantidad < minimo)` (D-07, estrictamente menor), `por_vencer` y `vencidos` con `v_hoy`. Siempre `::int` en los `count`.

---

### `supabase/schema.sql` - guard de solo lectura y `es_autor_en_mi_clinica`

**Analog guard:** schema.sql 3798-3799 (ultimo trigger del bloque 5.1):
```sql
drop trigger if exists guard_solo_lectura on public.dosis_aplicadas;
create trigger guard_solo_lectura before insert or update or delete on public.dosis_aplicadas for each row execute function public.guard_solo_lectura();
```
Agregar el mismo par para `public.productos` y `public.movimientos_inventario`. Actualizar los comentarios "Guarda en las 7 tablas" (linea 3739, 3738-3744) a 9. El trigger corre igual bajo RPC definer (`auth.uid()` viene del JWT; comentario 3741-3743), asi que el primer write de `mover_stock` dispara `LP004`. NO tocar `mi_plan()` (R2 exige 21 claves) ni agregar limites (D-15).

**Analog autoria:** schema.sql 2060-2080 (redefinicion actual; agregar un cuarto `or exists`):
```sql
create or replace function public.es_autor_en_mi_clinica(p_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select
  exists (select 1 from public.citas c where c.clinica_id = public.mi_clinica_id() and c.veterinario_id = p_id)
  or exists (select 1 from public.consultas co join public.mascotas m on m.id = co.mascota_id
             where co.veterinario_id = p_id and m.clinica_id = public.mi_clinica_id())
  or exists (select 1 from public.dosis_aplicadas d where d.clinica_id = public.mi_clinica_id() and d.veterinario_id = p_id)
  -- NUEVO:
  or exists (select 1 from public.movimientos_inventario m where m.clinica_id = public.mi_clinica_id() and m.veterinario_id = p_id)
$$;

revoke all on function public.es_autor_en_mi_clinica(uuid) from public, anon;
grant execute on function public.es_autor_en_mi_clinica(uuid) to authenticated;
```
Actualizar tambien los comentarios "ver redefinicion al final del archivo" (linea 1118 y ~2060).

---

### `supabase/tests/rls_smoke_test.sql` - bloque S + edicion R44 (test)

**Analog:** bloque Q (setup 2036-2075; checks Q2-Q7 y Q34) y R30/R44.

**Reglas mecanicas** (todo el script es un unico `do $$`):
- Declarar variables `s_*` en el `declare` global (junto a `r_*`, lineas 112-149). Ejemplo de estilo: `q_hoy date := date '2026-06-01'; q_vet_noadmin uuid := gen_random_uuid();`.
- Cabecera: linea 36 termina con "Total esperado: 238."; agregar una linea "Fase 6 (bloque S, N checks) ..." y el total `238+N`. Verificar con `grep -c "checks := checks + 1" supabase/tests/rls_smoke_test.sql` (hoy 238).
- Insertar el bloque S despues de R45 y antes del cierre "Volver a postgres y reportar" (linea ~4322).

**Setup con usuarios y rol** (Q 2043-2075):
```sql
  begin
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (q_vet_noadmin, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'smoke-q-noadmin@vetapp.invalid',
       jsonb_build_object('rol', 'VETERINARIO', 'nombre', 'Smoke Q NoAdmin', 'clinica_nombre', 'Smoke Clinica Q1'),
       now(), now());
    update public.perfiles set clinica_id = clinica_a_id, rol_clinica = 'veterinario', activo = true
      where id in (q_vet_noadmin, q_vet_x);
    perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    ...
  exception when others then
    failures := failures || ('SETUPQ error inesperado: ' || sqlerrm);
  end;
```
**Check feliz + lectura como postgres** (Q2, 2092-2108): `checks := checks + 1; begin ... perform set_config('role','postgres',true) ... failures := failures || format(...) ... exception when others then failures := failures || ('Q2 error inesperado: ' || sqlerrm); end;`

**Aislamiento entre clinicas** (Q3, 2110-2125): vet B ve 0, vet A ve >= 1 (control positivo).

**Escritura directa denegada** (Q5-Q7, 2140-2174) - usar para `INSERT`/`UPDATE productos set cantidad = 99` y UPDATE/DELETE de movimientos:
```sql
  begin
    insert into public.dosis_aplicadas (...) values (...);
    failures := failures || 'Q5 INSERT directo en dosis_aplicadas debía fallar';
  exception
    when insufficient_privilege then null;
    when others then failures := failures || ('Q5 error inesperado: ' || sqlerrm);
  end;
  -- UPDATE/DELETE: get diagnostics n = row_count; if n <> 0 then failures := ...
```
**Codigos de error propios**: copiar `when sqlstate 'LP004' then null;` (R30, 3868) como `when sqlstate 'IN001'` / `'IN002'`; `when check_violation` (Q8, 2182).

**Anon sin execute** (Q34, 2677-2706): agregar `public.mover_stock(uuid,int,text,text,uuid,text,uuid)`, `crear_producto(...)`, `actualizar_producto(...)`, `archivar_producto(uuid)`, `inventario_resumen()` a un `foreach ... has_function_privilege('anon', sig, 'execute')`.

**Solo lectura** - preparar el estado como R30 (3854-3908) por la herencia de plan (RESEARCH Pitfall 3): fijar `update public.clinica_planes set plan='gratis', miembros_max=1, ..., prueba_clinica_hasta = r_hoy - 16 where clinica_id = r_c_s` y llamar como `r_vet_s2`; esperar `when sqlstate 'LP004'` en `crear_producto`, `mover_stock`, `archivar_producto`, mientras `select from productos` sigue funcionando.

**Edicion obligatoria de R44** (4270-4302):
```sql
    if r_arr is null or cardinality(r_arr) <> 7
       or not (r_arr <@ array['cita_mascotas', 'citas', 'clientes', 'consultas', 'dosis_aplicadas', 'mascota_pesos', 'mascotas']
               and array['cita_mascotas', 'citas', 'clientes', 'consultas', 'dosis_aplicadas', 'mascota_pesos', 'mascotas'] <@ r_arr) then
```
-> `<> 9` y agregar `'movimientos_inventario', 'productos'` a ambos arrays (mantener orden alfabetico); actualizar el comentario "(guarda en exactamente 7 tablas)" de la linea 4270. Es una modificacion, no suma checks. Marcar el smoke como **pendiente del usuario** (se pega en el SQL Editor).

---

### `supabase/tests/verify_live_schema.sh` (test/script)

**Analog:** el mismo archivo.
- Lista de tablas anon (linea 73): `for t in protocolos_vacunacion dosis_aplicadas vacuna_alertas carne_enlaces; do` -> agregar `productos movimientos_inventario`. El bucle usa `col=id` por defecto (ambas tablas tienen `id`).
- Lista de RPC (linea 109): agregar `mover_stock crear_producto actualizar_producto archivar_producto inventario_resumen`.
- Sonda de embed (251-276), con `allow_denied` porque anon no tiene privilegios:
```bash
probe_embed dosis_aplicadas '*, veterinario:perfiles!dosis_veterinario_perfil_fkey(nombre, matricula, activo)' 'dosis veterinario embed' allow_denied
```
-> `probe_embed movimientos_inventario '*, autor:perfiles!movimientos_veterinario_perfil_fkey(nombre, activo)' 'movimientos autor embed' allow_denied` (400 = hint equivocado).

---

### `lib/features/inventory/domain/inventario_failure.dart` (error, request-response)

**Analog:** `lib/features/vaccination/domain/vacuna_failure.dart` (1-17), copiar completo:
```dart
import '../../../core/errors/limite_plan.dart';

class VacunaFailure implements Exception, ConLimitePlan {
  const VacunaFailure(this.message, {this.limite});

  final String message;

  @override
  final LimitePlan? limite;

  @override
  String toString() => message;
}
```
Renombrar a `InventarioFailure`. Doc `///` que explica el por que (convencion del proyecto).

---

### `lib/features/inventory/data/repositories/supabase_inventario_repository.dart` (repo, CRUD + RPC)

**Analog:** `lib/features/vaccination/data/repositories/supabase_vacuna_repository.dart`.

**Imports** (lineas 1-10):
```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/limite_plan_postgrest.dart';
import '../../../../core/errors/limite_plan.dart';
import '../../../../core/utils/formato.dart';
```
**Estructura base `_run` + `_filas`** (20-37):
```dart
class SupabaseVacunaRepository {
  SupabaseVacunaRepository(this._client);
  final SupabaseClient _client;

  Future<T> _run<T>(Future<T> Function() op, String generico) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      throw vacunaFailureDe(e);
    } catch (_) {
      throw VacunaFailure(generico);
    }
  }

  List<Map<String, dynamic>> _filas(Object? r) => [
    for (final f in (r as List? ?? const [])) f as Map<String, dynamic>,
  ];
```
**Escritura por RPC con params estaticos testeables** (85-159): `@visibleForTesting static Map<String, Object?> paramsRegistrarDosis(...)` con `blancoANull(...)` y todas las llaves `p_*` presentes aunque sean null (para que PostgREST resuelva la firma); `registrarDosis` hace `_client.rpc('registrar_dosis', params: ...)` y `return r as String;`. Replicar como `paramsCrearProducto`, `paramsMoverStock`.

**Lectura de resumen con fila unica** (206-217): `final r = _filas(await _client.rpc('vacunas_resumen')); if (r.isEmpty) return const ResumenVacunas(...); ... (f['vencidas'] as int?) ?? 0`. Copiar para `inventario_resumen` (`bajos`, `por_vencer`, `vencidos`). Para `mover_stock` el RPC devuelve `table (movimiento_id, cantidad_nueva)`: leer `_filas(r).first`.

**Lectura de tabla con embed del autor** (analog: `supabase_consulta_repository.dart` 28-36 y 136-157):
```dart
final rows = await _client
    .from('consultas')
    .select('*, veterinario:perfiles!consultas_veterinario_perfil_fkey(nombre, activo)')
    .eq('mascota_id', mascotaId)
    .order('fecha', ascending: false);
...
final autor = row['veterinario'] as Map<String, dynamic>?;
... veterinarioNombre: autor?['nombre'] as String?,
```
-> `movimientos(String productoId)` con `.limit(50)` y `.order('created_at', ascending: false)`; `productos()` con `.select().isFilter('archivado_at', null).order('nombre')` (RLS ya aisla; el cliente no filtra por clinica). Fecha `date` con `fechaDeBd` (`lib/features/vaccination/domain/fecha_bd.dart` 1-14, "nunca `DateTime.parse` directo"); instantes `created_at` con `DateTime.parse(...).toLocal()`.

**Traduccion de errores** (318-347, copiar la forma de `vacunaFailureDe` + `mensajeErrorVacuna`):
```dart
@visibleForTesting
VacunaFailure vacunaFailureDe(PostgrestException e) =>
    VacunaFailure(mensajeErrorVacuna(e), limite: limitePlanDe(e));

@visibleForTesting
String mensajeErrorVacuna(PostgrestException e) {
  switch (limitePlanDe(e)) {
    case LimitePlan.soloLectura:
      return 'Tu cuenta está en solo lectura. Pide al administrador que active el plan.';
    case _:
      break;
  }
  switch (e.code) {
    case '42501': return 'No tienes permiso para hacer esto en esta clínica.';
    case '23505': return 'Ya existe un registro igual.';
    default: return 'No pudimos completar la operación. Intenta de nuevo.';
  }
}
```
Agregar ramas `IN001`, `IN002`, `23505` ("Ya tienes un producto con ese nombre."), `23514`. Mensajes con tildes. Sin conexion (D-12): el `catch (_)` generico del `_run` debe distinguir `SocketException`/`ClientException` para el mensaje "Sin conexion. El ajuste no se guardo..." (no hay analogo en el repo: ver No Analog).

---

### `lib/features/inventory/presentation/providers/inventario_providers.dart` (provider)

**Analog:** `vacuna_providers.dart` (1-30), `alertas_providers.dart` (14-103), `invalidar_vacunas.dart` (1-24), `anular_dosis_providers.dart` (1-26).

**Repo + lecturas autoDispose** (vacuna_providers.dart 8-30):
```dart
final vacunaRepositoryProvider = Provider<SupabaseVacunaRepository>((ref) {
  return SupabaseVacunaRepository(ref.watch(supabaseClientProvider));
});

final carneProvider = FutureProvider.autoDispose.family<Carne, String>((ref, mascotaId) {
  return ref.watch(vacunaRepositoryProvider).carne(mascotaId);
});
```
**Clase de acciones con `Ref` (no autoDispose)** (alertas_providers.dart 28-37; anular_dosis_providers.dart 9-26):
```dart
final alertasActionsProvider = Provider<AlertasActions>(AlertasActions.new);

class AlertasActions {
  AlertasActions(this._ref);
  final Ref _ref;
  void _refrescar() => invalidarAlertasVacunas(_ref);
  ...
    await _ref.read(vacunaRepositoryProvider).gestionarAlerta(...);
    _refrescar();
```
**Invalidacion obligatoria tras cada mutacion (G4)** (invalidar_vacunas.dart 7-24): la rama Inicio del shell sigue montada, asi que un provider `autoDispose` con listener no se refresca solo.
```dart
void invalidarVacunas(Ref ref, {required String mascotaId, String? citaId}) {
  ref.invalidate(carneProvider(mascotaId));
  ref.invalidate(resumenVacunasMascotasProvider);
  invalidarAlertasVacunas(ref);
  ...
}
```
-> `invalidarInventario(Ref ref, {String? productoId})` invalida `productosProvider`, `resumenInventarioProvider` y `movimientosProvider(productoId)`.

**Deshacer (snackbar)**: analog `pendiente_tile.dart` 126-135 (`SnackBarAction(label: 'Deshacer', onPressed: () => actions.restaurar(_p))`). Captura `messenger`/`actions` ANTES del `await` (el sheet/fila se desmonta). Las acciones reciben `Ref`, no `WidgetRef`.

**Reloj**: `ref.read(clockProvider)()` + `diaBogota(...)` (`alertas_providers.dart` 91; `clock_provider.dart`, `zona_bogota.dart` `diaBogota`), nunca `DateTime.now()` en widgets.

**Admin**: `ref.watch(authProfileProvider).value?.esAdmin ?? false` (analog `datos_clinica_providers.dart` 23, `puedeEditarClinicaProvider`); crear `puedeAdministrarInventarioProvider` igual. `puedeEscribirProvider` ya existe (`plan_providers.dart` 46-48).

---

### `lib/features/inventory/presentation/inventario_routes.dart` + `app_router.dart` (route)

**Analog:** `lib/features/vaccination/presentation/vacunacion_routes.dart` (7-56).
```dart
/// ... Desde estas rutas solo se empujan rutas de primer nivel: empujar una ruta
/// de una rama del shell ... duplica la página del shell en el Navigator raíz (G5).
final List<GoRoute> vacunacionRoutes = [
  GoRoute(path: '/vacunas', builder: (_, _) => const VacunasPendientesScreen()),
  GoRoute(
    path: '/carne/:mascotaId',
    builder: (_, state) => CarneScreen(
      mascotaId: state.pathParameters['mascotaId']!,
      abrirCompartir: state.uri.queryParameters['compartir'] == '1',
    ),
  ),
];

String rutaCarne(String mascotaId, {bool compartir = false}) => Uri(
  path: '/carne/${Uri.encodeComponent(mascotaId)}',
  queryParameters: compartir ? {'compartir': '1'} : null,
).toString();
```
Rutas: `/inventario` (lee `state.uri.queryParameters['filtro'] == 'bajos'`), `/inventario/nuevo`, `/inventario/:id/editar`, `/inventario/:id`. **Declarar `nuevo` y `:id/editar` ANTES de `:id`** (o como subruta de `:id`) para que no colisionen. Helpers `rutaInventario({bool bajos})`, `rutaProducto(id)` con `Uri(...)` + `Uri.encodeComponent`; entradas opcionales con la sintaxis null-aware `'codigo': ?codigo` (vacunacion_routes 51-55).

`lib/core/router/app_router.dart`: agregar `import '../../features/inventory/presentation/inventario_routes.dart';` junto a la linea 20 y `...inventarioRoutes,` justo debajo de `...vacunacionRoutes,` (linea 92), fuera del `StatefulShellRoute`. `redirect` no requiere cambios (solo `vetExitPaths` empuja a `/inicio`).

---

### `.../screens/inventario_screen.dart` (lista + busqueda + filtros + FAB)

**Analogs combinados:** `clientes_list_screen.dart` (buscador y FAB con candado) y `vacunas_pendientes_screen.dart` (filtros, skeleton, error).

**Imports** (vacunas_pendientes_screen 1-12): `flutter/material`, `flutter_riverpod`, `core/theme/app_colors|app_spacing`, `core/widgets/app_bar/app_top_bar`, `buttons/app_button`, `cards/app_card`, `chips/app_filter_chip`; mas `go_router` y los de plan (`limite_plan_gate.dart`, `providers/plan_providers.dart`).

**Buscador local + estado de pantalla** (clientes_list 25-56): `ConsumerStatefulWidget`, `TextEditingController` con `dispose`, `AppTextField(label: ..., hideLabel: true, controller:, hintText:, onChanged: (_) => setState(() {}))`. Aqui el filtrado es sobre la lista ya cargada (RESEARCH Pattern 7 / Pitfall 9; no `ilike`).

**Chips de filtro** (vacunas_pendientes 14-22, 49-62): `enum _Filtro { todos('Todos'), bajos('Bajos'), ... }` y `AppFilterChip(label:, selected: _filtro == f, onTap: () => setState(() => _filtro = f))`. El filtro inicial viene del parametro de ruta `filtro=bajos`.

**FAB con candado de solo lectura** (clientes_list 73-100), copiar tal cual cambiando el destino (`asegurarEscritura` en lugar de `asegurarNuevoPaciente`, que es especifico de pacientes):
```dart
Widget _botonNuevoCliente(bool puedeEscribir) {
  Future<void> abrir() async {
    final ok = await asegurarNuevoPaciente(context, ref, plan: ref.read(miPlanProvider).value);
    if (!ok || !mounted) return;
    context.push('/clientes/nuevo');
  }

  final boton = FloatingActionButton.extended(
    onPressed: abrir,
    icon: Icon(iconoEscritura(puedeEscribir, Icons.add)),
    label: const Text('Nuevo cliente'),
  );
  if (puedeEscribir) return boton;
  return Semantics(
    button: true,
    label: semanticaEscritura(puedeEscribir, 'Nuevo cliente'),
    onTap: abrir,
    excludeSemantics: true,
    child: boton,
  );
}
```
**Skeleton + error con "Reintentar"** (vacunas_pendientes 66-98, `_SkeletonTile` 184-210): bloques `AppColors.surfaceMuted` con `AppSpacing.radiusSm`; `AppButton(label: 'Reintentar', variant: AppButtonVariant.outline, expand: false, onPressed: () => ref.invalidate(...))`.

**Estado vacio centrado** (clientes_list 113-140): `Center > Padding > Column(mainAxisSize.min)` con `headlineSmall` + `bodyLarge`. El UI-SPEC agrega circulo de 64 px `surfaceMuted` con icono 32 px.

**Pull-to-refresh**: `RefreshIndicator(onRefresh: ...)` envolviendo el `ListView` (clientes_list 142-144); aqui `onRefresh` invalida `productosProvider` + `resumenInventarioProvider` y espera `.future`. Padding inferior 88 px (constante local, UI-SPEC).

**`AsyncValue.when` con datos viejos durante refresh**: comportamiento por defecto (`skipLoadingOnRefresh`); no agregar spinner por cada -1.

---

### `.../screens/producto_form_screen.dart` (crear/editar)

**Analogs:** `mascota_form_screen.dart` 185-200 (catch + limite) y `consulta_form_screen.dart` 225-262 (disclosure).

**Patron de guardado con limite de plan** (mascota_form_screen 195-199):
```dart
    } on MascotaFailure catch (e) {
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
```
-> `on InventarioFailure catch (e)`. Para `23505` mostrar el mensaje inline bajo "Nombre del producto" (`errorText` de `AppTextField`).
**Pre-check al abrir**: `asegurarEscritura(context, ref, plan: ref.read(miPlanProvider).value)` (inicio_screen 26-36) antes de `context.push('/inventario/nuevo')`.
**Disclosure "Agregar mas detalles"** (consulta_form_screen 232-262): `InkWell` con `constraints: BoxConstraints(minHeight: AppSpacing.touchTarget)`, `Text('Agregar más detalles', style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted))` + `Icon(_detallesExpandidos ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)` y `if (_detallesExpandidos) ...[ ... ]`. (El UI-SPEC nombra `Icons.expand_more`; el repo usa `keyboard_arrow_*` aqui y `expand_more/less` en `mi_plan_screen.dart` 359: cualquiera es consistente.)
**Campos numericos**: `AppTextField(keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], maxLength: 7, autofocus: true)`; ver Hallazgo 2 (faltan `textInputAction`/prefijo). **Fecha de vencimiento**: ver Hallazgo 1.
**Edicion no-admin**: filas de solo lectura (sin icono de candado: el candado es solo por plan, UI-SPEC regla 5).

---

### `.../screens/producto_detail_screen.dart` (detalle + historial + archivar)

**Analog:** `mascota_detail_screen.dart` (patron `asegurarEscritura` antes de cada accion de escritura, lineas 114-120, 166, 256, 310, 332; control bloqueado ~360). `movimientosProvider(id)` con `.when` y reintento propio ("No pudimos cargar el historial.") como `carne_screen.dart`. Dialogo de archivar: ver analog `AlertDialog` en `cita_acciones.dart` 83-108:
```dart
final r = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('¿Cancelar esta cita?'),
    content: Text('...'),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Volver')),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
        onPressed: () => Navigator.of(ctx).pop(true),
        child: const Text('Cancelar cita'),
      ),
    ],
  ),
);
return r ?? false;
```
Reutilizarlo para "¿Confirmas este ajuste?" (|delta| > 10) y "Archivar producto". El boton "Archivar producto" usa `AppButtonVariant.destructive` (existe en `app_button.dart` linea 6).

---

### `.../widgets/ajuste_sheet.dart` (hoja modal, request-response)

**Analog:** `lib/features/vaccination/presentation/widgets/anular_dosis_sheet.dart` (1-197). Copiar la estructura completa:
- Funcion de apertura que **captura `messenger` y `router` antes del `await`** y abre `showModalBottomSheet<void>(context:, isScrollControlled: true, showDragHandle: true, builder: ...)` (19-37).
- `ConsumerStatefulWidget` con `bool _guardando`; `_anular()` hace `if (motivo == null || _guardando) return; setState(() => _guardando = true); try { await ref.read(...).call(...); if (!mounted) return; Navigator.of(context).pop(); messenger..hideCurrentSnackBar()..showSnackBar(SnackBar(content:, action: SnackBarAction(...))) } on VacunaFailure catch (e) { if (!mounted) return; setState(() => _guardando = false); ... }` (76-113).
- Layout: `Padding(EdgeInsets.only(left/right: AppSpacing.md, bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md))` > `SingleChildScrollView` > `Column(mainAxisSize.min)` (119-129).
- Chips de motivo: `Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [for (final m in _motivos) AppFilterChip(label: m, selected: _motivo == m, onTap: () => setState(() => _motivo = m))])` (140-151).
- Boton con `isLoading: _guardando` y `onPressed: ... == null ? null : _anular` (183-188).
Diferencia: en Fase 6 los errores del servidor van **inline en la hoja** (UI-SPEC §3 "Sheet failures"), no en snackbar; `LP004` -> `manejarLimitePlan` (hoja `LimitePlanSheet` encima, datos intactos). El "Deshacer" lo muestra la pantalla/fila, no la hoja (el snackbar usa el `messenger` capturado).

---

### `.../widgets/producto_fila.dart`, `ajuste_rapido_botones.dart` (fila con acciones)

**Analog:** `pendiente_tile.dart` (acciones en tarjeta + `SnackBarAction`, 105-135) y `ControlEscritura` (`plan/presentation/widgets/control_escritura.dart` 11-36):
```dart
class ControlEscritura extends StatelessWidget {
  const ControlEscritura({super.key, required this.puedeEscribir, required this.label,
    required this.onTap, required this.child});
  ...
  Widget build(BuildContext context) {
    if (puedeEscribir) return child;
    return Semantics(button: true, label: semanticaEscritura(puedeEscribir, label),
      onTap: onTap, excludeSemantics: true, child: child);
  }
}
```
Uso (inicio_screen 94-103): `ControlEscritura(puedeEscribir:, label: 'Vacunar', onTap: ..., child: AppButton(label:, icon: iconoEscritura(puedeEscribir, Icons.vaccines_outlined), onPressed: ...))`. Aplicar a "-1" y "+" (icono pasa a `Icons.lock_outline`, mismo tamano; `onTap` abre `LimitePlanSheet` via `asegurarEscritura`/`manejarLimitePlan`, sin atenuar con opacidad). Tarjeta: `AppCard(onTap: () => context.push(...), child: ConstrainedBox(constraints: BoxConstraints(minHeight: 48), ...))`. Bloqueo por fila en vuelo: estado local `Set<String> _enVuelo` en la pantalla (sin analogo).

---

### `.../widgets/insignia_stock.dart` (pill icono + texto)

**Analog:** `lib/core/widgets/status/dosis_estado_chip.dart` (15-87) - misma anatomia (record `_spec` + `Semantics(label, excludeSemantics)` + `Container(height: 28, padding: horizontal sm, BoxDecoration(color: bg, borderRadius: radiusLg, border: warning.withValues(alpha: 0.4)))` + `Row(Icon 14/16 + SizedBox(xs) + Text(labelMedium w600))`):
```dart
({Color bg, Color fg, Color? borde, IconData icon, String label}) get _spec => switch (estado) {
  DosisEstado.proxima => (bg: AppColors.warningBg, fg: AppColors.primaryText,
      borde: AppColors.warning, icon: Icons.schedule, label: 'Próxima'),
  DosisEstado.vencida => (bg: AppColors.destructive, fg: AppColors.onDestructive,
      borde: null, icon: Icons.error_outline, label: 'Vencida'),
  ...
};
```
NO extender `DosisEstadoChip` ni `AppStatusChip` (UI-SPEC: enums especificos; el widget es feature-local). Estados: Agotado (`error_outline`, destructive), Bajo (`trending_down`, warningBg), Vencido (`event_busy`), Vence pronto (`schedule`). Nota UI-SPEC: el icono de "Bajo"/"Vence pronto" usa `primaryText` (no `warning`) por contraste, a diferencia de la linea 58 del chip original.

---

### `.../widgets/stock_bajo_card.dart` (tarjeta de Inicio) + `inicio_screen.dart`

**Analog:** `vacunas_pendientes_card.dart` (14-104): `ConsumerWidget`, `ref.watch(resumen...Provider)`, `AppCard(onTap: () => context.push('/vacunas'), child: ConstrainedBox(constraints: BoxConstraints(minHeight: 48), child: Row(icono, Expanded(Column(...)), Icon(Icons.chevron_right))))` dentro de `Semantics(button: true, ...)`.
**Diferencias obligatorias (D-08 / UI-SPEC §6):** `async.when(loading: SizedBox.shrink, error: SizedBox.shrink, data: bajos == 0 ? SizedBox.shrink : tarjeta)`; contenedor `warningBg` + borde `AppColors.border` (no `AppCard` default); `minHeight: 56`; `context.push('/inventario?filtro=bajos')`.
**Integracion** (`inicio_screen.dart` 88-90):
```dart
              const SizedBox(height: AppSpacing.md),
              const VacunasPendientesCard(),
              const SizedBox(height: AppSpacing.md),
```
Insertar `StockBajoCard` despues de `VacunasPendientesCard`. Cuidado: la tarjeta se oculta, asi que el `SizedBox(md)` de separacion debe vivir DENTRO del widget (o usar un `Consumer`), para no dejar doble espacio cuando `bajos == 0`.

---

### `.../screens/mas_screen.dart` (fila "Inventario")

**Analog:** fila "Equipo" (mas_screen 69-94):
```dart
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () => context.push('/mas/equipo'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const Icon(Icons.group_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Equipo', style: Theme.of(context).textTheme.bodyLarge)),
                    if (miembros != null)
                      Text(miembros == 1 ? '1 miembro' : '$miembros miembros',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary)),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
```
Insertar la fila nueva entre "Mi plan" (cierra en linea 149) y "Recordatorios" (151). Ruta de primer nivel: `context.push('/inventario')` (NO `/mas/...`, G5). Pill "N bajos" dentro de `Flexible` (patron `PlanInsignia`, lineas 136-143); sin pill en carga/error: `ref.watch(resumenInventarioProvider).value?.bajos`. Anadir `Semantics` con label compuesto como la fila "Mi plan" (116-121) si la pill porta informacion.

---

### `lib/core/utils/formato.dart` (utility) - COP y miles

**Analog:** el propio `formato.dart`: funciones puras con record `({T? valor, String? error})` (`parsearFecha` 30-56, `parsearPeso` 62-71) y `blancoANull` (11-14). No usar `NumberFormat('es_CO')` (la app nunca llama `initializeDateFormatting`, comentario lineas 16-18): agrupar con `RegExp` a mano.
```dart
({int? valor, String? error}) parsearCop(String texto) { ... }   // acepta "85.000", "85000", "$ 85.000"; rechaza coma -> 'Usa pesos enteros, sin coma.'
String formatearCop(int pesos) => ...;                           // '$ 85.000'
String formatearMiles(int n) => ...;                             // '1.000.000'
```
Extender `test/formato_test.dart` (usa `group('...', () { test(...) })`, estructura en lineas 5-80). Ver tambien Hallazgo 1 (fecha sin tope futuro).

---

### `.../domain/pedido_whatsapp.dart` (utility, transform)

**Analog:** `lib/features/vaccination/domain/whatsapp_vacunas.dart` (1-48): funciones puras `String mensajeX({required ..., String? clinica})`, helper privado para el nombre de clinica nulo/vacio (`_conClinica`, 3-6), fecha con `formatearFecha`. Texto del pedido ya esta en RESEARCH "Code Examples" (`mensajePedidoStock`) y UI-SPEC (primera linea "Pedido de insumos:" si no hay nombre de clinica). Compartir con `ref.read(compartidorProvider).compartirTexto(texto)` (`core/utils/compartir.dart` 7-22), capturando el error para el snackbar "No pudimos abrir el menu de compartir." No usar `lanzador_externo` (sin destinatario, D-11). Test: `test/whatsapp_vacunas_test.dart` + `FakeCompartidor` (`test/helpers/fake_compartir.dart`, registra `compartidos`, lanza `error`).

---

### `test/helpers/fake_inventario.dart` (test helper)

**Analog:** `test/helpers/fake_vacunas.dart` (1-253): `class FakeVacunaRepository implements SupabaseVacunaRepository`; constructor con datos fijos + errores por metodo (`this.errorRegistrar`, ...); `llamadas = <({String metodo, Map<String, Object?> args})>[]`; `_log(metodo, [args])`; `_falla([Object? especifico]) { final e = especifico ?? error; if (e != null) throw e; }`; cada metodo `@override Future<...> x(...) async { _log('x', {...}); _falla(errorX); return data; }`.
Debe sobreescribir **todos** los metodos publicos del repo real (misma firma) o no compila. Los errores inyectados son `InventarioFailure(...)`.

---

### `test/inventario_invalidacion_test.dart`

**Analog:** `test/vacunas_invalidacion_test.dart` (28-95): `ProviderContainer` con `overrides: [repoProvider.overrideWithValue(repo)]`, `c.listen(provider, (_, _) {})` para simular pantallas vivas, `_cargar(c)` lee `.future` de cada uno, `_veces(repo, 'metodo')` cuenta `repo.llamadas`; tras la accion + recarga `expect(_veces(repo, 'resumen'), 2)`. Casos: crear, `mover_stock`, deshacer, archivar -> lista + resumen (+ historial del producto) se recargan.

---

### `test/router_inventario_cross_shell_test.dart`

**Analog:** `test/router_vacunas_cross_shell_test.dart` (completo, 1-188): `_app()` con `ProviderScope(retry: (retryCount, error) => null, overrides: [...planOverrides(), authProfileProvider.overrideWith(() => FakeAuthProfileNotifier(profile: vetProfile)), citaRepositoryProvider..., teamRepositoryProvider..., esClinicaMultiVetProvider.overrideWithValue(false), miembrosActivosProvider..., indicesColorVetProvider..., clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 17))], child: const VetApp())`; helpers `_container(tester)`, `_ubicacion(tester)` (`routerDelegate.currentConfiguration.last.matchedLocation`); `tester.view.physicalSize = const Size(800, 3000)`. Usa el `routerProvider` real (no `routerHarness`: ocultaba el fallo G5). Casos: Inicio -> `push('/inventario?filtro=bajos')` y Mas -> `push('/inventario')` abren UNA pagina, `tester.takeException()` es null, Atras vuelve; desde `/inventario` abrir `/inventario/nuevo` y `/inventario/:id` sin romper `!keyReservation.contains(key)`.

---

### `test/supabase_inventario_repository_test.dart`

**Analog:** `test/supabase_vacuna_repository_test.dart` (10-90): `mensajeErrorVacuna(PostgrestException(message: 'raw', code: code))` por codigo; `vacunaFailureDe(...).limite`; `paramsRegistrarDosis(...)` `p.keys.toSet()` igual al conjunto `p_*` exacto (incluye valores en blanco -> null). Casos Fase 6: `IN001`, `IN002`, `23505`, `42501`, `LP004` (por `code` y por `hint` con `P0001`), `paramsMoverStock`/`paramsCrearProducto` con todas las llaves.

---

### Tests de pantalla (`inventario_screen_test`, `producto_form_screen_test`, `ajuste_rapido_test`, `stock_bajo_card_test`)

**Analog:** `test/vacunas_pendientes_screen_test.dart` (1-75) e `inicio_screen_test.dart` (1-60):
```dart
Widget _appUnderTest({...}) {
  return routerHarness(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => const InicioScreen()), GoRoute(path: '/vacunas', builder: (_, _) => const Text('PANTALLA VACUNAS'))],
    overrides: [
      ...planOverrides(plan: plan),
      authProfileProvider.overrideWith(() => FakeAuthProfileNotifier(profile: profile, error: error)),
      vacunaRepositoryProvider.overrideWithValue(vacunas ?? FakeVacunaRepository()),
      ...
    ],
  );
}
```
`routerHarness` (`test/helpers/router_harness.dart`, `locale` solo si se abre `showDatePicker`); `planOverrides(plan: planSoloLectura)` para los candados; `clockProvider.overrideWithValue(() => DateTime.utc(...))` para vence-pronto; `FakeCompartidor` via `compartidorProvider.overrideWithValue`. Test de tarjeta de Inicio: copiar "tarjeta Vacunas pendientes con conteos y navega a /vacunas" (inicio_screen_test ~109-127: render, `tester.tap(find.text(...))`, `find.text('PANTALLA ...')`) y su gemelo con 0 -> `findsNothing`. Aserciones UI-SPEC: badges con icono + texto, candado `Icons.lock_outline`, confirmacion solo > 10, "Deshacer" solo <= 10, tarjeta oculta en 0/carga/error.

---

## Shared Patterns

### Autorizacion / Multi-tenencia (SQL)
**Fuente:** `schema.sql` 2005-2007 (policy), 2477-2479 (guardia en RPC), 2524-2528 (`es_admin_clinica`)
**Aplicar a:** todas las tablas y RPC de Fase 6
```sql
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());
...
if not public.es_veterinario() or v_clinica is null then
  raise exception '...' using errcode = 'insufficient_privilege';
end if;
```
Nunca confiar en `clinica_id`/`veterinario_id` del cliente; `auth.uid()` para la autoria.

### Solo-append + escritura solo por RPC definer
**Fuente:** `schema.sql` 1910-1912 (comentario), 2017-2024 (revokes), 2442-2569
**Aplicar a:** `productos` (cantidad solo cambia por `mover_stock`) y `movimientos_inventario` (sin update/delete).

### Solo lectura por plan (LP004)
**Fuente servidor:** `guard_solo_lectura` (`schema.sql` 3745-3799). **Fuente cliente:** `lib/features/plan/presentation/limite_plan_gate.dart`:
```dart
Future<bool> asegurarEscritura(BuildContext context, WidgetRef ref, {MiPlan? plan}) async { ... }   // 33-51
Future<bool> manejarLimitePlan(BuildContext context, WidgetRef ref, Object error, {FuncionPro? funcion}) async { ... } // 120-142
IconData iconoEscritura(bool puedeEscribir, IconData icono) => puedeEscribir ? icono : Icons.lock_outline; // 146-147
String semanticaEscritura(bool puedeEscribir, String label) => puedeEscribir ? label : '$label, bloqueado, solo lectura'; // 150-151
```
**Aplicar a:** FAB, "-1", "+", "Descontar 1", "Agregar stock", "Ajustar cantidad", editar, archivar, guardar del formulario. Patron de uso: pre-check con `asegurarEscritura(..., plan: ref.read(miPlanProvider).value)` y, en el `catch` de la `*Failure`, `if (mounted && await manejarLimitePlan(context, ref, e)) return;` antes de mostrar el mensaje. `Compartir`, lista, busqueda, detalle, historial y tarjeta de Inicio NO se bloquean.

### Traduccion de errores a `*Failure`
**Fuente:** `supabase_vacuna_repository.dart` 25-33 y 318-347; `vacuna_failure.dart`
**Aplicar a:** todo metodo del repositorio de inventario. Rama especifica por codigo + fallback generico en espanol; la presentacion captura solo `InventarioFailure` y muestra `e.message`; nunca texto crudo de `PostgrestException`.

### Invalidacion tras mutacion (G4)
**Fuente:** `invalidar_vacunas.dart` 11-24. **Aplicar a:** crear, mover (incluye deshacer), actualizar, archivar -> `productosProvider`, `resumenInventarioProvider`, `movimientosProvider(id)`.

### Fechas y zona
**Fuente:** `fecha_bd.dart` (`fechaDeBd`/`fechaABd`), `zona_bogota.dart` (`diaBogota`), `clock_provider.dart`, `formato.dart` (`formatearFecha`). Vence pronto = `0 <= dias <= 30`, vencido = `dias < 0`, siempre contra `diaBogota(clock())`.

### Snackbar con mensajes en espanol
**Fuente:** `dosis_registrada_snackbar.dart` 9-28 y `anular_dosis_sheet.dart` 90-105:
```dart
ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(texto), action: SnackBarAction(label: '...', onPressed: ...)));
```
Un solo snackbar a la vez (`hideCurrentSnackBar` primero), `SnackBarBehavior.floating`, 6 s para los de "Deshacer" (UI-SPEC §2.2).

### Convenciones de codigo (CLAUDE.md / skill)
Dominio en espanol, sufijos tecnicos en ingles, `snake_case.dart`, sin sufijo `UseCase`, sin freezed/mocktail/build_runner, imports relativos dentro de `lib/` (tests usan `package:vetapp/...`), `///` solo en entidades de dominio, repositorios y widgets reutilizables, `const` agresivo, colores/espaciados solo de `AppColors`/`AppSpacing`/`AppTypography`.

---

## No Analog Found

| Archivo / aspecto | Rol | Data Flow | Motivo |
|---|---|---|---|
| Deteccion de "sin conexion" (D-12) en el repositorio | utility | request-response | El repo no distingue errores de red: los `catch (_)` genericos devuelven un mensaje unico. Hay que introducir la rama (`SocketException`/`ClientException`) con un mensaje propio; sin precedente. |
| Estado "fila con RPC en vuelo" (`Set<String>` local) + doble toque | component | event-driven | Ninguna lista actual bloquea botones por fila; solo hay `bool _guardando` por hoja/formulario (`anular_dosis_sheet.dart` 62). Extender ese patron a un set por producto. |
| `ResumenBajosStrip` (franja `warningBg`) | component | transform | Cercano: `PlanBanner` (`plan/presentation/widgets/plan_banner.dart`, no leido a fondo) y la tarjeta de Inicio; no hay contenedor `warningBg` reutilizable. Construir local con tokens existentes. |

## Metadata

**Analog search scope:** `lib/features/{vaccination,plan,clients,patients,appointments,clinical_history,home,inventory,clinic}`, `lib/core/{data,errors,router,utils,widgets,theme}`, `supabase/schema.sql`, `supabase/tests/{rls_smoke_test.sql,verify_live_schema.sh}`, `test/` y `test/helpers/`.
**Files scanned:** ~45 (lectura directa) + greps de uso para `manejarLimitePlan`, `asegurarEscritura`, `AlertDialog`, `SnackBarAction`, overrides de repositorio en tests.
**Pattern extraction date:** 2026-10-31
