import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../../team/domain/miembro.dart';

/// Hoja "Asignar a": lista solo a los miembros [activos] (un retirado nunca
/// se ofrece) con la selección actual marcada. Devuelve el [Miembro] elegido
/// o `null` si se cierra sin elegir. [indices] es el color estable por
/// veterinario y [yoId] marca al usuario con "(Tú)".
Future<Miembro?> elegirVeterinario(
  BuildContext context, {
  required List<Miembro> activos,
  required String seleccionadoId,
  required String yoId,
  required Map<String, int> indices,
}) {
  return showModalBottomSheet<Miembro>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final textTheme = Theme.of(ctx).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text('Asignar a', style: textTheme.titleLarge),
              ),
              for (final m in activos)
                Semantics(
                  button: true,
                  selected: m.id == seleccionadoId,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(m),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            VetAvatar(
                              nombre: m.nombre,
                              indice: indices[m.id] ?? 0,
                              size: 40,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(m.nombre, style: textTheme.bodyLarge),
                            ),
                            if (m.id == yoId) ...[
                              Text(
                                '(Tú)',
                                style: textTheme.labelLarge?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Icon(
                              m.id == seleccionadoId
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: m.id == seleccionadoId
                                  ? AppColors.primaryText
                                  : AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
