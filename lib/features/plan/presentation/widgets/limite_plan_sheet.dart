import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/limite_plan.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../domain/mi_plan.dart';

/// Función exclusiva de Pro o Clínica que originó un [LimitePlan.funcion].
enum FuncionPro { logo, protocolos }

/// Abre la hoja explicativa de un límite del plan (D-16.3). Se usa igual
/// desde la verificación previa (flags de `mi_plan()`) y desde el respaldo
/// del servidor (`LP00x` con el formulario aún abierto).
Future<void> mostrarLimitePlanSheet(
  BuildContext context, {
  required LimitePlan limite,
  FuncionPro? funcion,
  MiPlan? plan,
  required bool esAdmin,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (_) => LimitePlanSheet(
      limite: limite,
      funcion: funcion,
      plan: plan,
      esAdmin: esAdmin,
    ),
  );
}

/// Hoja "Llegaste a los 50 pacientes", "El logo es parte de Pro", etc. Texto
/// fijo por variante: nunca muestra el mensaje crudo del servidor. [plan]
/// personaliza contadores y variantes; si es `null` se usan los valores del
/// plan Gratis.
class LimitePlanSheet extends StatelessWidget {
  const LimitePlanSheet({
    super.key,
    required this.limite,
    this.funcion,
    this.plan,
    required this.esAdmin,
  });

  final LimitePlan limite;
  final FuncionPro? funcion;
  final MiPlan? plan;
  final bool esAdmin;

  static const _fraseAdmin =
      'Pídele al administrador de tu clínica que active el plan.';

  int get _maximoPacientes => plan?.pacientesMax ?? 50;

  IconData get _icono => switch (limite) {
    LimitePlan.pacientes => Icons.pets_outlined,
    LimitePlan.miembros => Icons.group_outlined,
    LimitePlan.soloLectura => Icons.lock_outline,
    LimitePlan.funcion => switch (funcion) {
      FuncionPro.protocolos => Icons.tune,
      _ => Icons.image_outlined,
    },
  };

  String get _titulo => switch (limite) {
    LimitePlan.pacientes => 'Llegaste a los $_maximoPacientes pacientes',
    LimitePlan.miembros => 'Tu plan no tiene cupo para más veterinarios',
    LimitePlan.soloLectura => 'Tu cuenta está en solo lectura',
    LimitePlan.funcion => switch (funcion) {
      FuncionPro.logo => 'El logo es parte de Pro',
      FuncionPro.protocolos => 'Los protocolos propios son parte de Pro',
      null => 'Esta función es parte de Pro',
    },
  };

  String get _cuerpo {
    final base = switch (limite) {
      LimitePlan.pacientes =>
        'El plan Gratis incluye hasta $_maximoPacientes pacientes. '
            'Con Pro registras pacientes ilimitados. Tus pacientes, '
            'historias clínicas, carnés y agenda siguen igual.',
      LimitePlan.miembros =>
        plan != null && plan!.plan == PlanTipo.clinica && plan!.sinCupoMiembros
            ? 'Tu plan Clínica ya tiene sus ${plan!.miembrosMax} veterinarios '
                  'activos. Escríbenos para pasar a un tramo mayor.'
            : 'Tu plan incluye 1 veterinario activo. Con el plan Clínica '
                  'trabajan juntos 2, 3 o 5 veterinarios según el tramo.',
      LimitePlan.soloLectura =>
        'El plan de tu clínica no incluye más veterinarios en este momento. '
            'Puedes ver pacientes, historias, agenda y carnés, pero no crear '
            'ni editar. Habla con el administrador de tu clínica para activar '
            'el plan.',
      LimitePlan.funcion => switch (funcion) {
        FuncionPro.logo =>
          plan?.logoGuardado == true
              ? 'Tu logo está guardado y volverá a mostrarse cuando actives '
                    'Pro o Clínica.'
              : 'Con Pro tu logo aparece en el carné, el PDF y la página que '
                    'ven tus clientes. Mientras tanto se muestra solo el '
                    'nombre de tu clínica.',
        FuncionPro.protocolos =>
          'Con Pro creas y editas tus propios protocolos y los guardas en tu '
              'catálogo. Mientras tanto usas los protocolos estándar y puedes '
              'seguir registrando dosis.',
        null =>
          'Con Pro o Clínica accedes a esta función. Mientras tanto sigues '
              'usando el resto de la app sin cambios.',
      },
    };
    final conFrase = limite != LimitePlan.soloLectura && !esAdmin;
    return conFrase ? '$base $_fraseAdmin' : base;
  }

  String? get _contador {
    final p = plan;
    if (limite != LimitePlan.pacientes || p == null || p.pacientesMax == null) {
      return null;
    }
    return '${p.pacientesCount} de ${p.pacientesMax} pacientes';
  }

  void _verMiPlan(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/mas/plan');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final contador = _contador;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _icono,
                          size: 32,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Focus(
                      autofocus: true,
                      child: Semantics(
                        header: true,
                        child: Text(_titulo, style: textTheme.headlineSmall),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(_cuerpo, style: textTheme.bodyLarge),
                    if (contador != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        contador,
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Ver mi plan',
              onPressed: () => _verMiPlan(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Ahora no',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
