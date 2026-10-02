# VetApp

App móvil en Flutter para veterinarios independientes y clínicas pequeñas en Colombia, con Supabase como backend real (Postgres + RLS).

## Supabase

El proyecto ya existe en la nube (`apjonrmhkpyzbofupokb`). Para dejarlo listo desde cero (o verificar que sigue correcto):

1. En **SQL Editor**, pega y ejecuta [`supabase/schema.sql`](supabase/schema.sql).
2. En una consulta nueva, pega y ejecuta [`supabase/tests/rls_smoke_test.sql`](supabase/tests/rls_smoke_test.sql). Es intencional que termine en un mensaje de error: espera un texto que empiece con `RLS SMOKE: PASS` (el script fuerza una excepción al final para revertir automáticamente todos los datos de prueba que creó — no deja residuos).
3. Corre `bash supabase/tests/verify_live_schema.sh` — debe terminar con `LIVE_SCHEMA_OK` (prueba con la clave `anon` que las 4 tablas multi-tenant responden y que un insert anónimo es rechazado).
4. En **Authentication > Providers > Email**, revisa el estado de **"Confirm email"**. Por defecto está en ON: un registro nuevo exige abrir el correo de confirmación antes de poder iniciar sesión. Para desarrollo puedes apagarlo temporalmente (los registros hechos desde la app inician sesión de inmediato), pero **debe volver a estar en ON antes de tener usuarios reales**.
5. En **Authentication > URL Configuration**, agrega la URL de redirección de la aplicación para recuperación de contraseña.

El trigger de `auth.users` crea automáticamente la fila en `perfiles`. Si el rol es `VETERINARIO`, también crea la clínica indicada durante el registro. Los dueños de mascotas viven en la tabla `clientes` (sin cuenta propia, sin fila en `auth.users`) — el veterinario los registra directamente. Las políticas RLS aíslan cada clínica por `clinica_id` en `clinicas`, `perfiles`, `clientes` y `mascotas`; esa es la única frontera de aislamiento multi-tenant (la app no filtra por clínica en el cliente).

## Fase 2 — Clientes y Pacientes

Esta fase agrega historia clínica básica de mascotas (fotos, peso, vinculación de cuenta). Requiere aplicar un delta de esquema sobre lo de la Fase 1 y cuatro paquetes nuevos con permisos de cámara.

### Aplicar el delta de esquema (idempotente)

1. En **SQL Editor**, vuelve a pegar y ejecutar el archivo completo [`supabase/schema.sql`](supabase/schema.sql) (incluye la Fase 1 y la Fase 2; es idempotente, seguro de re-ejecutar aunque ya tengas la Fase 1 aplicada).
2. En una consulta nueva, pega y ejecuta el archivo completo [`supabase/tests/rls_smoke_test.sql`](supabase/tests/rls_smoke_test.sql) (también extendido con los checks de la Fase 2). Espera el mensaje `RLS SMOKE: PASS (53 checks)` (27 de la Fase 1 + 26 de la Fase 2); es intencional que termine en un error — el script fuerza una excepción al final para revertir automáticamente todos los datos de prueba que creó.
3. Corre `bash supabase/tests/verify_live_schema.sh` — debe terminar con `LIVE_SCHEMA_OK` (ahora también prueba `mascota_pesos` y las 3 RPCs nuevas con la clave `anon`, esperando rechazo).
4. En **Storage**, confirma que el bucket **`mascota-fotos`** existe, es **privado** (sin etiqueta "Public") y tiene exactamente 4 políticas (`mascota_fotos_select`/`insert`/`update`/`delete`, todas para el rol `authenticated`). El esquema las crea junto con el bucket en el paso 1; no se crean manualmente.

### Paquetes nuevos (fotos de mascota)

Instalados y fijados en `pubspec.yaml`:

