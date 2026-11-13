# Phase 7: Facturación - Pattern Map

**Mapped:** 2026-11-13
**Files analyzed:** 46 (new or modified)
**Analogs found:** 43 / 46 (3 have no direct analog; see "No Analog Found")

Sources read: `07-CONTEXT.md` (D-01..D-24), `07-RESEARCH.md` (architecture, DDL contract, RPC list, smoke plan T) and `06-PATTERNS.md` (format). Analogs come from Phase 6 (`inventory`), Phase 5 (`vaccination`), Phase 5.1 (`plan`), and the `clients`, `clinic`, `appointments` and `clinical_history` features. All paths are relative to `C:\Trabajo\VetApp`.

## Findings the planner must assume (verified in code)

1. **The Phase 6 header comment is now wrong.** `supabase/schema.sql` lines 4180-4181 say "Fase 7 (facturación) reutiliza esta misma RPC ampliando p_origen ('factura') con create or replace". RESEARCH rejects that: `mover_stock` stays byte-for-byte unchanged, and billing uses the private `_aplicar_movimiento_stock`. The Fase 7 block should add a comment that supersedes this one. Do not edit the `mover_stock` body (lines 4393-4475).
2. **The carnet PDF uses Figtree, not Noto.** `carne_pdf_service.dart` lines 18-22 load `PdfGoogleFonts.figtreeRegular/SemiBold`, plus Caprasimo as display through `CargarFuenteDisplayPdf` (lines 24-26; wired in `carne_pdf_providers.dart` line 9). The Noto fonts belong to `historia_clinica_pdf_service.dart` (lines 18-22). RESEARCH's "reuse the Noto fonts" is inaccurate; `CobroPdfService` should copy the carnet (Figtree + Caprasimo + logo).
3. **The WhatsApp number helper is `numeroWhatsApp`, not `normalizarTelefono`.** `lib/core/utils/telefono_co.dart` line 104 returns digits only, or `null` when the number is not a mobile or international number. The URI builder is `whatsappUri(numero, mensaje)` in `lib/features/appointments/domain/whatsapp_recordatorio.dart` lines 35-36. The carnet sheet uses both (`compartir_carne_sheet.dart` lines 66-81, 169).
4. **The plural for the stock message already exists.** `Unidad.etiqueta(int n)` (`lib/features/inventory/domain/entities/producto.dart` lines 24-36) gives "1 frasco", "2 frascos", "dosis", "ml". Build "Solo quedan 2 frascos de Amoxicilina." with `Unidad.desdeBd(detail.unidad).etiqueta(quedan)`. Do not hand-roll the `mensajeStock` switch from RESEARCH.
5. **`uuid` is only a transitive dependency** (`pubspec.lock` line 1341, `dependency: transitive`; not in `pubspec.yaml`). Importing `package:uuid` directly trips the `depend_on_referenced_packages` lint. Either add it as a direct dependency (that needs the legitimacy audit) or generate a v4 UUID with `Random.secure()` in a small pure-Dart helper (`lib/features/billing/domain/clave_idempotencia.dart`, with a test). No `Random.secure` use exists in `lib/` today.
6. **There is no reusable "active products picker" widget.** CONTEXT says one exists, but `grep` finds none. Only `productosProvider` exists (`inventario_providers.dart` lines 17-20); it already filters `archivado_at is null` (repository lines 56-63). The billing line picker is a new bottom sheet that watches `productosProvider` (see "No Analog Found").
7. **`MovimientoStock` has no `nota` field.** `movimientoDesdeFila` (`supabase_inventario_repository.dart` lines 261-274) drops `nota`, and `MovimientoTile` (lines 31-33) prints `motivo.etiqueta`, which gives "Venta" or "Ajuste deshecho". To show "CC-0012" or "Anulada CC-0012" (D-13), add `nota` to the entity and mapper, and prefer it in the tile title when `origen == 'factura'`. `MovimientoTile` has no "Deshacer" action; that action exists only in the snackbar right after a manual adjustment (`ajuste_stock.dart` lines 95-128). So RESEARCH Pitfall 4 is already safe; the planner only needs to keep it that way.
8. **`ConsultaFormScreen` throws away the new consultation id.** `registrarConsultaProvider` returns `Future<String>` (`consultas_providers.dart` line 42), but the form only shows "Consulta guardada" and pops (`consulta_form_screen.dart` lines 157-175). The "Cobrar" entry after a consultation needs that id, so capture it and add a `SnackBarAction('Cobrar')`, as `anular_dosis_sheet.dart` lines 91-104 do.
9. **The client edit form lives in `cliente_detail_screen.dart`.** There is no separate client form: controllers are at line 41 and following, `_llenarControladores` at lines 83-89, `_esDirty` at lines 91-99, the `Cliente(...)` rebuild at lines 129-142, and the fields at lines 208-242. The cédula field goes there, and the new-client screen (`nuevo_cliente_mascota_screen.dart`) can stay unchanged because the field is optional.
10. **Clients are written by direct PostgREST update, not by RPC** (`supabase_cliente_repository.dart` lines 85-109, policy `clientes_update` in schema.sql lines 173-174). An `alter table public.clientes add column if not exists cedula` plus a length check is enough; the comment at schema.sql line 223 ("la política de update ya existente cubre la escritura de estas columnas nuevas") is the precedent.
11. **R44 currently expects exactly 9 tables** (`rls_smoke_test.sql` lines 4320-4323, two literal arrays). It must become 13 with `'clinica_servicios','cobro_contadores','cobro_items','cobros'` added in alphabetical order to both arrays. The comment at schema.sql line 3740 ("Guarda en las 9 tablas") must be updated too. The smoke header line 37 says "Total esperado: 261"; add a Phase 7 line under it.
12. **The Más screen tests mount `MasScreen`.** The Inventario row watches `resumenInventarioProvider` (`mas_screen.dart` lines 82-83), which forced overrides in 9 tests during Phase 6. Recommendation: make the Cobros row static (no provider watch), so no existing test needs a new override.

---

## File Classification

### Backend (SQL / scripts)

| New/modified file | Role | Data Flow | Closest analog | Quality |
|---|---|---|---|---|
| `supabase/schema.sql`: Fase 7 tables `cobros`, `cobro_items`, `cobro_contadores`, `clinica_servicios` | migration/model | append-only CRUD | `productos` / `movimientos_inventario` (4187-4248) + RLS/revokes (4250-4265) | exact |
| `supabase/schema.sql`: `alter table clientes add column cedula`, `alter table clinicas add column nit` | migration | CRUD | `alter table public.clinicas add column if not exists logo_path` + check (3174-3178) | exact |
| `supabase/schema.sql`: private `_aplicar_movimiento_stock` | service (internal definer helper) | transactional | `mover_stock` body (4399-4475) + `_plan_efectivo` revoke from authenticated (3439) | exact |
| `supabase/schema.sql`: RPCs `crear_cuenta_cobro`, `crear_cotizacion`, `editar_cotizacion`, `marcar_cobro_pagado` | service (definer RPC) | request-response, transactional | `crear_producto` (4268-4310), `actualizar_producto` (4313-4359) | exact |
| `supabase/schema.sql`: RPC `anular_cuenta_cobro` | service (definer RPC) | request-response | `anular_dosis` (2573-2603) + `mover_stock` deshacer arm (4449-4458) | exact |
| `supabase/schema.sql`: RPC `cobros_resumen` | service (stable RPC) | request-response | `inventario_resumen` (4477-4502) | exact |
| `supabase/schema.sql`: RPC `cobro_para_pdf` | service (stable RPC, jsonb) | request-response | `carne_de_mascota` (4000-4045, logo gating line 4033) | exact |
| `supabase/schema.sql`: `guardar_servicio` / `archivar_servicio` | service (admin RPC) | CRUD | `crear_producto` / `archivar_producto` (4361-4391) | exact |
| `supabase/schema.sql`: `actualizar_clinica` with `p_nit` | service (definer RPC) | request-response | current 5-arg version (3232-3292) | exact |
| `supabase/schema.sql`: guard triggers, `es_autor_en_mi_clinica` (5 arms), grants | config/security | event-driven | 4504-4545 | exact |
| `supabase/tests/rls_smoke_test.sql`: block T + R44 edit + header + `t_*` vars | test | request-response | block S (setup 4357-4397, S11 4673-4697, S19 4936-4982) + R44 (4295-4327) | exact |
| `supabase/tests/verify_live_schema.sh`: tables, RPCs, payloads | test/script | request-response | lines 73, 109-196, 263-289 | exact |

