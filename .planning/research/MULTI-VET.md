# Multi-veterinario por clínica — análisis y diseño recomendado

**Fecha:** 2026-10-01 · **Estado:** propuesta (sin cambios de código/schema) · **Relacionado:** SCALE-02 (`.planning/REQUIREMENTS.md:115`), fila "Agenda multi-veterinario" en Out of Scope (`REQUIREMENTS.md:124`), `PROJECT.md:43`.

> Idea central: **el modelo de datos ya es "por clínica", no "por veterinario"**. Toda la RLS filtra por `clinica_id = mi_clinica_id()`, así que dos veterinarios con el mismo `perfiles.clinica_id` ya compartirían clientes, mascotas, historia y agenda. Lo que falta es (a) una forma segura de **entrar** a una clínica existente, (b) un **rol dentro de la clínica** (admin vs veterinario) y (c) que agenda/recordatorios/firmas usen al **veterinario asignado** y no "el usuario logueado".

---

## 1. Estado actual

### 1.1 Modelo de identidad

| Elemento | Hoy | Ref |
|---|---|---|
| `rol_perfil` | Enum global de tipo de cuenta: `VETERINARIO` / `CLIENTE` (no hay rol dentro de la clínica) | `supabase/schema.sql:7` |
| `clinicas` | id, nombre, ciudad, dirección, teléfono. Sin dueño, sin código, sin `activa` | `schema.sql:11-18` |
| `perfiles.clinica_id` | 1 clínica por perfil; `on delete set null` + check `veterinario_requiere_clinica` | `schema.sql:24,27` |
| Trigger de registro | `crear_perfil_nuevo_usuario`: si `metadata.rol = 'VETERINARIO'` **siempre inserta una clínica nueva** y le asigna el perfil. No hay forma de unirse a una existente | `schema.sql:78-111` |
| Helpers RLS | `es_veterinario()` (rol = VETERINARIO), `mi_clinica_id()` (lee `perfiles.clinica_id`), ambos `security definer` | `schema.sql:114-125`, hardening `1033-1045` |
| Anti-escalación | `perfiles_update` fija `rol` y `clinica_id` a los valores actuales; `perfiles_insert` solo CLIENTE sin clínica | `schema.sql:147-160` |
| `clinicas` escritura | Solo hay `clinicas_select`; **no existe policy de update** (nadie puede editar los datos de la clínica desde la app) | `schema.sql:138-140` |

### 1.2 Alcance de la RLS: ya es clínica-wide

- `clientes`, `mascotas`, `mascota_pesos`, fotos en Storage, `citas`, `cita_mascotas`, `consultas` (vía mascota): todo `es_veterinario() and clinica_id = mi_clinica_id()` (`schema.sql:164-196, 243-258, 421-454, 501-508, 639-656, 728-752`).
- `perfiles_select` ya permite ver los perfiles de la misma clínica (`schema.sql:144-145`) → listar "el equipo" no necesita policy nueva.
- RPCs (`registrar_cliente_con_mascota`, `registrar_mascota`, `crear_cita`, `actualizar_cita`, `registrar_consulta`, `generar_codigo_vinculacion`) toman la clínica de `mi_clinica_id()` (`schema.sql:269-345, 359-412, 786-950, 952-1030`). **Ninguna asume un único veterinario por clínica**.

### 1.3 Lo que sí asume "un veterinario = la clínica"

