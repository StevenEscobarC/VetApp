import 'package:go_router/go_router.dart';

import '../../clients/presentation/screens/nuevo_cliente_mascota_screen.dart';
import '../../patients/presentation/screens/mascota_form_screen.dart';
import 'screens/agenda_screen.dart';
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

/// Root route for the Agenda tab. Child routes are declared in the order
/// `nueva` (04-05), then `:id` with its children (04-06): static child
/// segments MUST precede `:id` so `/agenda/nueva` never matches it (same
/// rule as `clientes_routes.dart`).
final GoRoute agendaRoute = GoRoute(
  path: '/agenda',
  builder: (_, state) =>
      AgendaScreen(diaInicial: _parseDia(state.uri.queryParameters['dia'])),
  routes: [
    GoRoute(
      path: 'nueva',
      builder: (_, state) => CitaFormScreen(
        clienteIdInicial: state.uri.queryParameters['clienteId'],
        mascotaIdInicial: state.uri.queryParameters['mascotaId'],
        fechaInicial: _parseDia(state.uri.queryParameters['fecha']),
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
    ),
  ],
);
