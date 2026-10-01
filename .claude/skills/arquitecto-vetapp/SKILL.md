---
name: arquitecto-vetapp
description: Arquitecto senior Flutter + Supabase de VetApp, la app móvil para veterinarios independientes y clínicas pequeñas en Colombia (pacientes, clientes, historia clínica, agenda, vacunación, inventario, facturación). Úsala siempre que se pida diseñar, escribir, revisar, refactorizar o depurar código de VetApp — pantallas, providers de Riverpod, repositorios Supabase, SQL/RLS en supabase/schema.sql, rutas go_router o pruebas — aunque no se nombre "VetApp" si el contexto es esta app veterinaria en Flutter.
---

# Arquitecto VetApp

## 1. Propósito

Esta skill describe VetApp **como es hoy** (Fases 1-4 completas), para que cada cambio encaje sin fricción: misma estructura, mismas convenciones, mismas reglas de negocio. **El código manda**: si esta skill y el repo discrepan, sigue el repo y reporta la diferencia. Ante una duda, verifica con `ls`/`grep` antes de afirmar. Antes de diseñar lee también `CLAUDE.md` y el `*-CONTEXT.md` de la fase en `.planning/phases/`.

Nota: `.planning/codebase/*.md` y la sección "Architecture" de `CLAUDE.md` están parcialmente desactualizadas (dicen que Riverpod y go_router no se usan y que `lib/core/router/` está vacío; ya no es cierto).

Producto: el veterinario lleva su consulta desde el celular. Hoy solo el rol VETERINARIO tiene app funcional; el rol CLIENTE llega a `ClientHomeScreen` (`lib/features/auth/presentation/screens/client_home_screen.dart`) y su experiencia real es la Fase 9.

## 2. Stack real

Fuente: `pubspec.yaml`.

- Flutter estable, Dart `^3.11.1`, Material con tema propio.
- `flutter_riverpod` ^3.3.2 con providers **escritos a mano** (sin generador).
- `go_router` ^17.3.0, `supabase_flutter` ^2.9.1, `intl`, `google_fonts`.
- Foto: `image_picker`, `flutter_image_compress`, `permission_handler`, `cached_network_image`.
- PDF: `pdf` + `printing`. Recordatorios: `flutter_local_notifications` + `timezone`. Enlaces externos (WhatsApp, teléfono): `url_launcher`. Preferencias: `shared_preferences`.
- Dev: `flutter_test` y `flutter_lints` únicamente.
- **No existen** en el proyecto: freezed, json_serializable, build_runner, riverpod_generator/annotation, dio, mocktail, mockito. No los uses ni los importes; no introduzcas dependencias nuevas sin justificarlo.

## 3. Estructura de `lib/`

- `core/data/`: `supabase_client_provider.dart`, `clock_provider.dart`, `busqueda.dart`.
- `core/router/app_router.dart`: el único router.
- `core/theme/`: `app_colors`, `app_spacing`, `app_typography`, `app_theme`.
- `core/utils/`: `formato.dart`, `formato_hora.dart`, `telefono_co.dart`, `zona_bogota.dart`, `lanzador_externo.dart`, `captura_foto.dart`.
- `core/widgets/`: `app_bar/app_top_bar`, `buttons/app_button`, `cards/app_card`, `chips/app_filter_chip`, `inputs/app_text_field`, `media/app_photo_picker`, `status/app_status_chip`.
- `features/{appointments,auth,billing,clients,clinical_history,home,inventory,patients,vaccination}/`, cada una con subcarpetas `data/{repositories,services,datasources}`, `domain/{entities,*_failure.dart}` y `presentation/{providers,screens,widgets}` según haga falta.
- `billing`, `inventory` y `vaccination` solo tienen `domain/entities/` (stubs de fases futuras, sin tabla ni repositorio).
- No hay capa de use cases en las features activas: las pantallas llaman a providers/acciones y estos al repositorio. `domain/` también aloja lógica pura (p. ej. `appointments/domain/cita_solapes.dart`, `recordatorios_plan.dart`, `whatsapp_recordatorio.dart`; `clinical_history/domain/formato_consulta.dart`).
- Los repositorios son clases concretas `Supabase*Repository` en `data/repositories/` (sin interfaz abstracta). Las entidades son clases a mano con `copyWith`; el mapeo fila-a-entidad es `_fromRow` dentro del repositorio.

## 4. Patrón de providers (Riverpod, a mano)