| # | Supuesto | Dónde | Efecto con 2+ vets |
|---|---|---|---|
| A1 | Registro de vet crea clínica nueva siempre | `schema.sql:87-96`; `register_screen.dart:70`; `supabase_auth_repository.dart:61-74` | Imposible unirse a una clínica |
| A2 | `citas.veterinario_id` se fuerza a `auth.uid()` al crear | `citas_insert` `schema.sql:645-651`; `crear_cita` `schema.sql:831-834` | No se puede agendar para un colega |
| A3 | `veterinario_id` inmutable en citas | trigger `citas_validar_update` `schema.sql:683-689` | No se puede reasignar una cita |
| A4 | Agenda carga **todas** las citas de la clínica sin filtro por vet | `supabase_cita_repository.dart:23-39` | Agenda mezclada sin forma de filtrar |
| A5 | Solapes se calculan contra todas las citas | `cita_solapes.dart:18-30` (usado en `cita_form_screen.dart:255-307`) | Falsos avisos de cruce entre vets distintos |
| A6 | Recordatorios locales programan todas las citas de 30 días | `recordatorios_providers.dart:~197-209` (`entre(ahora, +30d)` → `planificar`) | **Cada celular notifica las citas de todos** |
| A7 | Firma de WhatsApp = nombre del usuario logueado | `cita_acciones.dart:208-212`, `recordar_manana_sheet.dart:108-112`, `whatsapp_recordatorio.dart:18-23` | Si el vet B envía el recordatorio de una cita del vet A, firma "B" |
| A8 | `consultas.veterinario_id` `on delete cascade` a `auth.users` | `schema.sql:471-476` | Borrar la cuenta de un vet que se fue **borra historia clínica** (registro legal) |
| A9 | Inicio muestra solo `clinicaNombre` del perfil | `inicio_screen.dart:57`; Fase 8 "sus próximas citas" (`ROADMAP.md` Fase 8 SC2) | Ambiguo: ¿mis citas o las de la clínica? |
| A10 | `Factura.veterinarioId` en la entidad (aún sin tabla) | `billing/domain/entities/factura.dart:25,35` | Bien encaminado: atribución, no aislamiento |
| A11 | Timeline de historia no muestra quién atendió | `Consulta.veterinarioId` existe (`consulta.dart:41,52`, `supabase_consulta_repository.dart:90`) pero no se pinta | Con varios vets se pierde la autoría visible |
| A12 | Router solo distingue VETERINARIO vs CLIENTE | `app_router.dart:50` | No hay pantalla "Equipo" ni estado "acceso revocado" |

Conclusión: el aislamiento (lo difícil) ya está bien hecho. El trabajo es de **membresía + atribución + filtros**, no de reescribir RLS.

---

## 2. Gaps de producto

1. **Unirse a una clínica**: no existe. Opciones: (a) código de invitación corto que genera el admin; (b) el admin agrega por email (requiere que el vet ya exista o un email de invitación de Supabase → más fricción y configuración SMTP); (c) enlace profundo. → (a) encaja con el patrón del código de cliente (Fase 2 D-07, `generar_codigo_vinculacion` `schema.sql:359-412`).
2. **Roles internos**: no hay dueño/admin. Alguien debe poder invitar, retirar miembros y editar los datos de la clínica (que hoy nadie puede editar).
3. **Salida de un veterinario**: los datos son de la clínica (todo cuelga de `clinica_id`), deben quedarse. Hay que revocar acceso sin borrar la cuenta (ver A8) y reasignar sus citas futuras.
4. **Agenda**: asignar cita a un vet, filtrar por vet, solapes por vet, reasignar.
5. **Autoría clínica**: consultas ya guardan `veterinario_id`; vacunas (Fase 5), ajustes de inventario (Fase 6) y facturas (Fase 7) deben hacer lo mismo desde el día uno.
6. **Notificaciones**: solo al veterinario asignado.
7. **Facturación**: cada factura registra quién la emitió; ingresos visibles a nivel clínica (al menos para el admin).
8. **Directorio (Fase 9)**: una cita `solicitada` por un cliente aún no tiene veterinario; hoy `citas.veterinario_id` es `not null` (`schema.sql:550`).

---

## 3. Diseño recomendado (mínimo, fricción-cero)

### 3.1 Schema

```sql
-- Rol dentro de la clínica (distinto del tipo de cuenta rol_perfil).
alter table perfiles
  add column rol_clinica text check (rol_clinica in ('admin','veterinario')),
  add column activo boolean not null default true;
-- check: rol = 'CLIENTE' or rol_clinica is not null

-- Invitaciones de un solo uso (varias simultáneas, auditables).
create table clinica_invitaciones (
  id uuid pk default gen_random_uuid(),
  clinica_id uuid not null references clinicas(id) on delete cascade,
  codigo text not null unique,            -- 8 chars, alfabeto sin ambiguos (sin 0/O/1/I/L)
  creada_por uuid not null references auth.users(id),
  expira_en timestamptz not null,         -- now() + 72h
  usada_por uuid references auth.users(id),
  usada_en timestamptz,
  revocada boolean not null default false
);
```