### Dart: domain and data

| File | Role | Data Flow | Analog | Quality |
|---|---|---|---|---|
| `lib/features/billing/domain/entities/cobro.dart` (replaces `factura.dart`) | model | transform | `producto.dart` (enums with `bd`/`desdeBd`/`etiqueta`, lines 1-61; entity 63-143) | role-match |
| `lib/features/billing/domain/entities/cobro_item.dart` | model | transform | `movimiento_stock.dart` (enum with `bd`+`etiqueta`, lines 1-27) | role-match |
| `lib/features/billing/domain/entities/servicio.dart` | model | transform | `Producto` (archived flag, price `int?`) | role-match |
| `ResumenCobros` (in `cobro.dart`) | model | transform | `ResumenInventario` (`producto.dart` 145-156) | exact |
| `lib/features/billing/domain/cobro_failure.dart` | model/error | request-response | `inventario_failure.dart` (1-37) | exact |
| `lib/features/billing/domain/numeracion.dart` (`formatearNumeroCobro`) | utility (pure) | transform | `stock.dart` / `formato.dart` `formatearMiles` | role-match |
| `lib/features/billing/domain/whatsapp_cobro.dart` (`mensajeCobroWhatsApp`) | utility (pure) | transform | `whatsapp_vacunas.dart` `mensajeCarneWhatsApp` | exact |
| `lib/features/billing/domain/clave_idempotencia.dart` | utility (pure) | transform | none (see No Analog) | none |
| `lib/features/billing/data/repositories/supabase_cobros_repository.dart` | service/repo | CRUD + RPC | `supabase_inventario_repository.dart` (1-333) | exact |
| `lib/features/billing/data/services/cobro_pdf_service.dart` | service | file-I/O (bytes) | `carne_pdf_service.dart` (1-408) | exact |
| `lib/features/inventory/domain/entities/movimiento_stock.dart` + repo mapper (modify: `nota`) | model | transform | same files | exact |
| `lib/features/inventory/presentation/widgets/movimiento_tile.dart` (modify: show `nota` for `factura`) | component | transform | same file, lines 31-38 | exact |
| `lib/features/clients/domain/entities/cliente.dart` (+ `cedula`) | model | transform | `direccion` field in the same file | exact |
| `lib/features/clients/data/repositories/supabase_cliente_repository.dart` (+ `cedula` in update and `_fromRow`) | repo | CRUD | `direccion` handling (lines 95, 141, 150) | exact |
| `lib/features/clinic/domain/clinica.dart` (+ `nit`) | model | transform | `direccion` in the same file | exact |
| `lib/features/clinic/data/repositories/supabase_clinica_repository.dart` (+ `p_nit`) | repo | request-response | `paramsActualizarClinica` (28-40) | exact |
| `lib/features/clinic/presentation/providers/datos_clinica_providers.dart` (+ `nit` in `GuardarDatosClinica.call`) | provider | request-response | same file 40-99 | exact |

### Dart: providers and routes

| File | Role | Data Flow | Analog | Quality |
|---|---|---|---|---|
| `lib/features/billing/presentation/providers/cobros_providers.dart` | provider | CRUD / request-response | `inventario_providers.dart` (1-178) | exact |
| `lib/features/billing/presentation/providers/borrador_cobro_provider.dart` (Notifier) | provider/store | event-driven (local) | none with a Notifier draft (see No Analog) | partial |
| `lib/features/billing/presentation/providers/cobro_pdf_providers.dart` (`cobroPdfServiceProvider`, `compartirCobroProvider`) | provider | file-I/O | `carne_pdf_providers.dart` (1-13) + `historia_clinica_pdf_providers.dart` (22-35) | exact |
| `cobroDeCitaProvider` (in `cobros_providers.dart`) | provider | request-response | `dosis_cita_providers.dart` (7-13) + `dosisDeCita` repo (299-315) | exact |
| `lib/features/billing/presentation/cobros_routes.dart` | route | request-response | `inventario_routes.dart` (1-51) + `rutaRegistrarDosis` (`vacunacion_routes.dart` 41-56) | exact |
| `lib/core/router/app_router.dart` (import + `...cobrosRoutes`) | route/config | request-response | line 94 `...inventarioRoutes` | exact |

### Dart: screens and widgets

| File | Role | Data Flow | Analog | Quality |
|---|---|---|---|---|
| `screens/cobros_screen.dart` (header, toggle, cards, FAB) | component | CRUD read | `inventario_screen.dart` (list, skeleton, error, FAB with padlock 114-140) | role-match |
| `screens/cobro_form_screen.dart` (draft, lines, price override) | component | CRUD write | `producto_form_screen.dart` (COP fields 451-472, `parsearCop`) + `consulta_form_screen.dart` (catch + `manejarLimitePlan`, 157-182) | role-match |
| `screens/cobro_detail_screen.dart` (pay, void, convert, share) | component | CRUD read + actions | `producto_detail_screen.dart` + `compartir_carne_sheet.dart` | role-match |
| `screens/servicios_screen.dart` (admin list) | component | CRUD | `inventario_screen.dart` + `puedeAdministrarInventarioProvider` (`inventario_providers.dart` 43-47) | role-match |
| `widgets/anular_cobro_sheet.dart` | component (modal) | request-response | `anular_dosis_sheet.dart` (19-115) | exact |
| `widgets/marcar_pagado_sheet.dart` (method chips) | component (modal) | request-response | `anular_dosis_sheet.dart` (chip selection 144-148) | role-match |
| `widgets/compartir_cobro_sheet.dart` | component (modal) | file-I/O + external app | `compartir_carne_sheet.dart` (1-200) | exact |
| `widgets/cobro_estado_chip.dart` | component (pill) | transform | `lib/core/widgets/status/app_status_chip.dart` (record `_spec`, line 19) / `insignia_stock.dart` | exact |
| `widgets/selector_linea_sheet.dart` (service / product / Otro) | component (modal) | CRUD read | none (see No Analog) | partial |
| `lib/features/home/presentation/screens/mas_screen.dart` (Cobros row) | component | navigation | Inventario row (199-231) | exact |
| `lib/features/appointments/presentation/screens/completar_cita_screen.dart` ("Cobrar") | component | navigation | `_dosisBloque` (lines 105-188 in file numbering) | exact |
| `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart` ("Cobrar" snackbar action) | component | navigation | `anular_dosis_sheet.dart` 91-104 (`SnackBarAction` + `router.push`) | exact |
| `lib/features/clients/presentation/screens/cliente_detail_screen.dart` (cédula field + "Nueva cuenta de cobro") | component | CRUD write + navigation | `_botonAgendarCita` (294-327) + field list (208-242) | exact |
| `lib/features/clinic/presentation/screens/datos_clinica_screen.dart` ("NIT o cédula" field) | component | CRUD write | `Teléfono` field (359-364) | exact |

### Tests

