# Phase 5: Vacunación y Desparasitación - Research

**Researched:** 2026-10-01
**Domain:** Carné de vacunación derivado (SQL como fuente única), alertas de clínica, y primera superficie pública anónima (carné compartible)
**Confidence:** MEDIUM-HIGH (esquema/patrones: HIGH, leídos del repo; hosting público: HIGH en restricciones de Supabase, MEDIUM en detalles de despliegue)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-00:** Fricción cero (Fase 2 D-01): mínimo de campos, búsqueda instantánea, nada de fechas escritas a mano.
- **D-01:** Catálogo base editable: protocolos estándar de Colombia precargados (tablas en `05-PROTOCOLOS-RESEARCH.md`); cada clínica ajusta intervalos o agrega biológicos propios en Más > Protocolos (modelo sugerido: globales semilla + sobrescrituras/biológicos por `clinica_id`).
- **D-02:** Serie automática: el protocolo sabe cuántas dosis tiene la serie primaria y cuándo pasa a refuerzo; la app infiere qué dosis toca según el historial, muestra "Dosis 2 de 3" / "Refuerzo". La próxima se calcula desde la fecha real de aplicación. La próxima dosis nunca es un campo guardado editable (Pitfall 7).
- **D-03:** Duración distinta al estándar (antirrábica 1 vs 3 años; externo 1 mes / 5 sem / 3 meses): chips de duración al registrar, con la del protocolo preseleccionada. Nunca se escribe una fecha.
- **D-04:** Biológico "Otro": nombre libre + chips de intervalo (21 días, 1 mes, 3 meses, 6 meses, 1 año, sin refuerzo), con opción "Guardar en mi catálogo".
- **D-05:** Entradas: (a) sección Carné en la ficha de la mascota ("+ Registrar dosis"); (b) al completar una cita con motivo Vacunación/Desparasitación se ofrece registrar la dosis; (c) acceso rápido global "Vacunar" (Inicio/Agenda): buscar mascota → registrar. NO sección de vacunas dentro del formulario de consulta.
- **D-06:** Obligatorios: biológico + fecha (precargada hoy). Opcionales: producto/marca, lote, observaciones (autocompletar con últimos productos/lotes de la clínica).
- **D-07:** Dosis históricas o aplicadas en otra clínica: fecha pasada + switch "Aplicada en otra clínica" (nombre opcional). Cuentan para serie y cálculo; el carné las muestra diferenciadas.
- **D-08:** Corrección: anular con motivo (queda tachada, no cuenta) y registrar la correcta. Sin edición ni borrado (solo-append, HIST-04).
- **D-09:** Cada dosis guarda el veterinario que la registró/aplicó (4.1). La tabla de dosis se agrega a `es_autor_en_mi_clinica` (04.1 D-13) para que nombre/matrícula sigan visibles aunque el vet ya no sea miembro.
- **D-10:** Alertas: tarjeta en Inicio, pantalla "Vacunas pendientes" agrupada Vencidas/Próximas, badge "Vencida"/"Próxima" en lista de pacientes y ficha. Sin push/local diaria.
- **D-11:** Ventana "Próxima" por tipo: refuerzo anual/trianual 14 días antes; dosis de serie 3 días antes; desparasitación 5 días antes. "Vencida" desde D+1.
- **D-12:** Acciones rápidas desde una alerta: Recordar por WhatsApp (formal, "usted", marca "recordatorio enviado" con fecha), Agendar cita (cliente, mascota, motivo prellenados), Registrar dosis (biológico preseleccionado), Descartar/posponer.
- **D-13:** Vencidas hace más de 6 meses salen de la lista activa (siguen marcadas en el carné).
- **D-14:** Alertas de toda la clínica, no por veterinario.
- **D-15:** Carné público tipo certificado: mascota (nombre, especie, raza, foto), clínica, veterinario con matrícula, y por dosis: biológico, producto, lote, fecha, vigencia/próxima y estado. Dosis externas marcadas. Nada de historia clínica ni contacto del dueño más allá de lo mínimo.
- **D-16:** Un link permanente por mascota, siempre actualizado, revocable ("Regenerar link" invalida el anterior). Token no adivinable.
- **D-17:** Compartir: WhatsApp al dueño (mensaje formal + link al +57 del cliente), hoja de compartir nativa, PDF descargable (`pdf`/`printing`). Sin QR.
- **D-18:** El dueño lo ve sin cuenta (VAC-05).
- **D-19:** Carné público y PDF llevan pie discreto "Hecho con VetApp" (siempre se muestra en esta fase).

### Claude's Discretion
- Schema exacto (tabla de dosis, protocolos global+clínica, cálculo vista/función vs Dart, RLS y tests vía `vetapp-supabase`); reconciliar `vacuna.dart`.
- Mecanismo de la página pública (Edge Function HTML, RPC anónima + página estática, u otro).
- Ajustes del catálogo base (intervalos por defecto dentro de rangos del research).
- Sugerencia de "reiniciar serie" (solo sugerencia, nunca bloqueo).
- Plantilla exacta de WhatsApp (recordatorio y envío del carné).
- Diseño visual (se resuelve en `/gsd-ui-phase 5`).

### Deferred Ideas (OUT OF SCOPE)
- Notificación local diaria de vacunas pendientes.
- Sección "Vacunas aplicadas" dentro del formulario de consulta.
- Código QR del carné.
- Vista "¿Puede ir a guardería?".
- Recordatorio automático al dueño sin toque manual (DIFF-01, v2).
- Descuento de inventario al aplicar una vacuna (Fase 6/7).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VAC-01 | Registrar vacuna/desparasitación aplicada (biológico, fecha) | Tabla `dosis_aplicadas` + RPC `registrar_dosis` (§Schema); entradas D-05 (§Entry points) |
| VAC-02 | Próxima fecha calculada por protocolo, no editable | Función SQL `_carne_filas` como única fuente (§Calculation); sin columna de próxima fecha |
| VAC-03 | Alerta de dosis próxima/vencida | RPC `vacunas_pendientes()` + `vacunas_resumen_mascotas()`; tabla `vacuna_alertas` para descartar/posponer/recordado (§Alerts) |
| VAC-04 | Link público de solo lectura sin exponer historia clínica | `carne_enlaces` + Edge Function JSON `carne` + RPC `carne_publico` solo `service_role` (§Public carné) |
| VAC-05 | Dueño ve el carné sin cuenta | Página estática (GitHub Pages) que consume la Edge Function; token en fragmento `#` (§Public carné) |
</phase_requirements>

## Summary

