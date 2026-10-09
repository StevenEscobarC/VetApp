# Reglas de Colombia para VetApp

Orienta decisiones de producto y código. No es asesoría legal: cuando una regla condicione el diseño (consentimientos, conservación de historias), señálalo y recomienda validarlo con un abogado o el gremio veterinario antes de producción. El comportamiento descrito sale de `lib/core/utils/` y sus pruebas en `test/`; si difieren, gana el código.

## Formato y localización

- **Locale**: `MaterialApp` usa `Locale('es', 'CO')` (`lib/main.dart`). La app **nunca llama `initializeDateFormatting`**, por eso los formatos de fecha/hora están escritos a mano o usan patrones numéricos: no uses `DateFormat` con nombres de mes/día localizados (lanzaría `LocaleDataException`).
- **Fechas** (`lib/core/utils/formato.dart`): `formatearFecha` produce `dd/mm/aaaa` (`01/10/2026`); `parsearFecha` valida el formato exacto, días de calendario reales y que no sea futura (mensaje: "Usa el formato dd/mm/aaaa"). En agenda, `formato_hora.dart` agrega `fechaLarga` (`mié 30/09/2026`), `diaCorto` (`mié 30/09`), `fechaHoraCorta` (`29/09 6:15 p. m.`) y `encabezadoDia` (`Hoy, mié 30/09`).
- **Horas** (`lib/core/utils/formato_hora.dart`): 12 horas con `a. m.` / `p. m.`, nunca 24 h. `hora12` da `10:30 a. m.`, `12:00 p. m.`, `12:15 a. m.`, `6:05 p. m.`; `rangoHoras` da `10:30 – 11:00 a. m.` o `11:30 a. m. – 12:30 p. m.`; `duracionTexto` da `15 min`, `1 h`, `1 h 30 min`. Los espacios son ASCII normales.
- **Zona horaria** (`lib/core/utils/zona_bogota.dart`): `America/Bogota` es UTC-5 fijo (sin horario de verano). La agenda **no usa `toLocal()`**: `aBogota`, `deBogota`, `diaBogota`, `rangoDiaUtc`, `rangoSemanaUtc` y `lunesDeSemana` fijan el desfase para que la zona del dispositivo nunca mueva los límites de un día. Guarda siempre `timestamptz` (UTC) y convierte para mostrar. Los recordatorios locales usan `timezone`.
- **Dinero (COP)**: aún **no existe** un helper en `lib/core/utils/` (no hay `NumberFormat` en `lib/`). Convención al introducirlo (previsto en Facturación, Fase 7): pesos sin decimales y punto como separador de miles (`$ 85.000`); guardar montos como enteros de pesos, nunca `double`. Créalo junto a `formato.dart` con su prueba, sin depender de `initializeDateFormatting`.
- **Pesos y números**: `parsearPeso` y `parsearNumeroPositivo` aceptan coma o punto decimal; `formatearPeso` muestra coma (`12,5 kg`).
- **Direcciones**: texto libre al estilo colombiano (`Cra 23 # 65-12`); no separes calle y número en campos distintos. Una cita a domicilio exige dirección (check en `citas`).

## Teléfono (`lib/core/utils/telefono_co.dart`)

- `normalizarTelefono(raw)` guarda **`57XXXXXXXXXX`** (sin `+`) para números colombianos de 10 dígitos que empiezan por 3 (celular) o 60 (fijo), p. ej. `300 123 4567` -> `573001234567`, mostrado como `+57 300 123 4567`. Los extranjeros se guardan como `+<dígitos>`; lo dudoso se conserva tal cual como `desconocido`. Es idempotente y nunca bloquea el guardado.
- `requiereAvisoTelefono` muestra un aviso suave (`kAvisoTelefono`) solo para fijos y números no reconocidos. `telefonoGuardable` / `telefonoSinDigitos` validan que haya al menos un dígito.
- `numeroWhatsApp(raw)` devuelve el número solo con dígitos para `https://wa.me/...` (celular colombiano o internacional), o `null` para fijos y no reconocidos. Úsalo siempre para armar enlaces de WhatsApp; abre enlaces con `lanzador_externo.dart`.
- No uses el formato E.164 con `+` para números colombianos al guardar.

## Documentos de identidad

- El schema actual **no** guarda documento de identidad del dueño ni NIT de la clínica (`clientes` y `clinicas` no tienen esas columnas). Registrar un cliente solo exige nombre y teléfono.
- Si en el futuro se pide (receta, factura, certificado), debe ser opcional y pedirse solo cuando haga falta; los tipos habituales son CC, CE, PPT, PA y NIT (con dígito de verificación). No lo agregues como obligatorio en el alta.

## Protección de datos personales

Ley 1581 de 2012 (habeas data) y su reglamentación:

- Autorización previa, expresa e informada antes de recolectar datos personales, con finalidad clara (gestionar citas, historias y comunicaciones). Hoy la app no tiene aún un flujo de consentimiento ni de política de tratamiento: si una tarea recolecta datos nuevos o abre la app a clientes (Fase 9), señálalo.
- Datos mínimos: no pidas más de lo necesario.
- El titular puede consultar, actualizar y pedir supresión; la supresión no borra historias clínicas que deban conservarse. Confirma con asesoría legal los tiempos de conservación antes de construir borrados.
- Mínimo privilegio: RLS por clínica (`es_veterinario()` + `mi_clinica_id()`), y nunca registres en logs teléfonos ni contenido clínico.
- Compartir datos con otra clínica o públicamente (p. ej. el link del carné de vacunación, Fase 5) requiere acción explícita y debe exponer solo lo necesario.

## Ejercicio profesional

- La medicina veterinaria está regulada por la Ley 576 de 2000 (código de ética); el profesional se identifica con su tarjeta profesional. Hoy el schema no guarda ese número: es "futuro, cuando aplique" (por ejemplo, en el perfil público del directorio de la Fase 9 o en documentos clínicos).
- La historia clínica es solo-append, con autor (`veterinario_id`) y fecha en cada entrada; una corrección es una entrada nueva.
- Medicamentos de control especial (ICA) y bienestar animal (Ley 1774 de 2016): no asumas formatos; si una tarea los toca, señálalo para validación regulatoria.

## Fuera de v1 (proponer fase)

Pagos (PSE, tarjetas, Nequi, Daviplata) y facturación electrónica ante la DIAN no están en el roadmap actual; la Fase 7 cubre cotizaciones/facturas simples en PDF. Si se piden, propón una fase nueva; si hay pagos, usa siempre una pasarela y nunca manejes datos de tarjeta en la app.
