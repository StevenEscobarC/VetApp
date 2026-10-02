# Phase 5: Vacunación y Desparasitación - Pattern Map

**Mapped:** 2026-10-01
**Files analyzed:** 31 (nuevos/modificados)
**Analogs found:** 27 / 31 (los 4 sin analog son la superficie pública nueva)

Convenciones del repo que aplican a TODO archivo Dart nuevo: imports relativos (sin barrels ni alias), sin sufijo `UseCase`, dominio en español / plumbing en inglés, `///` solo en dominio y `core/widgets`, repos con dos niveles de catch (`on PostgrestException` + catch-all) hacia un `*Failure` con mensaje en español, Riverpod (`Provider`/`FutureProvider.autoDispose.family`), rutas por feature (nunca en `app_router.dart` salvo registrar la lista).

## File Classification

| Archivo nuevo/modificado | Role | Data Flow | Analog más cercano | Calidad |
|---|---|---|---|---|
| `supabase/schema.sql` (bloque "Fase 5" al FINAL, antes de `notify pgrst`) | migration | CRUD + derivación | bloque 4.1 (`schema.sql:1050-1873`) + `consultas` (`:470-520`) + `registrar_consulta` (`:955-1035`) | exact |
| `supabase/tests/rls_smoke_test.sql` (bloque Q) | test | request-response | bloque P (`rls_smoke_test.sql:1708-1983`) | exact |
| `supabase/tests/verify_live_schema.sh` | test | request-response | mismo archivo (`:30-198`) | exact |
| `lib/features/vaccination/domain/entities/{dosis_aplicada,protocolo,carne_item}.dart` (reemplazan `vacuna.dart`) | model | transform | `consulta.dart` (`clinical_history/domain/entities`) | role-match |
| `lib/features/vaccination/domain/vacuna_failure.dart` | model/error | — | `appointments/domain/cita_failure.dart` | exact |
| `lib/features/vaccination/domain/whatsapp_vacunas.dart` | utility | transform | `appointments/domain/whatsapp_recordatorio.dart` | exact |
| `lib/features/vaccination/domain/ventanas.dart` (etiquetas/colores de estado) | utility | transform | `appointments/presentation/estado_cita_ui.dart` | role-match |
| `lib/features/vaccination/data/repositories/supabase_vacuna_repository.dart` | service | CRUD + RPC | `clinical_history/data/repositories/supabase_consulta_repository.dart` | exact |
| `lib/features/vaccination/data/services/carne_pdf_service.dart` | service | file-I/O | `clinical_history/data/services/historia_clinica_pdf_service.dart` | exact |
| `lib/features/vaccination/presentation/providers/{carne,alertas,protocolos}_providers.dart` | provider | request-response | `consultas_providers.dart` + `team_providers.dart` | exact |
| `.../providers/carne_pdf_providers.dart` | provider | file-I/O | `historia_clinica_pdf_providers.dart` (reusar `compartirPdfProvider`) | exact |
| `lib/features/vaccination/presentation/vacunacion_routes.dart` | route | — | `pacientes_routes.dart`, `equipo_routes.dart` | exact |
| `.../screens/registrar_dosis_screen.dart` | component | CRUD | `consulta_form_screen.dart` | role-match |
| `.../screens/vacunas_pendientes_screen.dart` | component | request-response | `recordatorios_screen.dart` (agenda) | role-match |
| `.../screens/protocolos_screen.dart` | component | CRUD, admin-gated | `team/presentation/screens/equipo_screen.dart` | role-match |
| `.../widgets/{estado_chip,dosis_card,enlace_carne_sheet}.dart` | component | request-response | `team/.../miembro_acciones_sheet.dart`, `appointments/.../recordar_manana_sheet.dart`, `AppStatusChip` | role-match |
| `lib/features/patients/presentation/screens/mascota_detail_screen.dart` (MOD: sección Carné + badge) | component | request-response | mismas secciones "Historia clínica" `:259-261` y `_exportarPdf` `:62-80` | exact |
| `lib/features/patients/presentation/screens/pacientes_list_screen.dart` (MOD: badges) | component | request-response | mismo archivo | exact |
| `lib/features/appointments/presentation/screens/completar_cita_screen.dart` (MOD: "Registrar dosis") | component | event-driven | `_MascotaCard.onRegistrar` `:130-160` | exact |
| `lib/features/appointments/presentation/screens/cita_form_screen.dart` (MOD: prellenado) | component | CRUD | `agenda_routes.dart:34-42` (`clienteIdInicial`/`mascotaIdInicial`) | exact |
| `lib/features/home/presentation/screens/inicio_screen.dart` (MOD: tarjeta + "Vacunar") | component | request-response | mismo archivo | exact |
| `lib/features/home/presentation/screens/mas_screen.dart` (MOD: entrada "Protocolos") | component | — | entrada "Equipo" `mas_screen.dart:65` | exact |
| `lib/core/router/app_router.dart` (MOD: `...masVacunacionRoutes`) | config | — | `...masTeamRoutes` `app_router.dart:111` | exact |
| `lib/features/patients/presentation/pacientes_routes.dart` (MOD: `:id/carne`, `:id/carne/dosis`) | route | — | hija `consultas/nueva` `:28-32` | exact |
| `test/helpers/fake_vacunas.dart` | test | — | `test/helpers/fake_consultas.dart` | exact |
| `test/*_test.dart` (registro, mapeo, pendientes, whatsapp, enlace, pdf) | test | — | `consulta_form_screen_test`, `supabase_consulta_repository_test`, `historia_clinica_pdf_service_test`, `whatsapp_recordatorio_test` | exact |
| `supabase/functions/carne/index.ts` | controller (Edge Fn) | request-response | NINGUNO | none |
| `public_carne/{index.html,carne.css,carne.js}` | component (web estática) | request-response | NINGUNO | none |
| `.github/workflows/pages-carne.yml` | config | — | NINGUNO | none |
| `lib/core/config/` constante `kCarneBaseUrl` (`--dart-define`) | config | — | `supabaseConfigured` / `String.fromEnvironment` en `auth_screens.dart:10-13` | role-match |

