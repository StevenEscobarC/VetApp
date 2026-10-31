# QA 261031-et0 — refrescar el plan sin relanzar (VET-43, punto 1)

- Fecha: 2026-10-31
- Dispositivo: AVD Pixel_9_API_35 (emulator-5554)
- Build: master bf9c523, `flutter run -d emulator-5554 --dart-define-from-file=dart_define.json`
- Cuenta: admin QA de "QA Clinica 51" (sesión conservada, sin login)
- Proceso de la app: PID 4282 en todos los tramos (A, B y C), verificado antes y después de C4. Sin relanzar, sin force-stop, sin hot restart.

## Resumen

| Caso | Descripción | Fuente | Resultado |
|------|-------------|--------|-----------|
| C1 | Más tras cambio de plan, sin relanzar | UI-SPEC 05.1 | PASS |
| C2 | Inicio tras cambio de plan | UI-SPEC 05.1 | PASS |
| C3 | Mi plan tras cambio | UI-SPEC 05.1 | PASS |
| C4 | Vuelta a primer plano tras otro cambio | UI-SPEC 05.1 | PASS |
| C5 | Restauración a Beta | orquestador | PASS |

## Filas del servidor (cambios hechos por el orquestador vía MCP)

1. Inicial: plan beta, fundador true, pagado_hasta null.
2. Tramo B: plan pro, fundador false, pagado_hasta 2026-11-05, origen pagado.
3. Tramo C (segundo cambio y restauración): plan beta, fundador false, pagado_hasta null, origen beta.
   Nota: la clínica queda con fundador false, no con el true inicial. El orquestador verificó que todas las clínicas están en beta.

## Tramo A (preparación)

1. Pestaña Más con la fila `Mi plan, Beta · Fundador`. Captura `qa/et0-A1-mas-mi-plan-beta.png`.
2. Agenda seleccionada, app en primer plano. Captura `qa/et0-A2-agenda-primer-plano.png`.

## Tramo B

### C1 — Más tras cambio: PASS
- Pasos: desde Agenda se tocó Más, espera 3 s, dump.
- Observado: `content-desc="Mi plan, Plan Pro · 5 días"` (antes: "Beta · Fundador").
- Evidencia: `qa/et0-B1-mas-tras-cambio.png`.

### C2 — Inicio tras cambio: PASS
- Observado: `content-desc="Tu plan termina en 5 días. Escríbenos por WhatsApp para renovarlo.. Ver mi plan"` con "Descartar aviso".
- Evidencia: `qa/et0-B2-inicio-tras-cambio.png`, `qa/et0-B4-inicio-antes-de-home.png`.

### C3 — Mi plan: PASS
- Observado: `Plan Pro / Activo / Activo hasta el 05/11/2026 / Te quedan 5 días.`, sin "Fundador".
- Evidencia: `qa/et0-B3-mi-plan.png`.
- Dato fuera de alcance: la tarjeta de uso mostraba "2 de 1 veterinarios" (2 miembros, Pro permite 1). Coherente con el límite del plan Pro, no relacionado con el refresco.

Cierre del tramo B: Inicio y KEYCODE_HOME; `topResumedActivity` = NexusLauncherActivity, PID 4282 vivo.

## Tramo C

### C4 — Vuelta a primer plano: PASS
- Pasos: PID antes = 4282. Con la app en segundo plano y Beta ya aplicado en el servidor, `am start -n com.vetapp.vetapp/.MainActivity` (sobre la actividad existente; adb respondió "Activity not started, its current task has been brought to the front"). PID después = 4282. `topResumedActivity` = `com.vetapp.vetapp/.MainActivity`.
- Esperado: Inicio (la pestaña que estaba enfocada) sin el banner "Tu plan termina en 5 días", disparado por el onResume y no por un cambio de pestaña.
- Observado: dump de Inicio con `Hola, QA Admin Cincuentayuno / QA Clinica 51`, `Vacunas pendientes / Todo al día`, `Vacunar`. No hay ningún nodo de banner ni "Descartar aviso". La captura (leída con Read) confirma que la pantalla no tiene banner.
- Validez: PID sin cambios, el caso es válido (no hubo relanzamiento).
- Evidencia: `qa/et0-C4-inicio-tras-volver.png`.

### C5 — Restauración a Beta: PASS
- Más: `content-desc="Mi plan, Beta"` (sin "Fundador"). Evidencia: `qa/et0-C5a-mas-beta.png` (leída con Read: chip "Beta").
- Mi plan: `Plan Beta / Activo / Beta / Acceso Beta completo / Todo está habilitado durante la Beta.`, además de "50 pacientes. Sin límite" y "2 veterinarios. Sin tope". Evidencia: `qa/et0-C5b-mi-plan-beta.png`.
- PID final = 4282.

## Conclusión

El plan de la clínica se relee sin relanzar en los tres disparadores comprobados: al enfocar Más (C1), al enfocar Inicio (C2), al abrir Mi plan (C3) y al volver la app a primer plano (C4). Las capturas de C1-C3 de Más/Inicio/Mi plan se refrescaron en ambos sentidos (Beta a Pro y Pro a Beta).

## Cambios al dispositivo

Ninguno: sin `pm clear`, zona horaria ni permisos. La app sigue en ejecución en Más > Mi plan, con la misma sesión.

QA: PASS — el plan se refresca sin relanzar (PID 4282 constante): Más, Inicio, Mi plan y vuelta a primer plano