| File | Role | Analog | Quality |
|---|---|---|---|
| `test/helpers/fake_cobros.dart` (`FakeCobrosRepository`, `cobroDePrueba`) | test helper | `test/helpers/fake_inventario.dart` (1-90+) | exact |
| `test/helpers/fake_clinica.dart` (modify: `nit`) | test helper | same file 33-58 | exact |
| `test/helpers/fake_clientes.dart` (no signature change; `Cliente` gains an optional field) | test helper | same | exact |
| `test/helpers/fake_pdf.dart` (reuse `fuentesDePrueba`, `fuenteDisplayDePrueba`, `CompartirPdfFalso`) | test helper | same | exact |
| `test/cobro_pdf_service_test.dart` | unit | `test/carne_pdf_service_test.dart` | exact |
| `test/supabase_cobros_repository_test.dart` | unit | `test/supabase_inventario_repository_test.dart` | exact |
| `test/cobros_invalidacion_test.dart` | unit (providers) | `test/inventario_invalidacion_test.dart` | exact |
| `test/numeracion_test.dart`, `test/cobro_test.dart`, `test/whatsapp_cobro_test.dart` | unit | `test/producto_test.dart`, `test/whatsapp_vacunas_test.dart` | exact |
| `test/cobros_screen_test.dart`, `test/cobro_detail_screen_test.dart`, `test/compartir_cobro_test.dart` | widget | `test/inventario_screen_test.dart` | role-match |
| `test/router_cobros_cross_shell_test.dart` | widget/router | `test/router_inventario_cross_shell_test.dart` | exact |
| `test/clinica_contrato_test.dart` (modify: key set + `p_nit`) | unit | same file 40-61 | exact |

---

## Pattern Assignments

### `supabase/schema.sql`: Fase 7 tables (migration, append-only)

**Analog:** the Phase 6 block, `schema.sql` lines 4176-4265.

**Placement:** a new header `-- ===== Fase 7: Facturación (delta idempotente) =====` after line 4545 (the last Phase 6 grant) and before `notify pgrst, 'reload schema';` (line 4547), which stays as the very last line. Order inside the block: tables, then indexes and triggers, then RLS and revokes, then the private helper, then the RPCs, then guard triggers, then `es_autor_en_mi_clinica`, then grants. `language sql` functions validate referenced tables when they are created.

**Table with check constraints and a self-check** (schema.sql 4187-4204):
```sql
create table if not exists public.productos (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  nombre text not null check (char_length(btrim(nombre)) between 1 and 80),
  ...
  precio_venta_cop int null check (precio_venta_cop is null or precio_venta_cop between 0 and 100000000),
  creado_por uuid not null references public.perfiles(id) on delete restrict,
  archivado_at timestamptz null,
  archivado_por uuid null references public.perfiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, clinica_id)
);
```
For `cobros`, apply RESEARCH "Data model": `unique (clinica_id, tipo, numero)`, `unique (clinica_id, clave_idempotencia)`, and plain FKs with `on delete set null` for `cliente_id`, `mascota_id`, `cita_id` and `consulta_id`, plus name snapshots (Pitfall 11). The tipo/estado checks follow the self-check style of `dosis_anulacion_consistente` (06-PATTERNS line 103): `check (anulada = (motivo_anulacion is not null))`.

**Composite FK and a named FK to perfiles in an idempotent block** (schema.sql 4221-4233):
```sql
do $$ begin
  alter table public.movimientos_inventario
    add constraint movimientos_producto_misma_clinica_fkey foreign key (producto_id, clinica_id)
    references public.productos(id, clinica_id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table public.movimientos_inventario
    add constraint movimientos_veterinario_perfil_fkey foreign key (veterinario_id)
    references public.perfiles(id) on delete restrict;
exception when duplicate_object then null;
end $$;
```
Use this for `cobro_items (cobro_id, clinica_id) -> cobros(id, clinica_id) on delete cascade`, which needs `unique (id, clinica_id)` on `cobros`. Name the author FK `cobros_creado_por_perfil_fkey` if the list embeds the author (and add a probe for it, see verify_live_schema).

**Partial unique index, as for `clinica_servicios`** (schema.sql 4235-4238):
```sql
create unique index if not exists productos_clinica_nombre_activo_uq
  on public.productos (clinica_id, lower(btrim(nombre))) where archivado_at is null;
```

**`updated_at` trigger** (schema.sql 4246-4248): copy it for `cobros` (quotes are edited) and `clinica_servicios`.

**RLS read-only plus revokes** (schema.sql 4250-4265):
```sql
alter table public.productos enable row level security;
drop policy if exists productos_select on public.productos;
create policy productos_select on public.productos for select to authenticated
  using (public.es_veterinario() and clinica_id = public.mi_clinica_id());
revoke all on table public.productos from anon;
revoke insert, update, delete, truncate on table public.productos from authenticated;
```
`cobro_contadores`: enable RLS, **no policy**, `revoke all ... from anon, authenticated`.

**New nullable columns** (schema.sql 3174-3178):
```sql
alter table public.clinicas add column if not exists logo_path text;

alter table public.clinicas drop constraint if exists clinicas_logo_path_formato;
alter table public.clinicas add constraint clinicas_logo_path_formato
  check (logo_path is null or logo_path ~ '^[0-9a-f-]{36}/logo-[0-9]{10,16}\.jpg$');
```
Use the same drop-then-add shape for `clinicas_nit_largo check (nit is null or char_length(nit) <= 30)` and `clientes_cedula_largo check (cedula is null or char_length(cedula) <= 20)`.

---

### `supabase/schema.sql`: `_aplicar_movimiento_stock` (private helper)

**Analog:** the `mover_stock` body (schema.sql 4399-4475), copied into a new function. **Do not modify `mover_stock`.**

**Lock, no-negative check, ledger insert** (schema.sql 4438-4473):
```sql
  select * into v_p from public.productos
   where id = p_producto_id and clinica_id = v_clinica
   for update;
  if not found or v_p.archivado_at is not null then
    raise exception 'Producto no disponible.' using errcode = 'IN002';
  end if;
  ...
  v_nueva := v_p.cantidad + p_delta;
  if v_nueva < 0 then
    raise exception 'No hay suficiente stock (quedan %).', v_p.cantidad using errcode = 'IN001';
  end if;

  update public.productos set cantidad = v_nueva where id = p_producto_id and clinica_id = v_clinica;

  insert into public.movimientos_inventario
    (clinica_id, producto_id, delta, cantidad_resultante, motivo, origen, ref_id, nota, deshace_id, veterinario_id)
  values
    (v_clinica, p_producto_id, p_delta, v_nueva, p_motivo, p_origen, p_ref_id, nullif(btrim(p_nota), ''), p_deshace_id, auth.uid())
  returning id into v_mov;
```
Differences for the helper:
- It takes `p_clinica` as a parameter instead of calling `mi_clinica_id()`.
- `archivado_at is not null` is allowed when `p_permitir_archivado` is set (voiding, Pitfall 3).
- `origen` is fixed to `'factura'`.
- IN001 carries `detail = json_build_object('producto', v_p.nombre, 'quedan', v_p.cantidad, 'unidad', v_p.unidad)::text` so Dart can build the message.

**Revoke from authenticated** (the precedent is `_plan_efectivo`, schema.sql 3439):
```sql
revoke all on function public._plan_efectivo(uuid, date) from public, anon, authenticated;
```

---

### `supabase/schema.sql`: billing RPCs (definer, transactional)

**Analog:** `crear_producto` (schema.sql 4268-4310).

**Function header, guard and drop-before-create** (4268-4290):
```sql
drop function if exists public.crear_producto(text, text, int, int, text, date, int, int);
create or replace function public.crear_producto(
  p_nombre text,
  ...
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
  v_id uuid;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario de una clínica puede gestionar el inventario.' using errcode = 'insufficient_privilege';
  end if;
```
Copy `drop function if exists <exact signature>` before every `create or replace`, plus `#variable_conflict use_column` (needed because `returns table (id, numero, ya_existia)` columns shadow table columns).

**Admin-only check** (`archivar_producto` 4376-4378 and `actualizar_producto` 4343-4348): use it for `guardar_servicio` / `archivar_servicio`, and for the void check `(public.es_admin_clinica() or v_c.creado_por = auth.uid())`.

**Void with reason** (`anular_dosis`, schema.sql 2573-2603):
```sql
  v_motivo text := nullif(trim(coalesce(p_motivo, '')), '');
  ...
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
```
RESEARCH sets the reason at 3..200 characters and the "already voided" error as `BC001` instead of `check_violation`.

