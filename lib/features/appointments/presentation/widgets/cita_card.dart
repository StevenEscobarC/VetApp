import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/app_status_chip.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../../../team/presentation/providers/team_providers.dart';
import '../../domain/entities/cita.dart';
import '../../domain/filtro_agenda.dart';
import '../providers/citas_providers.dart';
import '../estado_cita_ui.dart';
import 'cita_acciones.dart';

/// Tarjeta de una [Cita] en la lista del día: horario + estado, mascotas,
/// cliente · motivo, lugar y (si existe) el recordatorio enviado. Las
/// acciones se agregan en planes posteriores.
class CitaCard extends ConsumerWidget {
  const CitaCard({super.key, required this.cita, this.onTap, this.cruceCon});

  final Cita cita;

  /// Nombre(s) de la cita anterior con la que esta se cruza (D-09).
  final String? cruceCon;
  final VoidCallback? onTap;

  Future<void> _confirmar(BuildContext context, WidgetRef ref) =>
      cambiarEstadoConDeshacer(
        context,
        ref,
        cita: cita,
        nuevo: EstadoCita.confirmada,
        mensaje: 'Cita confirmada',
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final puede = ref.watch(puedeEscribirProvider);
    final apagada =
        cita.estado == EstadoCita.cancelada ||
        cita.estado == EstadoCita.noAsistio;
    final domicilio = cita.modalidad == ModalidadCita.domicilio;
    final lugar = domicilio
        ? ((cita.direccion?.isNotEmpty ?? false)
              ? cita.direccion!
              : 'A domicilio')
        : 'En consultorio';

    final marcarVet =
        ref.watch(esClinicaMultiVetProvider) &&
        ref.watch(filtroAgendaProvider) == FiltroAgenda.todas;
    final activos = ref.watch(miembrosActivosProvider);
    final miembro = activos
        .where((m) => m.id == cita.veterinarioId)
        .firstOrNull;
    // Sin datos aún (lista vacía) no se marca como retirado: evita el parpadeo.
    final retirado = activos.isNotEmpty && miembro == null;
    final indices = ref.watch(indicesColorVetProvider);
    final indice = indices[cita.veterinarioId] ?? 0;
    final nombreVet = (cita.veterinarioNombre ?? miembro?.nombre ?? '').trim();
    final nombrePila = nombreVet.isEmpty ? '' : nombreVet.split(' ').first;

    final tarjeta = AppCard(
      onTap: onTap ?? () => context.push('/agenda/${cita.id}'),
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
              if (marcarVet) ...[
                VetAvatar(
                  nombre: nombreVet,
                  indice: indice,
                  size: 24,
                  retirado: retirado,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    nombrePila,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge,
                  ),
                ),
                if (retirado && !cita.estado.esTerminal) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.warning_amber_outlined,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Sin atender',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.sm),
              ],
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
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.primaryText,
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
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!cita.estado.esTerminal) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                botonWhatsApp(
                  context,
                  ref,
                  cita,
                  variant: AppButtonVariant.text,
                ),
                if (domicilio)
                  botonComoLlegar(
                    context,
                    ref,
                    cita,
                    variant: AppButtonVariant.text,
                  ),
                ControlEscritura(
                  puedeEscribir: puede,
                  label: 'Completar',
                  onTap: () => irSiPuedeEscribir(
                    context,
                    ref,
                    '/agenda/${cita.id}/completar',
                  ),
                  child: AppButton(
                    label: 'Completar',
                    variant: AppButtonVariant.outline,
                    icon: iconoEscritura(puede, Icons.task_alt_outlined),
                    expand: false,
                    onPressed: () => irSiPuedeEscribir(
                      context,
                      ref,
                      '/agenda/${cita.id}/completar',
                    ),
                  ),
                ),
                if (cita.estado == EstadoCita.pendiente)
                  ControlEscritura(
                    puedeEscribir: puede,
                    label: 'Confirmar',
                    onTap: () => _confirmar(context, ref),
                    child: AppButton(
                      label: 'Confirmar',
                      variant: AppButtonVariant.text,
                      icon: iconoEscritura(puede, Icons.check_circle_outline),
                      expand: false,
                      onPressed: () => _confirmar(context, ref),
                    ),
                  ),
                IconButton(
                  tooltip: 'Más acciones',
                  icon: const Icon(Icons.more_vert),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => mostrarMasAcciones(context, ref, cita),
                ),
              ],
            ),
            ?avisoWhatsApp(context, cita),
          ],
        ],
      ),
    );

    if (!marcarVet) return tarjeta;
    // Franja izquierda de 4px: AppCard no admite decoración lateral.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Stack(
        children: [
          tarjeta,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: IgnorePointer(
              child: ColoredBox(
                color: retirado ? AppColors.border : VetAvatar.colorDe(indice),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
