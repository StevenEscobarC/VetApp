import 'package:go_router/go_router.dart';

import 'screens/mi_plan_screen.dart';

/// Rutas hijas de `/mas` del plan de la clínica (PLAN-06): `/mas/plan`.
final List<GoRoute> masPlanRoutes = [
  GoRoute(path: 'plan', builder: (_, _) => const MiPlanScreen()),
];
