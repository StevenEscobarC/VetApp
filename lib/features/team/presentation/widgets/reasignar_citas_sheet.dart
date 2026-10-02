import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../domain/miembro.dart';

/// Hoja "Reasignar citas": el administrador elige quién recibe las [n] citas
/// próximas de [nombre] antes de retirarlo (D-15). Devuelve el id elegido o
/// `null` si cancela ("Volver"). No se cierra tocando fuera: ninguna cita
/// puede quedar sin veterinario.
Future<String?> elegirDestinoCitas(
  BuildContext context, {
  required String nombre,
  required int n,
  required List<Miembro> candidatos,
  required String yoId,
  Map<String, int> indices = const {},
}) {
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (ctx) => _ReasignarCitasSheet(
      nombre: nombre,
      n: n,
      candidatos: candidatos,
      yoId: yoId,
      indices: indices,
    ),
  );
}

class _ReasignarCitasSheet extends StatefulWidget {
  const _ReasignarCitasSheet({
    required this.nombre,
    required this.n,
    required this.candidatos,
    required this.yoId,
    required this.indices,
  });

  final String nombre;
  final int n;
  final List<Miembro> candidatos;
  final String yoId;
  final Map<String, int> indices;

  @override
  State<_ReasignarCitasSheet> createState() => _ReasignarCitasSheetState();
}

class _ReasignarCitasSheetState extends State<_ReasignarCitasSheet> {
  late String _elegido = widget.candidatos.any((m) => m.id == widget.yoId)
      ? widget.yoId
      : widget.candidatos.first.id;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final n = widget.n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reasignar citas', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${widget.nombre} tiene $n '
              '${n == 1 ? 'cita próxima' : 'citas próximas'} sin atender. '
              '¿A quién se las asignamos?',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final m in widget.candidatos)
              Semantics(
                button: true,
                selected: m.id == _elegido,
                child: InkWell(
                  onTap: () => setState(() => _elegido = m.id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Row(
                      children: [
                        Icon(
                          m.id == _elegido
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: m.id == _elegido
                              ? AppColors.primaryText
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        VetAvatar(
                          nombre: m.nombre,
                          indice: widget.indices[m.id] ?? 0,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            m.id == widget.yoId ? '${m.nombre} (Tú)' : m.nombre,
                            style: textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: n == 1 ? 'Reasignar 1 cita' : 'Reasignar $n citas',
              onPressed: () => Navigator.of(context).pop(_elegido),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Volver',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
