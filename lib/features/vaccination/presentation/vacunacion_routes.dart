import 'package:go_router/go_router.dart';

import 'screens/registrar_dosis_screen.dart';
import 'screens/vacunas_pendientes_screen.dart';

/// Rutas de vacunación de primer nivel (fuera del shell de la barra
/// inferior) para que cualquier punto de entrada empuje la misma pantalla.
final List<GoRoute> vacunacionRoutes = [
  GoRoute(path: '/vacunas', builder: (_, _) => const VacunasPendientesScreen()),
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
