import 'package:go_router/go_router.dart';

import 'screens/carne_screen.dart';
import 'screens/registrar_dosis_screen.dart';
import 'screens/vacunas_pendientes_screen.dart';

/// Rutas de vacunación de primer nivel (fuera del shell de la barra
/// inferior) para que cualquier punto de entrada empuje la misma pantalla.
/// Desde estas rutas solo se empujan rutas de primer nivel: empujar una ruta
/// de una rama del shell (p. ej. `/pacientes/:id/carne`, `/agenda/nueva`)
/// duplica la página del shell en el Navigator raíz (G5).
final List<GoRoute> vacunacionRoutes = [
  GoRoute(path: '/vacunas', builder: (_, _) => const VacunasPendientesScreen()),
  GoRoute(
    path: '/carne/:mascotaId',
    builder: (_, state) => CarneScreen(
      mascotaId: state.pathParameters['mascotaId']!,
      abrirCompartir: state.uri.queryParameters['compartir'] == '1',
    ),
  ),
  GoRoute(
    path: '/dosis/nueva',
    builder: (_, state) {
      final qp = state.uri.queryParameters;
      return RegistrarDosisScreen(
        mascotaId: qp['mascotaId'] ?? '',
        codigoInicial: qp['codigo'],
        citaId: qp['citaId'],
        categoria: qp['categoria'],
      );
    },
  ),
];

/// Carné de primer nivel; con [compartir] abre la hoja de compartir.
String rutaCarne(String mascotaId, {bool compartir = false}) => Uri(
  path: '/carne/${Uri.encodeComponent(mascotaId)}',
  queryParameters: compartir ? {'compartir': '1'} : null,
).toString();

/// Ruta de "Registrar dosis". Los valores van codificados con
/// [Uri.queryParameters], nunca concatenados en crudo.
String rutaRegistrarDosis({
  required String mascotaId,
  String? codigo,
  String? citaId,
  String? categoria,
}) => Uri(
  path: '/dosis/nueva',
  queryParameters: {
    'mascotaId': mascotaId,
    'codigo': ?codigo,
    'citaId': ?citaId,
    'categoria': ?categoria,
  },
).toString();