La fase se resuelve con **SQL como única fuente de verdad del cálculo**. Las dosis aplicadas son filas append-only (con anulación); el catálogo de protocolos es una tabla con semillas globales (`clinica_id is null`) y filas por clínica; una función interna `_carne_filas(clinica, mascota?, hoy)` deriva, por (mascota, biológico), la posición en la serie, la próxima fecha, el estado y la etiqueta ("Dosis 2 de 3" / "Refuerzo"). Los tres consumidores (app, alertas de toda la clínica, página pública) llaman a esa misma función vía RPC; Dart solo formatea. Se descarta el cálculo en Dart porque las alertas son consultas de toda la clínica (traer todo el historial al cliente no escala) y la página pública (JS) tendría que duplicar la lógica.

La **superficie pública** tiene una restricción dura verificada: Supabase reescribe `text/html` a `text/plain` en Edge Functions y Storage en el dominio por defecto (solo con Custom Domain, de pago, se permite). Por eso el HTML no puede servirse desde Supabase gratis. Recomendación: **página estática** (HTML+JS vanilla, sin Flutter web) alojada en **GitHub Pages** (el repo `StevenEscobarC/VetApp` es público; costo cero), que lee el token del fragmento `#` y llama a una **Edge Function que devuelve JSON** (permitido en el dominio por defecto). La Edge Function es el único punto público: llama a la RPC `carne_publico` concedida solo a `service_role` (anon NO puede ejecutarla) y firma la URL de la foto del bucket privado. El token es de 244 bits (dos `gen_random_uuid()`), revocable por regeneración.

**Primary recommendation:** Delta `Fase 5` al final de `supabase/schema.sql` (después del bloque 4.1, para que la redefinición de `es_autor_en_mi_clinica` gane en cada re-pegado) con `protocolos_vacunacion`, `dosis_aplicadas`, `vacuna_alertas`, `carne_enlaces`, función `_carne_filas` + RPCs; Edge Function `carne` (JSON, `verify_jwt=false`); página estática `public_carne/` desplegada a GitHub Pages por Actions; Dart: entidad `DosisAplicada`/`Protocolo`/`EstadoCarne` reemplaza `vacuna.dart`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Cálculo próxima dosis / estado / posición de serie | Database (función SQL) | — | Fuente única para app, alertas de clínica y página pública; sin campo editable (Pitfall 7) |
| Catálogo de protocolos (semilla + override) | Database | App (pantalla Protocolos) | RLS por clínica; semillas globales de solo lectura |
| Registro / anulación de dosis (append-only) | API (RPC invoker/definer) | Database (RLS, FK restrict) | Invariantes (no futuro, motivo obligatorio, anular una vez) en el servidor |
| Alertas (Inicio, lista, badges) | Database (`vacunas_pendientes`, `vacunas_resumen_mascotas`) | App (providers Riverpod) | Consultas set-based de toda la clínica; el cliente solo muestra |
| Descartar/posponer/recordatorio enviado | Database (`vacuna_alertas`, RLS) | App | Estado de gestión anclado a la última dosis; se resetea solo al registrar otra |
| Link público (token, revocación) | Database (`carne_enlaces` + RPCs) | App (botón Regenerar/Desactivar) | Token generado en servidor; el app solo lo muestra |
| Servir datos públicos | API (Edge Function JSON) | Database (`carne_publico`, service_role) | Único punto anónimo; firma foto, valida formato, 404 uniforme |
| Renderizar carné público | CDN / Static (GitHub Pages) | Browser (JS) | Supabase no sirve HTML gratis; página sin framework, rápida en datos móviles |
| PDF del carné | Browser/Client (app, `pdf`/`printing`) | — | Mismo patrón de Fase 3; consume el mismo JSON de `carne_de_mascota` |
| WhatsApp / compartir | Client (app) | — | `whatsappUri`, `lanzadorExterno`, `compartidorProvider` ya existentes |

## Standard Stack

### Core (todo ya instalado; esta fase NO agrega paquetes Dart)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase_flutter | ^2.9.1 (lock 2.17.2) | RPC/RLS desde el app | Ya en uso; repos con traducción de errores a español [VERIFIED: pubspec.yaml] |
| flutter_riverpod | ^3.3.2 | Providers de carné/alertas | Patrón del repo (Riverpod + go_router en uso) [VERIFIED: repo] |
| go_router | ^17.3.0 | Rutas `/pacientes/:id/carne`, `/vacunas`, `/mas/protocolos` | `app_router.dart` + `*_routes.dart` por feature [VERIFIED: repo] |
| pdf / printing | 3.12.0 / 5.14.3 (fijados sin caret: 3.13+/5.15+ requieren Dart >= 3.12) | PDF del carné | Patrón Fase 3 `HistoriaClinicaPdfService` + `compartirPdfProvider` [VERIFIED: pubspec.yaml] |
| share_plus | ^13.3.1 | Hoja nativa con el link | `compartidorProvider` (`lib/core/utils/compartir.dart`) [VERIFIED: repo] |
| url_launcher | ^6.3.2 | WhatsApp `abrirEnApp` | `lanzadorExternoProvider` [VERIFIED: repo] |

### Fuera del app (nuevo, sin dependencias de paquete)
| Pieza | Tecnología | Propósito | Notas |
|-------|-----------|-----------|-------|
| Edge Function `carne` | Deno/TypeScript en Supabase (`supabase/functions/carne/index.ts`) | JSON público por token | `verify_jwt = false`; plan gratis incluye 500K invocaciones/mes [CITED: jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs] |
| Página estática `public_carne/` | HTML + CSS + JS vanilla (sin build) | Render del carné para el dueño | Desplegada a GitHub Pages por Actions; usa `fetch` + `location.hash` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Página estática + Edge Function JSON | Edge Function que sirve HTML | **No funciona gratis**: en dominio por defecto `text/html` se reescribe a `text/plain`; requiere Custom Domain de pago [CITED: supabase.com/changelog/29633-xhtml-responses-are-only-allowed-with-a-custom-domain-enabled] |
| idem | HTML en Supabase Storage público | Storage también devuelve HTML como texto plano [CITED: github.com/orgs/supabase/discussions/2557] |
| idem | Flutter web route (`/c/<token>`) | Bundle de ~2 MB+ (CanvasKit) en datos móviles de un dueño sin app, fuentes por Google Fonts, más superficie de ataque; app tiene guard de auth en `app_router.dart` que habría que abrir. Solo si se prefiere un único codebase y se acepta el peso |
| GitHub Pages | Cloudflare Pages / Netlify | Equivalentes gratis; Cloudflare permite headers (CSP real) y repos privados. Pages no permite headers → usar `<meta>` CSP/referrer. Cambiar es trivial (carpeta estática) |
| RPC anon directa `carne_publico` | Edge Function intermedia | RPC anon es más simple y testeable en SQL, pero **no puede firmar la foto** (bucket privado) y expone PostgREST con la anon key sin control. Fallback documentado en Open Questions |

**Installation:** ninguna dependencia Dart nueva. Edge Function: despliegue por Supabase MCP `deploy_edge_function` o `supabase functions deploy carne --no-verify-jwt` [ASSUMED: verificar con CLI instalada]. Página: workflow de GitHub Pages.