- **Por qué no 6 dígitos como el código de cliente:** ese código da acceso a *tus propias* mascotas; este da acceso a **toda la base clínica** de la clínica. 8 caracteres de un alfabeto de 31 (~8,5·10¹¹) + 72 h + un solo uso hace inviable la fuerza bruta. Se muestra como `K7MQ-4P2X`.
- Se mantiene "1 perfil ↔ 1 clínica" (`perfiles.clinica_id`). No se crea tabla `miembros` N:M: un vet que trabaja en dos clínicas es un caso real pero raro en el segmento objetivo y multiplicaría la complejidad (selector de clínica, `mi_clinica_id()` dependiente de contexto). Queda como pregunta abierta (Q5).
- `citas.veterinario_id` → pasa a **nullable solo si `estado = 'solicitada'`** (Fase 9); para el resto sigue requerido (check).
- Agregar FK `citas.veterinario_id → perfiles(id)` y `consultas.veterinario_id → perfiles(id)` (además/en lugar de `auth.users`) para que PostgREST pueda embeber `perfiles(nombre)` en un solo select.
- **Corregir A8:** `consultas.veterinario_id` a `on delete restrict` (mismo delta idempotente que HI-02 en `schema.sql:586-606`). Política de producto: un vet que sale **se desactiva, nunca se borra**.

### 3.2 Helpers y RLS

- `mi_clinica_id()` → devuelve `null` si `activo = false`. `es_veterinario()` → exige `activo`. Con eso, **todas las policies existentes cortan el acceso de un vet retirado sin tocarlas una por una**.
- Nuevo `es_admin_clinica()` (`security definer`, `rol_clinica = 'admin' and activo`), con el mismo revoke/grant del hardening (`schema.sql:1041-1044`).
- `clinicas_update`: solo `es_admin_clinica() and id = mi_clinica_id()`.
- `clinica_invitaciones`: select/insert/update solo admin de esa clínica; nadie más las ve. La validación del código ocurre únicamente dentro de RPC/trigger `security definer`.
- **Riesgos de escalación y su mitigación:**
  - *Vet se autopromueve a admin / se reactiva / se cambia de clínica:* `perfiles_update` hoy fija `rol` y `clinica_id` con subselects (`schema.sql:149-155`). Recomendado endurecer con **privilegios por columna**: `revoke update on perfiles from authenticated; grant update (nombre, telefono) on perfiles to authenticated;`. Así `rol_clinica`, `activo`, `clinica_id`, `rol` solo cambian vía RPC `security definer`.
  - *Unirse a otra clínica con metadata falsa:* el trigger **nunca** debe leer `clinica_id` de `raw_user_meta_data` (controlado por el usuario); solo `codigo_invitacion`, validado contra la tabla (no usado, no revocado, no expirado) y marcado como usado en la misma transacción (`for update`).
  - *Admin se quita a sí mismo y la clínica queda huérfana:* las RPC de rol/retiro rechazan dejar la clínica con 0 admins activos.
  - *Vet retirado conserva sesión:* RLS corta en la siguiente consulta (helpers leen `activo` en cada llamada); la app muestra "Ya no tienes acceso a {clínica}".
  - *Admin de clínica A actúa sobre perfil de clínica B:* toda RPC compara `p.clinica_id = mi_clinica_id()`.
  - *Asignar cita a un vet de otra clínica o inactivo:* `crear_cita`/`reasignar_cita` validan `veterinario_id` ∈ perfiles activos de `mi_clinica_id()`.

### 3.3 RPCs

