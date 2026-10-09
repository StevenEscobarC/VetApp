import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/errors/limite_plan.dart';
import '../../../../core/utils/formato.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../plan/domain/mi_plan.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/limite_plan_sheet.dart';
import '../../../plan/presentation/widgets/prueba_clinica_sheet.dart';
import '../../domain/miembro.dart';
import '../../domain/team_failure.dart';
import '../providers/team_providers.dart';
import 'acceso_revocado_screen.dart';
import '../widgets/invitacion_card.dart';
import '../widgets/miembro_acciones_sheet.dart';
import '../widgets/miembro_tile.dart';

/// Equipo de la clínica (TEAM-02/TEAM-03): lista de veterinarios con su rol.
/// Cualquier veterinario la ve; las acciones de administración llegan en
/// planes posteriores.
class EquipoScreen extends ConsumerStatefulWidget {
  const EquipoScreen({super.key});

  @override
  ConsumerState<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends ConsumerState<EquipoScreen> {
  final _invitacionKey = GlobalKey();
  bool _generando = false;
  bool _unirseAbierto = false;

  Future<bool> _confirmarReemplazo() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Generar un código nuevo?'),
        content: const Text('El código actual dejará de funcionar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generar nuevo'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  /// Plan de la clínica: el del provider (la pantalla lo observa) y, si no
  /// hay valor, una lectura directa. `null` si ninguna funciona.
  Future<MiPlan?> _leerPlan() async {
    MiPlan? plan;
    try {
      plan = await ref.read(miPlanProvider.future);
    } catch (_) {}
    if (plan != null) return plan;
    try {
      return await ref.read(planRepositoryProvider).miPlan();
    } catch (_) {
      return null;
    }
  }

  Future<void> _mostrarSinCupo(MiPlan planPrevio) async {
    MiPlan plan = planPrevio;
    ref.invalidate(miPlanProvider);
    try {
      plan = await ref.read(miPlanProvider.future) ?? planPrevio;
    } catch (_) {}
    if (!mounted) return;
    await mostrarLimitePlanSheet(
      context,
      limite: LimitePlan.miembros,
      plan: plan,
      esAdmin: true,
    );
  }

  Future<void> _avisarPruebaActiva(ScaffoldMessengerState messenger) async {
    DateTime? hasta;
    try {
      await ref.read(invitacionVigenteProvider.future);
      hasta = (await ref.read(miPlanProvider.future))?.vigenteHasta;
    } catch (_) {}
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          hasta == null
              ? 'Código generado'
              : 'Prueba Clínica activa hasta el ${formatearFecha(hasta)}',
        ),
      ),
    );
    _verInvitacion();
  }

  void _verInvitacion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _invitacionKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx);
    });
  }

  /// Quita el indicador de carga del botón antes de abrir una hoja.
  void _soltarBoton() {
    if (mounted) setState(() => _generando = false);
  }

  Future<void> _generar(bool hayVigente) async {
    if (hayVigente && !await _confirmarReemplazo()) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generando = true);
    try {
      // Falla cerrado: sin plan legible no se genera nada, porque el servidor
      // abriría la prueba Clínica (que se usa una sola vez) sin que el
      // usuario viera la oferta.
      final plan = await _leerPlan();
      if (plan == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No pudimos verificar tu plan. Intenta de nuevo.'),
          ),
        );
        return;
      }
      if (!mounted) return;
      if (plan.pruebaClinicaDisponible) {
        _soltarBoton();
        final r = await mostrarPruebaClinicaSheet(
          context,
          miembros: plan.pruebaClinicaMiembros,
          activar: () => ref.read(teamActionsProvider).generarInvitacion(),
        );
        if (r == true) {
          await _avisarPruebaActiva(messenger);
        } else if (r == false) {
          await _mostrarSinCupo(plan);
        }
        return;
      }
      if (plan.sinCupoMiembros) {
        _soltarBoton();
        await _mostrarSinCupo(plan);
        return;
      }
      await ref.read(teamActionsProvider).generarInvitacion();
      await ref.read(invitacionVigenteProvider.future);
      messenger.showSnackBar(const SnackBar(content: Text('Código generado')));
      _verInvitacion();
    } on TeamFailure catch (e) {
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No pudimos generar el código. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(teamProvider);
    final perfil = ref.watch(authProfileProvider).value;
    final indices = ref.watch(indicesColorVetProvider);
    final textTheme = Theme.of(context).textTheme;
    final esAdmin = perfil?.esAdmin ?? false;
    final invitacion = esAdmin ? ref.watch(invitacionVigenteProvider) : null;
    final vigente = invitacion?.value;
    // Observado para que el futuro esté vivo cuando _generar lo lee.
    final plan = esAdmin ? ref.watch(miPlanProvider).value : null;
    final cupos = plan?.miembrosMax;

    Widget body;
    if (team.hasError && !team.hasValue) {
      final error = team.error;
      body = AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error is TeamFailure
                  ? error.message
                  : 'No pudimos cargar el equipo. Intenta de nuevo.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Reintentar',
              variant: AppButtonVariant.outline,
              onPressed: () => ref.invalidate(teamProvider),
            ),
          ],
        ),
      );
    } else if (!team.hasValue) {
      body = Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            const _SkeletonTile(),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    } else {
      final todos = team.requireValue;
      final activos = todos.where((m) => m.activo).toList();
      final retirados = todos.where((m) => !m.activo).toList();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Miembros', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final m in activos) ...[
            MiembroTile(
              miembro: m,
              indice: indices[m.id] ?? 0,
              esYo: m.id == perfil?.id,
              onTap: esAdmin
                  ? () => mostrarAccionesMiembro(
                      context,
                      ref,
                      miembro: m,
                      esYo: m.id == perfil?.id,
                      hayOtroAdmin: activos.any(
                        (o) => o.esAdmin && o.id != m.id,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (activos.length == 1) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Eres el único veterinario de la clínica. Invita a un colega '
              'para compartir pacientes y agenda.',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (esAdmin && activos.length == 1) ...[
            if (_unirseAbierto)
              const UnirseConCodigoForm(variant: AppButtonVariant.outline)
            else
              AppButton(
                label: '¿Te registraste sin código? Unirme a otra clínica',
                variant: AppButtonVariant.text,
                onPressed: () => setState(() => _unirseAbierto = true),
              ),
          ],
          if (esAdmin) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Invitaciones', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (vigente != null)
              KeyedSubtree(
                key: _invitacionKey,
                child: InvitacionCard(
                  invitacion: vigente,
                  clinicaNombre: perfil?.clinicaNombre ?? 'tu clínica',
                ),
              )
            else if (invitacion?.isLoading ?? false)
              const _SkeletonTile()
            else if (invitacion?.hasError ?? false)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'No pudimos cargar el código.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  AppButton(
                    label: 'Reintentar',
                    variant: AppButtonVariant.text,
                    expand: false,
                    onPressed: () => ref.invalidate(invitacionVigenteProvider),
                  ),
                ],
              )
            else
              Text(
                'No hay códigos activos. Genera uno para invitar a un '
                'colega.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
          if (retirados.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _RetiradosSection(retirados: retirados, indices: indices),
          ],
          if (!esAdmin) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Solo los administradores pueden invitar o retirar '
              'veterinarios.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: const AppTopBar(title: 'Equipo'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: body,
            ),
          ),
          if (esAdmin && team.hasValue)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      label: vigente != null
                          ? 'Generar código nuevo'
                          : 'Invitar veterinario',
                      icon: Icons.person_add_alt_outlined,
                      isLoading: _generando,
                      onPressed: () => _generar(vigente != null),
                    ),
                    if (plan != null && cupos != null && cupos >= 2) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${plan.veterinariosActivos} de $cupos veterinarios',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RetiradosSection extends StatefulWidget {
  const _RetiradosSection({required this.retirados, required this.indices});

  final List<Miembro> retirados;
  final Map<String, int> indices;

  @override
  State<_RetiradosSection> createState() => _RetiradosSectionState();
}

class _RetiradosSectionState extends State<_RetiradosSection> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _abierto = !_abierto),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Retirados (${widget.retirados.length})',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Icon(
                  _abierto ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_abierto)
          for (final m in widget.retirados) ...[
            MiembroTile(miembro: m, indice: widget.indices[m.id] ?? 0),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: SizedBox(
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.all(
              Radius.circular(AppSpacing.radiusMd),
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
