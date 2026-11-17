import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../domain/cobro_failure.dart';
import '../../domain/entities/cobro.dart';
import '../providers/cobros_providers.dart';

/// Hoja "Anular {número}" (UI-SPEC §4.2, D-10, D-13): un documento emitido
/// nunca se edita; se anula con motivo y conserva su número. Anular una
/// cuenta de cobro devuelve sus productos al inventario en la misma
/// transacción del servidor. Sirve también para anular una cotización.
Future<void> showAnularCobroSheet(BuildContext context, Cobro cobro) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AnularCobroSheet(cobro: cobro, messenger: messenger),
  );
}

const _minMotivo = 3;
const _maxMotivo = 200;

class _AnularCobroSheet extends ConsumerStatefulWidget {
  const _AnularCobroSheet({required this.cobro, required this.messenger});

  final Cobro cobro;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_AnularCobroSheet> createState() => _AnularCobroSheetState();
}

class _AnularCobroSheetState extends ConsumerState<_AnularCobroSheet> {
  final _motivoCtrl = TextEditingController();
  bool _guardando = false;
  String? _errorMotivo;
  String? _error;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  bool get _devuelveProductos =>
      widget.cobro.esCuentaCobro && widget.cobro.productoIds.isNotEmpty;

  Future<void> _anular() async {
    if (_guardando) return;
    final motivo = _motivoCtrl.text.trim();
    if (motivo.length < _minMotivo) {
      setState(() => _errorMotivo = 'Escribe el motivo.');
      return;
    }
    setState(() {
      _guardando = true;
      _errorMotivo = null;
      _error = null;
    });
    final cobro = widget.cobro;
    final messenger = widget.messenger;
    try {
      await ref
          .read(cobrosActionsProvider)
          .anular(cobro: cobro, motivo: motivo);
      if (!mounted) return;
      Navigator.of(context).pop();
      final texto = _devuelveProductos
          ? '${cobro.numeroTexto} anulada. Los productos volvieron al '
                'inventario.'
          : '${cobro.numeroTexto} anulada.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(texto)));
    } on CobroFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      if (await manejarLimitePlan(context, ref, e)) return;
      if (!mounted) return;
      setState(() {
        _error = switch (e.tipo) {
          ErrorCobro.sinConexion =>
            'Sin conexión, la anulación no se guardó. Inténtalo de nuevo '
                'cuando tengas señal.',
          ErrorCobro.sinPermiso =>
            'Solo el administrador o quien la emitió puede anularla.',
          ErrorCobro.estadoInvalido =>
            'Ya estaba anulada. Actualiza para ver su estado.',
          // IN-05: un colega la convirtió con la hoja abierta.
          ErrorCobro.cotizacionNoDisponible =>
            'Esta cotización ya se convirtió. Actualiza para ver su estado.',
          _ => 'No pudimos anular. Intenta de nuevo.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = widget.cobro;
    final cuerpo = t.bodyLarge?.copyWith(color: AppColors.textSecondary);
    final frases = [
      'Queda anulada con su número y no se puede deshacer.',
      if (_devuelveProductos) 'Los productos vuelven al inventario.',
      if (c.esCuentaCobro && c.pagada)
        'Estaba pagada: deja de contar en lo cobrado.',
      if (c.esCuentaCobro) 'Si hace falta, emite una nueva.',
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Anular ${c.numeroTexto}', style: t.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final f in frases) ...[
              Text(f, style: cuerpo),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Motivo de la anulación',
              hintText: 'Ej. Error en el precio',
              controller: _motivoCtrl,
              maxLength: _maxMotivo,
              maxLines: 3,
              autofocus: true,
              enabled: !_guardando,
              textCapitalization: TextCapitalization.sentences,
              errorText: _errorMotivo,
              onChanged: (_) {
                if (_errorMotivo != null) {
                  setState(() => _errorMotivo = null);
                }
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: t.labelLarge?.copyWith(color: AppColors.destructive),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Anular',
              variant: AppButtonVariant.destructive,
              isLoading: _guardando,
              onPressed: _anular,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