## Package Legitimacy Audit

Esta fase no instala paquetes externos nuevos (todos los usados ya están en `pubspec.yaml` desde fases previas). Edge Function y página usan solo APIs nativas (`Deno.serve`, `fetch`) y `@supabase/supabase-js` vía `npm:`/`jsr:` solo si se decide usar cliente; **recomendación: no usar cliente, usar `fetch` a `/rest/v1/rpc/carne_publico` con la service key** → cero dependencias.

**Packages removed due to slopcheck [SLOP] verdict:** none (no se instaló ninguno)
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
 VET (app Flutter)                                        DUEÑO (sin cuenta)
 ───────────────                                          ──────────────────
 Ficha > Carné ──► registrar_dosis RPC ─┐                 abre https://<pages>/c/#<token>
 Completar cita ─► (mismo flujo)        │                          │ (fragmento: nunca viaja al servidor)
 "Vacunar" global ► (mismo flujo)       ▼                          ▼
                              ┌──────────────────────┐   página estática (GitHub Pages)
 anular_dosis RPC ───────────►│  dosis_aplicadas     │   JS lee location.hash → POST
 Protocolos (Más) ──► CRUD ──►│  protocolos_vacunacion│        │
 gestionar_alerta ──► upsert─►│  vacuna_alertas      │        ▼
 regenerar_enlace_carne ─────►│  carne_enlaces       │   Edge Function `carne` (JSON, sin JWT)
                              └─────────┬────────────┘     1. valida formato token (regex) → 404 uniforme
                                        │                  2. service_role → RPC carne_publico(token)
                         _carne_filas(clinica, mascota?, hoy)   3. firma foto (Storage, TTL corto)
                         ◄── ÚNICA fuente del cálculo ──►       4. JSON mínimo D-15, no-store
                                        │                          │
        ┌───────────────────────────────┼───────────────────┐      ▼
        ▼                               ▼                   ▼   render terracota/crema + "Hecho con VetApp"
 carne_de_mascota(mascota)   vacunas_pendientes()   vacunas_resumen_mascotas()
 (ficha, PDF, WhatsApp)      (Inicio, lista, D-13)  (badges en lista de pacientes)
```

### Recommended Project Structure
```
lib/features/vaccination/
├── domain/
│   ├── entities/            # dosis_aplicada.dart, protocolo.dart, carne_item.dart (REEMPLAZAN vacuna.dart)
│   ├── vacuna_failure.dart  # patrón AuthFailure/CitaFailure
│   ├── whatsapp_vacunas.dart# mensajeRecordatorioVacuna / mensajeCarne (reusa whatsappUri)
│   └── ventanas.dart        # SOLO etiquetas/colores de estado; NO calcula fechas
├── data/
│   ├── repositories/supabase_vacuna_repository.dart
│   └── services/carne_pdf_service.dart   # clon del patrón HistoriaClinicaPdfService (fuentes inyectables)
└── presentation/
    ├── vacunacion_routes.dart            # patrón agenda_routes.dart / pacientes_routes.dart
    ├── providers/                        # carne_providers, alertas_providers, protocolos_providers
    ├── screens/                          # carne_screen? (sección en ficha), registrar_dosis_screen, vacunas_pendientes_screen, protocolos_screen
    └── widgets/                          # estado_chip, dosis_card, enlace_carne_sheet
supabase/functions/carne/index.ts         # Edge Function JSON
public_carne/                             # index.html, carne.css, carne.js (+ .github/workflows/pages-carne.yml)
```

### Pattern 1: Modelo de datos (propuesto; nombres a confirmar por el planner)

**`protocolos_vacunacion`** (catálogo)
- `id uuid pk`, `clinica_id uuid null references clinicas on delete cascade` (null = semilla global), `codigo text not null` (clave estable: `polivalente`, `antirrabica`, `custom:<uuid>` para biológicos de clínica), `nombre`, `tipo text check in ('vacuna','desparasitacion_interna','desparasitacion_externa')`, `especies text[]`, `edad_min_dias int`, `dosis_serie int not null default 1`, `intervalo_serie_dias int`, `intervalo_refuerzo_dias int` (null = sin refuerzo), `opciones_duracion_dias int[]` (chips D-03), `intervalos_por_edad jsonb null` (solo desparasitación interna: `[{"hasta_dias":56,"intervalo":15},{"hasta_dias":180,"intervalo":30},{"intervalo":90}]`), `activo boolean default true`.
- Unicidad: `unique (coalesce(clinica_id,'00000000-0000-0000-0000-000000000000'), codigo)`.
- **Override = fila de clínica con el MISMO `codigo` que la global**. Catálogo efectivo de una clínica = su fila si existe, si no la global. Un override con `activo=false` oculta la global. Como el historial se enlaza por `codigo` (no por `id`), editar/ocultar un protocolo nunca rompe dosis previas.
- Semillas (`insert … on conflict do nothing`, idempotente): tablas §1 de `05-PROTOCOLOS-RESEARCH.md`. Una sola fila `polivalente` (perro) y los óctuple/séxtuple/quíntuple son texto en `producto`, no protocolos distintos. Códigos mínimos: `puppy_dp`, `polivalente`, `leptospirosis`, `bordetella`, `antirrabica` (perro+gato, opciones `{365,1095}`, default 365), `triple_felina`, `leucemia_felina`, `desp_interna` (con `intervalos_por_edad`), `desp_externa` (opciones `{30,35,84}`, default 30). Defaults dentro de rango = suposición ya señalada en el research de dominio; validar con 2-3 vets (no bloquea).
- RLS: select a vets activos (globales + propios); insert/update/delete solo filas con `clinica_id = mi_clinica_id()`; globales intocables (sin política que las permita). Recomendación: edición del catálogo solo `es_admin_clinica()` (ver Open Questions O3).

**`dosis_aplicadas`** (append-only)
- `id`, `mascota_id`, `clinica_id` (FK compuesta `(mascota_id, clinica_id) → mascotas(id, clinica_id)`; el unique ya existe, `schema.sql:537`), `veterinario_id uuid not null references auth.users on delete restrict` + FK adicional a `perfiles(id) on delete restrict` con nombre `dosis_veterinario_perfil_fkey` (para embed `veterinario:perfiles!dosis_veterinario_perfil_fkey(nombre, matricula, activo)`, como `consultas_veterinario_perfil_fkey`), `codigo_protocolo text not null` (`otro:<slug>` si es libre), `biologico_nombre text not null` (snapshot, el carné sobrevive a ediciones del catálogo), `tipo text`, `producto`, `lote`, `observaciones`, `fecha_aplicacion date not null`, `duracion_elegida_dias int null` (override de chip, D-03; null = el del protocolo), `sin_refuerzo boolean default false` (chip "sin refuerzo", D-04), `es_refuerzo boolean default false` (salta la serie: adulto que llega con carné de papel), `inicia_serie boolean default false` ("reiniciar serie", sugerencia §3.6), `externa boolean default false`, `clinica_externa text`, `anulada boolean default false`, `motivo_anulacion`, `anulada_at`, `anulada_por`, `created_at`.
- **Sin columna de próxima fecha ni de número de dosis** (ambas derivadas).
- Fecha como `date` (no `timestamptz`): evita corrimiento por zona; el app precarga hoy con `diaBogota(DateTime.now())`. Validar `fecha_aplicacion <= hoy_bogota` dentro de la RPC (un `check` con `now()` no es inmutable).
- Índice `(mascota_id, codigo_protocolo, fecha_aplicacion)` y `(clinica_id)`.
- RLS: select por `clinica_id = mi_clinica_id()` + `es_veterinario()`; insert con `veterinario_id = auth.uid()` y mascota de la clínica; **sin política update/delete** (HIST-04). `anular_dosis(p_id, p_motivo)` es `security definer`, valida clínica + motivo no vacío + no anulada ya, y es el único camino de UPDATE (solo toca las 4 columnas de anulación).

**`vacuna_alertas`** (gestión mutable, no clínica): `dosis_ref_id uuid pk references dosis_aplicadas` (la **última** dosis válida del biológico), `clinica_id`, `descartada_at`, `pospuesta_hasta date`, `recordatorio_enviado_at timestamptz`. Anclar a `dosis_ref_id` hace que al registrar una dosis nueva la gestión previa deje de aplicar sola (la nueva última dosis no tiene fila). RLS por clínica; upsert directo permitido a vets activos. Posponer con chips 7/15/30 días (nada de fechas escritas).

**`carne_enlaces`**: `mascota_id pk`, `clinica_id`, `token text unique not null`, `activo boolean default true`, `creado_at`, `regenerado_at`. Token = `replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')` (64 hex, 244 bits; `gen_random_uuid()` es núcleo de Postgres, mismo criterio ya documentado en `schema.sql:350`). RLS select solo vets de la clínica; escritura únicamente vía RPC `obtener_o_crear_enlace_carne(p_mascota)` y `regenerar_enlace_carne(p_mascota)` / `desactivar_enlace_carne(p_mascota)` (definer, validan clínica).

