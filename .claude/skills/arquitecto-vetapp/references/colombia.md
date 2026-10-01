# Reglas de Colombia para VetApp

Esta guía orienta decisiones de producto y de código. No es asesoría legal: cuando una regla condicione el diseño (consentimientos, conservación de historias, recetas), señálalo y recomienda validarlo con un abogado o con el gremio veterinario antes de salir a producción.

## Formato y localización

- Locale `es_CO` (`Intl.defaultLocale = 'es_CO'` e `initializeDateFormatting('es_CO')`).
- **Dinero (COP)**: sin decimales, punto como separador de miles: `$ 85.000`. Con `intl`: `NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)`. Guarda montos como enteros de pesos, nunca `double`.
- **Fechas**: `dd/MM/yyyy` (`01/10/2026`); fecha larga `EEEE d 'de' MMMM 'de' y` (`jueves 1 de octubre de 2026`).
- **Horas**: formato de 12 horas con `a. m.` / `p. m.` en la UI (`3:30 p. m.`).
- **Zona horaria**: `America/Bogota` (UTC−5, sin horario de verano). Guarda en UTC (`timestamptz` en Postgres) y muestra en hora de Bogotá; las citas se crean siempre interpretando la hora en la zona de la clínica.
- **Teléfono**: celular de 10 dígitos que empieza por 3; almacénalo en E.164 (`+573001234567`) y muéstralo como `300 123 4567`.
- **Direcciones**: formato colombiano libre (`Cra 23 # 65-12`, `Calle 50 # 20-30 Apto 301`); no fuerces campos de calle/número separados al estilo de otros países.

## Documentos de identidad

Tipos a soportar en el registro del propietario:

| Código | Documento |
|---|---|
| CC | Cédula de ciudadanía |
| CE | Cédula de extranjería |
| PPT | Permiso por Protección Temporal |
| PA | Pasaporte |
| NIT | Número de Identificación Tributaria (clínicas y personas jurídicas) |

- El NIT se muestra con dígito de verificación (`900123456-7`); valida el dígito con el algoritmo de la DIAN.
- No exijas documento para el primer registro del propietario si no es necesario (el registro debe ser fácil); pídelo cuando se necesite, por ejemplo al emitir una receta o un certificado.

## Protección de datos personales

Ley 1581 de 2012 (Habeas Data) y su reglamentación:

- **Autorización previa, expresa e informada** antes de recolectar datos personales: casilla no marcada por defecto, enlace a la política de tratamiento, y registro de fecha y versión de la política aceptada (`autorizacionDatos` en el modelo).
- Informa la finalidad: gestionar citas, historias clínicas y comunicaciones de la clínica.
- El titular debe poder consultar, actualizar y pedir supresión de sus datos: prevé estas acciones en el perfil. La supresión no borra historias clínicas que deban conservarse; anonimiza los datos del propietario cuando aplique.
- Mínimo privilegio en la base de datos: RLS por clínica y propietario. Nunca registres en logs documentos, teléfonos ni contenido clínico.
- Compartir la historia de una mascota con otra clínica requiere acción explícita del propietario.

## Historia clínica y ejercicio profesional

- La medicina veterinaria en Colombia está regulada (Ley 576 de 2000, código de ética profesional), y el profesional se identifica con su **tarjeta profesional**. Por eso, cada consulta, receta y certificado registra el veterinario responsable y su número de tarjeta.
- Trata la historia clínica como un documento con valor legal: inmutable una vez cerrada (correcciones por adenda), con autor y fecha en cada entrada, y conservada aunque el propietario deje de usar la app. Confirma con asesoría legal el tiempo mínimo de conservación antes de implementar borrados.
- Los medicamentos de uso veterinario están bajo control del ICA. Si la receta incluye medicamentos de control especial, señálalo como un caso que requiere validación regulatoria adicional en vez de asumir un formato.
- Bienestar animal: Ley 1774 de 2016. Relevante si la app maneja reportes de maltrato o eutanasias; no lo asumas para otras tareas.

## Pagos (solo si la tarea lo pide)

Medios habituales en Colombia: PSE, tarjetas, Nequi y Daviplata. Integra siempre a través de una pasarela (p. ej. Wompi, ePayco, Mercado Pago) y nunca manejes datos de tarjeta en la app ni en tu backend.
