import 'package:intl/intl.dart';

/// Mensaje único para cualquier campo numérico inválido de la consulta
/// (peso, temperatura, frecuencias) — una sola redacción reutilizada tanto
/// por [parsearNumeroPositivo] como por quien la llama, per UI-SPEC's
/// Copywriting Contract.
const String kErrorNumericoInvalido = 'Ingresa un valor numérico válido';

/// `null` para [texto] vacío o solo espacios — nunca `''` (D-03). Usado al
/// normalizar campos opcionales antes de enviarlos al backend.
String? blancoANull(String? texto) {
  final t = texto?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// `dd/mm/aaaa` — sin argumento de locale: el patrón es puramente numérico
/// (no depende de nombres de mes/día localizados), así que no dispara
/// `LocaleDataException` — la app nunca llama `initializeDateFormatting`.
final DateFormat _formatoFecha = DateFormat('dd/MM/yyyy');

/// Formatea [fecha] como `dd/mm/aaaa` — formato colombiano usado en toda
/// la app (fechas de nacimiento, historial de peso, etc.).
String formatearFecha(DateTime fecha) => _formatoFecha.format(fecha);

/// Interpreta [texto] como una fecha `dd/mm/aaaa`. Vacío devuelve
/// `(valor: null, error: null)` (campo opcional sin tocar, per D-04) — un
/// texto no vacío que no cumple el formato exacto, o que no es un día de
/// calendario real (ej. 31 de febrero), o que cae en el futuro, devuelve
/// `valor: null` con el [error] correspondiente en español. Con
/// [permitirFuturo] en `true` (ej. vencimiento de un producto) las fechas
/// futuras son válidas; por defecto se rechazan, como en todo otro caller.
({DateTime? valor, String? error}) parsearFecha(
  String texto, {
  bool permitirFuturo = false,
}) {
  final t = texto.trim();
  if (t.isEmpty) return (valor: null, error: null);

  DateTime fecha;
  try {
    fecha = _formatoFecha.parseStrict(t);
  } catch (_) {
    return (valor: null, error: 'Usa el formato dd/mm/aaaa');
  }

  // `parseStrict` no valida días de calendario reales (Dart's DateTime
  // constructor "rueda" el 31 de febrero al 2 o 3 de marzo en vez de
  // lanzar) — reformatear y comparar contra el texto original detecta esa
  // clase de fecha inválida sin necesitar una librería de calendario.
  if (_formatoFecha.format(fecha) != t) {
    return (valor: null, error: 'Usa el formato dd/mm/aaaa');
  }

  final hoy = DateTime.now();
  final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
  if (!permitirFuturo && fecha.isAfter(hoySinHora)) {
    return (valor: null, error: 'La fecha no puede ser futura');
  }

  return (valor: fecha, error: null);
}

/// Interpreta [texto] como un peso en kg, aceptando coma o punto decimal
/// (`12,5` o `12.5`). Vacío devuelve `(valor: null, error: null)` (campo
/// opcional). Cualquier otro valor no numérico, o fuera del rango
/// `0 < peso < 1000`, devuelve el error en español.
({double? valor, String? error}) parsearPeso(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return (valor: null, error: null);

  final valor = double.tryParse(t.replaceAll(',', '.'));
  if (valor == null || valor <= 0 || valor >= 1000) {
    return (valor: null, error: 'Ingresa un peso válido en kg');
  }
  return (valor: valor, error: null);
}

/// Interpreta [texto] como un número positivo, aceptando coma o punto
/// decimal (`38,5` o `38.5`) — usado por los signos vitales del examen
/// físico (temperatura, frecuencias) que no comparten el rango de peso de
/// [parsearPeso]. Vacío devuelve `(valor: null, error: null)` (campo
/// opcional). Solo es válido si `0 < valor < [maximo]`; si [entero] es
/// `true`, [texto] no puede tener parte fraccionaria (ej. frecuencia
/// cardíaca). Cualquier otra condición devuelve el mismo mensaje en
/// español, per UI-SPEC's Copywriting Contract (una sola redacción para
/// todo campo numérico de la consulta).
({double? valor, String? error}) parsearNumeroPositivo(
  String texto, {
  bool entero = false,
  double maximo = 1000,
}) {
  final t = texto.trim();
  if (t.isEmpty) return (valor: null, error: null);

  final valor = double.tryParse(t.replaceAll(',', '.'));
  if (valor == null || valor <= 0 || valor >= maximo) {
    return (valor: null, error: kErrorNumericoInvalido);
  }
  if (entero && valor != valor.truncateToDouble()) {
    return (valor: null, error: kErrorNumericoInvalido);
  }
  return (valor: valor, error: null);
}

/// Formatea [pesoKg] con coma como separador decimal y hasta 2 decimales,
/// recortando ceros sobrantes (`12.5` -> `'12,5 kg'`, `12.0` -> `'12 kg'`).
String formatearPeso(double pesoKg) {
  var texto = pesoKg.toStringAsFixed(2);
  texto = texto.replaceFirst(RegExp(r'0+$'), '');
  texto = texto.replaceFirst(RegExp(r'\.$'), '');
  texto = texto.replaceAll('.', ',');
  return '$texto kg';
}

/// Etiqueta en español para una edad en años calculada
/// ([Mascota.edadEnAnios]). `null` (sin fecha de nacimiento) devuelve
/// cadena vacía — la UI simplemente omite la edad en ese caso.
String formatearEdad(int? anios) {
  if (anios == null) return '';
  if (anios == 0) return 'Menos de 1 año';
  if (anios == 1) return '1 año';
  return '$anios años';
}

/// Agrupa [n] con punto como separador de miles (`85000` -> `'85.000'`).
/// Sin formateador con locale: la app nunca llama
/// `initializeDateFormatting` (mismo motivo que [_formatoFecha]).
String formatearMiles(int n) {
  final digitos = n.abs().toString();
  final agrupado = digitos.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return n < 0 ? '-$agrupado' : agrupado;
}

/// Dinero en COP como entero, sin decimales ni IVA hasta la Fase 7 (D-16):
/// `85000` -> `'\$ 85.000'`.
String formatearCop(int pesos) => '\$ ${formatearMiles(pesos)}';

const String _errorCopEntero = 'Usa pesos enteros, sin coma.';

/// Interpreta [texto] como pesos enteros (D-16). Acepta `85000`, `85.000`,
/// `$ 85.000` y `$85.000`; la coma decimal se rechaza (Colombia usa punto
/// de miles). Vacío devuelve `(valor: null, error: null)`. Más de
/// 100.000.000 se rechaza, igual que el CHECK del servidor.
({int? valor, String? error}) parsearCop(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return (valor: null, error: null);
  if (t.contains(',')) return (valor: null, error: _errorCopEntero);

  final limpio = t.replaceAll(RegExp(r'[\$\s.]'), '');
  if (limpio.isEmpty || !RegExp(r'^\d+$').hasMatch(limpio)) {
    return (valor: null, error: _errorCopEntero);
  }
  final valor = int.tryParse(limpio);
  if (valor == null || valor > 100000000) {
    return (valor: null, error: 'El valor es demasiado alto.');
  }
  return (valor: valor, error: null);
}

final RegExp _separadoresDocumento = RegExp(r'[.\s]');
final RegExp _cedulaValida = RegExp(r'^[0-9]{5,12}$');
final RegExp _nitValido = RegExp(r'^[0-9]{5,12}(-[0-9])?$');
final RegExp _soloDigitos = RegExp(r'^[0-9]+$');

/// Cédula del cliente como solo dígitos (D-24): quita puntos y espacios.
/// Vacío devuelve `(valor: null, error: null)` (campo opcional). Debe tener
/// 5 a 12 dígitos, igual que el CHECK `clientes_cedula_formato` del
/// servidor, para que la UI rechace antes que la base de datos.
({String? valor, String? error}) normalizarCedula(String texto) {
  final t = texto.replaceAll(_separadoresDocumento, '');
  if (t.isEmpty) return (valor: null, error: null);
  if (!_cedulaValida.hasMatch(t)) {
    return (
      valor: null,
      error: 'Revisa la cédula: debe tener entre 5 y 12 números.',
    );
  }
  return (valor: t, error: null);
}

/// Cédula guardada como dígitos, mostrada con puntos de miles
/// (`'1020304050'` -> `'1.020.304.050'`). Un texto que no es solo dígitos
/// se devuelve tal cual (datos viejos sin normalizar).
String formatearCedula(String digitos) {
  if (!_soloDigitos.hasMatch(digitos)) return digitos;
  return formatearMiles(int.parse(digitos));
}

/// NIT (o cédula) de la clínica (D-04): quita puntos y espacios y admite el
/// dígito de verificación opcional tras un guion (`'900123456-7'`). Vacío
/// devuelve `(valor: null, error: null)`. Refleja el CHECK
/// `clinicas_nit_formato` del servidor.
({String? valor, String? error}) normalizarNit(String texto) {
  final t = texto.replaceAll(_separadoresDocumento, '');
  if (t.isEmpty) return (valor: null, error: null);
  if (!_nitValido.hasMatch(t)) {
    return (
      valor: null,
      error:
          'Usa solo números y, si es NIT, el guion del dígito de verificación.',
    );
  }
  return (valor: t, error: null);
}

/// NIT guardado como `'900123456-7'`, mostrado como `'900.123.456-7'`:
/// agrupa solo la parte numérica y conserva el dígito de verificación.
String formatearNit(String nit) {
  final guion = nit.indexOf('-');
  final cuerpo = guion < 0 ? nit : nit.substring(0, guion);
  final dv = guion < 0 ? '' : nit.substring(guion);
  if (!_soloDigitos.hasMatch(cuerpo)) return nit;
  return '${formatearMiles(int.parse(cuerpo))}$dv';
}
