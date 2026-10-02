import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';

/// Decisión del veterinario sobre una alerta: posponer [dias] o descartar
/// con [motivo] (exactamente uno de los dos viene definido).
typedef DecisionAlerta = ({int? dias, String? motivo});

enum _Opcion {
  posponer7('Posponer 7 días'),
  posponer30('Posponer 30 días'),
  fallecida('Mascota fallecida'),
  cambioVet('Cambió de veterinario'),
  otro('Otro motivo');

  const _Opcion(this.label);
  final String label;
}

/// Hoja "¿Qué hacemos con esta alerta?" (D-12). Devuelve la decisión o
/// `null` si se cierra con "Volver".
Future<DecisionAlerta?> mostrarDescartarAlertaSheet(BuildContext context) {
  return showModalBottomSheet<DecisionAlerta>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const DescartarAlertaSheet(),
  );
}

class DescartarAlertaSheet extends StatefulWidget {
  const DescartarAlertaSheet({super.key});

  @override
  State<DescartarAlertaSheet> createState() => _DescartarAlertaSheetState();
}

class _DescartarAlertaSheetState extends State<DescartarAlertaSheet> {
  final _motivoCtrl = TextEditingController();
  _Opcion? _sel;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  void _aplicar() {
    final r = switch (_sel!) {
      _Opcion.posponer7 => (dias: 7, motivo: null),
      _Opcion.posponer30 => (dias: 30, motivo: null),
      _Opcion.fallecida => (dias: null, motivo: _Opcion.fallecida.label),
      _Opcion.cambioVet => (dias: null, motivo: _Opcion.cambioVet.label),
      _Opcion.otro => (
        dias: null,
        motivo: _motivoCtrl.text.trim().isEmpty
            ? _Opcion.otro.label
            : _motivoCtrl.text.trim(),
      ),
    };
    Navigator.of(context).pop<DecisionAlerta>(r);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Qué hacemos con esta alerta?',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final o in _Opcion.values)
              InkWell(
                onTap: () => setState(() => _sel = o),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        _sel == o
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _sel == o
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(o.label, style: textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
              ),
            if (_sel == _Opcion.otro) ...[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Motivo',
                controller: _motivoCtrl,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Volver',
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Aplicar',
                    variant: AppButtonVariant.text,
                    onPressed: _sel == null ? null : _aplicar,
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
