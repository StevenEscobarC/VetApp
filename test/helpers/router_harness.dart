import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/theme/app_theme.dart';

/// Minimal router-backed test harness reused by every screen test from
/// Plan 03 onward: boots a real [GoRouter] scoped to just the [routes]
/// under test, wrapped in the same [AppTheme.light] the app itself uses,
/// with [ProviderScope] [overrides] for fakes. Deliberately smaller than the
/// app's real `routerProvider` (no auth redirect, no `AppShell` bottom nav)
/// so screen tests stay focused on the screen, not the whole navigation
/// stack.
Widget routerHarness({
  required String initialLocation,
  required List<RouteBase> routes,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: overrides,
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: GoRouter(initialLocation: initialLocation, routes: routes),
    ),
  );
}