- Cliente: `supabaseClientProvider` (`lib/core/data/supabase_client_provider.dart`) es el **único** lugar que toca `Supabase.instance.client`; todo repositorio se construye desde él. Reloj inyectable: `clockProvider` (`clock_provider.dart`); el código de agenda no llama `DateTime.now()` directo.
- Repositorio: `Provider<SupabaseXRepository>` (p. ej. `citaRepositoryProvider` en `lib/features/appointments/presentation/providers/citas_providers.dart`).
- Lecturas: `FutureProvider.autoDispose(.family)` (`agendaSemanaProvider`, `citaProvider`; `mascotas_providers.dart`, `consultas_providers.dart`).
- Estado de lista con ciclo propio: `AsyncNotifier` (`ClientesNotifier` en `clientes_providers.dart`, `MascotasNotifier`, `AuthProfileNotifier` en `auth_providers.dart`).
- Escrituras: clase de acciones que guarda un `Ref`, llama al repositorio e invalida providers; su provider **no** es `autoDispose` (`CitaActions`/`citaActionsProvider`, `RegistrarConsulta`/`registrarConsultaProvider`). `citasRevisionProvider` (un `Notifier<int>`) se incrementa para avisar de cambios a quien reprograma recordatorios.
- La UI usa `AsyncValue.when` (carga, error con reintento, vacío); `ref.watch` en `build`, `ref.read` en callbacks.

## 5. Routing

`lib/core/router/app_router.dart` define `routerProvider` (`GoRouter`). Una sola compuerta de auth en `redirect:` que lee `authProfileProvider`: `/splash` mientras carga, rutas públicas (`/login`, `/register`, `/reset-password`) sin sesión, `/cliente` para perfiles que no son veterinario, `/inicio` para veterinarios. `refreshListenable` reevalúa al cambiar la sesión. Los veterinarios navegan por un `StatefulShellRoute.indexedStack` (`AppShell`) con 5 ramas: inicio, pacientes, agenda, clientes, más. Cada feature expone su rama (`pacientes_routes.dart`, `agenda_routes.dart`, `clientes_routes.dart`). Ningún widget repite la lógica de redirección.

## 6. Manejo de errores

- Una excepción por feature, en español y sin depender del SDK: `AuthFailure` (`auth/domain/auth_failure.dart`), `CitaFailure`, `ClienteFailure`, `ConsultaFailure`, `MascotaFailure` (cada una en su `domain/`).
- El repositorio traduce `PostgrestException`/`AuthException` con un helper (`_messageFor`, `mensajeErrorCita` en `supabase_cita_repository.dart`): una rama específica por código/mensaje conocido y un fallback genérico en español. Las traducciones nuevas van en ese helper, no en el sitio de llamada.
- La presentación captura solo la `*Failure` de su feature (`on CitaFailure catch (e)` en `cita_form_screen.dart`; `on AuthFailure catch` en `login_screen.dart`) y muestra `e.message`.

## 7. Backend Supabase

- `supabase/schema.sql` es la **única fuente**, idempotente (re-ejecutable completa). No existe `supabase/migrations/`. El cambio se aplica por el humano en el SQL Editor, o por un agente vía Supabase MCP **solo con OK explícito del usuario**; nunca se escribe en la base viva sin él.
- Todo cambio de schema/RLS pasa por el agente `vetapp-supabase` y se acompaña de checks en `supabase/tests/rls_smoke_test.sql` (un bloque `do $$` con contador `checks`; termina siempre en un error `RLS SMOKE: PASS|FAIL (n checks)` a propósito, para revertir lo creado). Se pega y ejecuta en el SQL Editor tras aplicar el schema.
- `supabase/tests/verify_live_schema.sh` verifica contra el proyecto en la nube que las tablas se exponen y que `anon` no puede escribir; usa solo la anon key y nunca la imprime.
- Multi-tenencia por `clinica_id`. Políticas `to authenticated` basadas en `es_veterinario()` y `mi_clinica_id()` (funciones `security definer` con `execute` revocado a `anon`/`public`). RPCs de negocio (`registrar_cliente_con_mascota`, `registrar_mascota`, `generar_codigo_vinculacion`, `crear_cita`, `actualizar_cita`, `registrar_consulta`) son `security invoker`, para que la RLS siga aplicando dentro.
- Integridad entre tenants con FKs compuestas `(x_id, clinica_id)` apoyadas en `unique (id, clinica_id)`.
- La app usa solo la anon key + sesión; credenciales por `--dart-define` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). **Nunca** escribas URLs, refs de proyecto ni claves en código, docs ni skills.
- Modelo de datos detallado: `references/modelo-dominio.md`.

## 8. Sistema de diseño

Identidad aprobada: paleta terracota/crema, Caprasimo (títulos) + Figtree (cuerpo) vía `google_fonts`. Todo color, espaciado y tipografía sale de `AppColors`, `AppSpacing`, `AppTypography` y `AppTheme` (`lib/core/theme/`); no uses valores sueltos ni los defaults de Material 3. Reutiliza `AppButton`, `AppCard`, `AppTextField`, `AppStatusChip`, `AppTopBar`, `AppFilterChip` y `AppPhotoPicker` antes de crear widgets nuevos. La revisión visual se delega al agente `vetapp-brand-ui`.

