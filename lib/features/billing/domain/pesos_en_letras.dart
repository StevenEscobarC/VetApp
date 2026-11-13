const List<String> _unidades = [
  '',
  'un',
  'dos',
  'tres',
  'cuatro',
  'cinco',
  'seis',
  'siete',
  'ocho',
  'nueve',
  'diez',
  'once',
  'doce',
  'trece',
  'catorce',
  'quince',
  'dieciséis',
  'diecisiete',
  'dieciocho',
  'diecinueve',
  'veinte',
  'veintiún',
  'veintidós',
  'veintitrés',
  'veinticuatro',
  'veinticinco',
  'veintiséis',
  'veintisiete',
  'veintiocho',
  'veintinueve',
];

const List<String> _decenas = [
  '',
  '',
  '',
  'treinta',
  'cuarenta',
  'cincuenta',
  'sesenta',
  'setenta',
  'ochenta',
  'noventa',
];

const List<String> _centenas = [
  '',
  'ciento',
  'doscientos',
  'trescientos',
  'cuatrocientos',
  'quinientos',
  'seiscientos',
  'setecientos',
  'ochocientos',
  'novecientos',
];

/// 1..999 en letras. Siempre va antes de 'mil', 'millón(es)' o 'pesos', así
/// que el 1 final se apocopa ('un', 'veintiún', 'treinta y un').
String _grupo(int n) {
  if (n == 100) return 'cien';
  final partes = <String>[];
  final c = n ~/ 100;
  final resto = n % 100;
  if (c > 0) partes.add(_centenas[c]);
  if (resto > 0 && resto < 30) {
    partes.add(_unidades[resto]);
  } else if (resto >= 30) {
    final d = resto ~/ 10;
    final u = resto % 10;
    partes.add(u == 0 ? _decenas[d] : '${_decenas[d]} y ${_unidades[u]}');
  }
  return partes.join(' ');
}

/// Valor en letras de una cuenta de cobro, en español de Colombia, para la
/// línea "La suma de: {en letras} ($ 120.000)" del PDF (UI-SPEC PDF §2):
/// `120000` -> `'ciento veinte mil pesos'`, `1000000` ->
/// `'un millón de pesos'`. Acepta 0..999.999.999; fuera de ese rango lanza
/// [ArgumentError] (los totales del servidor nunca llegan tan alto).
String pesosEnLetras(int pesos) {
  if (pesos < 0 || pesos > 999999999) {
    throw ArgumentError.value(pesos, 'pesos', 'Fuera de 0..999.999.999');
  }
  if (pesos == 0) return 'cero pesos';
  if (pesos == 1) return 'un peso';

  final millones = pesos ~/ 1000000;
  final miles = (pesos ~/ 1000) % 1000;
  final resto = pesos % 1000;

  final partes = <String>[];
  if (millones == 1) {
    partes.add('un millón');
  } else if (millones > 1) {
    partes.add('${_grupo(millones)} millones');
  }
  if (miles == 1) {
    partes.add('mil');
  } else if (miles > 1) {
    partes.add('${_grupo(miles)} mil');
  }
  if (resto > 0) partes.add(_grupo(resto));

  // 'de pesos' solo tras un número exacto de millones ('un millón de pesos').
  final exactoEnMillones = millones > 0 && miles == 0 && resto == 0;
  partes.add(exactoEnMillones ? 'de pesos' : 'pesos');
  return partes.join(' ');
}