## Pattern Assignments

### `supabase/schema.sql` — bloque "Fase 5" (migration, CRUD + derivación)

**Analogs:** bloque 4.1 (idempotencia/orden), tabla `consultas`, RPC `registrar_consulta`.

**Posición (crítico):** al FINAL del archivo, después del bloque 4.1 y antes de `notify pgrst, 'reload schema';` (`schema.sql:1873`). Si va antes, el bloque 4.1 recrea la versión vieja de `es_autor_en_mi_clinica` en cada re-pegado (Pitfall 2).

**Encabezado de delta idempotente** (`schema.sql:1050-1053`):
```sql
-- ===== Fase 4.1: Equipo de la clínica (delta idempotente) =====
-- ... Se re-ejecuta completo sin error.
-- Orden: columnas primero (las funciones `language sql` se validan al crearlas).
```

**Tabla append-only + RLS** (copiar de `consultas`, `schema.sql:470-515`): `create table if not exists`, `veterinario_id uuid not null references auth.users(id) on delete restrict`, índice `(mascota_id, fecha desc)`, `enable row level security`, `drop policy if exists` + `create policy ... to authenticated using (public.es_veterinario() and exists (select 1 from public.mascotas m where m.id = X.mascota_id and m.clinica_id = public.mi_clinica_id()))`. Cierre: "Sin política update/delete" comentado (HIST-04). Para `dosis_aplicadas` usar además `clinica_id` con FK compuesta `(mascota_id, clinica_id) -> mascotas(id, clinica_id)` (unique ya existe, `schema.sql:537`).

**FK a perfiles para embed** (`schema.sql:1818-1822`):
```sql
do $$ begin
  alter table public.consultas
    add constraint consultas_veterinario_perfil_fkey foreign key (veterinario_id)
    references public.perfiles(id) on delete restrict;
exception when duplicate_object then null;
end $$;
```
Replicar como `dosis_veterinario_perfil_fkey`.

**Helpers de autoría (D-09) — redefinir con OR** (`schema.sql:1113-1130`; el comentario "Fase 5: la tabla de vacunas debe sumarse (OR) aquí" debe actualizarse):
```sql
create or replace function public.es_autor_en_mi_clinica(p_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select
  exists (select 1 from public.citas c where c.clinica_id = public.mi_clinica_id() and c.veterinario_id = p_id)
  or exists (select 1 from public.consultas co join public.mascotas m on m.id = co.mascota_id
             where co.veterinario_id = p_id and m.clinica_id = public.mi_clinica_id())
  -- Fase 5: or exists (select 1 from public.dosis_aplicadas d where d.clinica_id = public.mi_clinica_id() and d.veterinario_id = p_id)
$$;
```
Las tablas deben existir ANTES (las funciones `language sql` se validan al crearlas).

