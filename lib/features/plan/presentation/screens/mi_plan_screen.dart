import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/mi_plan.dart';
import '../../domain/plan_failure.dart';
import '../plan_textos.dart';
import '../providers/plan_providers.dart';
import '../widgets/caracteristica_tile.dart';
import '../widgets/plan_insignia.dart';
import '../widgets/uso_contador_tile.dart';

const String _errorGenerico = 'No pudimos cargar tu plan. Intenta de nuevo.';

/// "Mi plan" (`/mas/plan`): qué plan tiene la clínica, hasta cuándo y cuánto
/// se ha usado. Lo ven todos los veterinarios; todo lo que muestra viene de
/// `mi_plan()` (el servidor decide fechas y límites).
class MiPlanScreen extends ConsumerWidget {
  const MiPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(miPlanProvider);

    Widget body;
    if (plan.hasError && !plan.hasValue) {
      final error = plan.error;
      body = _ErrorPlan(
        mensaje: error is PlanFailure ? error.message : _errorGenerico,
        onReintentar: () => ref.invalidate(miPlanProvider),
      );
    } else if (!plan.hasValue) {
      body = const _EsqueletoPlan();
    } else if (plan.requireValue == null) {
      body = _ErrorPlan(
        mensaje: _errorGenerico,
        onReintentar: () => ref.invalidate(miPlanProvider),
      );
    } else {
      body = _ContenidoPlan(plan: plan.requireValue!);
    }

    return Scaffold(
      appBar: const AppTopBar(title: 'Mi plan'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: body,
        ),
      ),
    );
  }
}

class _ContenidoPlan extends StatelessWidget {
  const _ContenidoPlan({required this.plan});

  final MiPlan plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!plan.puedeEscribir) ...[
          const _AvisoSoloLectura(),
          const SizedBox(height: AppSpacing.lg),
        ],
        _TarjetaPlan(plan: plan),
        const SizedBox(height: AppSpacing.lg),
        Text('Uso de tu clínica', style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        _Usos(plan: plan),
        const SizedBox(height: AppSpacing.lg),
        _QueIncluye(actual: plan.plan),
      ],
    );
  }
}

class _AvisoSoloLectura extends StatelessWidget {
  const _AvisoSoloLectura();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: AppColors.primaryText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu cuenta está en solo lectura',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Puedes ver todo, pero no crear ni editar. Habla con el '
                  'administrador de tu clínica para activar el plan.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({required this.plan});

