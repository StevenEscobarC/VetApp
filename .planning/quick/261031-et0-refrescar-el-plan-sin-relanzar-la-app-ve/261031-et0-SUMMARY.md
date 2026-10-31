# Quick 261031-et0: Refrescar el plan sin relanzar la app (VET-43 punto 1) - Summary

**Resultado:** `mi_plan()` se relee (a) al volver la app a primer plano, (b) al enfocar Inicio o Más en `AppShell`, (c) al abrir Mi plan con el plan ya en caché. Sin polling ni timers ni dependencias nuevas.

## Mecanismo por punto

| Punto | Cambio | Por qué |
|-------|--------|---------|
| onResume | `miPlanProvider` crea `AppLifecycleListener(onResume: ref.invalidateSelf)` con `ref.onDispose(lifecycle.dispose)` (`plan_providers.dart`) | Mismo patrón que `authProfileProvider`; explícito y comprobable sin depender de la cascada de auth |
| Inicio / Más | `AppShell` pasa a `ConsumerStatefulWidget`; `didUpdateWidget` detecta cambio de `currentIndex` hacia 0 o 4 e invalida en `addPostFrameCallback` con guarda `mounted` (`app_shell.dart`) | Cubre toque y `context.go('/inicio')`; las ramas raíz siguen montadas en el `IndexedStack`, un `initState` no serviría; Riverpod no permite invalidar durante el build |
| Mi plan | `MiPlanScreen` pasa a `ConsumerStatefulWidget`; `initState` invalida tras el frame solo si `ref.exists(miPlanProvider)` (`mi_plan_screen.dart`) | Todas las entradas a `/mas/plan` en un solo lugar; la guarda evita doble lectura en frío |

## Estado por tarea

| Tarea | Estado | Verificación |
|-------|--------|--------------|
| 1 RED: `test/plan_refresco_test.dart` | ✅ | `flutter test test/plan_refresco_test.dart` falló en 5 casos esperados (Mi plan con caché, Más, Inicio por toque, Inicio con `go`, onResume) y pasó frío y sin polling; `flutter analyze` sin issues. Commit `fd61826` |
| 2 GREEN: fix | ✅ | `flutter analyze` sin issues; tests afectados (8 archivos): `+88 All tests passed`; `flutter test` completo: `+856 All tests passed` |

## Pruebas

- Nuevas en `plan_refresco_test.dart`: 7.
- Total `flutter test`: 856 (antes 849), todas en verde.

## Deviaciones

**1. [Rule 3 - Bloqueo] Pruebas existentes rotas por el nuevo `AppLifecycleListener`**
- `test/mi_plan_test.dart` y `test/team_actions_test.dart` (usan `test()` + `ProviderContainer`): fallaban con "Binding has not yet been initialized". Fix: `TestWidgetsFlutterBinding.ensureInitialized();` como primera línea de `main()` (el plan anticipaba el primero; el segundo es el caso "otra prueba" del plan). Sin tocar aserciones.
- `test/recordar_manana_sheet_test.dart` (`_ida`): `AppLifecycleListener` aserta transiciones válidas y el helper saltaba `resumed -> paused -> resumed`. Ahora recorre `inactive -> hidden -> paused -> hidden -> inactive -> resumed`. Mismas aserciones; la hoja solo observa paused/hidden y resumed.
- En `plan_refresco_test.dart` la prueba de onResume usa la misma secuencia válida (corregido dentro del commit GREEN).

## Notas

- Sin cambios en `pubspec.yaml`, `pubspec.lock`, `supabase/`, ni Linear. Sin `Timer`/`Stream.periodic` en los archivos tocados.
- Comprobación en emulador (cambiar el plan con `asignar_plan` y ver Inicio / Más / Mi plan actualizarse sin relanzar): pendiente, queda para `vetapp-qa`.
- Commits de código: `fd61826` (RED), `0167310` (GREEN).

## Verificación del orquestador (pm-vetapp, 2026-10-31)

- Fusión en master: `bf9c523` (commits `fd61826` RED, `0167310` fix). Diff revisado: sin aserciones debilitadas; cambios en pruebas existentes limitados a `TestWidgetsFlutterBinding.ensureInitialized()` y transiciones de ciclo de vida válidas.
- Compuerta sobre master: `flutter analyze` → `No issues found!` · `flutter test` → `+856: All tests passed!`.
- QA en emulador (`vetapp-qa`, 261031-et0-QA-REPORT.md): `QA: PASS` C1..C5 con el PID 4282 constante (sin relanzar): Más pasó de "Beta · Fundador" a "Plan Pro · 5 días", Inicio mostró "Tu plan termina en 5 días", Mi plan "Activo hasta el 05/11/2026"; con la app en segundo plano el plan volvió a Beta y al traerla a primer plano Inicio quedó sin banner y Más/Mi plan en Beta.
- Estado de planes: QA Clinica 51 restaurada a Beta (fundador false); todas las clínicas en beta, verificadas por MCP.
- Capturas de Mi plan del admin (`et0-B3`, `et0-C5b`) quedan fuera del repo (pueden mostrar el número de soporte).