### Pattern 2: Cálculo derivado — una función, tres consumidores

```sql
-- Source: diseño propio sobre schema existente (patrón security definer + search_path del repo)
-- _carne_filas: INTERNA, sin grants a anon/authenticated. Devuelve 1 fila por (mascota, codigo_protocolo)
-- con la última dosis válida y todo lo derivado.
create or replace function public._carne_filas(p_clinica uuid, p_mascota uuid, p_hoy date)
returns table (mascota_id uuid, codigo_protocolo text, biologico_nombre text, tipo text,
               ultima_dosis_id uuid, ultima_fecha date, posicion int, dosis_serie int,
               proxima_fecha date, etiqueta_proxima text, estado text, dias_vencida int,
               ventana_dias int, sugerir_reiniciar boolean)
language sql stable security definer set search_path = public as $$
  with validas as (
    select d.*,
           sum(d.inicia_serie::int) over w as serie_idx
    from public.dosis_aplicadas d
    where d.clinica_id = p_clinica and not d.anulada
      and (p_mascota is null or d.mascota_id = p_mascota)
    window w as (partition by d.mascota_id, d.codigo_protocolo order by d.fecha_aplicacion, d.created_at)
  ), pos as (
    select v.*, row_number() over (partition by mascota_id, codigo_protocolo, serie_idx
                                   order by fecha_aplicacion, created_at) as n,
           count(*)     over (partition by mascota_id, codigo_protocolo, serie_idx) as total
    from validas v
  )
  -- ... join lateral al protocolo efectivo (clínica o global por codigo), quedarse con n = total,
  -- posicion = case when es_refuerzo then dosis_serie else n end,
  -- proxima = fecha + case when posicion < dosis_serie then intervalo_serie
  --                        when sin_refuerzo then null
  --                        else coalesce(duracion_elegida_dias, intervalo_por_edad(...), intervalo_refuerzo) end,
  -- ventana = case tipo like 'desparasitacion%' then 5 when posicion < dosis_serie then 3 else 14 end,
  -- estado  = case when proxima is null then 'completo'
  --                when p_hoy > proxima then 'vencida'
  --                when p_hoy >= proxima - ventana then 'proxima' else 'al_dia' end
$$;
```
- `p_hoy` es **parámetro**: las RPCs públicas pasan `(now() at time zone 'America/Bogota')::date` (Colombia sin DST, UTC-5 fijo, coherente con `zona_bogota.dart`); el smoke test pasa fechas fijas → pruebas deterministas sin `now()`.
- Wrappers con grants: `carne_de_mascota(p_mascota)` (authenticated; verifica `mascotas.clinica_id = mi_clinica_id()`), `vacunas_pendientes()` (authenticated; D-13: excluye `vencida` con `dias_vencida > 180`, y filas descartadas/pospuestas vía `vacuna_alertas`; devuelve también datos de mascota/cliente/teléfono para las acciones D-12), `vacunas_resumen_mascotas()` (por mascota: n vencidas / n próximas, para badges), `carne_publico(p_token)` (**solo `service_role`**).
- Dosis anuladas y externas aparecen en la lista detallada del carné (tachadas/diferenciadas) pero **nunca** entran a `validas`.
- `sugerir_reiniciar`: `posicion < dosis_serie and p_hoy - ultima_fecha > 42` (research §3.6); solo bandera de UI.
- Etiqueta de la próxima: `posicion < dosis_serie` → "Dosis {posicion+1} de {dosis_serie}"; si no → "Refuerzo". `completo` = sin refuerzo.
- Mascota sin ninguna dosis de un biológico → no hay fila (no se alerta "nunca vacunada"; fuera de alcance, ver Open Questions O5).

### Pattern 3: Dart — solo mapeo y presentación
```dart
// Source: convención del repo (zona_bogota.dart, formato.dart)
// `date` de Postgres llega como 'YYYY-MM-DD'. NO usar DateTime.parse (hora local).
DateTime fechaDeBd(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
// Mostrar con formatearFecha(...) (dd/mm/aaaa). Hoy de Bogotá: diaBogota(DateTime.now()).
```
`EstadoCarne { alDia, proxima, vencida, completo }` se mapea 1:1 con `AppStatus`/`AppStatusChip` existentes (`lib/core/widgets/status/`). Repositorio `SupabaseVacunaRepository` con `try/on PostgrestException/catch` → `VacunaFailure` con mensajes en español (patrón `SupabaseCitaRepository`; mapear `23503`, `42501`, `P0001`, `23514`).