**RPC (security invoker, validaciones con errcode)** — copiar forma de `registrar_consulta` (`schema.sql:955-1035`): `p_` params con `default null`, `v_clinica_id := public.mi_clinica_id()`, `raise exception '...' using errcode = 'insufficient_privilege' | 'foreign_key_violation' | 'check_violation'`, `insert ... auth.uid() ... nullif(trim(x), '')`, luego grants:
```sql
revoke all on function public.registrar_consulta(uuid, text, ...) from public, anon;
grant execute on function public.registrar_consulta(uuid, text, ...) to authenticated;
```
Aplicar a `registrar_dosis`, `anular_dosis` (definer; solo toca 4 columnas de anulación), `carne_de_mascota`, `vacunas_pendientes`, `vacunas_resumen_mascotas`, `obtener_o_crear_enlace_carne`, `regenerar_enlace_carne`, `desactivar_enlace_carne`. `carne_publico` y `_carne_filas`: `revoke all ... from public, anon, authenticated; grant execute ... to service_role`. Mapeo de `errcode` a mensajes en el repo Dart (ver abajo).

**Pitfall 9:** `drop function if exists ...` de firmas viejas antes de cambiar argumentos (precedente `crear_cita` 9 args, `schema.sql:1539`, grants `:1829-1850`).

**Cierre:** reafirmar grants de helpers (`schema.sql:1865-1871`) y `notify pgrst, 'reload schema';` (`:1873`). Semillas: `insert ... on conflict do nothing`.

---

### `supabase/tests/rls_smoke_test.sql` — bloque Q (test)

**Analog:** bloque P (`rls_smoke_test.sql:1708-1983`), un único `do $$ ... end $$` con `failures text[]` y contador `checks`.

**Patrón por check** (cambio de rol/JWT, `rls_smoke_test.sql:1750-1763`):
```sql
checks := checks + 1;
perform set_config('role', 'postgres', true);
-- setup como superusuario ...
perform set_config('request.jwt.claims', json_build_object('sub', vet_a_id, 'role', 'authenticated')::text, true);
perform set_config('role', 'authenticated', true);
begin
  perform public.actualizar_cita(...);
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.citas where ...) then
    failures := failures || 'P24 la cita abierta no se reasignó a vet_a2';
  end if;
exception when others then
  failures := failures || ('P24 ...: error inesperado: ' || sqlerrm);
end;
```
Negativo esperado: `begin ... failures := failures || 'Pxx debía fallar'; exception when check_violation then null; when others then failures := failures || (...); end;`.

**Pie obligatorio** (`:1975-1982`): siempre termina con `raise exception 'RLS SMOKE: PASS|FAIL ...'` (rollback total). Insertar el bloque Q ANTES de ese pie, renumerar como `Q1..Qn`, actualizar el "Total esperado: 145" del encabezado (`:34`) y añadir línea "Fase 5 (bloque Q ...)" al comentario de cobertura. Para el cálculo usar `p_hoy` fijo (llamar `_carne_filas` como `postgres`), no `now()`. Check de `es_autor_en_mi_clinica` con vet retirado: replicar P30 (`:1960-1972`, consulta a `pg_constraint`) más lectura de embed.

---

### `supabase/tests/verify_live_schema.sh`

**Analog:** el propio archivo.
- Tablas anónimas: añadir a la lista `for t in clinicas ... cita_mascotas` (`:60`) — nuevas tablas con RLS: aceptar 200 con `[]` o 401/403/404 (patrón `clinica_invitaciones`, `:63-76`; no usar el bucle de `200` plano para `carne_enlaces`).
- RPCs: añadir nombres al `for rpc in ...` (`:90`) y un `case` con payload por RPC (`:91-131`); `401/403` = `OK protegido`. Para `carne_publico` aceptar también 404 (como `consumir_invitacion`, `:138`).
- Embeds: `probe_embed dosis_aplicadas '*, veterinario:perfiles!dosis_veterinario_perfil_fkey(nombre, matricula, activo)' 'dosis veterinario embed'` (patrón `:171-187`).
- Edge Function: sonda `curl -X POST .../functions/v1/carne -d '{"token":"xx"}'` espera 404 JSON; acumular con `any_fail=1`.
- Mantener el final `LIVE_SCHEMA_OK` (`:198`).

---

### `lib/features/vaccination/data/repositories/supabase_vacuna_repository.dart` (service, RPC/CRUD)

**Analog:** `lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart`

