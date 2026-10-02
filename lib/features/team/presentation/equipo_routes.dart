import 'package:go_router/go_router.dart';

import 'screens/equipo_screen.dart';

/// Rutas hijas de `/mas` del equipo. Los planes posteriores agregan rutas
/// aquí, nunca en `app_router.dart`.
final List<GoRoute> masTeamRoutes = [
  GoRoute(path: 'equipo', builder: (_, _) => const EquipoScreen()),
];
