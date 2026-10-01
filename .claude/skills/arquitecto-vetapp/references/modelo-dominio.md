# Modelo de dominio de VetApp

Derivado de `supabase/schema.sql` (la fuente de verdad). Si algo aquí difiere del schema, gana el schema. Cada invariante se marca **[DB]** (check, unique, FK, trigger o RLS) o **[App]** (se valida solo en Flutter).

## Contenido

1. Convenciones generales
2. clinicas, perfiles
3. clientes
4. mascotas, mascota_pesos
5. consultas
6. citas, cita_mascotas
7. RLS en resumen
8. Planeado (sin columnas definidas)

## 1. Convenciones generales

- Multi-tenencia por `clinica_id`. Las tablas hijas llevan `clinica_id` y FKs compuestas `(x_id, clinica_id)` hacia `unique (id, clinica_id)` del padre, para que una fila nunca apunte a otra clínica. [DB]
- Solo VETERINARIO opera datos de negocio; los clientes (dueños) **no tienen cuenta** salvo vinculación (Fase 9).
- Historial append-only para peso y consultas: sin política update/delete. [DB]
- `estado` de cita es `text` + check, no enum (el enum solo existe para `rol_perfil`).
- Teléfonos y textos libres se guardan como `text not null default ''`.

## 2. clinicas y perfiles

**clinicas**: `id`, `nombre` (no vacío [DB]), `ciudad`, `direccion`, `telefono`, `created_at`. La crea el trigger de registro cuando el usuario es VETERINARIO. Lectura solo para veterinarios de esa clínica. [DB]

**perfiles**: `id` (= `auth.users.id`, on delete cascade), `nombre`, `rol` (`rol_perfil`: `VETERINARIO` | `CLIENTE`), `clinica_id` (on delete set null), `telefono`, `created_at`.

- Un VETERINARIO siempre tiene clínica (`veterinario_requiere_clinica`). [DB]
- Lo crea el trigger `on_auth_user_created` (`crear_perfil_nuevo_usuario`, security definer) a partir de `raw_user_meta_data` (`rol`, `nombre`, `telefono`, `clinica_*`). [DB]
- Nadie puede cambiar su propio `rol` ni `clinica_id` (política `perfiles_update` con `with check`); un insert directo solo permite `CLIENTE` sin clínica. [DB]
- Cada usuario ve su perfil; el veterinario ve los de su clínica. [DB]

## 3. clientes

Dueños de mascotas registrados por el veterinario. Columnas: `id`, `clinica_id` (cascade), `nombre` (no vacío), `telefono`, `email` (nullable), `direccion`, `notas`, `created_at`, `updated_at`, y para vinculación: `perfiles_id` (nullable, FK a `auth.users`, on delete set null), `codigo_vinculacion` (nullable), `codigo_expira_en`.

- `unique (id, clinica_id)` habilita las FKs compuestas. [DB]
- `codigo_vinculacion` debe ser exactamente 6 dígitos y es único **global** (índice parcial), no solo por clínica. [DB]
- El código lo genera la RPC `generar_codigo_vinculacion` (security invoker); el lado CLIENTE que lo reclama (`reclamar_codigo_cliente`) **no existe aún** (Fase 9). [DB]
- `updated_at` lo mantiene el trigger `tocar_updated_at`. [DB]
- Solo el veterinario de la clínica hace select/insert/update/delete. [DB]
- Normalización del teléfono a `57XXXXXXXXXX` y aviso de número dudoso: solo en Flutter (`telefono_co.dart`). [App]
- Borrar un cliente borra en cascada sus mascotas y citas (D-20). [DB]

## 4. mascotas y mascota_pesos

**mascotas**: `id`, `dueno_id`, `clinica_id`, `nombre` (no vacío), `especie` (texto libre en BD), `raza`, `fecha_nacimiento` (nullable), `foto_path` (ruta en el bucket privado `mascota-fotos`, nunca una URL firmada), `created_at`.

- FK compuesta `mascotas_dueno_misma_clinica_fkey (dueno_id, clinica_id) -> clientes(id, clinica_id)` on delete cascade; `unique (id, clinica_id)`. [DB]
- Mapeo a enum `Especie` (`especieDesdeTexto`) y fecha no futura: [App] (`mascota.dart`, `formato.dart`). La BD acepta cualquier texto de especie.
- Storage `mascota-fotos`: políticas por carpeta = `mi_clinica_id()`. [DB]
- RPCs atómicas: `registrar_cliente_con_mascota`, `registrar_mascota` (security invoker). [DB]

**mascota_pesos**: `id`, `mascota_id` (cascade), `peso_kg numeric(6,2)` (> 0), `registrado_en`, `created_at`. Append-only: sin update/delete. [DB] El rango `0 < peso < 1000` y el formato con coma: [App] (`parsearPeso`).

## 5. consultas

Historia clínica. Columnas: `id`, `mascota_id` (cascade), `veterinario_id` (FK a `auth.users`, on delete cascade), `fecha`, `anamnesis`, `peso_kg`, `temperatura_c`, `frecuencia_cardiaca`, `frecuencia_respiratoria`, `mucosas`, `diagnostico`, `tratamiento`, `evolucion`, `cita_id` (nullable, on delete set null), `created_at`.