**Reversal by `deshace_id`** (`mover_stock` 4449-4458): the unique index `movimientos_deshace_uq` (4239-4240) makes a double reversal impossible. Pass `deshace_id = original movement id` for each reverse movement.

**Summary RPC** (`inventario_resumen`, 4478-4502): `returns table`, `stable`, `v_hoy date := public._hoy_bogota()`, `count(*) filter (...)`. `cobros_resumen` uses `sum(total_cop) filter (where estado='pagada' and pagada_el >= date_trunc('month', v_hoy))` and casts to `bigint`.

**PDF payload with the plan-gated logo** (`carne_de_mascota`, 4030-4036):
```sql
    'clinica', (
      select jsonb_build_object(
        'nombre', cl.nombre, 'ciudad', cl.ciudad, 'direccion', cl.direccion, 'telefono', cl.telefono, 'logo_path', case when coalesce((select e.logo_permitido from public._plan_efectivo(cl.id) e), false) then cl.logo_path end
      )
      from public.clinicas cl where cl.id = v_clinica
    ),
```
Add `'nit', cl.nit`. The client block comes from the cobro snapshot (`cliente_nombre`, `cliente_cedula`) and never includes the phone (D-24).

---

### `supabase/schema.sql`: `actualizar_clinica(..., p_nit)`

**Analog:** the same function (schema.sql 3232-3292).

**Trim and length validation** (3241-3260):
```sql
  v_telefono text := trim(coalesce(p_telefono, ''));
  ...
  if v_nombre = '' or length(v_nombre) > 120
     or length(v_ciudad) > 80
     or length(v_direccion) > 160
     or length(v_telefono) > 30 then
    raise exception 'Revisa los datos de la clínica.' using errcode = 'check_violation';
  end if;
```
Add `v_nit text := nullif(trim(coalesce(p_nit, '')), '')` with `length(v_nit) > 30`, `nit = v_nit` in the update, and `'nit', v_row.nit` in the returned jsonb (3279-3286).

**Signature change:** in the Fase 7 block, run `drop function if exists public.actualizar_clinica(text, text, text, text, text);` and then recreate it with 6 arguments, `p_nit text default null`. The grants at 3291-3292 are for the old signature: emit new `revoke`/`grant` for `(text, text, text, text, text, text)` in the Fase 7 grants section. Leave lines 3232-3292 untouched; the file is re-run top to bottom, so the later block wins. Update the `verify_live_schema.sh` payload (line 188) to include `"p_nit":null`.

---

### `supabase/schema.sql`: guard, authorship, grants

**Guard triggers** (schema.sql 4504-4509):
```sql
drop trigger if exists guard_solo_lectura on public.productos;
create trigger guard_solo_lectura before insert or update or delete on public.productos for each row execute function public.guard_solo_lectura();
```
Repeat this for `cobros`, `cobro_items`, `clinica_servicios` and `cobro_contadores` (13 tables in total). Also update the comment at line 3740.

**`es_autor_en_mi_clinica`** (schema.sql 4512-4533): copy **all 4 arms** (citas, consultas via mascotas, dosis_aplicadas, movimientos_inventario) word for word, then add:
```sql
  or exists (
    select 1 from public.cobros c where c.clinica_id = public.mi_clinica_id()
      and p_id in (c.creado_por, c.pagado_por, c.anulada_por)
  )
  or exists (
    select 1 from public.clinica_servicios s where s.clinica_id = public.mi_clinica_id() and s.creado_por = p_id
  )
```
followed by the same `revoke`/`grant` pair (4532-4533).

**Grants** (schema.sql 4535-4545): one `revoke all ... from public, anon;` + `grant execute ... to authenticated;` pair per exact signature.

---

### `supabase/tests/rls_smoke_test.sql`: block T

**Analog:** block S.

**Header** (line 37): add a line `-- Fase 7 (bloque T, N checks): facturación — ... Total esperado: 261+N.`

**Variables** (lines 151-160, the `-- Fase 6 (bloque S)` declarations): add `-- Fase 7 (bloque T)` with `t_*` uuids (`t_vet_admin`, `t_vet_col`, `t_vet_otro`, `t_c`, `t_c_otro`, `t_p1`, `t_cobro`, `t_n`, `t_n2`, `t_row record`, `t_sql text`, `t_json jsonb`).

**Placement:** after S23 ends (around line 5076, `exception when others then failures := failures || ('S23 error inesperado: ' ...)`) and before the block `-- Volver a postgres y reportar.`

**Setup with own fixtures** (lines 4357-4397): insert `auth.users` with `raw_user_meta_data` `rol/nombre/clinica_nombre`, read `clinica_id` from `perfiles`, and add a colleague through `generar_invitacion_clinica()` + `codigo_invitacion`. Never reuse `vet_a`/`vet_b` or `s_*`; their plans get mutated earlier. Wrap the setup in `begin ... exception when others then failures := failures || ('SETUPT error inesperado: ' || sqlerrm); end;`.

**Expected error and "nothing changed" check** (S11, 4673-4697):
```sql
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
    ...
    if s_row.cantidad is distinct from 3 or s_n <> s_n2 then
      failures := failures || format('S11 el stock insuficiente cambió datos: ...');
    end if;
  exception when others then
    failures := failures || ('S11 error inesperado: ' || sqlerrm);
  end;
```
Use this shape for T14-T16: IN001 leaves no header, items or movements, and the counter is not burned.

**Read-only loop over several SQL statements** (S19, 4936-4982): put the plan in read-only mode (`update clinica_planes set plan='gratis', miembros_max=1, ...`), then `foreach s_sql in array array[...] loop begin execute s_sql; ... exception when others then if sqlstate is distinct from 'LP004' ...`. Use it for T32 (create, pay, void).

**R44 edit** (lines 4320-4323): change `cardinality(r_arr) <> 9` to `<> 13` and both literal arrays to:
```sql
array['cita_mascotas', 'citas', 'clientes', 'clinica_servicios', 'cobro_contadores', 'cobro_items', 'cobros', 'consultas', 'dosis_aplicadas', 'mascota_pesos', 'mascotas', 'movimientos_inventario', 'productos']
```
Also update the comment at line 4295 ("exactamente 9 tablas").

---

### `supabase/tests/verify_live_schema.sh`

**Analog:** the same file.
- **Tables:** add `cobros cobro_items clinica_servicios cobro_contadores` to the loop on line 73. The `id` column works for all except `cobro_contadores` (use `col=clinica_id`, the same `[ "$t" = ... ] && col=...` pattern as lines 75-76).
- **RPCs:** add `crear_cuenta_cobro crear_cotizacion editar_cotizacion marcar_cobro_pagado anular_cuenta_cobro cobros_resumen cobro_para_pdf guardar_servicio archivar_servicio` to the list on line 109. Add a `case` payload for each RPC with required parameters (lines 112-123 pattern). Example: `crear_cuenta_cobro) payload='{"p_clave":"00000000-0000-0000-0000-000000000000","p_cliente_id":"00000000-0000-0000-0000-000000000000","p_items":[]}' ;;`.
- **`_aplicar_movimiento_stock`:** add it to the 404 "not exposed" branch, like `_plan_efectivo` (line 212).
- **`actualizar_clinica`:** add `"p_nit":null` to the payload on line 188.
- **Embed probe:** if the repository embeds the author, add `probe_embed cobros '*, autor:perfiles!cobros_creado_por_perfil_fkey(nombre)' 'cobros autor embed' allow_denied` and `probe_embed cobros '*, cobro_items(*)' 'cobros items embed' allow_denied` next to line 289.

---

### `lib/features/billing/domain/cobro_failure.dart` (error model)