### Pattern 4: Página pública + Edge Function
```ts
// supabase/functions/carne/index.ts — Source: diseño propio; Deno.serve estándar de Supabase Edge Functions
const TOKEN = /^[0-9a-f]{64}$/;
Deno.serve(async (req) => {
  const cors = { 'Access-Control-Allow-Origin': ORIGEN_PAGES, 'Vary': 'Origin' };
  if (req.method === 'OPTIONS') return new Response(null, { headers: { ...cors, 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'content-type' } });
  const { token } = await req.json().catch(() => ({}));
  const nf = () => new Response(JSON.stringify({ error: 'no_encontrado' }), { status: 404, headers: { ...cors, 'content-type': 'application/json', 'cache-control': 'no-store' } });
  if (typeof token !== 'string' || !TOKEN.test(token)) return nf();      // sin tocar la BD
  // fetch SUPABASE_URL/rest/v1/rpc/carne_publico con la service role key (secreto del runtime, nunca en el cliente)
  // si vacío/error → nf() (revocado e inexistente indistinguibles)
  // si hay foto_path → createSignedUrl(bucket mascota-fotos, 300s) y reemplazar por foto_url; NUNCA devolver foto_path
  // responder JSON D-15, cache-control: no-store
});
```
- Página `public_carne/index.html`: `<meta name="referrer" content="no-referrer">`, `<meta name="robots" content="noindex,nofollow">`, CSP por `<meta>` (`default-src 'self'; connect-src https://<ref>.supabase.co; img-src 'self' https://<ref>.supabase.co data:; style-src 'self'; script-src 'self'`). Token leído de `location.hash` (el fragmento no se envía al servidor de Pages, no queda en logs ni en `Referer`), enviado por POST. Renderizar con `textContent` (nunca `innerHTML` con datos de la BD → XSS por nombre de producto/lote/clínica).
- Branding terracota/crema, Caprasimo + Figtree: **autoalojar las fuentes** (woff2 en `public_carne/`) en lugar de Google Fonts, para no filtrar la visita a un tercero (Ley 1581/privacidad) y evitar bloqueo en datos móviles.
- Estilos `@media print` para "Imprimir/guardar PDF" desde el navegador del dueño (cero código extra).
- Footer "Hecho con VetApp" (D-19) fijo en página y PDF.
- URL del link compartido: `https://stevenescobarc.github.io/VetApp/c/#<token>` [ASSUMED: ruta final según config de Pages; moverla a un dominio propio después solo cambia una constante `kCarneBaseUrl` (dart-define)].

### Anti-Patterns to Avoid
- **Guardar `proxima_dosis` / `numero_dosis`** en cualquier tabla (viola D-02/Pitfall 7). Tampoco cachearlo en `vacuna_alertas`.
- **Duplicar la lógica de cálculo en Dart y JS**: el cálculo vive solo en `_carne_filas`.
- **RPC pública concedida a `anon`**: expone PostgREST sin control y no puede firmar fotos; la RPC pública es `service_role` only.
- **Token en query string** (`?t=`): queda en logs/Referer/historial de WhatsApp preview; usar fragmento.
- **Devolver `foto_path`, `dueno_id`, teléfono, email, dirección, `cliente_id`, notas** en el JSON público.
- **Redefinir `es_autor_en_mi_clinica` ANTES del bloque 4.1** del archivo: cada re-pegado del archivo recrearía la versión vieja (el bloque 4.1 ya recrea las suyas en cada ejecución). Va después, al final.
- **Sección de vacunas en el formulario de consulta** (descartado por D-05).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Token no adivinable | Generador propio en Dart/JS | `gen_random_uuid()` x2 en servidor | CSPRNG del servidor, sin extensiones, 244 bits |
| Hoy en Bogotá | `DateTime.now().toLocal()` | `diaBogota`/`aBogota` (Dart) y `now() at time zone 'America/Bogota'` (SQL) | Zona del dispositivo mueve el día |
| WhatsApp/+57 | Formateo propio de teléfonos | `normalizarTelefono`, `estadoWhatsApp`, `whatsappUri`, `lanzadorExterno.abrirEnApp` | Ya prueban celular/fijo/internacional (VET-25) |
| PDF | Dibujar con canvas | `pdf` + `printing` + `PdfGoogleFonts` inyectable (clon de `HistoriaClinicaPdfService`) | Seam de tests ya resuelto |
| Compartir | `Intent` nativo | `compartidorProvider` / `Printing.sharePdf` | Ya inyectables en tests |
| Rate limiting de la página | Contadores propios | Entropía del token + 404 uniforme + validación de formato | Con 244 bits la enumeración es inviable; ver Threat Model |
| Chips/estado UI | Widgets nuevos | `AppFilterChip`, `AppStatusChip`, `AppCard`, `AppButton` | Identidad visual ya definida |
| Cálculo de fechas de calendario (meses) | Sumar 30 días por "1 mes" | Duraciones en **días** (30/35/84/365/1095) como en el research | Evita ambigüedad de meses; fechas siempre `date + int` |

**Key insight:** el dominio es "aritmética de fechas + estado", que es trivial en SQL con ventanas y devastador si se duplica; todo el valor está en tener una sola definición probada por el smoke test.

## Runtime State Inventory

No aplica (fase aditiva, no es rename/refactor). Único ítem: `supabase/functions/` y `public_carne/` son artefactos nuevos; `es_autor_en_mi_clinica` se **redefine** (cambio de función viva, ver Pitfall 2). `vacuna.dart` no tiene referencias en `lib/` ni `test/` [VERIFIED: grep], se puede reemplazar sin migración.

## Common Pitfalls

### Pitfall 1: HTML en Supabase (verificado)
**What goes wrong:** Se construye una Edge Function que devuelve `text/html` y el navegador muestra código fuente.
**Why:** En dominio por defecto Supabase reescribe a `text/plain` (Functions y Storage); solo Custom Domain lo permite.
**How to avoid:** JSON desde Edge Function + HTML estático en otro host. **Warning signs:** la página muestra etiquetas como texto.

### Pitfall 2: Orden del delta y `es_autor_en_mi_clinica`
**What goes wrong:** La definición con `dosis_aplicadas` se pierde al re-pegar el archivo porque el bloque 4.1 posterior recrea la versión sin dosis; el carné pierde nombre/matrícula del vet retirado (rompe D-09 silenciosamente).
**How to avoid:** bloque Fase 5 después del 4.1 (antes del `notify pgrst` final), `create or replace` con `OR exists(select 1 from dosis_aplicadas d where d.clinica_id = mi_clinica_id() and d.veterinario_id = p_id)`, actualizar el comentario "Fase 5: la tabla de vacunas debe sumarse aquí", y un check de smoke test (como P28) que lea el nombre de un vet retirado vía embed.
**Warning signs:** `veterinario` llega `null` en el embed de dosis.