- `diagnostico` y `tratamiento` obligatorios y no vacíos. [DB]
- Examen físico opcional; si viene, los numéricos deben ser > 0. [DB] Rangos máximos y mensajes: [App] (`parsearNumeroPositivo`).
- Solo-append: sin update/delete, ni para el autor; una corrección es una fila nueva sin vínculo formal (Fase 3, D-01). [DB]
- `veterinario_id` debe ser el usuario que inserta. [DB]
- `cita_id` opcional; única por `(cita_id, mascota_id)` cuando no es null (índice parcial). [DB]
- Si trae `cita_id`, la mascota debe estar en `cita_mascotas` de esa cita, de la misma clínica, y la cita en `pendiente`/`confirmada`/`completada`; no recibe consultas una cita `cancelada`, `no_asistio` o `solicitada`. [DB]
- `registrar_consulta(p_cita_id, ...)` (security invoker) guarda consulta y peso en una sola transacción (D-02): el peso también alimenta `mascota_pesos`. [DB]

## 6. citas y cita_mascotas

**citas**: `id`, `clinica_id`, `cliente_id`, `veterinario_id`, `fecha_hora timestamptz`, `duracion_min` (5 a 480, default 30), `modalidad` (`consultorio` | `domicilio`, default `consultorio`), `direccion`, `motivo` (no vacío, default `Consulta general`), `notas`, `estado` (default `pendiente`), `recordatorio_enviado_at` (nullable), `created_at`, `updated_at`.

- `estado` en: `solicitada`, `pendiente`, `confirmada`, `completada`, `cancelada`, `no_asistio`. `solicitada` está reservada para la Fase 9; la app trata un valor desconocido o `solicitada` como pendiente (`EstadoCita.desdeValor`). [DB]/[App]
- `domicilio` exige `direccion` no vacía (`citas_domicilio_requiere_direccion`). [DB]
- FK compuesta `(cliente_id, clinica_id) -> clientes` on delete cascade (borrar cliente borra sus citas). `veterinario_id -> auth.users` on delete **restrict**: no se puede borrar un veterinario con citas. [DB]
- Insert directo solo en `pendiente`/`confirmada`, con `veterinario_id = auth.uid()`. Sin política delete: cancelar es cambiar el estado. [DB]
- Trigger `citas_validar_update` (BEFORE UPDATE, aplica también a las RPC):
  - `cliente_id`, `clinica_id` y `veterinario_id` son inmutables.
  - Fecha, duración, modalidad, dirección, motivo y notas solo se editan si la cita estaba `solicitada`/`pendiente`/`confirmada`.
  - `recordatorio_enviado_at` se puede marcar o desmarcar siempre.
  - Transiciones permitidas: `solicitada -> pendiente|confirmada|cancelada`; `pendiente -> confirmada|completada|cancelada|no_asistio`; `confirmada -> pendiente|completada|cancelada|no_asistio`; `cancelada|no_asistio -> pendiente` (Reabrir, siempre).
  - Solo dentro de 10 minutos desde `old.updated_at` ("Deshacer"): `cancelada|no_asistio -> confirmada` y `completada -> pendiente|confirmada`.
  - Nunca: volver a `solicitada`, ni `cancelada|no_asistio -> completada`, ni terminal a terminal.
- **Solapes**: sin exclusion constraint. Dos citas pueden cruzarse; la app solo **avisa sin bloquear** (Fase 4, D-09/D-10) con `cita_solapes.dart`. [App]
- `crear_cita` y `actualizar_cita` (security invoker) manejan la cita y sus mascotas en una transacción. [DB]
- Recordatorios locales (`flutter_local_notifications`) y mensaje de WhatsApp: [App].

**cita_mascotas**: PK `(cita_id, mascota_id)` más `clinica_id`; FKs compuestas a `citas` y `mascotas` (cascade). Una cita cubre varias mascotas del mismo cliente (D-03). [DB]

- Insert directo: la mascota debe ser del cliente de la cita, misma clínica, y la cita `pendiente`/`confirmada`. Sin update; delete solo veterinario de la clínica. [DB]

## 7. RLS en resumen

- Helpers `security definer`: `mi_perfil()`, `es_veterinario()`, `mi_clinica_id()`; `execute` revocado a `anon`/`public` y concedido a `authenticated`. [DB]
- Todas las políticas son `to authenticated` y combinan `es_veterinario()` con `clinica_id = mi_clinica_id()` (o un `exists` sobre la mascota/cita padre).
- No hay políticas para el rol CLIENTE sobre datos clínicos; las agregará la Fase 9.
- Cada cambio de RLS lleva checks en `supabase/tests/rls_smoke_test.sql`.

## 8. Planeado (sin columnas definidas)

No existen tablas ni columnas para esto en `schema.sql`; no inventes columnas al diseñarlas, defínelas en la fase correspondiente con `vetapp-supabase`.

- Vacunas y desparasitación: Fase 5.
- Inventario/productos con stock mínimo: Fase 6.
- Facturas/cotizaciones con ítems y descuento de inventario: Fase 7.
- Directorio de veterinarias, reclamo del código de vinculación, citas `solicitada` y reseñas (estrellas + comentario, una por cliente y clínica): Fase 9.

Las entidades Dart de `lib/features/{vaccination,inventory,billing}/domain/entities/` (`vacuna.dart`, `producto.dart`, `factura.dart`) son stubs del scaffolding original y **todavía no se mapean a ninguna tabla**.
