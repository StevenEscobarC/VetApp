import 'package:go_router/go_router.dart';

import 'screens/mascota_detail_screen.dart';
import 'screens/mascota_form_screen.dart';
import 'screens/pacientes_list_screen.dart';

/// Root route for the Pacientes tab. Later plans (edición) add child
/// `GoRoute`s here — keeps `app_router.dart` untouched by every subsequent
/// Pacientes plan, mirroring `clientes_routes.dart`'s own convention.
final GoRoute pacientesRoute = GoRoute(
  path: '/pacientes',
  builder: (_, _) => const PacientesListScreen(),
  routes: [
    GoRoute(
      path: ':id',
      builder: (_, state) => MascotaDetailScreen(
        mascotaId: state.pathParameters['id']!,
        rutaBase: state.uri.path,
      ),
      routes: [
        GoRoute(
          path: 'editar',
          builder: (_, state) =>
              MascotaFormScreen(mascotaId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
