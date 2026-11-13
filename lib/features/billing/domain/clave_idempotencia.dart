import 'dart:math';

/// Clave de idempotencia de un borrador de cobro (D-21): un UUID v4
/// (RFC 4122) que se crea una sola vez por borrador y se reenvía tal cual
/// en cada reintento, para que el servidor (único por clínica) no duplique
/// el documento si la primera respuesta se perdió.
///
/// Se genera a mano con [Random.secure] porque `uuid` solo es dependencia
/// transitiva: importarlo dispararía `depend_on_referenced_packages`. El
/// parámetro [rng] existe únicamente como costura determinista para tests.
String generarClaveIdempotencia([Random? rng]) {
  final r = rng ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
