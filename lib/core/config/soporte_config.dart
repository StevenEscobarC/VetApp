/// WhatsApp de soporte al que el administrador escribe para activar o cambiar
/// el plan (D-14). Se inyecta en build con
/// `--dart-define=SOPORTE_WHATSAPP=<celular>`. Sin valor por defecto a propósito:
/// ningún número vive en el código, y vacío oculta número y botón (build de
/// Play Store).
const String kSoporteWhatsapp = String.fromEnvironment('SOPORTE_WHATSAPP');

/// Nombre de la app para el texto nuevo. Único lugar donde se escribe: el
/// cambio de marca está pendiente de dominios y registros, así que ningún
/// texto nuevo debe llevar el nombre literal.
const String kNombreApp = 'VetApp';
