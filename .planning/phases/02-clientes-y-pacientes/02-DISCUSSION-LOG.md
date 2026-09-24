# Phase 2: Clientes y Pacientes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-24
**Phase:** 2-Clientes y Pacientes
**Areas discussed:** Visión de diferenciación (fricción cero), Flujo de alta, Campos obligatorios, Foto de mascota, Búsqueda, Manejo de multi-mascota

---

## Visión de diferenciación

**Freeform:** El usuario explicó que su diferenciación no es una función puntual, sino que la app se sienta rápida, fácil e intuitiva, para que a nadie le dé pereza reservar o hacer cualquier acción. Se registró como principio transversal en `PROJECT.md` (Constraints), no solo para esta fase.

---

## Flujo de alta (cliente nuevo con mascota)

| Option | Description | Selected |
|--------|-------------|----------|
| Cliente + mascota en un solo flujo | Flujo continuo sin navegar a otra pantalla | ✓ |
| Dos pasos separados | Crear cliente, guardar, luego agregar mascota por separado | |

**User's choice:** Cliente + mascota en un solo flujo

---

## Campos obligatorios al crear

| Option | Description | Selected |
|--------|-------------|----------|
| Mínimo absoluto | Cliente: nombre+teléfono. Mascota: nombre+especie. Resto opcional/después | ✓ |
| Completo desde el inicio | Pedir todos los datos relevantes de una vez | |

**User's choice:** Mínimo absoluto

---

## Foto de mascota

| Option | Description | Selected |
|--------|-------------|----------|
| Abrir cámara directo | Un toque abre la cámara | ✓ |
| Elegir de galería primero | Abre selector de galería, cámara como alternativa | |

**User's choice:** Abrir cámara directo

---

## Búsqueda

| Option | Description | Selected |
|--------|-------------|----------|
| Instantánea mientras escribes | Resultados al teclear, sin botón ni Enter | ✓ |
| Buscar al confirmar | Botón o Enter para ver resultados | |

**User's choice:** Instantánea mientras escribes

---

## Multi-mascota (cliente existente trae otra mascota)

| Option | Description | Selected |
|--------|-------------|----------|
| Buscar cliente existente + "agregar mascota" | Busca al dueño, toca "Nueva mascota" desde su ficha | ✓ |
| Siempre crear cliente nuevo | Deduplicar después | |

**User's choice:** Buscar cliente existente + "agregar mascota"

---

## Claude's Discretion

- Diseño exacto de UI del flujo combinado cliente+mascota (wizard vs scroll continuo).
- Mecanismo de debounce para búsqueda instantánea.
- Estructura exacta de historial de peso (tabla nueva vs. campo de auditoría).
- Manejo de permisos de cámara/galería.

## Deferred Ideas

- Aplicar el principio de fricción cero a las fases futuras — ya registrado en PROJECT.md para retomarse en cada discuss-phase.
