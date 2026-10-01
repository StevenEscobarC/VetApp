---
status: partial
phase: 04-agenda-y-citas
source: [04-VERIFICATION.md]
started: 2026-10-01T00:00:00Z
updated: 2026-10-01T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. WhatsApp reminder on a physical phone with WhatsApp installed
expected: Tapping "WhatsApp" on a cita (client with Colombian mobile) opens the WhatsApp chat with the formal D-14 message prefilled (tildes, "—", "SÍ" intact); on return the cita shows "Recordatorio enviado". The emulator UAT (2026-10-01) only exercised the "No pudimos abrir WhatsApp" fallback.
result: [pending]

### 2. No llegan recordatorios después de cerrar sesión (QA C4, BLOCKED en emulador)
expected: Con una cita a ~20 min y el aviso configurado, cerrar sesión desde Más → al pasar la hora del aviso no llega ninguna notificación. Al volver a iniciar sesión, los recordatorios se reprograman sin duplicados. vetapp-qa no pudo probarlo porque cerrar sesión pierde la sesión de prueba y no hay credenciales de prueba en el repo.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
