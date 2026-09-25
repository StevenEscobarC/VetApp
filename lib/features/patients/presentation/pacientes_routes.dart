import 'package:go_router/go_router.dart';

import 'screens/pacientes_list_screen.dart';

/// Root route for the Pacientes tab. Later plans (ficha, edición) add child
/// `GoRoute`s here — keeps `app_router.dart` untouched by every subsequent
/// Pacientes plan, mirroring `clientes_routes.dart`'s own convention.
final GoRoute pacientesRoute = GoRoute(
  path: '/pacientes',
  builder: (_, _) => const PacientesListScreen(),
);
