import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/entities/carne.dart';
import '../../domain/vacuna_failure.dart';
import '../providers/anular_dosis_providers.dart';
import '../vacunacion_routes.dart';

/// Hoja "Anular dosis" (D-08): la dosis no se borra ni se edita, queda
/// tachada en Historial con su motivo. Al terminar ofrece "Registrar dosis"
/// con el biológico preseleccionado para cargar la correcta.
Future<void> showAnularDosisSheet(
  BuildContext context,
  DosisCarne dosis, {
  required String mascotaId,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AnularDosisSheet(
      dosis: dosis,
      mascotaId: mascotaId,
      messenger: messenger,
      router: router,
    ),
  );
}

const _motivos = ['Error de registro', 'Dosis duplicada', 'Otro motivo'];
const _otroMotivo = 'Otro motivo';

class _AnularDosisSheet extends ConsumerStatefulWidget {
  const _AnularDosisSheet({
    required this.dosis,
    required this.mascotaId,
    required this.messenger,
    required this.router,
  });

  final DosisCarne dosis;
  final String mascotaId;
  final ScaffoldMessengerState messenger;
  final GoRouter router;

  @override
  ConsumerState<_AnularDosisSheet> createState() => _AnularDosisSheetState();
}

class _AnularDosisSheetState extends ConsumerState<_AnularDosisSheet> {
  final _otroCtrl = TextEditingController();
  String? _motivo;
  bool _guardando = false;

  @override
  void dispose() {
    _otroCtrl.dispose();
    super.dispose();
  }

  String? get _motivoFinal {
    if (_motivo == null) return null;
    if (_motivo == _otroMotivo) return blancoANull(_otroCtrl.text);
    return _motivo;
  }

  Future<void> _anular() async {
    final motivo = _motivoFinal;
    if (motivo == null || _guardando) return;
    setState(() => _guardando = true);
    final dosis = widget.dosis;
    final messenger = widget.messenger;
    final router = widget.router;
    final mascotaId = widget.mascotaId;
    try {
      await ref
          .read(anularDosisProvider)
          .call(mascotaId: mascotaId, dosisId: dosis.id, motivo: motivo);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Dosis anulada. Registra la correcta.'),
            action: SnackBarAction(
              label: 'Registrar dosis',
              onPressed: () => router.push(
                rutaRegistrarDosis(
                  mascotaId: mascotaId,
                  codigo: dosis.codigoProtocolo,
                ),
              ),
            ),
          ),
        );
    } on VacunaFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dosis = widget.dosis;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anular dosis', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${dosis.biologicoNombre} · '
              '${formatearFecha(dosis.fechaAplicacion)}',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Motivo', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in _motivos)
                  AppFilterChip(
                    label: m,
                    selected: _motivo == m,
                    onTap: () => setState(() => _motivo = m),
                  ),
              ],
            ),
            if (_motivo == _otroMotivo) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Describe el motivo',
                controller: _otroCtrl,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'La dosis quedará tachada y no contará para la próxima fecha. '
              'No se puede deshacer.',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Volver',
                    variant: AppButtonVariant.outline,
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Anular dosis',
                    variant: AppButtonVariant.destructive,
                    isLoading: _guardando,
                    onPressed: _motivoFinal == null ? null : _anular,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
