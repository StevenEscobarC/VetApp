# VetApp

Módulo de autenticación y roles para clínicas veterinarias en Flutter y Supabase.

## Supabase

1. Crea un proyecto gratuito en [Supabase](https://supabase.com/).
2. En **SQL Editor**, pega y ejecuta [`supabase/schema.sql`](supabase/schema.sql).
3. En **Authentication > Providers > Email**, deja activo Email y exige confirmación de correo.
4. En **Authentication > URL Configuration**, agrega la URL de redirección de la aplicación para recuperación de contraseña.

El trigger crea automáticamente una fila en `perfiles`. Si el rol es `VETERINARIO`, también crea la clínica indicada durante el registro. Las políticas RLS están activas desde la creación de las tablas. `mascotas.clinica_id` es el vínculo necesario para aislar mascotas por clínica.

## Ejecutar Flutter

No se guardan claves en el código fuente. Pasa la URL y la clave pública al iniciar:

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA
```

Usa únicamente la clave pública `anon`/`publishable`. Nunca incluyas la `service_role` en la aplicación móvil.

La sesión la persiste `supabase_flutter` y se restaura al abrir la app. El correo de confirmación es obligatorio antes de acceder al perfil. Los errores de Auth se traducen a mensajes sencillos en español.

## Estructura principal

- `lib/features/auth/`: login, registro, recuperación y `AuthGate`.
- `lib/features/auth/data/`: repositorio de Supabase Auth y lectura de perfiles.
- `lib/features/home/`: panel existente de veterinario.
- `lib/features/patients/`: dominio de mascotas para módulos posteriores.
- `supabase/schema.sql`: tablas, trigger, índices y políticas RLS.