**Analog:** `lib/features/inventory/domain/inventario_failure.dart` (lines 1-37, full file):
```dart
import '../../../core/errors/limite_plan.dart';

/// Clasificación del error para que la UI decida (p. ej. refrescar la lista).
enum ErrorInventario {
  stockInsuficiente,
  noDisponible,
  ...
  sinPermiso,
  datosInvalidos,
  sinConexion,
  soloLectura,
  otro,
}

class InventarioFailure implements Exception, ConLimitePlan {
  const InventarioFailure(
    this.message, {
    this.tipo = ErrorInventario.otro,
    this.limite,
  });

  final String message;
  final ErrorInventario tipo;

  @override
  final LimitePlan? limite;

  @override
  String toString() => message;
}
```
Enum `ErrorCobro { stockInsuficiente, productoNoDisponible, yaAnulada, yaConvertida, sinPermiso, datosInvalidos, sinConexion, soloLectura, otro }`. Keep `ConLimitePlan` so that `manejarLimitePlan` / LP004 works.

---

### `lib/features/billing/domain/entities/cobro.dart`, `cobro_item.dart`, `servicio.dart` (models)

**Analog:** `producto.dart` (lines 1-156) and `movimiento_stock.dart` (lines 1-27).

**Enum with a DB value and a label** (`movimiento_stock.dart` 2-18):
```dart
enum MotivoMovimiento {
  compra('compra', 'Compra'),
  ...
  const MotivoMovimiento(this.bd, this.etiqueta);
  final String bd;
  final String etiqueta;
  static MotivoMovimiento desdeBd(String v) => MotivoMovimiento.values
      .firstWhere((m) => m.bd == v, orElse: () => MotivoMovimiento.conteo);
}
```
Use it for:
- `TipoCobro` (`cotizacion`→'Cotización', `cuentaCobro`→'Cuenta de cobro');
- `EstadoCobro` (`abierta`, `convertida`, `pendiente`, `pagada`, `anulada`);
- `MetodoPago` (`efectivo`, `nequi`, `daviplata`, `transferencia`, `tarjeta`, `otro`; the labels are the D-15 chips);
- `TipoLinea` (`servicio`, `producto`, `otro`).

**Entity with a `///` doc, `const` constructor, computed getters and `copyWith`** (`producto.dart` 63-143). `CobroItem` uses `final int cantidad` and `int get subtotalCop => cantidad * precioUnitarioCop`. Do not copy the stub's `double` (`factura.dart` lines 12-16). Delete `factura.dart`; nothing imports it.

**Summary value class** (`producto.dart` 145-156): `ResumenCobros({this.cobradoMes = 0, this.porCobrar = 0})`.

---

### `lib/features/billing/data/repositories/supabase_cobros_repository.dart` (repo, CRUD + RPC)

**Analog:** `supabase_inventario_repository.dart` (full file, 1-333).

**Imports** (lines 1-13):
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/limite_plan_postgrest.dart';
import '../../../../core/errors/limite_plan.dart';
import '../../../vaccination/domain/fecha_bd.dart';
```

**`_run` wrapper with a network branch** (lines 34-49):
```dart
  Future<T> _run<T>(
    Future<T> Function() op,
    String generico, {
    String sinConexion = kMensajeSinConexion,
  }) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      throw inventarioFailureDe(e);
    } catch (e) {
      if (esErrorDeRed(e)) {
        throw InventarioFailure(sinConexion, tipo: ErrorInventario.sinConexion);
      }
      throw InventarioFailure(generico);
    }
  }
```
`sinConexion` for creation: `'Sin conexión, el cobro no se creó.'` (D-21). Import `esErrorDeRed` from the inventory repository (it is a top-level `@visibleForTesting` function, lines 328-332) or move it to `lib/core/data/` in a separate refactor task. Do not duplicate it.

**RPC with `@visibleForTesting` params builders** (lines 76-100, 182-240):
```dart
  Future<String> crearProducto({...}) => _run(() async {
    final r = await _client.rpc('crear_producto', params: paramsCrearProducto(...));
    return r as String;
  }, 'No pudimos guardar el producto. Intenta de nuevo.');

  @visibleForTesting
  static Map<String, Object?> paramsCrearProducto({...}) => {
    'p_nombre': nombre.trim(),
    ...
  };
```
`paramsCrearCuentaCobro` sends `p_clave`, `p_cliente_id`, `p_mascota_id`, `p_cita_id`, `p_consulta_id`, `p_cotizacion_id`, and `p_items` as a `List<Map>` with `{tipo, producto_id?, servicio_id?, descripcion, cantidad, precio_unitario_cop}`. It never sends a total or a number.

**`returns table` read** (lines 146-151): `final f = _filas(r).first;` then `(id: f['id'], numero: f['numero'], yaExistia: f['ya_existia'])`.

**Embedded read with a FK hint** (lines 158-169):
```dart
        final r = await _client
            .from('movimientos_inventario')
            .select('*, autor:perfiles!movimientos_veterinario_perfil_fkey(nombre)')
            .eq('producto_id', productoId)
            .order('created_at', ascending: false)
            .limit(kMovimientosHistorial);
```
For the list: `.from('cobros').select().eq('tipo', tipo.bd).order('created_at', ascending: false)`. For the detail: `select('*, cobro_items(*)')`. "Cobro de una cita": `.from('cobros').select('id, numero, estado').eq('cita_id', citaId).neq('estado', 'anulada')`, modeled on `dosisDeCita` (`supabase_vacuna_repository.dart` 299-315).

**Error code to type to message, one translation table** (lines 276-321):
```dart
ErrorInventario _tipoDe(PostgrestException e, LimitePlan? limite) {
  if (limite == LimitePlan.soloLectura) return ErrorInventario.soloLectura;
  return switch (e.code) {
    'IN001' => ErrorInventario.stockInsuficiente,
    'IN002' => ErrorInventario.noDisponible,
    ...
    '42501' => ErrorInventario.sinPermiso,
    '23514' => ErrorInventario.datosInvalidos,
    _ => ErrorInventario.otro,
  };
}
```
Add `'BC001' => yaAnulada` (or invalid state) and `'BC002' => yaConvertida`. For IN001, parse `e.details` as JSON (`producto`, `quedan`, `unidad`) and build the message with `Unidad.desdeBd(unidad).etiqueta(quedan)` (Finding 4). Fall back to a generic message if `details` does not parse.

---

### `lib/features/billing/data/services/cobro_pdf_service.dart` (service, file I/O)

**Analog:** `carne_pdf_service.dart` (lines 1-408).

**Imports and reused seams** (lines 1-16, 26-32):
```dart
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../clinical_history/data/services/historia_clinica_pdf_service.dart'
    show CargarFuentesPdf;
