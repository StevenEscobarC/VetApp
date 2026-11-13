# 06 — Auditoría de marca (vetapp-brand-ui)

Fecha: 2026-11-13. Base: master `da2a64d`. Referencia: `06-UI-SPEC.md`.

Alcance:
- `lib/features/inventory/presentation/**`
- `lib/features/home/presentation/screens/mas_screen.dart`
- `lib/features/home/presentation/screens/inicio_screen.dart`

## Veredicto

PASS con observaciones: 0 BLOCKER, 2 WARN, 5 INFO.

## Lo que está bien

- **Color:** solo `AppColors.*`. No hay `Color(0x…)` ni `Colors.*`. El único `withValues(alpha: 0.4)` es el borde `warning` de la insignia, que el spec permite.
- **Tipografía:** no hay `GoogleFonts`, `fontFamily` ni `fontSize` literales. La cantidad usa `displaySmall` y los títulos `headlineSmall`.
- **Widgets core:** `AppTopBar`, `AppTextField`, `AppFilterChip`, `AppButton` (incluida la variante destructive) y `AppCard`.
- **Formato:**
  - Fechas con `formatearFecha`.
  - COP con `formatearCop`.
  - Cantidades con `formatearMiles`.
- **Targets y semántica:**
  - Botones de ajuste y steppers de 48×48.
  - Tooltips en los botones de solo icono.
  - Semántica en insignias, filas y en la tarjeta de Inicio.
  - Fila de Más: orden correcto, `minHeight` 56 y el pill aparece solo con `bajos > 0`.
- **Copy:** coincide con el spec en los empty states, errores, diálogos, la tarjeta de Inicio, los helpers, los mensajes de ajuste y el estado offline.
- **Estados:** esqueleto, error con "Reintentar", pull-to-refresh, empty states e historial (cargando, error y vacío).

## Hallazgos

| Severidad | Archivo:línea | Hallazgo | Corrección sugerida |
|---|---|---|---|
| WARN | `lib/features/inventory/presentation/widgets/insignia_stock.dart:87-90` | La insignia usa `labelMedium`, que no tiene `fontSize` propio y cae a 12. El spec pide Label 14/600. Además el `fontWeight: w600` es un literal redundante. | Usar `labelLarge?.copyWith(color: s.fg)`, quitar el `fontWeight` y verificar que el texto cabe en los 28px de alto. |
| WARN | `lib/features/inventory/presentation/screens/inventario_screen.dart:85-92` | Mientras carga, la cabecera (búsqueda y chips) no se muestra. El spec pide la cabecera visible pero deshabilitada; hoy la pantalla salta al llegar los datos. | Mostrar siempre la cabecera, deshabilitada mientras carga. |
| INFO | `lib/features/inventory/presentation/screens/producto_form_screen.dart:411` | En edición el enlace dice "Más detalles"; el spec solo define "Agregar más detalles". | Unificar el texto. |
| INFO | `lib/features/inventory/presentation/screens/producto_form_screen.dart:400, 695` | Los desplegables (`InkWell` + `Container`) no tienen `Semantics(button, expanded)`. | Envolverlos en `Semantics`. |
| INFO | `lib/features/inventory/presentation/screens/producto_detail_screen.dart:436, 502` y `lib/features/inventory/presentation/widgets/ajuste_stock.dart:192` | Hay `TextButton` crudos en diálogos. Es aceptable porque el tema garantiza los 48dp. | Sin acción. |
| INFO | `lib/features/inventory/presentation/widgets/ajuste_rapido_botones.dart:145` | `OutlinedButton` cuadrado de 48×48. Es aceptable porque `AppButton` es de ancho completo. | Sin acción. |
| INFO | (sin verificar) | No se revisó el snackbar (6 s, uno a la vez) ni la regla de Deshacer con \|delta\| ≤ 10. | Los cubren los widget tests del spec. |

BRAND: PASS
