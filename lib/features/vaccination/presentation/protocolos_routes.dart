import 'package:go_router/go_router.dart';

import 'screens/protocolos_screen.dart';

/// Rutas hijas de `/mas` del catálogo de protocolos (D-01).
final List<GoRoute> masProtocolosRoutes = [
  GoRoute(path: 'protocolos', builder: (_, _) => const ProtocolosScreen()),
];
