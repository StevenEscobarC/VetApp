# Phase 8: Dashboard y Diseño Visual - Discussion Log

> **Audit trail only.** No hubo preguntas al usuario. Por su instrucción permanente del 2026-11-14 ("no esperes confirmación mía, siempre haz lo recomendado"), el orquestador eligió la opción recomendada en cada punto. Las decisiones están en 08-CONTEXT.md.

**Fecha:** 2026-11-16 · **Fase:** 08-dashboard-y-diseño-visual

| Punto | Elegido (recomendado) | Alternativas descartadas |
|---|---|---|
| Alcance de las métricas | De la clínica, mes calendario de Bogotá | Por veterinario · últimos 30 días |
| Fuente de ingresos | Pagadas en el mes (igual que "Cobrado este mes") | Emitidas en el mes · incluir pendientes |
| Fuente de los datos | Una RPC `inicio_resumen()` | 3 consultas desde el cliente |
| Próximas citas | 5 próximas desde ahora, de toda la clínica | Solo hoy · solo las mías |
| Accesos rápidos | Paciente, Cita, Cobro y Vacunar | Mantener "Factura" del mockup (choca con 07 D-01) |
| Tocar una métrica | Ingresos lleva a Cobros y Pacientes a Pacientes; Consultas no navega | Crear una lista global de consultas |
| Diseño en toda la app | Auditoría completa y luego correcciones BLOCKER/WARN por feature | Solo Inicio · rediseño completo |
| Modo oscuro | Se mantiene y se verifica el contraste | Rediseñarlo |
| Plan | Sin límite nuevo | Tope en Gratis |