**Imports** (`:1-6`):
```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/formato.dart';
import '../../domain/vacuna_failure.dart';
```
**Lectura con embed + dos niveles de catch** (`:25-43`):
```dart
final rows = await _client.from('consultas')
    .select('*, veterinario:perfiles!consultas_veterinario_perfil_fkey(nombre, activo)')
    .eq('mascota_id', mascotaId).order('fecha', ascending: false);
...
} on PostgrestException catch (e) { throw ConsultaFailure(_messageFor(e)); }
  catch (_) { throw const ConsultaFailure('No pudimos cargar ... Intenta de nuevo.'); }
```
**RPC con todos los `p_` presentes (null permitido)** y `blancoANull(...)` para opcionales (`:57-86`). **Sin `actualizar`/`eliminar`** (solo-append; `anularDosis` es RPC). **Mapa de errores centralizado** `@visibleForTesting String mensajeErrorX(PostgrestException e)` con `switch (e.code)` en `42501`, `23503`, `23505`, `23514`, `23502`/`22003` (`:92-115`), y mapper `@visibleForTesting ...DesdeFila(Map<String,dynamic>)` (`:118-140`). Para columnas `date` NO usar `DateTime.parse`: usar `fechaDeBd` (UTC) de RESEARCH Pattern 3.

### `vacuna_failure.dart`
**Analog:** `appointments/domain/cita_failure.dart` (copiar completo: `class VacunaFailure implements Exception { const VacunaFailure(this.message); final String message; toString => message; }` con `///` explicando que la capa de datos traduce `PostgrestException`).

### `whatsapp_vacunas.dart`
**Analog:** `appointments/domain/whatsapp_recordatorio.dart:1-50`. Reusar `firmaVeterinario`, `whatsappUri` (usa `Uri.encodeComponent`, nunca `queryParameters`) y `estadoWhatsApp(telefono)` (`:44-50`); plantillas "usted" de RESEARCH §WhatsApp. Marcar `recordatorio_enviado_at` SOLO si `lanzadorExternoProvider.abrirEnApp(uri)` devolvió `true` (`lanzador_externo.dart:4-15`).

### `carne_pdf_service.dart` (service, file-I/O)
**Analog:** `historia_clinica_pdf_service.dart`
- Typedef inyectable de fuentes (`:12-20`): `typedef CargarFuentesPdf = Future<({pw.Font regular, pw.Font bold})> Function();` + `PdfGoogleFonts.notoSansRegular/Bold`. Reusar el typedef o clonarlo; tests usan `fuentesDePrueba()`/`fuentesQueFallan()` de `test/helpers/fake_pdf.dart`.
- Constructor `X({CargarFuentesPdf? cargarFuentes}) : _cargarFuentes = cargarFuentes ?? _cargarFuentesReales;` (`:33-36`).
- `generar({...}) async` envuelto en `try`; cualquier fallo -> un único `VacunaFailure` (doc `:67-72`); `pw.Document(theme: pw.ThemeData.withFont(base:, bold:))`, `pw.MultiPage(header:, footer: 'Página X de Y', build:)` (`:84-110`).
- Extra Fase 5: `pw.TextDecoration.lineThrough` para anuladas (D-23: en el PDF van ocultas, usar solo en app/si se pide), etiqueta "Otra clínica", pie "Hecho con VetApp" (D-19), dueño "María G." (D-20). Método estático `nombreArchivo(...)` como `HistoriaClinicaPdfService.nombreArchivo`.
- Compartir con el `compartirPdfProvider` existente (`historia_clinica_pdf_providers.dart`), NO crear otro; ojo: su catch lanza `ConsultaFailure` — si se reutiliza tal cual, el mensaje de la pantalla debe tolerarlo, o envolver en el servicio de carné.

### Providers (`carne_providers`, `alertas_providers`, `protocolos_providers`)
**Analogs:** `consultas_providers.dart`, `team_providers.dart`
```dart
final consultaRepositoryProvider = Provider<SupabaseConsultaRepository>((ref) {
  return SupabaseConsultaRepository(ref.watch(supabaseClientProvider));
});
final consultasProvider = FutureProvider.autoDispose.family<List<Consulta>, String>((ref, mascotaId) {
  return ref.watch(consultaRepositoryProvider).porMascota(mascotaId);
});
```
- Imports: `core/data/supabase_client_provider.dart`, `core/data/clock_provider.dart`, `auth/presentation/providers/auth_providers.dart`.
- Acción de escritura como clase imperativa con `Ref` guardado y provider NO autoDispose (`RegistrarConsulta`, `consultas_providers.dart:24-60`); recortar con `.trim()`, opcionales vacíos a `null`, y tras éxito `ref.invalidate(...)` de carné, resumen de alertas, `citaProvider`/agenda (si hay `cita_id`).
- Gating admin: `perfil.esAdmin` de `authProfileProvider` (`supabase_auth_repository.dart:26`) y `esClinicaMultiVetProvider` (`team_providers.dart:~35`) para D-24 (en clínica de 1 vet, siempre editable; en 2+ solo admin). Patrón de lectura condicional: `invitacionVigenteProvider` (`team_providers.dart:45-52`).

