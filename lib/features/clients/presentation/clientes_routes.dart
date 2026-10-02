import 'package:go_router/go_router.dart';

import '../../clinical_history/presentation/screens/consulta_form_screen.dart';
import '../../patients/presentation/screens/mascota_detail_screen.dart';
import '../../vaccination/presentation/screens/carne_screen.dart';
import '../../patients/presentation/screens/mascota_form_screen.dart';
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
          path: 'nueva-mascota',
          builder: (_, state) =>
              MascotaFormScreen(clienteId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'mascotas/:mascotaId',
          builder: (_, state) => MascotaDetailScreen(
            mascotaId: state.pathParameters['mascotaId']!,
            rutaBase: state.uri.path,
          ),
          routes: [
            GoRoute(
              path: 'editar',
              builder: (_, state) => MascotaFormScreen(
                mascotaId: state.pathParameters['mascotaId']!,
              ),
            ),
            GoRoute(
              path: 'carne',
              builder: (_, state) => CarneScreen(
                mascotaId: state.pathParameters['mascotaId']!,
                abrirCompartir: state.uri.queryParameters['compartir'] == '1',
              ),
            ),
            GoRoute(
              path: 'consultas/nueva',
              builder: (_, state) => ConsultaFormScreen(
                mascotaId: state.pathParameters['mascotaId']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
