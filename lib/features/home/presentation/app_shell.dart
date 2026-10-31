import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../plan/presentation/providers/plan_providers.dart';

/// Bottom-nav shell over the 5 [StatefulShellRoute] branches. Desktop
/// `NavigationRail` is intentionally not ported from the old mock (deferred
/// per SKELETON.md — mobile-first for this skeleton).
///
/// También relee el plan de la clínica (`mi_plan()`) cada vez que se enfoca
/// Inicio o Más, para que un cambio de plan en el servidor se vea sin relanzar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Ramas que releen el plan al enfocarse: Inicio (0) y Más (4)
/// (05.1-UI-SPEC: "on Inicio focus, Más open").
const _ramasQueRefrescanPlan = {0, 4};

class _AppShellState extends ConsumerState<AppShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final indice = widget.navigationShell.currentIndex;
    if (indice != oldWidget.navigationShell.currentIndex &&
        _ramasQueRefrescanPlan.contains(indice)) {
      // Corre durante el build: Riverpod no permite invalidar hasta el frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(miPlanProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.pets_outlined),
          selectedIcon: Icon(Icons.pets),
          label: 'Pacientes',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today),
          label: 'Agenda',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Clientes',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz),
          label: 'Más',
        ),
      ],
    ),
  );
}
