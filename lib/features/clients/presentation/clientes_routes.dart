import 'package:go_router/go_router.dart';

import 'screens/clientes_list_screen.dart';

/// Root route for the Clientes tab. Later plans (04 alta combinada, 07
/// ficha, 08 vinculación, 09 edición) add child `GoRoute`s here — this keeps
/// `app_router.dart` untouched by every subsequent Clientes plan.
final GoRoute clientesRoute = GoRoute(
  path: '/clientes',
  builder: (_, _) => const ClientesListScreen(),
);