### Pitfall 3: Serie mal inferida
**What goes wrong:** Adulto que llega con carné de papel (dosis externa de hace 11 meses) aparece como "Dosis 2 de 3 en 21 días".
**How to avoid:** switch "Es refuerzo (ya vacunado antes)" (`es_refuerzo`) en el formulario, sugerido cuando la mascota tiene > 16 semanas y no hay dosis previas del biológico; `inicia_serie` para reiniciar. Solo sugerencia, nunca bloqueo (D-00).

### Pitfall 4: Anular una dosis cambia posiciones
**What goes wrong:** Anular la dosis 1 hace que la 2 pase a ser "1 de 3" y la próxima fecha se mueva.
**Why/How:** es el comportamiento correcto (D-08: no cuenta), pero la UI debe decirlo ("Al anular, el carné se recalcula") y el smoke test debe cubrirlo.

### Pitfall 5: `date` parseado como hora local en Dart
`DateTime.parse('2026-10-02')` es medianoche local; al formatear/comparar con `aBogota` hay corrimientos. Usar `fechaDeBd` (UTC) y comparar solo `date` con `date`.

### Pitfall 6: Mascota/cliente eliminado
Cascada: `mascotas` → `dosis_aplicadas` y `carne_enlaces` (`on delete cascade`) para no dejar enlaces huérfanos que 404 correctamente; `veterinario_id` es `restrict` (consistente con 4.1 D-06: borrar un auth.user con dosis falla, no destruye registros clínicos).

### Pitfall 7: Foto en bucket privado
`foto_path` no sirve en público. La Edge Function firma TTL corto (300 s) y la página la pide en cada carga; nunca persistir la URL firmada. Si la firma falla, mostrar el carné sin foto (degradación, no error).

### Pitfall 8: Privacidad / Ley 1581 de 2012
Datos de la mascota y de la clínica no son datos personales del dueño; el **nombre del dueño sí lo es**. Recomendación: **no incluir ningún dato del dueño** en el carné público (D-15 "más allá de lo mínimo" → mínimo = nada) [ASSUMED: confirmar con el usuario, ver O4]. La matrícula/nombre del vet es dato profesional exigido por ICA (D-15). El link es un "secreto portador": quien lo tenga lo ve; la UI debe advertirlo al compartir y ofrecer Regenerar/Desactivar.

### Pitfall 9: `notify pgrst, 'reload schema'` y firmas
Cada RPC nueva con parámetros por defecto: eliminar firmas viejas (`drop function if exists …`) antes de cambiar argumentos, como se hizo con `crear_cita` (9 args); evita sobrecargas ambiguas en PostgREST.

## Code Examples

### Aplicar y probar el esquema (patrón del proyecto, Plan 04.1-01)
1. Delta idempotente al **final** de `supabase/schema.sql` (`create table if not exists`, `drop policy if exists` + `create policy`, `create or replace function`, `revoke … from public, anon` + `grant … to authenticated`, `notify pgrst, 'reload schema'`).
2. Aplicar en vivo con Supabase MCP `apply_migration` (nombre `fase_05_vacunacion`) **con autorización explícita del usuario**; el SQL del smoke test lo pega el usuario en el SQL Editor (el envío por MCP lo bloqueó el clasificador de seguridad en 4.1) → tarea `[BLOCKING]` human-action.
3. Extender `supabase/tests/rls_smoke_test.sql` con el bloque **Q (Q1..Qn)** y actualizar el total esperado (4.1 dejó 145 checks): aislamiento por clínica de las 4 tablas, FK restrict del vet, anulación (motivo obligatorio, una sola vez, no cuenta), cálculo con `p_hoy` fijo (serie 1/3→3/3→refuerzo; antirrábica 365 vs 1095; chip sin refuerzo; `es_refuerzo`; reinicio; ventanas 14/3/5 exactas en los bordes D-3, D, D+1; D-13 a 180/181 días; externa cuenta), descartar/posponer se resetean al registrar dosis nueva, `es_autor_en_mi_clinica` con vet retirado, `anon` no ejecuta ninguna RPC nueva ni `carne_publico`, `authenticated` tampoco ejecuta `carne_publico` ni `_carne_filas`, `regenerar_enlace_carne` invalida el token anterior, y `carne_publico` solo devuelve las claves D-15 (check de la lista de keys, que no aparezca `telefono`/`email`/`dueno`).
4. `supabase/tests/verify_live_schema.sh`: añadir sondas anónimas — tablas nuevas `[]`/401, RPCs nuevas `protegido 401`, `carne_publico` vía `/rest/v1/rpc` con anon = 401/403/404, y Edge Function con token mal formado = 404 JSON (sin tocar BD).

### WhatsApp (plantillas propuestas, formales, "usted")
```dart
// Source: patrón de lib/features/appointments/domain/whatsapp_recordatorio.dart
String mensajeRecordatorioVacuna({required String cliente, required String mascota,
    required String biologico, required String fecha, required String firma}) =>
  'Hola $cliente, le recordamos que a $mascota le corresponde ${biologico.toLowerCase()} '
  'el $fecha. — $firma. Responda a este mensaje para agendar su cita.';
String mensajeCarne({required String cliente, required String mascota, required String url, required String firma}) =>
  'Hola $cliente, este es el carné de vacunación de $mascota, siempre actualizado: $url — $firma.';
```
- "Recordatorio enviado" se marca (upsert `vacuna_alertas.recordatorio_enviado_at`) solo si `abrirEnApp` devolvió `true` (misma regla VET-25 que citas: `wa.me` en navegador no cuenta).

### PDF
Clonar `HistoriaClinicaPdfService`: constructor con `CargarFuentesPdf` inyectable, `generar({mascota, items, clinica})` → `Uint8List`, errores → `VacunaFailure`. Dosis anuladas con `pw.TextDecoration.lineThrough`, externas con etiqueta "Otra clínica", pie "Hecho con VetApp". Compartir con `compartirPdfProvider` (`Printing.sharePdf`). Los datos salen del mismo `carne_de_mascota`, por lo que PDF, app y página pública no pueden divergir.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Edge Function sirviendo HTML en dominio por defecto | Solo con Custom Domain; si no, `text/plain` | Cambio de Supabase publicado 2024-10-02 | La página debe vivir fuera de Supabase |
| `proximaDosis` guardada (`vacuna.dart`) | Derivada de protocolo + historial | Esta fase (Pitfall 7) | Se elimina la entidad actual |
| Ventana fija de 7 días (`requiereRefuerzoProximo`) | 14/3/5 días por tipo (D-11) | Esta fase | Lógica en SQL |

**Deprecated/outdated:** `lib/features/vaccination/domain/entities/vacuna.dart` (`TipoBiologico`, `proximaDosis`); comentarios de Firebase en otras entidades no aplican.

## Entry Points & Integración con código existente