```
Import `CargarFuenteDisplayPdf`, `CargarLogoPdf`, `ValidarImagenPdf` and `imagenDecodificable` with `show` from `../../../vaccination/data/services/carne_pdf_service.dart`. Do not copy them.

**Constructor with injected seams** (lines 66-83), **non-throwing logo** (105-116) and **display-font fallback** (95-103):
```dart
  CarnePdfService({
    CargarFuentesPdf? cargarFuentes,
    CargarFuenteDisplayPdf? cargarFuenteDisplay,
    CargarLogoPdf? cargarLogo,
    ValidarImagenPdf? validarImagen,
    Duration timeoutLogo = const Duration(seconds: 5),
  }) : _cargarFuentes = cargarFuentes ?? _cargarFuentesReales,
  ...
  Future<pw.MemoryImage?> _logo(String? path) async {
    final cargar = _cargarLogo;
    if (path == null || path.isEmpty || cargar == null) return null;
    try {
      final bytes = await cargar(path).timeout(_timeoutLogo);
      if (!await _validarImagen(bytes)) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
```
`_cargarFuentesReales` stays private per file (lines 18-22, Figtree). Copy those 4 lines.

**`MultiPage` with a header (logo + clinic + title), a 3-part footer with "Hecho con VetApp", and a striped table** (lines 202-385). The header's right side shows `'Cuenta de cobro'` / `'Cotización'` in `titulos.titulo` and the number. Below the clinic name it shows `NIT o cédula: ...` when present, then the phone and the address. The table columns are `Descripción | Cant. | Valor unitario | Subtotal`, with `formatearCop`. The total row is bold. The voided state gets an "ANULADA" banner styled like the `'Vencida'` cell (lines 245-271: a destructive border box).

**Wrap every failure in the typed error** (lines 387-390):
```dart
      return await doc.save();
    } catch (_) {
      throw const VacunaFailure('No pudimos generar el PDF. Intenta de nuevo.');
    }
```
Throw `CobroFailure` here.

**Pure file-name helper** (lines 398-407): `static String nombreArchivo(String numero, String cliente)` returns `CC-0012_<Cliente>.pdf` with the same `[^A-Za-z0-9]+` to `_` sanitizer and trimmed underscores.

**Pure `@visibleForTesting` row builder** (`filasPdf`, lines 147-169): `static List<List<String>> filasPdf(Cobro c)`, so tests check content without parsing the PDF.

---

### `lib/features/billing/presentation/providers/cobros_providers.dart` (provider)

**Analog:** `inventario_providers.dart` (lines 1-178).

**Repository and read providers** (lines 11-41):
```dart
final inventarioRepositoryProvider = Provider<SupabaseInventarioRepository>((ref) {
  return SupabaseInventarioRepository(ref.watch(supabaseClientProvider));
});

final productosProvider = FutureProvider.autoDispose<List<Producto>>((ref) {
  return ref.watch(inventarioRepositoryProvider).productos();
});

final productoProvider = FutureProvider.autoDispose.family<Producto?, String>((ref, id) {
  return ref.watch(inventarioRepositoryProvider).producto(id);
});
```
Create `cobrosProvider.family<List<Cobro>, TipoCobro>`, `cobroProvider.family<Cobro?, String>`, `resumenCobrosProvider`, `serviciosProvider` and `cobroDeCitaProvider.family`.

**Admin flag** (lines 43-47):
```dart
final puedeAdministrarInventarioProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(authProfileProvider).value?.esAdmin ?? false,
);
```
Copy it as `puedeAdministrarServiciosProvider`. The void button needs `esAdmin || cobro.creadoPor == profile.id`.

**Invalidation helper** (lines 49-59):
```dart
void invalidarInventario(Ref ref, {String? productoId}) {
  ref.invalidate(productosProvider);
  ref.invalidate(resumenInventarioProvider);
  if (productoId != null) {
    ref.invalidate(productoProvider(productoId));
    ref.invalidate(movimientosProvider(productoId));
  }
}
```
`invalidarCobros(Ref ref, {String? cobroId, Iterable<String> productoIds = const [], String? citaId})` invalidates:
- `cobrosProvider` (the whole family);
- `cobroProvider(id)`;
- `resumenCobrosProvider`;
- `cobroDeCitaProvider(citaId)`;
- for each product id, `invalidarInventario(ref, productoId: id)`.

**Actions class with rethrow and invalidation** (lines 61-63, 151-177):
```dart
final inventarioActionsProvider = Provider<InventarioActions>(InventarioActions.new);

    try {
      final r = await _repo.moverStock(...);
      invalidarInventario(_ref, productoId: productoId);
      return r;
    } on InventarioFailure catch (e) {
      if (e.tipo == ErrorInventario.stockInsuficiente || ...) {
        invalidarInventario(_ref, productoId: productoId);
      }
      rethrow;
    }
```
**Deviation (RESEARCH, WR-03 lesson):** in `CobrosActions`, invalidate on **every** `CobroFailure` before `rethrow`, including `sinConexion` and `otro`, because the server may have committed.

**PDF providers** (`carne_pdf_providers.dart` 7-13 and `historia_clinica_pdf_providers.dart` 22-35):
```dart
final carnePdfServiceProvider = Provider<CarnePdfService>(
  (ref) => CarnePdfService(
    cargarFuenteDisplay: () => PdfGoogleFonts.caprasimoRegular(),
    cargarLogo: (path) =>
        ref.read(clinicaLogoDatasourceProvider).descargar(path),
  ),
);

final compartirPdfProvider = Provider<CompartirPdf>((ref) {
  return ({required Uint8List bytes, required String filename}) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (_) {
      throw const ConsultaFailure('No pudimos generar el PDF. Intenta de nuevo.');
    }
  };
});
```
Add `compartirCobroProvider` with the same `CompartirPdf` typedef, imported with `show CompartirPdf`, that throws `CobroFailure`. This way the test fake `CompartirPdfFalso` works unchanged.

---

### `lib/features/billing/presentation/cobros_routes.dart` + `app_router.dart` (route)

**Analog:** `inventario_routes.dart` (lines 1-51) and `rutaRegistrarDosis` (`vacunacion_routes.dart` lines 41-56).

**Top-level routes outside the shell (G5), literal paths before `:id`** (`inventario_routes.dart` 7-38):
```dart
/// Rutas de inventario de primer nivel (fuera del shell de la barra inferior)
/// ... empujar una ruta de una rama del shell duplica la página del shell en
/// el Navigator raíz (G5).
final List<GoRoute> inventarioRoutes = [
  GoRoute(path: '/inventario', builder: ...),
  GoRoute(path: kRutaNuevoProducto, builder: (_, _) => const ProductoFormScreen()),
  GoRoute(path: '/inventario/:id/editar', ...),
  GoRoute(path: '/inventario/:id', ...),
];
```
Routes: `/cobros`, `/cobros/nuevo`, `/cobros/servicios`, `/cobros/:id`.

**Query parameters encoded with `?` null-aware entries** (`vacunacion_routes.dart` 43-56):
```dart
String rutaRegistrarDosis({required String mascotaId, String? codigo, String? citaId, String? categoria}) => Uri(
  path: '/dosis/nueva',
  queryParameters: {'mascotaId': mascotaId, 'codigo': ?codigo, 'citaId': ?citaId, 'categoria': ?categoria},
).toString();
```
`rutaNuevoCobro({String? clienteId, String? mascotaId, String? citaId, String? consultaId, String? cotizacionId, TipoCobro tipo = TipoCobro.cuentaCobro})`.

**Router registration** (`app_router.dart` lines 20 and 94): add `import '../../features/billing/presentation/cobros_routes.dart';` and `...cobrosRoutes,` next to `...inventarioRoutes,`.

---

### `screens/cobros_screen.dart` (list + header + toggle + FAB)

**Analog:** `inventario_screen.dart` (lines 1-200).

- **Structure** (lines 61-112): `Scaffold(appBar: AppTopBar(title: 'Cobros'))`, a fixed header above an `Expanded(async.when(skipLoadingOnRefresh: true, data:, loading: () => const _Esqueleto(), error: (_, _) => _Error(onReintentar: ...)))`.
- **Pull to refresh** (lines 55-59):
  ```dart
  Future<void> _refrescar() async {
    ref.invalidate(productosProvider);
    ref.invalidate(resumenInventarioProvider);
    await ref.read(productosProvider.future).catchError((_) => <Producto>[]);
  }
  ```
- **Toggle:** use `AppFilterChip` (import at line 12, use at line 200) for "Cotizaciones / Cuentas de cobro".
- **FAB with padlock in read-only mode** (lines 114-140):
  ```dart
  Widget _botonNuevoProducto(bool puedeEscribir) {
    Future<void> abrir() async {
      final ok = await asegurarEscritura(context, ref, plan: ref.read(miPlanProvider).value);
      if (!ok || !mounted) return;
      context.push(kRutaNuevoProducto);
    }
    final boton = FloatingActionButton.extended(
      onPressed: abrir,
      icon: Icon(iconoEscritura(puedeEscribir, Icons.add)),
      label: const Text('Nuevo producto'),
    );
    if (puedeEscribir) return boton;
    return Semantics(button: true, label: semanticaEscritura(puedeEscribir, 'Nuevo producto'), onTap: abrir, excludeSemantics: true, child: boton);
  }
  ```
  The label is "Nueva cuenta de cobro".

---

### `screens/cobro_form_screen.dart` (draft form)

**Analogs:** `producto_form_screen.dart` (COP fields) and `consulta_form_screen.dart` (submit).

- **COP input** (`producto_form_screen.dart` lines 451-472): `AppTextField(label: 'Precio ...', prefixText: '\$ ', ...)` with `parsearCop(ctrl.text)` (lines 100, 129). It returns `({int? valor, String? error})` (`formato.dart` line 147).
- **Submit with typed catch and plan gate** (`consulta_form_screen.dart` lines 157-182):
  ```dart
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consulta guardada')));
      context.pop();
    } on ConsultaFailure catch (e) {
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
  ```
  On failure, the draft stays (D-21). On `yaExistia == true`, show "Cuenta de cobro ya creada" and navigate to the detail.

---

### `widgets/anular_cobro_sheet.dart` and `widgets/marcar_pagado_sheet.dart` (modal)

**Analog:** `anular_dosis_sheet.dart` (lines 19-115).

**Capture the messenger and router before opening** (lines 19-37):
```dart
Future<void> showAnularDosisSheet(BuildContext context, DosisCarne dosis, {required String mascotaId}) {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AnularDosisSheet(dosis: dosis, mascotaId: mascotaId, messenger: messenger, router: router),
  );
}
```
**Reason chips plus "Otro motivo" with free text, `maxLength: 120`, destructive CTA disabled until valid** (lines 39-40, 70-74, 144-157, 185-187). For the payment sheet, the same chip selection with the 6 `MetodoPago` values and a primary CTA "Marcar como pagada".

**Submit, then pop, then a snackbar with a follow-up action** (lines 76-115). After voiding, offer "Emitir de nuevo" with `router.push(rutaNuevoCobro(...))`.

---

### `widgets/compartir_cobro_sheet.dart` (share PDF + WhatsApp)

**Analog:** `compartir_carne_sheet.dart` (lines 1-200).

**WhatsApp only in the app, with a fallback notice** (lines 66-81):
```dart
  Future<void> _whatsapp(Carne carne, String token) async {
    final numero = numeroWhatsApp(carne.duenoTelefono);
    if (numero == null) return;
    ...
    final ok = await ref.read(lanzadorExternoProvider).abrirEnApp(whatsappUri(numero, mensaje));
    if (!ok && mounted) _aviso('No pudimos abrir WhatsApp.');
  }
