/// Clasificación de un teléfono según el plan de numeración colombiano.
enum ClaseTelefono { celularCo, fijoCo, internacional, desconocido, vacio }

/// Normaliza un teléfono escrito a mano (D-16): se guarda como
/// `573001234567` para números colombianos y `+<dígitos>` para extranjeros
/// (el `+` evita que re-normalizar confunda un número extranjero con uno
/// colombiano). No hay migración masiva: se normaliza al guardar y de nuevo
/// al usar el número (WhatsApp), por eso la función es idempotente y nunca
/// bloquea el guardado — lo dudoso se devuelve como [ClaseTelefono.desconocido]
/// conservando los dígitos escritos.
///
/// Solo sobreviven dígitos y un `+` inicial, así que el resultado es seguro
/// para incrustar en una URL `wa.me`.
({String guardado, ClaseTelefono clase, String formateado}) normalizarTelefono(
  String raw,
) {
  final t = raw.trim();
  if (t.isEmpty) {
    return (guardado: '', clase: ClaseTelefono.vacio, formateado: '');
  }

  var conMas = t.startsWith('+');
  var digitos = t.replaceAll(RegExp(r'\D'), '');
  if (digitos.isEmpty) {
    return (guardado: '', clase: ClaseTelefono.vacio, formateado: '');
  }
  if (!conMas && digitos.startsWith('00')) {
    conMas = true;
    digitos = digitos.substring(2);
  }

  String? nacional;
  if (conMas) {
    if (digitos.startsWith('57')) {
      nacional = digitos.substring(2);
    } else {
      final guardado = '+$digitos';
      return (
        guardado: guardado,
        clase: ClaseTelefono.internacional,
        formateado: guardado,
      );
    }
  } else if (digitos.length == 12 && digitos.startsWith('57')) {
    nacional = digitos.substring(2);
  } else if (digitos.length == 10) {
    nacional = digitos;
  }

  if (nacional != null && nacional.length == 10) {
    final clase = nacional.startsWith('3')
        ? ClaseTelefono.celularCo
        : nacional.startsWith('60')
        ? ClaseTelefono.fijoCo
        : null;
    if (clase != null) {
      return (
        guardado: '57$nacional',
        clase: clase,
        formateado:
            '+57 ${nacional.substring(0, 3)} ${nacional.substring(3, 6)} '
            '${nacional.substring(6)}',
      );
    }
  }

  return (
    guardado: conMas ? '+$digitos' : digitos,
    clase: ClaseTelefono.desconocido,
    formateado: conMas ? '+$digitos' : digitos,
  );
}

/// `true` cuando conviene mostrar el aviso suave "no parece un celular
/// colombiano": solo fijos y números no reconocidos (nunca vacío ni
/// internacional).
bool requiereAvisoTelefono(String raw) {
  final clase = normalizarTelefono(raw).clase;
  return clase == ClaseTelefono.fijoCo || clase == ClaseTelefono.desconocido;
}

/// Número listo para `wa.me` (solo dígitos, sin `+`), o `null` si no es un
/// celular colombiano ni un número internacional.
String? numeroWhatsApp(String raw) {
  final r = normalizarTelefono(raw);
  switch (r.clase) {
    case ClaseTelefono.celularCo:
      return r.guardado;
    case ClaseTelefono.internacional:
      return r.guardado.substring(1);
    case ClaseTelefono.fijoCo:
    case ClaseTelefono.desconocido:
    case ClaseTelefono.vacio:
      return null;
  }
}
