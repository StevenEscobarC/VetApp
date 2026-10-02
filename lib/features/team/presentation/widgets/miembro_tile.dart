import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../domain/miembro.dart';
import 'rol_badge.dart';

/// Fila de un miembro del equipo. Sin prefijo "Dr(a)." en la lista (UI-SPEC
/// §2); el chevron solo aparece cuando la fila es accionable ([onTap]).
class MiembroTile extends StatelessWidget {
  const MiembroTile({
    super.key,
    required this.miembro,
    required this.indice,
    this.esYo = false,
    this.onTap,
  });

  final Miembro miembro;
  final int indice;
  final bool esYo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final matricula = miembro.matricula?.trim() ?? '';
    return AppCard(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            VetAvatar(
              nombre: miembro.nombre,
              indice: indice,
              retirado: !miembro.activo,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: miembro.nombre,
                      children: [
                        if (esYo)
                          TextSpan(
                            text: ' (Tú)',
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    style: textTheme.bodyLarge,
                  ),
                  if (matricula.isNotEmpty)
                    Text(
                      'Mat. $matricula',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            RolBadge(miembro: miembro),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
