# VetApp — Referencia de diseño móvil

Fuente: `vetapp-mobile-designs.html` (mockups aportados por el usuario, guardados en esta carpeta).
Extraído/observado el 2026-09-24 renderizando el bundle en navegador.

Este documento resume el lenguaje visual para que las fases de UI (`/gsd:ui-phase`) y planeación lo usen como contrato de diseño sin tener que reabrir el HTML empaquetado (pesado, contiene assets en base64).

## Pantallas incluidas en el mockup

1. **Login** — logo (huella de pata), título "VetApp", tagline "Tu consultorio veterinario en el bolsillo", campos correo/contraseña, "¿Olvidaste tu contraseña?", botón primario "Iniciar sesión", divisor "o continúa con", botón "Continuar con Google", link "Regístrate".
2. **Inicio (Dashboard)** — saludo "Hola, Dra. Ramírez", estado "Sincronizado", tarjetas de métricas (Consultas, Ingresos $3.8M, Nuevos), sección "Próximas citas" con estados (Confirmada/Pendiente), "Accesos rápidos" (Paciente / Cita / Factura), bottom nav.
3. **Pacientes (lista)** — buscador, chips de filtro (Todos/Perros/Gatos/Otros), tarjetas de mascota (nombre, raza, edad, dueño).
4. **Ficha de paciente / Historia clínica** — datos básicos (raza, edad, peso), timeline de historia clínica (fecha, motivo, notas), botón "Grabar nota de voz", botón primario "Nueva consulta".
5. **Clientes** — buscador, tarjetas de cliente (nombre, teléfono, # mascotas).
6. **Agenda** — selector de días de semana (LUN–VIE), lista de citas por hora con estado (Confirmada/Pendiente), botón "Nueva cita".
7. **Carné de vacunación** — tarjetas por vacuna (nombre, fecha aplicada/próxima, estado "Al día"/"Próxima"), botón "Compartir carné".
8. **Inventario** — alerta "N productos con stock bajo", buscador, tarjetas de producto con nivel (Bajo/Óptimo).
9. **Facturación** — resumen "Ingresos del mes", toggle Cotizaciones/Facturas, tarjetas de transacción con estado (Pagada/Pendiente).

## Navegación

Bottom tab bar persistente en las pantallas internas: **Inicio · Pacientes · Agenda · Clientes · Más**.

## Tipografía

- **Display / headings**: `Caprasimo` (serif slab decorativo) — usado en título de marca y nombres de pacientes/encabezados de pantalla.
- **Cuerpo / UI**: `Figtree` (sans-serif) — labels, inputs, texto de cuerpo, badges.
- Ambas son Google Fonts, deben cargarse explícitamente en la app (Flutter: `google_fonts` package o fuentes empaquetadas).

## Paleta de color (observada, valores aproximados)

| Token sugerido | Hex | Uso |
|---|---|---|
| `background` | `#F5EAD8` | Fondo principal cálido (crema) |
| `background-alt` | `#F0EEE6` | Fondo secundario / superficies |
| `surface` | `#EEE7DB` | Tarjetas / inputs |
| `surface-muted` | `#EBDDC5` | Inputs, chips inactivos |
| `border` | `#DCD3C4` | Bordes y separadores |
| `primary` | `#C67139` | Terracota — botones primarios, iconos activos, acentos |
| `primary-hover` | `#D67F48` | Terracota claro — estados hover/press |
| `primary-strong` | `#8C491A` | Terracota oscuro — texto sobre fondos claros con acento |
| `primary-text` | `#643312` | Texto marrón oscuro sobre superficies claras |
| `text-primary` | `#201E1D` | Texto principal (casi negro cálido) |
| `text-secondary` | `#474238` | Texto secundario |
| `text-muted` | `#645C50` | Texto terciario / metadata |
| `placeholder` | `#82796A` | Placeholders, texto deshabilitado |
| `success` (verde oliva) | `#56633F` / `#3D472B` | Texto de estado "Confirmada" / "Al día" |
| `success-bg` | `#F0FAE1` | Fondo de badge de éxito |
| `success-alt-bg` | `#8FA073` | Variante de fondo verde oliva |
| `warning-bg` | `#FFF2EB` | Fondo de badge "Bajo" (alerta de inventario) |
| `whatsapp-tint` | `rgba(37,211,102,0.133)` | Tinte usado en algún botón/acento tipo WhatsApp |

Nota: son valores extraídos por inspección (`getComputedStyle`) del mockup renderizado, no un archivo de tokens oficial — deben confirmarse/ajustarse en la fase de UI si el usuario tiene un design system formal.

## Patrones de componentes observados

- **Cards** con esquinas muy redondeadas (~20-24px), fondo `surface`, sin sombras duras (shadow suave o ninguna).
- **Badges de estado** con fondo tenue + texto de color fuerte (ej. "Confirmada" verde oliva sobre fondo verde claro; "Bajo" terracota/peach sobre fondo peach).
- **Botón primario**: fondo terracota sólido, texto blanco, esquinas redondeadas, ancho completo.
- **Chips de filtro**: outline redondeado, estado activo con fondo sólido.
- **Iconografía**: estilo simple/line, ícono de huella de pata como logo de marca.
- **Bottom navigation**: 5 ítems, ícono + label, activo resaltado en terracota.
- **Inputs**: fondo `surface-muted`, sin borde duro, radios grandes.

## Implicaciones para la app (Flutter)

- Definir un `ThemeData`/`ColorScheme` custom basado en esta paleta (no usar Material defaults).
- Integrar `Caprasimo` y `Figtree` vía `google_fonts` o assets locales empaquetados (revisar licencias/version pinning).
- Bottom nav de 5 secciones mapea directamente a los módulos ya visibles en `schema.sql`/código existente (pacientes, clientes, agenda, facturación, inventario) — confirmar contra `codebase/ARCHITECTURE.md`.
- Este documento es la entrada principal para `/gsd:ui-phase` en las fases que toquen estas pantallas.

---
*Generado a partir de `vetapp-mobile-designs.html` aportado por el usuario. Última actualización: 2026-09-24.*
