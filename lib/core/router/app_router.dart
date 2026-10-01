import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/agenda_routes.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/client_home_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/clients/presentation/clientes_routes.dart';
import '../../features/appointments/presentation/screens/recordatorios_screen.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/home/presentation/screens/inicio_screen.dart';
import '../../features/home/presentation/screens/mas_screen.dart';
import '../../features/patients/presentation/pacientes_routes.dart';

const _publicPaths = {'/login', '/register', '/reset-password'};

/// Bridges [authProfileProvider] to [GoRouter.refreshListenable] so the
/// router re-evaluates `redirect:` the instant the session changes, not
/// just on the next navigation.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProfileProvider, (previous, next) => notifyListeners());
  }
}

/// The single auth gate for the whole app — no widget re-implements this
/// branching. Reads [authProfileProvider] and `state.matchedLocation`.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProfileProvider);
      final location = state.matchedLocation;

      if (auth.isLoading && !auth.hasValue) {
        return location == '/splash' ? null : '/splash';
      }

      final profile = auth.value;
      if (profile == null) {
        return _publicPaths.contains(location) ? null : '/login';
      }

      if (!profile.esVeterinario) {
        return location == '/cliente' ? null : '/cliente';
      }

      const vetExitPaths = {
        '/splash',
        '/login',
        '/register',
        '/reset-password',
        '/cliente',
      };
      if (vetExitPaths.contains(location)) return '/inicio';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(path: '/cliente', builder: (_, _) => const ClientHomeScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/inicio', builder: (_, _) => const InicioScreen()),
            ],
          ),
          StatefulShellBranch(routes: [pacientesRoute]),
          StatefulShellBranch(routes: [agendaRoute]),
          StatefulShellBranch(routes: [clientesRoute]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mas',
                builder: (_, _) => const MasScreen(),
                routes: [
                  GoRoute(
                    path: 'recordatorios',
                    builder: (_, _) => const RecordatoriosScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });

  return router;
});
