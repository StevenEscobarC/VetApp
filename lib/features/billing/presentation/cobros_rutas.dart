import '../domain/entities/cobro.dart';

/// Rutas de cobros: solo constructores de paths, sin importar pantallas, para
/// que las pantallas de la fase no choquen entre sí al registrarse. Los
/// valores van en [Uri.queryParameters], nunca concatenados en crudo.
const String kRutaCobros = '/cobros';
const String kRutaServicios = '/servicios';

String rutaCobro(String id) => '/cobros/${Uri.encodeComponent(id)}';

String rutaNuevoCobro({
  TipoCobro tipo = TipoCobro.cuentaCobro,
  String? clienteId,
  String? mascotaId,
  String? citaId,
  String? consultaId,
  String? desdeCobroId,
}) => Uri(
  path: '/cobros/nuevo',
  queryParameters: {
    'tipo': tipo == TipoCobro.cotizacion ? 'cot' : 'cc',
    'clienteId': ?clienteId,
    'mascotaId': ?mascotaId,
    'citaId': ?citaId,
    'consultaId': ?consultaId,
    'desdeCobroId': ?desdeCobroId,
  },
).toString();

String rutaEditarCotizacion(String id) =>
    '/cobros/${Uri.encodeComponent(id)}/editar';

String rutaConvertirCotizacion(String id) =>
    '/cobros/${Uri.encodeComponent(id)}/convertir';

/// Lista en la pestaña del [tipo].
String rutaCobrosTipo(TipoCobro tipo) =>
    tipo == TipoCobro.cotizacion ? '$kRutaCobros?tipo=cot' : kRutaCobros;