### `vacunacion_routes.dart` + registro de rutas
**Analogs:** `equipo_routes.dart` (lista de `GoRoute` hijos de `/mas`), `pacientes_routes.dart:14-36`.
```dart
final List<GoRoute> masTeamRoutes = [
  GoRoute(path: 'equipo', builder: (_, _) => const EquipoScreen()),
];
```
Crear `masVacunacionRoutes` (`protocolos`, `vacunas`) y spread en `app_router.dart:~111` junto a `...masTeamRoutes`. Hijas `carne` y `carne/dosis` dentro de `pacientesRoute` `:id` (`pacientes_routes.dart:21-33`, query params para biológico sugerido y `citaId`). NO tocar `_publicPaths` (`app_router.dart:20`): la superficie pública no es ruta del app. Regla: segmentos estáticos antes de `:id` (`agenda_routes.dart:25-28`). Parseo de query: `_parseDia` (`agenda_routes.dart:11-20`).

### `registrar_dosis_screen.dart` (component, CRUD)
**Analog:** `clinical_history/presentation/screens/consulta_form_screen.dart` (form -> `RegistrarConsulta` provider -> `on ConsultaFailure catch (e)` -> `setState(_error)`). Fecha precargada con `diaBogota(DateTime.now())` (`zona_bogota.dart:~20`), mostrar con `formatearFecha`. Chips con `AppFilterChip`, botones `AppButton`, tarjetas `AppCard` (no widgets nuevos).

### `vacunas_pendientes_screen.dart`
**Analog:** `appointments/presentation/screens/recordatorios_screen.dart` + `recordar_manana_sheet.dart` (lista de acciones WhatsApp con `abrirEnApp`), estados con `AppStatusChip` (`AppStatus` mapea 1:1 a `EstadoCarne`).

### `protocolos_screen.dart`
**Analog:** `team/presentation/screens/equipo_screen.dart:86-87` (`final esAdmin = perfil?.esAdmin ?? false;` condiciona acciones) y `miembro_acciones_sheet.dart` para sheets de acción.

### `mascota_detail_screen.dart` (MOD)
Seguir la sección existente: título `Text('Historia clínica', style: textTheme.titleMedium)` + widget extraído (`:259-261`). Mantener el archivo manejable (ya 500 líneas): sección `Carné` como widget en `vaccination/presentation/widgets`. PDF: reutilizar patrón `_exportarPdf` (`:62-80`: leer provider `.future`, `ref.read(...ServiceProvider).generar`, `ref.read(compartirPdfProvider)(bytes:, filename:)`) y el `IconButton` de AppBar (`:175-177`).

### `completar_cita_screen.dart` (MOD)
Añadir acción solo si `cita.motivo` ∈ {Vacunación, Desparasitación} (`motivos_cita.dart:3-10`), junto a `onRegistrar` (`:130-160`):
```dart
onRegistrar: () => context.push('/agenda/${cita.id}/completar/consulta/${m.id}'),
```
-> nueva ruta con `mascotaId`, `citaId` y biológico sugerido. NO tocar `_omitidas`/`mascotasConConsulta`. Mostrar "Dosis registrada: {Biológico}" (D-22, `cita_id` nullable en `dosis_aplicadas`, igual que `consultas.cita_id`; validar pertenencia a la cita como hace `registrar_consulta`).

### `fake_vacunas.dart` + tests
**Analog:** `test/helpers/fake_consultas.dart:1-60` — `class FakeVacunaRepository implements SupabaseVacunaRepository` con datos fijos o `error` fijo + bitácora de llamadas como lista de records con nombre; reutilizar `FakeLanzadorExterno` (`fake_url_launcher.dart`), `fake_compartir.dart`, `CompartirPdfFalso`/`fuentesDePrueba` (`fake_pdf.dart`), `router_harness.dart`.

---

## Shared Patterns