| RPC | Quién | Qué hace |
|---|---|---|
| trigger `crear_perfil_nuevo_usuario` (modificado) | registro | Si `metadata.codigo_invitacion` → valida, consume, perfil `rol_clinica='veterinario'` en esa clínica; si es inválido `raise` con mensaje mapeable. Si no hay código → crea clínica como hoy y `rol_clinica='admin'` |
| `generar_invitacion_clinica()` | admin | Crea código 8 chars, 72 h; devuelve código + expiración (patrón de `generar_codigo_vinculacion`) |
| `revocar_invitacion(id)` | admin | Marca revocada |
| `unirse_a_clinica(codigo)` | vet ya registrado | Solo si su clínica actual está **vacía** (él es el único miembro y 0 clientes) → la mueve; si no, error "Tu clínica ya tiene datos; no se pueden fusionar clínicas" |
| `cambiar_rol_miembro(perfil_id, rol)` | admin | Admin ↔ veterinario, nunca deja 0 admins |
| `retirar_miembro(perfil_id)` | admin | `activo=false`; devuelve nº de citas futuras abiertas del vet para que la UI ofrezca reasignar |
| `reasignar_citas(de_vet, a_vet)` / `actualizar_cita(..., p_veterinario_id)` | cualquier vet activo | Reasigna citas abiertas; el trigger `citas_validar_update` (`schema.sql:683-689`) se relaja: `veterinario_id` puede cambiar solo si la cita está solicitada/pendiente/confirmada y el destino es miembro activo |
| `crear_cita(..., p_veterinario_id default auth.uid())` | vet | Default "yo" → cero cambios para el vet independiente |
| (opcional) `validar_codigo_invitacion(codigo)` anon | registro | Devuelve solo el nombre de la clínica para mostrar "Te unirás a Clínica X" antes de crear la cuenta. Opcional; si se hace, con límite de intentos |

`citas_insert` (`schema.sql:645-651`) cambia `veterinario_id = auth.uid()` por "veterinario activo de mi clínica".

### 3.4 Flutter — touchpoints

- **Registro** (`register_screen.dart`, `supabase_auth_repository.dart:61-74`): en rol Veterinario, selector segmentado "Crear mi clínica" / "Tengo un código de clínica". Mapear el error del trigger en `_messageFor` (Supabase lo devuelve como "Database error saving new user").
- **AuthProfile** (`supabase_auth_repository.dart:110-128`): agregar `rolClinica`, `activo`, getter `esAdminClinica`. Router (`app_router.dart:50`): si vet `!activo` → pantalla de acceso revocado (con "Crear mi propia clínica" si se aprueba Q4).
- **Más → "Equipo"** (nueva, en `mas_screen.dart`): lista de miembros (nombre, rol, activo), botón "Invitar veterinario" (muestra código grande + compartir por WhatsApp), acciones de admin (hacer admin, retirar). Para vets no admin: solo lectura. **Más → "Datos de la clínica"** editable por admin.
- **Agenda** (`agenda_screen.dart`, `citas_providers.dart`): chips "Mías / Todas / {colega}" — default **"Mías"**; los chips solo aparecen si la clínica tiene ≥2 vets activos (el vet independiente no ve nada nuevo). `CitaCard` muestra iniciales/avatar del vet asignado cuando hay ≥2.
- **Formulario de cita** (`cita_form_screen.dart`): selector "Veterinario" (default yo; oculto con 1 vet). `solapesCon` (`cita_solapes.dart:18`) filtra por `veterinarioId` del candidato.
- **Recordatorios locales** (`recordatorios_providers.dart` → `planificar`, `recordatorios_plan.dart`): filtrar `veterinarioId == perfil.id`.
- **WhatsApp** (`cita_acciones.dart:208-212`, `recordar_manana_sheet.dart:108-112`): firma con el nombre del **vet asignado** (embebido `perfiles(nombre)` en el select de `supabase_cita_repository.dart`), no `profile.nombre`. La lista "Recordar mañana" de un vet muestra por defecto sus citas.
- **Historia clínica**: timeline y PDF muestran "Atendió: Dr(a). X".
- **Inicio** (`inicio_screen.dart`): "Mis citas de hoy"; contadores clínica-wide solo para admin (Fase 8).

### 3.5 Migración de datos existentes