## 9. Colombia

COP sin decimales, fechas `dd/mm/aaaa`, horas `10:30 a. m.`, zona `America/Bogota` fija (UTC-5), teléfonos normalizados a `57XXXXXXXXXX`. Helpers: `zona_bogota.dart`, `formato_hora.dart`, `telefono_co.dart`, `formato.dart`. Detalle y límites legales en `references/colombia.md`.

## 10. Nombres

Dominio en español (`Cita`, `Mascota`, `Cliente`, `Consulta`), sufijos técnicos en inglés (`Repository`, `Provider`, `Screen`) y `Failure` para errores. Archivos `snake_case.dart`; repositorios `Supabase<Dominio>Repository`; sin sufijo `UseCase`. Textos de UI en español de Colombia.

## 11. Pruebas

- Solo `flutter_test`. Los dobles son **fakes a mano** en `test/helpers/fake_*.dart` (`fake_auth`, `fake_citas`, `fake_clientes`, `fake_consultas`, `fake_fotos`, `fake_mascotas`, `fake_pdf`, `fake_recordatorios`, `fake_url_launcher`), inyectados con `overrides` de `ProviderScope`.
- Pantallas con navegación: `test/helpers/router_harness.dart` (`routerHarness`, un `GoRouter` mínimo con el tema real y sin redirect de auth).
- Archivos de prueba planos en `test/`, nombrados `<unidad>_test.dart` (`supabase_cita_repository_test.dart`, `cita_form_screen_test.dart`, `telefono_co_test.dart`).
- Todo repositorio, provider o pantalla nueva lleva su prueba; las pruebas no llaman a Supabase real. `flutter analyze` y `flutter test` deben quedar en verde (agente `vetapp-gate`).

## 12. Flujo de trabajo

- Los cambios al repo pasan por GSD: `/gsd-quick`, `/gsd-fast`, `/gsd-execute-phase`. Nada de ediciones directas fuera de ese flujo salvo que el usuario lo pida.
- Agentes del proyecto (`.claude/agents/`):
  - `vetapp-gate`: ejecuta `flutter analyze` + `flutter test`, diagnostica y corrige hasta verde.
  - `vetapp-qa`: ejecuta casos manuales/UAT de una fase en el emulador Android y escribe el reporte; no edita código.
  - `vetapp-supabase`: cambios en `schema.sql`, RLS multi-tenant y checks del smoke test.
  - `vetapp-brand-ui`: auditoría visual y de formato colombiano (solo lectura).
  - `vetapp-opportunity-research`: investigación de producto y backlog de mejoras.
- Linear: equipo VetApp, un proyecto por fase más "Plataforma y Calidad", donde van los refactors candidatos y la deuda técnica.

## 13. Cómo responder

1. Si algo ambiguo cambia el diseño (rol, regla de negocio no definida), haz una o dos preguntas concretas; si no, empieza.
2. Plan breve: archivos a crear/cambiar y su capa.
3. Archivos completos con su ruta; en archivos existentes, fragmentos con contexto suficiente.
4. Si hay cambios de datos: SQL idempotente para `schema.sql`, políticas RLS y los checks nuevos del smoke test (delegando en `vetapp-supabase`).
5. Pruebas con los fakes y el harness existentes.
6. Cierra con decisiones, riesgos y pendientes en pocas líneas.

## 14. Refactors candidatos (no aplicar sin decisión)

Ideas que **no** son el estado actual ni reglas. Proponer en Linear (Plataforma y Calidad) con costo, riesgo y archivos afectados; no aplicar sin decisión del usuario ni dentro de otra tarea.

- `Result<T>` con `Failure` sellado en vez de excepciones por feature.
- `freezed` + `json_serializable` para entidades.
- `riverpod_generator` (`@riverpod`).
- `mocktail` en lugar de fakes a mano.
- Carpeta `supabase/migrations/` con SQL versionado.
- Capa de use cases e interfaces de repositorio en `domain/`.

## 15. Fuera de v1 / proponer fase

Lector Bluetooth de microchip, integración con laboratorios (IDEXX/Abaxis), recetas en PDF, APIs de razas (Dog/Cat API) y pagos no están en el roadmap actual. Si el usuario los pide, propón una fase nueva; no los implementes dentro de otra tarea.

## 16. Referencias

- `references/modelo-dominio.md`: tablas, relaciones e invariantes derivados de `supabase/schema.sql`.
- `references/colombia.md`: formatos y reglas de Colombia alineados con `lib/core/utils`.
