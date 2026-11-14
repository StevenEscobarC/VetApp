import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../appointments/presentation/providers/recordatorios_providers.dart';
import '../../../appointments/presentation/screens/recordatorios_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../billing/presentation/cobros_rutas.dart';
import '../../../inventory/presentation/inventario_routes.dart';
import '../../../inventory/presentation/providers/inventario_providers.dart';
import '../../../plan/presentation/plan_textos.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/plan_insignia.dart';
import '../../../team/presentation/providers/team_providers.dart';

String _textoBajos(int n) => n == 1 ? '1 bajo' : '$n bajos';

/// Pill "N bajos" de la fila Inventario (INV-02): icono + texto, nunca solo
/// color. Envuelve a varias líneas con textos grandes.
class _PillBajos extends StatelessWidget {
  const _PillBajos({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.trending_down,
            size: 16,
            color: AppColors.primaryText,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              texto,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sign-out lives here (no confirmation dialog — out of scope per
/// 01-UI-SPEC.md) so the human checkpoint in Plan 06 can switch accounts.
class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anticipacion =
        ref.watch(anticipacionRecordatorioProvider).value ?? 60;
    final miembros = ref
        .watch(teamProvider)
        .value
        ?.where((m) => m.activo)
        .length;
    final matricula = ref.watch(authProfileProvider).value?.matricula;
    final plan = ref.watch(miPlanProvider).value;
    final insignia = plan == null ? null : insigniaPlan(plan);
    // Cargando o con error no hay pill: la fila sigue siendo tocable.
    final bajosInventario =
        ref.watch(resumenInventarioProvider).value?.bajos ?? 0;
    return Scaffold(
      appBar: const AppTopBar(title: 'Más'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              onTap: () => context.push('/mas/perfil'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Mi perfil',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    if (matricula != null && matricula.isNotEmpty)
                      Text(
                        'Mat. $matricula',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () => context.push('/mas/equipo'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const Icon(Icons.group_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Equipo',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    if (miembros != null)
                      Text(
                        miembros == 1 ? '1 miembro' : '$miembros miembros',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () => context.push('/mas/clinica'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Datos de la clínica',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: insignia == null
                  ? 'Mi plan'
                  : 'Mi plan, ${insignia.texto}',
              excludeSemantics: true,
              button: true,
              child: AppCard(
                onTap: () => context.push('/mas/plan'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Mi plan',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      if (insignia != null)
                        Flexible(
                          child: PlanInsignia(
                            compacta: true,
                            texto: insignia.texto,
                            estilo: insignia.estilo,
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: bajosInventario > 0
                  ? 'Inventario, ${_textoBajos(bajosInventario)}'
                  : 'Inventario',
              excludeSemantics: true,
              button: true,
              child: AppCard(
                onTap: () => context.push(rutaInventario()),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Inventario',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      if (bajosInventario > 0)
                        Flexible(
                          child: _PillBajos(
                            texto: _textoBajos(bajosInventario),
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Estática, sin `ref.watch` (D-20): leer cobros nunca se bloquea
            // y las pruebas de Más no necesitan otro override.
            Semantics(
              label: 'Cobros',
              excludeSemantics: true,
              button: true,
              child: AppCard(
                onTap: () => context.push(kRutaCobros),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Cobros',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () => context.push('/mas/recordatorios'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Recordatorios',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      etiquetaAnticipacion(anticipacion),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () => context.push('/mas/protocolos'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    const Icon(Icons.tune),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Protocolos de vacunación',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Cerrar sesión',
              icon: Icons.logout,
              variant: AppButtonVariant.outline,
              onPressed: () => ref.read(authProfileProvider.notifier).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