| Punto | Archivo existente | Cambio |
|-------|-------------------|--------|
| Sección Carné en ficha | `lib/features/patients/presentation/screens/mascota_detail_screen.dart` (500 líneas) | Sección "Carné" con resumen (estados + "+ Registrar dosis") y "Compartir carné"; mantener el archivo manejable extrayendo widgets a `vaccination/presentation/widgets` |
| Completar cita | `.../appointments/presentation/screens/completar_cita_screen.dart` | Hoy ofrece "¿Registrar la consulta?" por mascota (`onRegistrar` → `context.push('/agenda/:id/completar/consulta/:mid')`, `_omitidas`, `mascotasConConsulta`). Añadir, solo si `cita.motivo` ∈ {Vacunación, Desparasitación} (`motivos_cita.dart`), una acción "Registrar dosis" por mascota → ruta de registro con `mascotaId` y biológico sugerido por motivo. NO tocar el flujo de consulta; el estado "dosis registrada" se refleja volviendo a consultar `carne_de_mascota` (no hay `cita_id` en dosis; vincular dosis↔cita es opcional → ver O6) |
| Acceso rápido "Vacunar" | `inicio_screen.dart` | Botón → selector de mascota con búsqueda instantánea (reusar el patrón de `pacientes_list_screen.dart`) → registrar dosis |
| Tarjeta Inicio | `inicio_screen.dart` | Provider `resumenVacunasProvider` desde `vacunas_pendientes()` ("3 vencidas, 5 esta semana") |
| Badges | `pacientes_list_screen.dart` + ficha | `vacunas_resumen_mascotas()` (un solo RPC; no N+1) |
| Protocolos | `mas_screen.dart` + nuevo `vacunacion_routes.dart` | Entrada "Protocolos"; registrar rutas en `app_router.dart` como `agendaRoutes`/`pacientesRoutes` |
| Agendar desde alerta | `cita_form_screen.dart` | Parámetros prellenados (cliente, mascota, motivo "Vacunación"/"Desparasitación") vía `extra`/query |
| Guard de router | `app_router.dart` `_publicPaths` | **No tocar**: la superficie pública NO es una ruta del app (vive en Pages) |

Los números de ruta y firmas exactas los define el planner leyendo `agenda_routes.dart`/`pacientes_routes.dart`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | URL final de Pages `https://stevenescobarc.github.io/VetApp/c/#<token>` y que el usuario acepta alojar la página en el repo público | Pattern 4 | Si prefiere dominio propio/otro host, solo cambia `kCarneBaseUrl` |
| A2 | `supabase functions deploy --no-verify-jwt` / MCP `deploy_edge_function` disponibles en el entorno del usuario | Standard Stack | Si no, tarea humana de despliegue o fallback sin foto (O2) |
| A3 | El carné público no muestra NINGÚN dato del dueño | Pitfall 8 | Si el usuario quiere nombre del dueño, agregarlo explícitamente (Ley 1581: aviso de privacidad) |
| A4 | Edición del catálogo solo por admin de clínica | Schema | Friccionaría a vets no-admin; ajustable por política RLS |
| A5 | Un solo protocolo `polivalente` (valencia = texto en `producto`) | Schema | Si los vets quieren protocolos distintos por valencia, agregar semillas |
| A6 | Defaults de intervalos del research (suposiciones ya marcadas) | Schema semillas | Validar con 2-3 vets; son datos editables, no código |
| A7 | Supabase no ofrece rate limit por IP para Edge Functions sin configuración adicional | Threat Model | Si lo ofrece, usarlo como defensa en profundidad |
| A8 | GitHub Pages gratis para repo público, sin headers personalizables | Standard Stack | Si cambian condiciones, migrar a Cloudflare Pages (misma carpeta) |

## Open Questions

1. **Dónde calcular (SQL vs Dart)** — RESOLVED por este research: SQL (`_carne_filas`); CONTEXT lo dejó a discreción.
2. **Foto en carné público (D-15) con bucket privado** — RESOLVED: Edge Function firma TTL 300 s. Fallback si el despliegue de la función se bloquea: RPC anon `carne_publico` sin foto en una primera entrega y foto en seguimiento (el planner puede partir la oleada así).
3. **¿Quién edita el catálogo (admin vs cualquier vet)?** — OPEN, recomendación admin (A4); confirmar en plan o discuss rápido.
4. **¿Algún dato del dueño en el público?** — OPEN, recomendación ninguno (A3).
5. **Mascota sin dosis de un biológico ("nunca vacunada")** — OPEN, fuera de alcance (D-10 solo habla de dosis próximas/vencidas); backlog junto a "¿Puede ir a guardería?".
6. **Vincular dosis ↔ cita (`cita_id` nullable)** — OPEN, recomendación: agregar columna nullable `cita_id` (como `consultas.cita_id`) para marcar "dosis registrada" en `completar_cita_screen`; si se omite, usar la heurística "dosis de hoy para esa mascota". Decisión de plan.
7. **Mecanismo público** — RESOLVED: página estática en GitHub Pages + Edge Function JSON (CONTEXT lo dejó a discreción).
8. **Revocación/regeneración** — RESOLVED por D-16: `regenerar_enlace_carne` reemplaza el token; `desactivar_enlace_carne` además bloquea sin reemplazo.
9. **Tono/plantilla WhatsApp** — RESOLVED: formal con "usted" (D-12, Fase 4 D-14); plantillas arriba.
10. **Descartar/posponer: motivos** — RESOLVED con persistencia en `vacuna_alertas` (descartar con chips de motivo opcionales: "Falleció", "Cambió de veterinario", "Otro"; posponer 7/15/30 días).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase proyecto vivo (MCP `apply_migration`) | Aplicar delta | ✓ (usado en 4.1) | — | Pegado manual en SQL Editor |
| SQL Editor (usuario) | Smoke test | ✓ (manual) | — | — |
| Edge Functions (plan gratis) | `carne` | ✓ (cuota 500K/mes) | — | RPC anon sin foto (O2) |
| GitHub repo público | Pages | ✓ (`StevenEscobarC/VetApp`, visibility PUBLIC [VERIFIED: gh]) | — | Cloudflare Pages |
| `gh` CLI | Verificar/activar Pages | ✓ | — | UI de GitHub |
| Flutter/Dart SDK | Tests/build | ✓ (Dart ^3.11.1) | — | — |
| Node (pruebas JS de la página) | Opcional | ? no verificado | — | Probar la página manualmente + sonda curl |

