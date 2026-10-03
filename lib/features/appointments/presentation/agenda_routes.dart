import 'package:go_router/go_router.dart';

import '../../clinical_history/presentation/screens/consulta_form_screen.dart';
import '../../clients/presentation/screens/nuevo_cliente_mascota_screen.dart';
import '../../patients/presentation/screens/mascota_form_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/cita_detail_screen.dart';
import 'screens/completar_cita_screen.dart';
import 'screens/cita_form_screen.dart';

/// `yyyy-mm-dd` -> `DateTime.utc(y, m, d)`; `null` si falta o es inválido.
DateTime? _parseDia(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  if (m == null) return null;
  return DateTime.utc(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

/// "Nueva cita" con sus subrutas `cliente` / `mascota`, montada bajo [ruta]
/// (`'/agenda/nueva'` dentro del shell o `'/citas/nueva'` de primer nivel).
GoRoute _nuevaCita({required String path, required String ruta}) => GoRoute(
  path: path,
  builder: (_, state) => CitaFormScreen(
    clienteIdInicial: state.uri.queryParameters['clienteId'],
    mascotaIdInicial: state.uri.queryParameters['mascotaId'],
    fechaInicial: _parseDia(state.uri.queryParameters['fecha']),
    motivoInicial: state.uri.queryParameters['motivo'],
    rutaBase: ruta,
  ),
  routes: [
    GoRoute(
      path: 'cliente',
      builder: (_, _) =>
          const NuevoClienteMascotaScreen(devolverResultado: true),
    ),
    GoRoute(
      path: 'mascota',
      builder: (_, state) => MascotaFormScreen(
        clienteId: state.uri.queryParameters['clienteId'] ?? '',
      ),
    ),
  ],
);

/// "Nueva cita" de primer nivel (fuera del shell, como `/vacunas` y
/// `/dosis/nueva`). Las pantallas que viven en una ruta raíz deben empujar
/// esta y no `/agenda/nueva`: empujar una ruta de una rama del
/// `StatefulShellRoute` desde una ruta raíz duplica la página del shell en el
/// Navigator raíz (assert `!keyReservation.contains(key)`, G5).
final GoRoute citaNuevaRaizRoute = _nuevaCita(
  path: '/citas/nueva',
  ruta: '/citas/nueva',
);

/// Ruta de [citaNuevaRaizRoute] con los valores prefijados codificados.
String rutaNuevaCita({String? clienteId, String? mascotaId, String? motivo}) =>
    Uri(
      path: '/citas/nueva',
      queryParameters: {
        'clienteId': ?clienteId,
        'mascotaId': ?mascotaId,
        'motivo': ?motivo,
      },
    ).toString();

/// Root route for the Agenda tab. Child routes are declared in the order
/// `nueva` (04-05), then `:id` with its children (04-06): static child
/// segments MUST precede `:id` so `/agenda/nueva` never matches it (same
/// rule as `clientes_routes.dart`).
final GoRoute agendaRoute = GoRoute(
  path: '/agenda',
  builder: (_, state) =>
      AgendaScreen(diaInicial: _parseDia(state.uri.queryParameters['dia'])),
  routes: [
    _nuevaCita(path: 'nueva', ruta: '/agenda/nueva'),
    GoRoute(
      path: ':id',
      builder: (_, state) =>
          CitaDetailScreen(citaId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'editar',
          builder: (_, state) =>
              CitaFormScreen(citaId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'completar',
          builder: (_, state) =>
              CompletarCitaScreen(citaId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'consulta/:mascotaId',
              builder: (_, state) => ConsultaFormScreen(
                mascotaId: state.pathParameters['mascotaId']!,
                citaId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
