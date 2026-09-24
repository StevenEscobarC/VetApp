---
phase: 01-fundacion
reviewed: 2026-09-24T00:00:00Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - android/app/build.gradle.kts
  - android/settings.gradle.kts
  - lib/core/data/supabase_client_provider.dart
  - lib/core/router/app_router.dart
  - lib/core/theme/app_colors.dart
  - lib/core/theme/app_theme.dart
  - lib/core/theme/app_typography.dart
  - lib/features/auth/domain/auth_failure.dart
  - lib/features/auth/data/repositories/supabase_auth_repository.dart
  - lib/features/auth/presentation/providers/auth_providers.dart
  - lib/features/auth/presentation/screens/auth_scaffold.dart
  - lib/features/auth/presentation/screens/client_home_screen.dart
  - lib/features/auth/presentation/screens/login_screen.dart
  - lib/features/auth/presentation/screens/register_screen.dart
  - lib/features/auth/presentation/screens/reset_password_screen.dart
  - lib/features/home/presentation/app_shell.dart
  - lib/features/home/presentation/screens/coming_soon_screen.dart
  - lib/features/home/presentation/screens/inicio_screen.dart
  - lib/features/home/presentation/screens/mas_screen.dart
  - lib/main.dart
  - supabase/schema.sql
  - supabase/tests/rls_smoke_test.sql
  - supabase/tests/verify_live_schema.sh
  - test/app_theme_test.dart
  - test/helpers/fake_auth.dart
  - test/inicio_screen_test.dart
  - test/widget_test.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-09-24T00:00:00Z
**Depth:** standard
**Files Reviewed:** 26 (`test/widget_test.dart` counted once alongside the 26 listed files; `27` files were listed, `26` unique paths reviewed after de-dup)
**Status:** issues_found

## Summary

Reviewed the Phase 1 "Fundación" walking skeleton: the Riverpod/go_router auth flow, the terracota/crema design tokens, and the real Supabase schema + RLS policies (including the composite `clientes`/`mascotas` tenant model). The Android FlutterFire leftovers were correctly removed, and the previously-dead `domain/` scaffolding (unused `AuthRepository` interface, `Veterinario` entity, usecases) was deleted rather than left to rot.

**RLS self-escalation fix — verified sound.** The old `perfiles_update` policy (`using (id = auth.uid()) with check (id = auth.uid())`) let any authenticated user rewrite their own `rol` and `clinica_id` directly via PostgREST, which (combined with the veterinarian-only RLS policies on `clinicas`/`clientes`/`mascotas`) was a full cross-tenant privilege escalation: a `CLIENTE` could `PATCH` their own `perfiles` row to `rol='VETERINARIO', clinica_id=<any-clinic>` and immediately gain read/write access to that clinic's clients and patients. The fix adds a `with check` that pins `rol` and `clinica_id` to their pre-update values via a self-referencing subquery (`select p.rol from public.perfiles p where p.id = auth.uid()`). Traced through PostgreSQL's RLS evaluation order (WITH CHECK is evaluated against the newly-computed row *before* the new heap tuple is written), this subquery reliably reads the pre-update value, so the check cannot be defeated by a same-statement race. `IS NOT DISTINCT FROM` correctly handles the `CLIENTE` case where `clinica_id` is `NULL`. `supabase/tests/rls_smoke_test.sql` (checks C5/C6/A17) exercises exactly this attack and expects `insufficient_privilege` (SQLSTATE 42501, the correct code for an RLS `WITH CHECK` violation). No bypass found.

**Rate-limit error-masking fix — correctly ordered, but see WR-02/WR-03.** The new `rate limit` branch in `_messageFor` is inserted *before* the generic `password`/`email` substring checks, so a "Email rate limit exceeded" message (which contains the substring `email`) is now caught by the specific branch instead of falling through to the misleading "Ingresa un correo válido." message. The fix is behaviorally correct. However, the replacement message itself has a quality problem (WR-02) and the surrounding substring-matching approach has the same class of masking risk for other message types (WR-03).

