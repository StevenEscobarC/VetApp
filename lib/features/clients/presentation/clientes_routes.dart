import 'package:go_router/go_router.dart';

import '../../patients/presentation/screens/mascota_detail_screen.dart';
import 'screens/cliente_detail_screen.dart';
import 'screens/clientes_list_screen.dart';
import 'screens/nuevo_cliente_mascota_screen.dart';

/// Root route for the Clientes tab. Later plans (09 edición) add child
/// `GoRoute`s here — this keeps `app_router.dart` untouched by every
/// subsequent Clientes plan. `nuevo` MUST stay the first child so
/// `/clientes/nuevo` never matches the `:id` child below.
final GoRoute clientesRoute = GoRoute(
  path: '/clientes',
  builder: (_, _) => const ClientesListScreen(),
  routes: [
    GoRoute(
      path: 'nuevo',
      builder: (_, _) => const NuevoClienteMascotaScreen(),
    ),
    GoRoute(
      path: ':id',
      builder: (_, state) =>
          ClienteDetailScreen(clienteId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'mascotas/:mascotaId',
          builder: (_, state) => MascotaDetailScreen(
            mascotaId: state.pathParameters['mascotaId']!,
            rutaBase: state.uri.path,
          ),
        ),
      ],
    ),
  ],
);
