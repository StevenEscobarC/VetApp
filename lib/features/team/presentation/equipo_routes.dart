import 'package:go_router/go_router.dart';

import '../../clinic/presentation/screens/datos_clinica_screen.dart';
import 'screens/equipo_screen.dart';
import 'screens/mi_perfil_screen.dart';

/// Rutas hijas de `/mas` del equipo. Los planes posteriores agregan rutas
/// aquí, nunca en `app_router.dart`.
final List<GoRoute> masTeamRoutes = [
  GoRoute(path: 'equipo', builder: (_, _) => const EquipoScreen()),
  GoRoute(path: 'perfil', builder: (_, _) => const MiPerfilScreen()),
  GoRoute(path: 'clinica', builder: (_, _) => const DatosClinicaScreen()),
];