### Tenant/RLS
**Fuente:** `schema.sql:503-510` + helpers `mi_clinica_id()` / `es_veterinario()` (activo) / `es_admin_clinica()` (`:1094-1105`). **Aplicar a:** las 4 tablas nuevas. Siempre `to authenticated`, `revoke ... from public, anon`.

### Solo-append
**Fuente:** comentario `schema.sql:517-519` y doc de `supabase_consulta_repository.dart:10-19`. **Aplicar a:** `dosis_aplicadas` (anulación vía RPC) y su repositorio (sin `actualizar`/`eliminar`).

### Errores en español
**Fuente:** `supabase_consulta_repository.dart:92-115`. **Aplicar a:** repo de vacunas; centralizar códigos en una función `mensajeErrorVacuna`.

### Fechas y zona
**Fuente:** `lib/core/utils/zona_bogota.dart` (`aBogota`, `diaBogota`, UTC-5 fijo), `formato.dart` (`formatearFecha` dd/mm/aaaa, `blancoANull`). **Aplicar a:** todo; en SQL `(now() at time zone 'America/Bogota')::date` pasado como `p_hoy`.

### WhatsApp / teléfono +57 / compartir
**Fuente:** `whatsapp_recordatorio.dart:35-50`, `telefono_co.dart`, `lanzador_externo.dart`, `compartir.dart` (`compartidorProvider.compartirTexto`). **Aplicar a:** recordatorio de vacuna, envío de carné, hoja nativa.

### UI atoms
**Fuente:** `lib/core/widgets/**` (`AppButton`, `AppCard`, `AppTextField`, `AppFilterChip`, `AppStatusChip`) y tokens `AppColors/AppSpacing`. **Aplicar a:** todas las pantallas; seguir `05-UI-SPEC.md` (aprobado).

### Config en tiempo de compilación
**Fuente:** `String.fromEnvironment` (`auth_screens.dart:10-13`, `main.dart:10-11`). **Aplicar a:** `kCarneBaseUrl` (`--dart-define`), valor por defecto `https://stevenescobarc.github.io/VetApp/c/`.

## No Analog Found

Primera superficie pública/anónima; usar RESEARCH.md Pattern 4 y estas convenciones mínimas:

| Archivo | Role | Data Flow | Convenciones mínimas a seguir |
|---|---|---|---|
| `supabase/functions/carne/index.ts` | Edge Function | request-response | No existe `supabase/functions/` (confirmado por CLAUDE.md). Un directorio por función, `index.ts` con `Deno.serve`; `verify_jwt = false` en `supabase/config.toml` (`[functions.carne]`) o `--no-verify-jwt`; solo `fetch` nativo (cero dependencias); `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` como secretos del runtime (nunca en repo público ni cliente); validar token con `/^[0-9a-f]{64}$/` antes de tocar la BD; 404 JSON uniforme para inexistente/revocado/mal formado; CORS solo al origen de Pages; `cache-control: no-store`; devolver solo claves D-15/D-20 (sin `foto_path`, teléfono, apellido completo, dosis anuladas D-23); firmar foto del bucket `mascota-fotos` TTL 300 s y degradar sin foto si falla. Comentarios en español. |
| `public_carne/index.html`, `carne.css`, `carne.js` | web estática | request-response | HTML+CSS+JS vanilla sin build; token de `location.hash` -> POST a la función; render SOLO con `textContent`; `<meta name="referrer" content="no-referrer">`, `noindex,nofollow`, CSP por `<meta>`; fuentes Caprasimo + Figtree autoalojadas (woff2); paleta terracota/crema de `app_colors.dart`; `@media print`; pie fijo "Hecho con VetApp" (D-19). Seguir UI-SPEC §11. |
| `.github/workflows/pages-carne.yml` | CI | batch | Workflow de GitHub Pages por Actions publicando solo `public_carne/`. Acción humana: activar Pages (Source: GitHub Actions). |
| Despliegue de la función | — | — | `supabase functions deploy carne --no-verify-jwt` o MCP `deploy_edge_function`, con autorización explícita del usuario; fallback documentado en D-25 (RPC anónima sin foto). |

## Metadata

**Analog search scope:** `lib/features/{appointments,clinical_history,team,patients,home}`, `lib/core/{utils,router}`, `supabase/schema.sql`, `supabase/tests/`, `test/helpers/`.
**Files scanned:** ~35 (lecturas dirigidas con rangos de línea).
**Pattern extraction date:** 2026-10-01
