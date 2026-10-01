import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/app_status_chip.dart';
import '../../domain/entities/cita.dart';
import '../estado_cita_ui.dart';

/// Tarjeta de una [Cita] en la lista del día: horario + estado, mascotas,
/// cliente · motivo, lugar y (si existe) el recordatorio enviado. Las
/// acciones se agregan en planes posteriores.
class CitaCard extends StatelessWidget {
  const CitaCard({super.key, required this.cita, this.onTap, this.cruceCon});

  final Cita cita;

  /// Nombre(s) de la cita anterior con la que esta se cruza (D-09).
  final String? cruceCon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final apagada = cita.estado == EstadoCita.cancelada ||
        cita.estado == EstadoCita.noAsistio;
    final domicilio = cita.modalidad == ModalidadCita.domicilio;
    final lugar = domicilio
        ? ((cita.direccion?.isNotEmpty ?? false)
              ? cita.direccion!
              : 'A domicilio')
        : 'En consultorio';

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rangoHoras(aBogota(cita.fechaHora), aBogota(cita.fin)),
                  style: textTheme.labelLarge,
                ),
              ),
              AppStatusChip(status: estadoAStatus(cita.estado)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            cita.nombresMascotasCorto,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            '${cita.clienteNombre} · ${cita.motivo}',
            style: textTheme.bodyMedium?.copyWith(
              color: apagada ? AppColors.textMuted : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                domicilio ? Icons.home_outlined : Icons.storefront_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  lugar,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (cruceCon != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Se cruza con $cruceCon',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (cita.recordatorioEnviadoAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.done_all, size: 16, color: AppColors.success),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Recordatorio enviado '
                    '${fechaHoraCorta(aBogota(cita.recordatorioEnviadoAt!))}',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
