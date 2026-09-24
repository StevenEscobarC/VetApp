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