**Missing dependencies with no fallback:** ninguna conocida. **Acción humana necesaria:** activar GitHub Pages (Settings > Pages > Source: GitHub Actions) y autorizar `apply_migration`/deploy de la función.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + fakes en `test/helpers/` ; SQL: `supabase/tests/rls_smoke_test.sql` (manual en SQL Editor) |
| Config file | `analysis_options.yaml` (flutter_lints); sin config de test aparte |
| Quick run command | `flutter test test/<archivo>_test.dart` |
| Full suite command | `flutter test` y `flutter analyze` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VAC-01 | Registrar dosis (biológico+fecha; externa; anular con motivo) | widget + repo fake | `flutter test test/registrar_dosis_screen_test.dart` | ❌ Wave 0 |
| VAC-01 | RLS/RPC de dosis (aislamiento, append-only, anulación) | SQL smoke | pegar `rls_smoke_test.sql` (bloque Q) | ✅ extender |
| VAC-02 | Serie 1/3→refuerzo, duración elegida, ventanas, `es_refuerzo`, reinicio | SQL smoke (`p_hoy` fijo) | `rls_smoke_test.sql` Q | ✅ extender |
| VAC-02 | Mapeo Dart de filas calculadas, `fechaDeBd`, etiquetas | unit | `flutter test test/vacuna_mapeo_test.dart` | ❌ Wave 0 |
| VAC-03 | Tarjeta Inicio, lista Vencidas/Próximas, badges, D-13, descartar/posponer | widget + provider fake | `flutter test test/vacunas_pendientes_screen_test.dart` | ❌ Wave 0 |
| VAC-03 | WhatsApp recordatorio (marca solo si `abrirEnApp` true) | widget (`FakeLanzadorExterno`) | `flutter test test/whatsapp_vacunas_test.dart` | ❌ Wave 0 |
| VAC-04 | Enlace: crear/regenerar/desactivar, compartir texto/WhatsApp/PDF | widget + fakes (`fake_compartir`, `fake_pdf`) | `flutter test test/enlace_carne_sheet_test.dart`, `test/carne_pdf_service_test.dart` | ❌ Wave 0 |
| VAC-04/05 | `carne_publico` solo claves D-15; token viejo inválido; anon/authenticated sin acceso | SQL smoke + sonda | `rls_smoke_test.sql` Q + `bash supabase/tests/verify_live_schema.sh` | ✅ extender |
| VAC-05 | Edge Function: token mal formado → 404; válido → JSON mínimo; página renderiza sin cuenta | manual + curl | `curl` documentado en plan; verificación visual en celular | manual-only (justificación: host externo) |

### Sampling Rate
- **Per task commit:** `flutter test <archivo del task>` + `flutter analyze`
- **Per wave merge:** `flutter test`
- **Phase gate:** suite completa verde + smoke SQL PASS + `verify_live_schema.sh` LIVE_SCHEMA_OK antes de `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/helpers/fake_vacunas.dart` — `FakeVacunaRepository` (patrón `FakeCitaRepository`: logs de llamadas, `error`/`errorX` inyectables)
- [ ] Tests listados arriba (registro, mapeo, pendientes, WhatsApp, enlace, PDF)
- [ ] Bloque Q en `rls_smoke_test.sql` (+ nuevo total)
- [ ] Sondas en `verify_live_schema.sh`
- Framework: ya instalado; ninguna instalación nueva

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (el público no autentica; el link es secreto portador) | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | RLS por `clinica_id` + `es_veterinario()`; RPC definer con verificación interna; `revoke … from public, anon`; `carne_publico` solo `service_role` |
| V5 Input Validation | yes | Regex de token en Edge Function; `check`/validaciones en RPC (fecha no futura, longitudes, motivo obligatorio); render con `textContent` |
| V6 Cryptography | yes | Token CSPRNG (`gen_random_uuid` x2); no hand-roll |
| V8 Data Protection | yes | JSON mínimo D-15, `no-store`, sin `foto_path`, URL firmada TTL corto, Ley 1581 |

### Known Threat Patterns (superficie pública)
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Enumeración/adivinanza de tokens | Information Disclosure | 244 bits; formato validado antes de la BD; 404 uniforme (inexistente = revocado) |
| Fuga del token por Referer/logs/preview | Information Disclosure | Token en fragmento `#`, POST en el cuerpo, `referrer: no-referrer`, `noindex` |
| Link reenviado a terceros | Information Disclosure | Contenido mínimo; Regenerar/Desactivar; advertencia al compartir |
| XSS por datos de clínica (nombre, producto, lote) | Tampering / Elevation | `textContent`, CSP por `<meta>`, sin `innerHTML` |
| Exposición de PostgREST con anon key | Information Disclosure | `carne_publico` no concedida a anon; sonda en `verify_live_schema.sh` |
| Service role key | Elevation of Privilege | Solo como secreto del runtime de la función; nunca en cliente ni repo público |
| DoS / scraping de la función | Denial of Service | Validación temprana barata, cuota gratis 500K/mes, sin cálculo caro antes de validar (A7); monitorear invocaciones |
| Lectura cruzada entre clínicas | Information Disclosure | RLS + `clinica_id` compuesto + checks Q del smoke test |
| Veterinario retirado destruye/oculta historial | Tampering | `veterinario_id on delete restrict` + `es_autor_en_mi_clinica` extendido |
| Edición retroactiva de dosis | Tampering | Sin política update/delete; anulación solo por RPC |
| CORS abierto | — | `Access-Control-Allow-Origin` solo al origen de Pages |

## Sources

### Primary (HIGH confidence)
- Repo: `supabase/schema.sql` (helpers 4.1, patrón RPC/RLS, unique mascotas `(id, clinica_id)`), `supabase/tests/rls_smoke_test.sql`, `verify_live_schema.sh`, `04.1-01-SUMMARY.md`, `pubspec.yaml`, `app_router.dart`, `completar_cita_screen.dart`, `historia_clinica_pdf_service.dart`, `compartir.dart`, `lanzador_externo.dart`, `whatsapp_recordatorio.dart`, `zona_bogota.dart`
- https://supabase.com/changelog/29633-xhtml-responses-are-only-allowed-with-a-custom-domain-enabled — HTML solo con Custom Domain
- `.planning/research/PITFALLS.md` §Pitfall 7; `05-CONTEXT.md`; `05-PROTOCOLOS-RESEARCH.md`

### Secondary (MEDIUM confidence)
- https://github.com/orgs/supabase/discussions/2557 — Storage devuelve HTML como texto plano
- https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/ — 500K invocaciones/mes en plan gratis
- https://supabase.com/docs/guides/functions/limits — límites de Edge Functions

### Tertiary (LOW confidence)
- Detalles de despliegue de Pages/Edge Function (A1, A2, A7, A8): no verificados en esta sesión

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no hay paquetes nuevos, todo leído de `pubspec.yaml`
- Architecture (SQL como fuente única, esquema): HIGH — alineado con patrones y helpers reales del repo
- Hosting público: MEDIUM — restricción de Supabase verificada; despliegue Pages/Edge sin probar aún
- Pitfalls: HIGH para esquema/orden de delta; MEDIUM para privacidad (Ley 1581 sin asesoría legal)

**Research date:** 2026-10-01
**Valid until:** 2026-10-31 (la política de HTML de Supabase y precios pueden cambiar; revalidar antes de ejecutar)