No critical/blocker-level defects were found in this batch. Four warnings and three info-level items are listed below — mostly UX/quality gaps in the auth screens and error-message design, not security or data-loss risks.

## Warnings

### WR-01: Reset-password success message rendered in error/red styling

**File:** `lib/features/auth/presentation/screens/reset_password_screen.dart:33-41,51`
**Issue:** `_ResetPasswordScreenState` uses a single `_message` field for *both* the success confirmation ("Revisa tu correo para crear una nueva contraseña.") and the `AuthFailure` error text, and passes it to `AuthScaffold(error: _message, ...)`. `AuthScaffold` unconditionally renders the `error` slot in the destructive/error color (`lib/features/auth/presentation/screens/auth_scaffold.dart:54`: `TextStyle(color: colorScheme.error)`). The result: a *successful* password-reset request is displayed to the user in red, as if something failed — actively misleading. `LoginScreen` and `RegisterScreen` do not have this bug because they only ever put failure text into their `_error` field.
**Fix:** Track success and error separately and only pass real failures into `AuthScaffold.error`, e.g.:
```dart
String? _error;
String? _success;

Future<void> _submit() async {
  setState(() { _loading = true; _error = null; _success = null; });
  try {
    await ref.read(authRepositoryProvider).resetPassword(_email.text);
    if (mounted) {
      setState(() => _success = 'Revisa tu correo para crear una nueva contraseña.');
    }
  } on AuthFailure catch (error) {
    if (mounted) setState(() => _error = error.message);
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```
and render `_success` with a neutral/`AppColors.success` style (or via a `SnackBar`) instead of feeding it into the shared error slot.

### WR-02: Internal Supabase-dashboard operational instructions leaked into production user-facing copy

**File:** `lib/features/auth/data/repositories/supabase_auth_repository.dart:146-150`
**Issue:** The new rate-limit message tells the end user to go into the Supabase dashboard and disable "Confirm email" (`Authentication > Providers > Email`):
```dart
return 'Se alcanzó el límite de correos por ahora. '
    'Desactiva "Confirm email" en Supabase (Authentication > Providers > Email) '
    'para registrarte sin esperar el correo, o intenta de nuevo en unos minutos.';
```
This is developer/operator guidance written for the solo dev's own verification session, not for a real veterinarian/client end user in Colombia — they have no access to (and shouldn't be told about) the project's Supabase configuration. Shipping this string as-is exposes internal backend implementation details to end users and gives them an action they cannot perform.
**Fix:** Keep the user-facing message actionable only for the user; drop the operator instructions:
```dart
if (message.contains('rate limit')) {
  return 'Se alcanzó el límite de correos por ahora. Intenta de nuevo en unos minutos.';
}
```
If the dashboard reminder is useful during development, put it in a code comment or a debug-only log instead of the string shown to real users.

### WR-03: Generic substring matching on "password"/"email" can silently overwrite more specific/accurate Supabase errors