| Paquete | Versión | Uso |
|---|---|---|
| `image_picker` | `^1.2.3` | Abrir la cámara (o galería) para la foto de la mascota |
| `flutter_image_compress` | `^2.5.1` | Comprimir la foto antes de subirla a Storage |
| `permission_handler` | `^12.0.3` | Verificar/solicitar el permiso de cámara antes de abrirla |
| `cached_network_image` | `^3.4.1` | Cachear y mostrar la foto de la mascota por su `foto_path` |

`cached_network_image` se mantiene deliberadamente en `^3.4.1` (no `^4.x`) hasta un futuro bump del SDK de Dart — la versión 4 exige una constraint de SDK más nueva que la actual (`^3.11.1`).

### Permisos de cámara

- **Android**: `android/app/src/main/AndroidManifest.xml` ya declara `android.permission.CAMERA` y `android.permission.INTERNET`.
- **iOS**: `ios/Runner/Info.plist` ya declara `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription`.
- **macOS** (solo la primera vez que compiles para macOS): `permission_handler` requiere macros de preprocesador explícitas o siempre reporta la cámara como denegada. En el `Podfile` generado (`macos/Podfile`), dentro del bloque `post_install`, agrega a `GCC_PREPROCESSOR_DEFINITIONS`:
  ```
  'PERMISSION_CAMERA=1',
  'PERMISSION_PHOTOS=1',
  ```
  (junto a las demás definiciones ya generadas por CocoaPods). No es necesario en Android/iOS — solo afecta el build de macOS.

## Fase 3 — Historia Clínica

Esta fase agrega el registro estructurado de consultas (historia clínica), la línea de tiempo por paciente y la exportación a PDF. Requiere aplicar un delta de esquema sobre lo de la Fase 1-2 y dos paquetes nuevos para generar/compartir el PDF.

### Aplicar el delta de esquema (idempotente)

1. En **SQL Editor**, vuelve a pegar y ejecutar el archivo completo [`supabase/schema.sql`](supabase/schema.sql) (incluye las Fases 1-3; es idempotente, seguro de re-ejecutar aunque ya tengas las fases anteriores aplicadas).
2. En una consulta nueva, pega y ejecuta el archivo completo [`supabase/tests/rls_smoke_test.sql`](supabase/tests/rls_smoke_test.sql) (también extendido con los checks de la Fase 3). Espera el mensaje `RLS SMOKE: PASS (70 checks)` (53 de las Fases 1-2 + 17 de la Fase 3); es intencional que termine en un error — el script fuerza una excepción al final para revertir automáticamente todos los datos de prueba que creó.
3. Corre `bash supabase/tests/verify_live_schema.sh` — debe terminar con `LIVE_SCHEMA_OK` (ahora también prueba `consultas` y la RPC `registrar_consulta` con la clave `anon`, esperando rechazo).
4. La tabla `consultas` es de solo-append por diseño: no existe política de `update` ni `delete` — una corrección se registra siempre como una consulta nueva, nunca editando o borrando la anterior (HIST-04). La RPC `registrar_consulta` inserta la consulta y, si se envía un peso, también una fila en `mascota_pesos` en la misma transacción (D-02) — nunca dos escrituras separadas.

### Paquetes nuevos (exportar a PDF)

Instalados y fijados en `pubspec.yaml` como versiones **exactas** (sin `^`):

| Paquete | Versión | Uso |
|---|---|---|
| `pdf` | `3.12.0` | Generar el documento PDF de la historia clínica |
| `printing` | `5.14.3` | Abrir la hoja de compartir/guardar nativa del sistema |

Es decir, `pubspec.yaml` fija `pdf: 3.12.0` y `printing: 5.14.3` exactos. Las versiones `3.13+`/`5.15+` de estos paquetes requieren Dart `>=3.12.0`, mientras el proyecto sigue fijado en `^3.11.1` — por eso están pineadas sin caret. **No** correr `flutter pub upgrade` sobre estos dos paquetes; relajar el pin solo después de subir el SDK del proyecto.