Delta idempotente al final de `schema.sql`: `update perfiles set rol_clinica='admin' where rol='VETERINARIO' and rol_clinica is null;` (cada vet actual creó su clínica → es su admin). `activo` default true. Las citas/consultas ya tienen `veterinario_id` correcto. Ningún dato se mueve. Extender `rls_smoke_test.sql` con un vet A2 en la clínica de A (positivo: ve todo de A; asigna cita a A), vet retirado (negativo: 0 filas en todas las tablas), auto-promoción (negativo), código expirado/usado/revocado (negativo), clínica sin admins (negativo), cita asignada a vet de B (negativo).

---

## 4. Ubicación en el roadmap

**Recomendación: Phase 4.1 "Equipo de la clínica" (INSERTED), antes de la Fase 5.** Razones:
- Agenda y recordatorios (A2–A7) acaban de cerrarse; el contexto está fresco y son la parte que más cambia.
- Las Fases 5, 6 y 7 crean tablas nuevas; si nacen con `veterinario_id`/`registrado_por` y alertas clínica-wide, no hay retrofit.
- Es pequeña: ~3 planes (schema+RLS+smoke test · registro/equipo/router · agenda/recordatorios/WhatsApp/historia).

Requiere actualizar `REQUIREMENTS.md`: promover SCALE-02 a v1 como `TEAM-01..05` y reescribir la fila de Out of Scope a "Agenda multi-recurso (salas/equipos)", que sigue fuera. Actualizar `PROJECT.md:43`.

Impacto en fases siguientes (aplica aunque 4.1 se posponga):

| Fase | Qué debe hacer para ser multi-vet ready |
|---|---|
| 5 Vacunación | `vacunas_aplicadas.veterinario_id` (default `auth.uid()` vía RPC, FK `restrict`); carné muestra el vet que aplicó; **alertas de dosis próximas/vencidas son de la clínica** (cualquier vet ve todas), no del vet que aplicó; link público por mascota, no por vet |
| 6 Inventario | Stock compartido por clínica; cada ajuste/movimiento guarda `registrado_por` |
| 7 Facturación | `facturas.veterinario_id` (quién emitió, ya está en `factura.dart:25`); visibilidad clínica-wide; el estado pagada/pendiente lo cambia cualquiera |
| 8 Dashboard | "Mis próximas citas" para todos; ingresos/consultas del mes clínica-wide para admin, con filtro por vet opcional |
| 9 Directorio | Cita `solicitada` sin vet (`veterinario_id` nullable solo en ese estado); al aceptarla se asigna (default quien acepta); reseñas siguen siendo por clínica |

---

## 5. Preguntas abiertas (decisión de producto)

1. **¿El vet que se une necesita aprobación del admin?** *Recomendado: no.* El código es de un solo uso, expira en 72 h y lo genera el admin a propósito; el admin ve al nuevo miembro en "Equipo" y puede retirarlo. Aprobación extra = fricción sin ganancia real.
2. **¿Los veterinarios no-admin ven todo (todas las citas, todas las historias, facturas)?** *Recomendado: sí, todo lo clínico y la agenda completa* (es una clínica pequeña; el paciente es de la clínica). Única excepción posible: ingresos/reportes del dashboard solo para admin.
3. **¿Rol "auxiliar/recepción" en v1?** *Recomendado: no.* Contradice la premisa "sin recepcionista"; el enum `rol_clinica` se deja extensible para agregarlo luego (con permisos de agenda/clientes pero sin historia clínica).
4. **Un vet retirado, ¿qué puede hacer con su cuenta?** *Recomendado:* ve una pantalla de "acceso revocado" con opción de **crear su propia clínica vacía** (RPC `crear_mi_clinica`) o unirse a otra con código. Nunca se lleva datos ni se borra su autoría.
5. **¿Un vet puede pertenecer a varias clínicas a la vez?** *Recomendado: no en v1* (1 perfil ↔ 1 clínica). Si aparece la demanda, migrar a tabla `clinica_miembros` + selector de clínica; el diseño de helpers lo permite.
6. **Agenda por defecto: ¿"Mías" o "Todas"?** *Recomendado: "Mías"* (cada vet planea su día y recibe solo sus notificaciones), con chip "Todas" a un toque; el vet independiente no ve ningún cambio.