```
**PDF to the share sheet with a busy flag and the clock provider** (lines 98-120):
```dart
  Future<void> _pdf(Carne carne) async {
    if (_generando) return;
    setState(() => _generando = true);
    try {
      final ahora = ref.read(clockProvider)();
      final bytes = await ref.read(carnePdfServiceProvider).generar(carne: carne, generadoEn: ahora);
      await ref.read(compartirPdfProvider)(bytes: bytes, filename: CarnePdfService.nombreArchivo(carne.mascotaNombre, aBogota(ahora)));
    } on VacunaFailure catch (e) {
      if (mounted) _aviso(e.message);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }
```
**Hide or disable the WhatsApp row without a phone** (lines 169, 190-200: `numero == null ? 'Sin teléfono registrado' : ...`). The client phone is not in the PDF payload, so read it from `clienteProvider(clienteId)`. Without a `cliente_id` (deleted client), the WhatsApp row is hidden.

**Message builder** (`whatsapp_vacunas.dart`, `mensajeCarneWhatsApp`):
```dart
String mensajeCarneWhatsApp({required String dueno, required String mascota, required String url, required String veterinario, String? clinica}) {
  final firma = (clinica == null || clinica.trim().isEmpty) ? '$veterinario.' : '$veterinario, ${clinica.trim()}.';
  return 'Buen día, $dueno. Le compartimos el carné de vacunación de '
      '$mascota, siempre actualizado: $url. Cualquier duda, con gusto le ayudamos. $firma';
}
```
`mensajeCobroWhatsApp({cliente, numero, totalCop, clinica, esCotizacion})` lives in `lib/features/billing/domain/whatsapp_cobro.dart` and is unit-tested. It uses "usted" and `formatearCop`.

---

### `lib/features/home/presentation/screens/mas_screen.dart` (Cobros row)

**Analog:** the Inventario row (lines 199-231).
```dart
            Semantics(
              label: ... 'Inventario',
              excludeSemantics: true,
              button: true,
              child: AppCard(
                onTap: () => context.push(rutaInventario()),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text('Inventario', style: Theme.of(context).textTheme.bodyLarge)),
                      ...
                      const Icon(Icons.chevron_right),
```
Insert `const SizedBox(height: AppSpacing.sm)` and a "Cobros" `AppCard` (icon `Icons.receipt_long_outlined`, `context.push(rutaCobros())`) right after line 231. Keep it static (Finding 12).

---

### `completar_cita_screen.dart`: "Cobrar"

**Analog:** `_dosisBloque` in the same file. It watches a per-appointment provider, shows "registered" when data exists, and otherwise shows a tappable `AppCard` that pushes a top-level route with `citaId`:
```dart
    final registradas = ref.watch(dosisDeCitaProvider(cita.id)).maybeWhen(
          data: (d) => [...],
          orElse: () => const <String>[],
        );
    if (registradas.isNotEmpty) {
      return Row(children: [const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success), ... Text('Dosis registrada: ...')]);
    }
    return Semantics(
      label: 'Registrar dosis aplicada, ${m.nombre}',
      excludeSemantics: true,
      button: true,
      child: AppCard(
        onTap: () async {
          final r = await context.push<DosisRegistrada>(rutaRegistrarDosis(mascotaId: m.id, citaId: cita.id, ...));
```
"Cobrar" works per appointment, not per pet. It watches `cobroDeCitaProvider(cita.id)`, shows "Cobrada CC-0012" when a CC exists, and otherwise pushes `rutaNuevoCobro(citaId: cita.id, clienteId: cita.clienteId, mascotaId: <single pet or null>)`. The same pattern can be added to the completed state of `cita_detail_screen.dart` (lines 292-305 show the per-pet "Consulta registrada" text, and lines 519-531 the completed-state action).

---

### `cliente_detail_screen.dart`: cédula + "Nueva cuenta de cobro"

**Analog:** the same file.
- **Field:** add `_cedulaCtrl` next to `_direccionCtrl` (lines 41, 58, 70), fill it in `_llenarControladores` (line 87), compare it in `_esDirty` (line 97), pass it in the `Cliente(...)` rebuild (lines 135-137), and add `AppTextField(label: 'Cédula (opcional)', controller: _cedulaCtrl, keyboardType: TextInputType.number)` after "Dirección" (line 240).
- **Button with padlock** (`_botonAgendarCita`, lines 294-327):
  ```dart
  Widget _botonAgendarCita(BuildContext context) {
    final puedeEscribir = ref.watch(puedeEscribirProvider);
    Future<void> abrir() async {
      if (!await asegurarEscritura(context, ref, plan: ref.read(miPlanProvider).value)) return;
      if (!context.mounted) return;
      context.go(...);
    }
    return ControlEscritura(
      puedeEscribir: puedeEscribir,
      label: 'Agendar cita',
      onTap: abrir,
      child: AppButton(label: 'Agendar cita', icon: iconoEscritura(puedeEscribir, Icons.event_outlined), variant: AppButtonVariant.outline, onPressed: abrir),
    );
  }
  ```
  Use `context.push(rutaNuevoCobro(clienteId: widget.clienteId))`. It is `push`, not `go`: `/cobros/nuevo` is top-level, and pushing a top-level route from a shell branch is the allowed direction (G5). Place it after `_botonAgendarCita` (line 262).

**Repository** (`supabase_cliente_repository.dart`): add `'cedula': blank-to-null(cliente.cedula)` to the update map (lines 89-97) and `cedula: row['cedula'] as String?` (normalizing an empty string to null like `direccion`, lines 141 and 150) in `_fromRow`. Add `cedula` to `Cliente` and its `copyWith` (`cliente.dart` lines 9-55).

---

### Clinic NIT: `clinica.dart`, `supabase_clinica_repository.dart`, `datos_clinica_providers.dart`, `datos_clinica_screen.dart`

**Analog:** the `telefono` path end to end.
- `Clinica`: add `this.nit` (nullable) to the constructor, to `desdeJson` (blank to null, like `logo` lines 15 and 22), and to `copyWith` (lines 35-51).
- `miClinica` select (repository line 19): add `nit` to the column list `'id, nombre, ciudad, direccion, telefono, logo_path'`.
- `paramsActualizarClinica` (lines 28-40): add `'p_nit': (nit == null || nit.trim().isEmpty) ? null : nit.trim()`; and `actualizar({..., String? nit})` (lines 44-61).
- `GuardarDatosClinica.call` (`datos_clinica_providers.dart` 40-99): add a `String? nit` parameter and pass it through.
- Form (`datos_clinica_screen.dart` 359-364): add `AppTextField(label: 'NIT o cédula (opcional)', controller: _nit, maxLength: 30, keyboardType: TextInputType.number)` after "Teléfono", with a soft helper that recommends filling it in for cuentas de cobro (RESEARCH legal item 2).
- Tests: update `test/clinica_contrato_test.dart` lines 48-54 (the expected key set gains `'p_nit'`) and `FakeClinicaRepository.actualizar` (`test/helpers/fake_clinica.dart` lines 33-58) with `String? nit`.

---

### `test/helpers/fake_cobros.dart` (test helper)

**Analog:** `test/helpers/fake_inventario.dart` (lines 1-90+).
```dart
Producto productoDePrueba({String id = 'p1', String nombre = 'Amoxicilina', Unidad unidad = Unidad.frasco, int cantidad = 5, ...}) => Producto(...);

class FakeInventarioRepository implements SupabaseInventarioRepository {
  FakeInventarioRepository({List<Producto>? productos, ..., this.error, this.errorProductos, ...})
      : _productos = [...?productos], ...;
  final llamadas = <({String metodo, Map<String, Object?> args})>[];
  Completer<void>? bloqueoMover;
  void _log(String metodo, [Map<String, Object?> args = const {}]) => llamadas.add((metodo: metodo, args: args));
  void _falla(Object? propio) { final e = propio ?? error; if (e != null) throw e; }
```
`FakeCobrosRepository implements SupabaseCobrosRepository`:
- it stores state and assigns numbers per type;
- it replays the same `clave` with `yaExistia: true`;
- it has a per-method `error*` field and `llamadas`;
- it exposes `Completer? bloqueoCrear` for the double-tap test.

Also add `cobroDePrueba(...)`. PDF tests reuse `fuentesDePrueba`, `fuenteDisplayDePrueba` and `CompartirPdfFalso` from `test/helpers/fake_pdf.dart`, and `FakeCompartidor` from `fake_compartir.dart`. Mock `LanzadorExterno` from `test/helpers/fake_url_launcher.dart`.

---

## Shared Patterns

### Tenant check plus definer RPC (SQL)
**Source:** `supabase/schema.sql` lines 4279-4290 (`crear_producto`).
**Apply to:** every Fase 7 RPC.
```sql
language plpgsql
security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception '...' using errcode = 'insufficient_privilege';
  end if;
```
Re-verify every client-sent id with `clinica_id = v_clinica` (cliente, mascota, cita, consulta, producto, servicio, cotización).

### Read-only enforcement
**Source:** the `guard_solo_lectura` trigger (schema.sql 3746-3779) plus `ControlEscritura` / `asegurarEscritura` / `iconoEscritura` (`lib/features/plan/presentation/widgets/control_escritura.dart` line 11, `limite_plan_gate.dart` lines 33 and 146).
**Apply to:** the 4 new tables and every write button (new CC, pay, void, convert, services editor, cédula save). Sharing a PDF is not a write and is never blocked (the same rule as `inventario_screen.dart` line 164).

### Typed failure in repositories, never Supabase in presentation
**Source:** `supabase_inventario_repository.dart` lines 34-49 and 276-321. **Apply to:** `SupabaseCobrosRepository`. Screens catch only `CobroFailure` and call `manejarLimitePlan(context, ref, e)` first (`consulta_form_screen.dart` line 179).

### Invalidation after a mutation
**Source:** `inventario_providers.dart` lines 49-59 and 151-177. **Apply to:** every `CobrosActions` method. Billing also calls `invalidarInventario` for each product id in the lines, and invalidates on every failure class (WR-03).

### Formatting
**Source:** `lib/core/utils/formato.dart`: `formatearCop` (line 139), `parsearCop` (147), `formatearMiles` (128), `formatearFecha` (23, dd/mm/aaaa). `zona_bogota.dart`: `aBogota` (9) and `diaBogota` (18). `clockProvider` (`lib/core/data/clock_provider.dart`) gives "today" in the UI and in tests. DB dates go through `fechaABd` / `fechaDeBd` (`lib/features/vaccination/domain/fecha_bd.dart`, used in the inventory repository at lines 9, 198 and 254).

### External apps and share
**Sources:**
- `LanzadorExterno.abrirEnApp`: `lib/core/utils/lanzador_externo.dart` lines 14-15 and 43-63.
- `Compartidor`: `compartir.dart` lines 7-22.
- `CompartirPdf`: `historia_clinica_pdf_providers.dart` lines 22-35.

All three are injectable providers, and tests override them.

### Doc comments and language
Domain entities, the repository and reusable widgets get `///` comments that explain why. Private `_State` classes get none. User-visible copy is in Spanish. **The word "Factura" never appears in user-visible strings.** The only allowed occurrence is the DB `origen` value `'factura'`, which never reaches the UI because the tile shows `nota`. Add a grep gate per plan: `rg -n -i "factura" lib`, reviewed against that allow-list.

---

## No Analog Found

| File | Role | Data Flow | Reason / guidance |
|---|---|---|---|
| `lib/features/billing/domain/clave_idempotencia.dart` | utility | transform | No UUID generation exists in `lib/`, and `uuid` is transitive only (Finding 5). Write a small `Random.secure()` v4 generator (16 bytes, set the version and variant bits, hex with dashes) with a format test. Alternative: add `uuid` as a direct dependency after the legitimacy audit. |
| `borrador_cobro_provider.dart` (Riverpod `Notifier` draft) | store | event-driven (local) | No feature keeps a multi-step draft in a Notifier; forms use `StatefulWidget` controllers. Use a `Notifier<BorradorCobro>` (`flutter_riverpod` 3.x `NotifierProvider.autoDispose`) holding the key, client, pet, cita/consulta, cotización id and lines. The key is created once in `build()` and never regenerated on retry. Methods: `agregarServicio`, `agregarProducto`, `agregarOtro`, `cambiarPrecio(index, cop)` (D-07), `cambiarCantidad`, `quitar`. `FakeClientesNotifier extends ClientesNotifier` (`test/helpers/fake_clientes.dart` line 97) shows how the repo fakes an existing Notifier in tests. |
| `widgets/selector_linea_sheet.dart` (pick a service, an active product or "Otro") | component | CRUD read | There is no picker sheet over `productosProvider` (Finding 6). Build it as a `showModalBottomSheet(isScrollControlled: true, showDragHandle: true)`, as `anular_dosis_sheet.dart` lines 26-36 do. It has three sections (Servicios from `serviciosProvider`, Productos from `productosProvider`, "Otro"), a local search like `inventario_screen.dart` lines 74-83, and it shows stock with `Unidad.etiqueta`. |

## Metadata

**Analog search scope:**
- `supabase/schema.sql`: Phase 5 (1878-3170), Phase 5.1 (3294-4174) and Phase 6 (4176-4547).
- `supabase/tests/`.
- In `lib/features/`: `inventory`, `vaccination`, `clinical_history`, `clients`, `clinic`, `appointments`, `home`, `plan` and `billing`.
- `lib/core/utils`, `lib/core/router` and `test/helpers`.

**Files scanned:** about 45 read or grepped.
**Pattern extraction date:** 2026-11-13