  final MiPlan plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lineas = lineasVigencia(plan);
    final enGracia = plan.estado == EstadoPlan.gracia;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                size: 24,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(nombrePlan(plan.plan), style: textTheme.titleLarge),
              ),
              const SizedBox(width: AppSpacing.sm),
              PlanInsignia(
                texto: enGracia ? 'En gracia' : 'Activo',
                estilo: enGracia ? EstiloPlan.alerta : EstiloPlan.activo,
              ),
            ],
          ),
          if (plan.esPrueba || plan.plan == PlanTipo.beta || plan.fundador) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (plan.esPrueba)
                  const PlanInsignia(
                    texto: 'Prueba',
                    estilo: EstiloPlan.prueba,
                  ),
                if (plan.plan == PlanTipo.beta)
                  const PlanInsignia(texto: 'Beta', estilo: EstiloPlan.beta),
                if (plan.fundador)
                  const PlanInsignia(
                    texto: 'Fundador',
                    estilo: EstiloPlan.beta,
                    icono: Icons.star_outline,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(lineas.linea, style: textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            lineas.detalle,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (lineas.nota != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              lineas.nota!,
              style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

String _pacientes(int n) => n == 1 ? '1 paciente' : '$n pacientes';

String _veterinarios(int n) => n == 1 ? '1 veterinario' : '$n veterinarios';

class _Usos extends StatelessWidget {
  const _Usos({required this.plan});

  final MiPlan plan;

  @override
  Widget build(BuildContext context) {
    final maxP = plan.pacientesMax;
    final maxM = plan.miembrosMax;

    final String? ayudaPacientes;
    if (maxP == null) {
      ayudaPacientes = 'Sin límite';
    } else if (plan.pacientesAlTope) {
      ayudaPacientes =
          'Límite alcanzado: puedes seguir atendiendo, pero no registrar más.';
    } else if (plan.pacientesCount * 100 >= maxP * 80) {
      ayudaPacientes = 'Te quedan ${maxP - plan.pacientesCount}';
    } else {
      ayudaPacientes = null;
    }

    final String? ayudaVets;
    if (maxM == null) {
      ayudaVets = 'Sin tope';
    } else if (maxM >= 2 && plan.sinCupoMiembros) {
      ayudaVets = 'Cupo completo';
    } else {
      ayudaVets = null;
    }

    return Column(
      children: [
        UsoContadorTile(
          icono: Icons.pets_outlined,
          texto: maxP == null
              ? _pacientes(plan.pacientesCount)
              : '${plan.pacientesCount} de $maxP pacientes',
          progreso: maxP == null || maxP == 0
              ? null
              : plan.pacientesCount / maxP,
          ayuda: ayudaPacientes,
        ),
        const SizedBox(height: AppSpacing.sm),
        UsoContadorTile(
          icono: Icons.group_outlined,
          texto: maxM == null
              ? _veterinarios(plan.veterinariosActivos)
              : '${plan.veterinariosActivos} de $maxM veterinarios',
          progreso: maxM == null || maxM < 2
              ? null
              : plan.veterinariosActivos / maxM,
          ayuda: ayudaVets,
        ),
        const SizedBox(height: AppSpacing.sm),
        CaracteristicaTile(
          icono: Icons.image_outlined,
          titulo: 'Logo en carné, PDF y página',
          incluido: plan.logoPermitido,
          estado: plan.logoPermitido
              ? 'Incluido'
              : plan.logoGuardado
              ? 'Guardado, oculto en Gratis'
              : 'No incluido en Gratis',
        ),
        const SizedBox(height: AppSpacing.sm),
        CaracteristicaTile(
          icono: Icons.tune,
          titulo: 'Protocolos propios',
          incluido: plan.protocolosPropiosPermitidos,
          estado: plan.protocolosPropiosPermitidos
              ? 'Incluido'
              : 'No incluido en Gratis',
          ayuda: plan.protocolosPropiosPermitidos
              ? null
              : 'Los protocolos estándar siguen disponibles.',
        ),
      ],
    );
  }
}

/// Comparación de planes sin precios, plegada por defecto.
class _QueIncluye extends StatefulWidget {
  const _QueIncluye({required this.actual});

  final PlanTipo actual;

  @override
  State<_QueIncluye> createState() => _QueIncluyeState();
}

class _QueIncluyeState extends State<_QueIncluye> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _abierto,
          child: InkWell(
            onTap: () => setState(() => _abierto = !_abierto),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Qué incluye cada plan',
                      style: textTheme.titleLarge,
                    ),
                  ),
                  Icon(_abierto ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        if (_abierto) ...[
          const SizedBox(height: AppSpacing.sm),
          _FilaPlan(
            titulo: 'Gratis',
            detalle:
                'Hasta 50 pacientes · 1 veterinario · carné con el nombre '
                'de la clínica',
            esActual: widget.actual == PlanTipo.gratis,
          ),
          const SizedBox(height: AppSpacing.sm),
          _FilaPlan(
            titulo: 'Pro',
            detalle:
                'Pacientes ilimitados · 1 veterinario · logo y protocolos '
                'propios',
            esActual: widget.actual == PlanTipo.pro,
          ),
          const SizedBox(height: AppSpacing.sm),
          _FilaPlan(
            titulo: 'Clínica',
            detalle:
                'Pacientes ilimitados · 2, 3 o 5 veterinarios según el tramo '
                '· logo y protocolos propios',
            esActual: widget.actual == PlanTipo.clinica,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'El carné, la historia clínica, la agenda y las alertas de '
            'vacunas están incluidos en todos los planes.',
            style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _FilaPlan extends StatelessWidget {
  const _FilaPlan({
    required this.titulo,
    required this.detalle,
    required this.esActual,
  });

  final String titulo;
  final String detalle;
  final bool esActual;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo, style: textTheme.bodyLarge)),
              if (esActual)
                const PlanInsignia(
                  texto: 'Tu plan',
                  estilo: EstiloPlan.gratis,
                  icono: Icons.check_circle_outline,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detalle,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPlan extends StatelessWidget {
  const _ErrorPlan({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Reintentar',
            variant: AppButtonVariant.outline,
            onPressed: onReintentar,
          ),
        ],
      ),
    );
  }
}

class _EsqueletoPlan extends StatelessWidget {
  const _EsqueletoPlan();

  @override
  Widget build(BuildContext context) {
    Widget bloque(double alto) => Container(
      height: alto,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
    return Column(
      children: [
        bloque(140),
        const SizedBox(height: AppSpacing.sm),
        bloque(72),
        const SizedBox(height: AppSpacing.sm),
        bloque(72),
      ],
    );
  }
}
