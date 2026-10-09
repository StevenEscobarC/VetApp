import 'package:flutter/material.dart';

import '../../../../core/errors/limite_plan.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Abre la oferta de la prueba Clínica (D-11). Devuelve `true` cuando
/// [activar] terminó bien (la hoja se cierra), `false` cuando [activar] falló
/// con un límite de cupo de veterinarios (la hoja se cierra para que quien
/// llama abra la hoja de cupo) y `null` si el usuario elige "Ahora no" o la
/// descarta. Cualquier otro error muestra un aviso y deja la hoja abierta.
Future<bool?> mostrarPruebaClinicaSheet(
  BuildContext context, {
  required int miembros,
  required Future<void> Function() activar,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (_) => PruebaClinicaSheet(miembros: miembros, activar: activar),
  );
}

/// Hoja "Plan Clínica 30 días gratis, sin tarjeta". La prueba la abre el
/// servidor dentro de la misma llamada que genera el código ([activar]); la
/// app solo muestra la oferta y no menciona dinero fuera de "sin tarjeta".
class PruebaClinicaSheet extends StatefulWidget {
  const PruebaClinicaSheet({
    super.key,
    required this.miembros,
    required this.activar,
  });

  final int miembros;
  final Future<void> Function() activar;

  @override
  State<PruebaClinicaSheet> createState() => _PruebaClinicaSheetState();
}

class _PruebaClinicaSheetState extends State<PruebaClinicaSheet> {
  bool _activando = false;

  Future<void> _activar() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _activando = true);
    try {
      await widget.activar();
      if (mounted) navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      if (limiteDe(e) == LimitePlan.miembros) {
        navigator.pop(false);
        return;
      }
      setState(() => _activando = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No pudimos activar la prueba. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final beneficios = [
      'Hasta ${widget.miembros} veterinarios durante la prueba',
      'Logo y protocolos propios',
      'Sin tarjeta y sin cobro automático',
    ];
    return PopScope(
      canPop: !_activando,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
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
                          child: const Icon(
                            Icons.group_add_outlined,
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
                          child: Text(
                            'Plan Clínica 30 días gratis, sin tarjeta',
                            style: textTheme.headlineSmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Invita a tus colegas y trabajen juntos con '
                        'pacientes, agenda y carnés compartidos.',
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final b in beneficios) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExcludeSemantics(
                              child: Icon(
                                Icons.check_circle_outline,
                                size: 20,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(b, style: textTheme.labelLarge),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Si después no sigues con el plan Clínica, tus '
                        'colegas pasan a solo lectura tras 15 días de '
                        'gracia. No pierdes ningún dato.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Activar y generar código',
                isLoading: _activando,
                onPressed: _activar,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Ahora no',
                variant: AppButtonVariant.text,
                onPressed: _activando
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
