# 07 — Auditoría de marca (vetapp-brand-ui)

Fecha: 2026-11-14. Base: master `7d85c01`. Referencia: `07-UI-SPEC.md`.

Alcance:
- `lib/features/billing/presentation/**`;
- los puntos de entrada "Cobrar" (completar cita, detalle de cita, línea de tiempo y formulario de consulta, ficha del cliente);
- la fila de Más;
- los campos de cédula y NIT;
- `cobro_pdf_service.dart`.

## Veredicto

PASS: 0 BLOCKER, 2 WARN y 5 INFO.

## Lo que está bien

- **Colores y tipografía:**
  - colores solo por `AppColors`;
  - tipografía solo por `textTheme`;
  - espaciado y áreas táctiles por `AppSpacing`.
- **Formatos:** fechas con `formatearFecha` y COP con `formatearCop` / `formatearMiles`.
- **"Factura":** no aparece en ningún texto visible. La única aparición es la constante interna `kOrigenCobro`.
- **Copy:** todo el texto estático coincide con el UI-SPEC: snackbars, "Debe a:", "La suma de:", "ANULADA", "Cédula (opcional)" y "NIT o cédula (opcional)".
- **Widgets compartidos:** `AppTopBar`, `AppButton`, `AppTextField`, `AppFilterChip` y `AppCard`.
- **Estados:** carga, error con "Reintentar", vacíos a la medida y sin conexión (`warningBg` + `wifi_off`).
- **Candado de solo lectura:** está en `CobrarBoton`, en el botón flotante de Cobros y en el detalle. La lectura nunca se bloquea.
- **Semántica:** filas, chips y botones, y los botones de solo ícono tienen etiqueta.
- **Puntos de entrada "Cobrar":** completar cita, detalle de cita, línea de tiempo, formulario de consulta y ficha del cliente.
- **PDF:** usa Caprasimo + Figtree, `AppColors`, `formatearFecha`, "Página x de y" y el sello "ANULADA".

## Hallazgos

| Severidad | Archivo:línea | Hallazgo | Corrección sugerida |
|---|---|---|---|
| WARN | `lib/features/billing/presentation/screens/cobro_form_screen.dart:305-319` | El diálogo "Emitir" usa `TextButton` y `ElevatedButton` crudos en vez de `AppButton`. | `AppButton(label: 'Emitir', expand: false)` y `AppButton(variant: text)` para "Revisar". |
| WARN | `cobro_form_screen.dart:305,492,611,685,943`; `anular_cobro_sheet.dart:164` | `TextButton` crudos. El tema ya garantiza los 48 dp. | Pasarlos a `AppButtonVariant.text` (aceptable si se mantienen). |
| INFO | `cobro_pdf_service.dart:377` | `PdfColors.white` va escrito directo para las filas alternas. | Constante con nombre o `AppColors.surface`. |
| INFO | `cobro_pdf_service.dart:229-391` | Los `fontSize` del PDF son literales. El paquete `pdf` no puede usar `textTheme`. | Agruparlos como constantes `_kPdf*`. |
| INFO | `cobros_screen.dart`, `servicios_screen.dart`, `cobro_fila.dart`, `elegir_cliente_sheet.dart`, `mas_screen.dart` | Números sueltos para altos e íconos (88, 56, 64, 40, 32, 24, 20). | Tokens en `AppSpacing` si se reutilizan. |
| INFO | `cobros_screen.dart:160-165` | `FloatingActionButton.extended` crudo, pero con tokens y candado. | Crear un `AppFab` en core si se reutiliza. |
| INFO | `consulta_form_screen.dart:~186` | Sin dueño, el snackbar "Consulta guardada" no tiene "Cobrar" y no explica por qué. | Confirmarlo contra el spec. |

BRAND: PASS