La primera exportación descarga la tipografía Noto Sans desde Google Fonts (requiere internet una sola vez; luego queda cacheada localmente). El PDF se comparte solo mediante la hoja nativa del dispositivo — no genera ningún link público ni sube nada a un servidor (D-05, uso exclusivo del veterinario).

## Fase 4 — Agenda y Citas

Agrega `citas` (una o varias mascotas del mismo cliente vía `cita_mascotas`), las RPC `crear_cita` / `actualizar_cita`, el vínculo `consultas.cita_id` y la nueva firma de 11 argumentos de `registrar_consulta` (`p_cita_id`).

1. En **SQL Editor**, pega y ejecuta el archivo completo [`supabase/schema.sql`](supabase/schema.sql) (idempotente; espera "Success. No rows returned").
2. En una consulta nueva, pega y ejecuta [`supabase/tests/rls_smoke_test.sql`](supabase/tests/rls_smoke_test.sql). Espera el mensaje `RLS SMOKE: PASS (115 checks)` (70 de las Fases 1-3 + 25 de la Fase 4 + 20 de los fixes de la revisión de la Fase 4); termina en error a propósito para revertir los datos de prueba.
3. Corre `bash supabase/tests/verify_live_schema.sh` — debe imprimir `OK citas embed` y terminar con `LIVE_SCHEMA_OK`.

## Fase 4.1 — Equipo de la clínica

Agrega membresía y roles (`perfiles.rol_clinica`, `activo`, `matricula`), códigos de invitación de 8 caracteres (`clinica_invitaciones`, vigencia 72 h, un solo uso), las RPC de equipo (`generar_invitacion_clinica`, `revocar_invitacion`, `retirar_miembro`, `cambiar_rol_miembro`, `crear_mi_clinica`, `unirse_a_clinica`), citas asignables por veterinario (`crear_cita` / `actualizar_cita` con `p_veterinario_id`) y `consultas.veterinario_id` en `ON DELETE RESTRICT`.

1. En **SQL Editor**, pega y ejecuta el archivo completo [`supabase/schema.sql`](supabase/schema.sql): ahora incluye las Fases 1-4.1 y debe pegarse entero (idempotente; espera "Success. No rows returned").
2. En una consulta nueva, pega y ejecuta el archivo completo [`supabase/tests/rls_smoke_test.sql`](supabase/tests/rls_smoke_test.sql). Espera el mensaje `RLS SMOKE: PASS (145 checks)` (115 de las Fases 1-4 + 30 de la Fase 4.1); termina en error a propósito para revertir los datos de prueba.
3. Corre `bash supabase/tests/verify_live_schema.sh` — debe imprimir `OK citas veterinario embed`, `OK consultas veterinario embed` y terminar con `LIVE_SCHEMA_OK`.

## Carné público (Fase 5)

El dueño de la mascota abre un enlace y ve el carné de vacunación y desparasitación sin cuenta ni instalación.

**Arquitectura:** página estática en GitHub Pages (`public_carne/`, publicada en `https://stevenescobarc.github.io/VetApp/c/`) -> Edge Function `carne` (JSON, `verify_jwt=false`) -> RPC `carne_publico`, ejecutable solo con `service_role`. La página nunca habla directo con la base de datos.

**Por qué no HTML desde Supabase:** el gateway de Edge Functions reescribe las respuestas HTML a `text/plain`, así que la página se sirve desde Pages y la función solo devuelve JSON.

**Pasos de despliegue**