**File:** `lib/features/auth/data/repositories/supabase_auth_repository.dart:151-154`
**Issue:** `_messageFor` maps *any* `AuthException` whose message contains `"password"` to a fixed "La contraseña debe tener al menos 8 caracteres." This will fire for password-related errors that have nothing to do with length (e.g. Supabase's optional password-complexity/strength messages, or a "New password should be different from the old password" style message from a future change-password flow), showing the user an inaccurate fix ("use 8 characters") for a problem that isn't about length. The same risk applies to the trailing `contains('email')` catch-all. This is the exact class of bug the rate-limit fix (WR above) just had to work around by inserting a check *earlier* in the chain — the underlying design (loose substring matching with no distinction by error code) will keep producing this failure mode for any future Supabase error text that happens to contain these common words.
**Fix:** Prefer matching on `AuthException.code` (supabase_flutter/gotrue expose structured error codes, e.g. `weak_password`) where available, falling back to substring matching only for messages with no code; at minimum, add a comment flagging that new branches must be inserted before the generic `password`/`email` fallbacks (as was just done for rate-limiting) to avoid regressing this class of bug again.

### WR-04: `_profileFor` has no specific exception handling for Postgrest failures, unlike every other repository method

**File:** `lib/features/auth/data/repositories/supabase_auth_repository.dart:110-130`
**Issue:** Every other method in this class follows the documented two-tier pattern (`on AuthException catch (error) { throw AuthFailure(_messageFor(error)); } catch (_) { throw const AuthFailure('<generic>'); }`). `_profileFor` talks to Postgrest (`_client.from('perfiles')...`), not GoTrue, so it has *no* specific `on PostgrestException` branch at all — everything (network failure, RLS denial, "no rows found" from `.single()`, a bad cast like `data['rol'] as String` throwing `TypeError`) is swallowed by a single `catch (_)` into "No encontramos tu perfil. Intenta de nuevo." Combined with `AuthProfileNotifier.build()` treating any `AuthFailure` here as "sign the user out" (`lib/features/auth/presentation/providers/auth_providers.dart:41-46`), a transient network blip or a genuine schema/RLS bug during profile fetch will silently force-sign-out the user with no diagnostic trail (no logger exists in the app).
**Fix:** Distinguish "profile row genuinely missing" from other failures, and don't force sign-out on transient failures:
```dart
} on PostgrestException catch (error) {
  throw AuthFailure(
    error.code == 'PGRST116'
        ? 'No encontramos tu perfil. Intenta de nuevo.'
        : 'No fue posible cargar tu perfil. Verifica tu conexión.',
  );
} catch (_) {
  throw const AuthFailure('No fue posible cargar tu perfil. Intenta de nuevo.');
}
```

## Info

### IN-01: Duplicate color tokens under different semantic names

**File:** `lib/core/theme/app_colors.dart:16-19`
**Issue:** `secondary` (`0xFFEBDDC5`) is identical to `surfaceMuted`, and `accent` (`0xFFD67F48`) is identical to `primaryHover`. The comment explains these are intentionally kept for backward compatibility ("Legacy field names kept so existing widgets keep compiling"), so this is a deliberate shim rather than an oversight, but it's still a maintenance hazard: a future rebrand that changes `surfaceMuted` without also updating `secondary` will silently desync two "same" colors.
**Fix:** Either migrate remaining call sites off the legacy names now (this phase already touched most of the theme) or leave a `@Deprecated` annotation on `secondary`/`accent`/`onSecondary`/`onAccent` pointing at their canonical replacement so new code doesn't pick the legacy name.

### IN-02: No-op buttons in `ClientHomeScreen` give no feedback

**File:** `lib/features/auth/presentation/screens/client_home_screen.dart:35-42`
**Issue:** "Agregar mascota" and "Agendar cita" have empty `onPressed: () {}` handlers with no disabled state, tooltip, or "coming soon" feedback — tapping them does nothing observable, which reads as a broken button rather than an intentionally deferred feature (contrast with `ComingSoonScreen`, which at least shows "Próximamente" for the vet-side placeholders).
**Fix:** Either disable the buttons until the real feature lands, or show a lightweight `SnackBar`("Disponible próximamente")` on tap, consistent with how the vet-side nav destinations communicate "not yet built."

### IN-03: `clinicas` has no UPDATE/DELETE RLS policy (pre-existing gap, not introduced by this diff)

**File:** `supabase/schema.sql:138-140`
**Issue:** `clinicas_select` is the only policy on `public.clinicas`; RLS defaults to deny for `UPDATE`/`DELETE`, so once a clinic is created by the signup trigger there is no way — even for the owning veterinarian — to correct its `nombre`/`ciudad`/`direccion`/`telefono` from the app. This predates the current diff (the `clinicas_select` policy is unchanged) so it's not a regression, but it's worth tracking since a future "editar clínica" screen (likely under `Más`) will need a scoped policy (`using/with check (id = mi_clinica_id() and es_veterinario())`) added at that time.
**Fix:** No action needed for Phase 1; note for the phase that implements clinic-profile editing.

---

_Reviewed: 2026-09-24T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
