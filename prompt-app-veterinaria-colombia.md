# Prompt optimizado — App para veterinarios en Colombia (Flutter)

## Cómo usar este documento
Copia y pega la sección **"PROMPT MAESTRO"** directamente en la IA que uses para programar (Claude Code, ChatGPT, Cursor, etc.). Las secciones de diferenciadores y funcionalidades ya están incorporadas dentro del prompt, así que no necesitas añadir nada más — pero puedes editar cualquier parte antes de enviarlo.

---

## PROMPT MAESTRO (cópialo tal cual)

```
Actúa como un ingeniero de software senior especializado en Flutter y en el desarrollo de aplicaciones para el sector salud/veterinario en Latinoamérica.

CONTEXTO DEL PRODUCTO
Voy a construir una aplicación móvil (Android/iOS) en Flutter dirigida a veterinarios y clínicas veterinarias independientes en Colombia (médicos veterinarios que atienden mascotas de forma particular, a domicilio, o en consultorios pequeños/medianos — no hospitales grandes). El objetivo es que el veterinario pueda gestionar su consulta desde el celular sin depender de un computador ni de un software de escritorio.

STACK TÉCNICO
- Frontend: Flutter (última versión estable), arquitectura limpia (Clean Architecture) con separación en capas (presentation, domain, data).
- Gestión de estado: Riverpod (o Bloc si lo prefieres justifica cuál usarás y por qué).
- Backend: Firebase (Firestore + Authentication + Storage + Cloud Functions) o Supabase — elige uno y justifica la decisión según costo, facilidad de despliegue en Colombia y necesidad de trabajar offline-first.
- Debe funcionar offline-first con sincronización posterior (los veterinarios suelen atender en zonas rurales con mala conexión).
- Autenticación: correo/contraseña + inicio de sesión con Google.
- Notificaciones push (Firebase Cloud Messaging) para recordatorios.

REQUISITOS REGULATORIOS Y DE CONTEXTO COLOMBIA
- Debe contemplar la posibilidad de generar facturación electrónica compatible con la DIAN (a futuro, vía integración con un proveedor tecnológico autorizado tipo Siigo, Alegra o Factus mediante API).
- La historia clínica debe seguir una estructura similar a la usada por veterinarios colombianos (anamnesis, examen físico, diagnóstico, tratamiento, evolución) y permitir exportarla en PDF.
- Debe soportar el registro de vacunación con los biológicos comunes en Colombia (antirrábica, polivalente/óctuple, etc.) y generar el carné de vacunación digital.
- Moneda en pesos colombianos (COP), formato de fecha dd/mm/aaaa.

FUNCIONALIDADES IMPRESCINDIBLES (MVP — desarróllalas en este orden de prioridad)
1. Gestión de pacientes (mascotas): ficha con especie, raza, edad, peso, foto, dueño asociado, historial médico.
2. Gestión de clientes (dueños): datos de contacto, mascotas asociadas, historial de citas y pagos.
3. Historia clínica digital: registro de consultas, diagnósticos, tratamientos, con línea de tiempo por paciente.
4. Agenda y citas: calendario con recordatorios automáticos vía notificación push y opción de enviar recordatorio por WhatsApp (deep link a WhatsApp con mensaje prellenado).
5. Carné de vacunación y desparasitación digital, con alertas automáticas de próxima dosis.
6. Inventario básico de medicamentos e insumos, con alertas de stock mínimo.
7. Facturación simple (cotización/recibo en PDF) con posibilidad de evolucionar a facturación electrónica DIAN.
8. Modo offline con sincronización automática al recuperar conexión.
9. Panel de estadísticas básicas: consultas del mes, ingresos, pacientes nuevos.
10. Backup automático en la nube.

INSTRUCCIONES DE DESARROLLO
1. Empieza proponiendo la estructura de carpetas del proyecto Flutter siguiendo Clean Architecture.
2. Define el modelo de datos (entidades: Veterinario, Cliente, Mascota, Consulta, Vacuna, Cita, Producto/Inventario, Factura) con sus relaciones.
3. Genera el esquema de Firestore/Supabase con las colecciones/tablas necesarias.
4. Implementa el MVP empezando por autenticación → gestión de pacientes → historia clínica → agenda, en ese orden, un módulo a la vez.
5. En cada módulo, incluye: modelo, repositorio, casos de uso, provider/bloc, y la UI en Material 3 con un diseño limpio y profesional (paleta de color sobria, apta para uso clínico).
6. Explica las decisiones técnicas relevantes a medida que avances.
7. No implementes todos los módulos de una vez: pregunta antes de continuar al siguiente módulo si el alcance no es claro.
```

---

## Ideas de diferenciación frente a la competencia

Los actores actuales en Colombia (Vetlogy, GVET, Panacea, y plataformas internacionales como Digitail o IDEXX Neo) ya cubren lo básico: historia clínica, agenda, facturación e inventario, generalmente **pensados para clínicas con computador fijo en recepción**. Los huecos de mercado están aquí:

1. **Mobile-first para el veterinario "solo" o a domicilio**, no para la clínica con recepcionista. La mayoría de competidores son plataformas web adaptadas a móvil; una app nativa Flutter pensada 100% para el celular del veterinario que atiende sobre la marcha es un diferencial real.
2. **Modo offline real**, no solo "acceso desde cualquier dispositivo con internet" (como ofrecen GVET o Provet Cloud). En zonas rurales o barrios con mala señal, esto es decisivo.
3. **Recordatorios por WhatsApp** en lugar de solo SMS/push — en Colombia el canal de comunicación dominante con el cliente final es WhatsApp, y ningún competidor lo integra de forma nativa.
4. **Carné de vacunación digital compartible** (link o PDF) que el dueño de la mascota pueda mostrar en guarderías, peluquerías o al viajar — hoy es un dolor real y nadie lo resuelve bien.
5. **Precio y modelo freemium** pensado para el veterinario independiente colombiano (la mayoría de competidores cobran en dólares o tienen planes pensados para clínicas establecidas, no para quien recién empieza).
6. **IA aplicada a la consulta**: sugerencias de diagnóstico diferencial o de dosificación de medicamentos según peso/especie, y transcripción automática de notas de voz a historia clínica durante la consulta (manos ocupadas con el paciente).

---

## Funcionalidades imprescindibles (resumen enumerado)

**Fase 1 — MVP indispensable**
- Registro y perfil del veterinario
- Gestión de clientes (dueños de mascotas)
- Gestión de pacientes (mascotas) con foto e historial
- Historia clínica digital exportable en PDF
- Agenda de citas con recordatorios
- Carné de vacunación y desparasitación
- Inventario básico de medicamentos
- Recibos/cotizaciones en PDF
- Modo offline con sincronización

**Fase 2 — Diferenciadores**
- Recordatorios automáticos vía WhatsApp
- Carné de vacunación compartible públicamente
- Facturación electrónica DIAN
- Estadísticas e ingresos
- Notas de voz transcritas a historia clínica
- Sugerencias asistidas por IA (dosificación, diagnóstico diferencial)

**Fase 3 — Escalamiento**
- App complementaria para el dueño de la mascota (ver historial, citas, carné)
- Multi-usuario (varios veterinarios en una misma clínica)
- Telemedicina veterinaria (videollamada de seguimiento)
