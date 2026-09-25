import 'package:go_router/go_router.dart';

import 'screens/clientes_list_screen.dart';
import 'screens/nuevo_cliente_mascota_screen.dart';

/// Root route for the Clientes tab. Later plans (07 ficha, 08 vinculación,
/// 09 edición) add child `GoRoute`s here — this keeps `app_router.dart`
/// untouched by every subsequent Clientes plan. `nuevo` MUST stay the first
/// child so `/clientes/nuevo` never matches the `:id` child a later plan
/// adds.
final GoRoute clientesRoute = GoRoute(
  path: '/clientes',
  builder: (_, _) => const ClientesListScreen(),
  routes: [
    GoRoute(
      path: 'nuevo',
      builder: (_, _) => const NuevoClienteMascotaScreen(),
    ),
  ],
);
