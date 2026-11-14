import 'package:go_router/go_router.dart';

import '../domain/entities/cobro.dart';
import 'cobros_rutas.dart';
import 'screens/cobro_detail_screen.dart';
import 'screens/cobros_screen.dart';

/// Rutas de cobros de primer nivel (fuera del shell de la barra inferior),
/// para que cualquier punto de entrada (Más, cita, consulta, cliente) empuje
/// la misma pantalla. Desde estas pantallas solo se empujan rutas de primer
/// nivel: empujar una ruta de una rama del shell duplica la página del shell
/// en el Navigator raíz (G5).
///
/// Orden: los segmentos literales (`nuevo`, `:id/editar`, `:id/convertir`)
/// que agregan los planes siguientes se declaran ANTES de `:id` para que el
/// parámetro nunca los capture.
final List<GoRoute> cobrosRoutes = [
  GoRoute(
    path: kRutaCobros,
    builder: (_, state) => CobrosScreen(
      tipoInicial: state.uri.queryParameters['tipo'] == 'cot'
          ? TipoCobro.cotizacion
          : TipoCobro.cuentaCobro,
    ),
  ),
  GoRoute(
    path: '/cobros/:id',
    builder: (_, state) =>
        CobroDetailScreen(cobroId: state.pathParameters['id']!),
  ),
];
