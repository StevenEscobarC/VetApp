/// URL base de la página pública del carné (D-16). Se puede sobrescribir en
/// build con `--dart-define=CARNE_BASE_URL=...`; el token va en el fragmento
/// (`#`) para que nunca llegue a los logs del servidor estático.
const String kCarneBaseUrl = String.fromEnvironment(
  'CARNE_BASE_URL',
  defaultValue: 'https://stevenescobarc.github.io/VetApp/c/',
);

/// Enlace permanente del carné para [token].
String urlCarne(String token) => '$kCarneBaseUrl#$token';