1. Desplegar la función `supabase/functions/carne/index.ts` con `verify_jwt=false` (CLI `supabase functions deploy carne --no-verify-jwt` o el MCP de Supabase). `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` los inyecta el runtime; `CARNE_ORIGEN` por defecto es `https://stevenescobarc.github.io`.
2. Definir la variable del repo (no es secreta): `gh variable set CARNE_FUNCTION_URL --body "https://<project-ref>.supabase.co/functions/v1/carne"`. El workflow `.github/workflows/pages-carne.yml` genera `config.js` con ella.
3. Activar Pages con fuente GitHub Actions: `gh api -X POST repos/StevenEscobarC/VetApp/pages -f build_type=workflow` (o Settings > Pages > Source: GitHub Actions).
4. `git push origin master`; el workflow "Carné público (GitHub Pages)" publica `public_carne/`.
5. Verificar: `REQUIRE_CARNE_FN=1 bash supabase/tests/verify_live_schema.sh` debe terminar con `LIVE_SCHEMA_OK`.

**App Flutter:** el enlace que copia la app usa por defecto `https://stevenescobarc.github.io/VetApp/c/`. Se puede cambiar con `--dart-define=CARNE_BASE_URL=https://otro.dominio/c/`.

**Privacidad**

- El token va en el fragmento `#` de la URL: no llega a los logs del servidor ni se envía como `Referer` (la página usa `no-referrer`) (D-15).
- Token inválido o inexistente responde siempre `404 {"error":"no_encontrado"}` sin tocar la base de datos si no cumple el formato (D-20).
- Los enlaces se pueden revocar y la respuesta no expone `logo_path` ni `foto_path`; el logo de la clínica y la foto se entregan como URL firmadas de corta vida (el logo, 300 s, D-26) (D-23).
- CORS solo permite el origen de Pages, nunca `*` ni el origen del solicitante.

**FALLBACK (no habilitado; brecha futura):** si el despliegue de la Edge Function quedara bloqueado, se otorgaría a `anon` una RPC pública sin foto (variante de `carne_publico` sin `foto_path`, con el token validado por regex) y la página apuntaría a `/rest/v1/rpc/<rpc>` con la clave anon. Debe planificarse con `/gsd:plan-phase 5 --gaps`; hoy no está activo.

## Ejecutar Flutter

No se guardan claves en el código fuente. Crea un archivo `dart_define.json` en la raíz del repo (ya está en `.gitignore`, nunca se sube) con este contenido:

```json
{
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_ANON_KEY": "TU_CLAVE_PUBLICA"
}
```

Luego:

```powershell
flutter pub get
flutter run --dart-define-from-file=dart_define.json
```

Usa únicamente la clave pública `anon`/`publishable`. Nunca incluyas la `service_role` en la aplicación móvil.

Alternativa equivalente sin archivo (pasando las variables inline):

```powershell
flutter run --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA
```

Otros comandos útiles:

```powershell
flutter analyze
flutter test
```

La sesión la persiste `supabase_flutter` y se restaura al abrir la app (el usuario vuelve directo a Inicio, sin pasar por login). Los errores de Auth se traducen a mensajes sencillos en español.

## Estructura principal

- `lib/core/data/`: `supabaseClientProvider`, el único punto de acceso a `Supabase.instance.client`.
- `lib/core/router/`: `routerProvider` (go_router), redirección basada en el perfil autenticado y las 5 secciones de navegación (`/inicio`, `/pacientes`, `/agenda`, `/clientes`, `/mas`).
- `lib/core/theme/`: paleta terracota/crema y tipografía Caprasimo (títulos) + Figtree (cuerpo).
- `lib/features/auth/`: `data/repositories` (repositorio de Supabase Auth y lectura de perfiles), `presentation/providers` (estado de sesión con Riverpod), `presentation/screens` (login, registro, recuperación, inicio de sesión de cliente).
- `lib/features/home/presentation/`: `AppShell` (contenedor con navegación inferior), `InicioScreen` (datos reales del veterinario) y las pantallas "Próximamente" de los módulos aún no implementados.
- `supabase/schema.sql`: tablas, trigger, índices y políticas RLS.
- `supabase/tests/`: `rls_smoke_test.sql` (prueba de RLS de un solo paste) y `verify_live_schema.sh` (sonda REST con la clave anon).
