import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/dosis_estado_chip.dart';
import '../../../appointments/presentation/agenda_routes.dart';
import '../../../patients/presentation/widgets/mascota_foto_avatar.dart';
import '../../domain/entities/carne.dart';
import '../../domain/entities/protocolo.dart';
import '../../domain/estado_dosis_ui.dart';
import '../providers/alertas_providers.dart';
import '../providers/registrar_dosis_providers.dart';
import '../vacunacion_routes.dart';
import 'descartar_alerta_sheet.dart';
import 'dosis_registrada_snackbar.dart';

String _dias(int n) => '$n ${n == 1 ? 'día' : 'días'}';

/// Fila de alerta (D-12): estado de la dosis y las cuatro acciones rápidas.
/// Toda la tarjeta abre el carné de la mascota.
class PendienteTile extends ConsumerWidget {
  const PendienteTile({super.key, required this.pendiente});

  final PendienteVacuna pendiente;

  PendienteVacuna get _p => pendiente;

  String _vencimiento(DateTime hoy) {
    final fecha = formatearFecha(_p.proximaFecha);
    if (_p.estado == EstadoCarne.vencida) {
      return 'Venció el $fecha · hace ${_dias(_p.diasVencida)}';
    }
    final dif = DateTime.utc(
      _p.proximaFecha.year,
      _p.proximaFecha.month,
      _p.proximaFecha.day,
    ).difference(hoy).inDays;
    if (dif <= 0) return 'Vence hoy';
    return 'Vence el $fecha · en ${_dias(dif)}';
  }

  Future<void> _recordar(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(alertasActionsProvider).recordar(_p);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No pudimos abrir WhatsApp.')),
        );
    }
  }

  void _agendar(BuildContext context) {
    final motivo = switch (_p.tipo) {
      TipoDosis.vacuna => 'Vacunación',
      _ => 'Desparasitación',
    };
    // Ruta de primer nivel: esta fila vive en `/vacunas`, fuera del shell
    // (empujar `/agenda/nueva` desde aquí rompía el Navigator, G5).
    context.push(
      rutaNuevaCita(
        clienteId: _p.clienteId,
        mascotaId: _p.mascotaId,
        motivo: motivo,
      ),
    );
  }

  Future<void> _registrar(BuildContext context, WidgetRef ref) async {
    // El router se toma antes del await: al registrar, la alerta sale de la
    // lista y esta fila se desmonta, así que su `context` ya no sirve para
    // navegar desde el snackbar (QA Fase 5, G7).
    final router = GoRouter.of(context);
    final r = await router.push<DosisRegistrada>(
      rutaRegistrarDosis(mascotaId: _p.mascotaId, codigo: _p.codigoProtocolo),
    );
    // RegistrarDosis ya refresca Inicio y pendientes (invalidarVacunas).
    if (r == null || !context.mounted) return;
    final mascotaId = _p.mascotaId;
    mostrarDosisRegistrada(
      context,
      r,
      onCompartir: () => router.push(rutaCarne(mascotaId, compartir: true)),
    );
  }

  Future<void> _descartar(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(alertasActionsProvider);
    final decision = await mostrarDescartarAlertaSheet(context);
    if (decision == null) return;
    String texto;
    try {
      final dias = decision.dias;
      if (dias != null) {
        final hasta = await actions.posponer(_p, dias);
        texto = 'Alerta pospuesta hasta el ${formatearFecha(hasta)}';
      } else {
        await actions.descartar(_p, decision.motivo ?? 'Otro motivo');
        texto = 'Alerta descartada';
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No pudimos actualizar la alerta. Intenta de nuevo.'),
          ),
        );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => actions.restaurar(_p),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final hoy = diaBogota(ref.watch(clockProvider)());
    final vencida = _p.estado == EstadoCarne.vencida;
    final conTelefono = numeroWhatsApp(_p.clienteTelefono) != null;
    final enviado = _p.recordatorioEnviadoAt;

    return AppCard(
      onTap: () => context.push(rutaCarne(_p.mascotaId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MascotaFotoAvatar(fotoPath: _p.mascotaFotoPath, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_p.mascotaNombre, style: textTheme.bodyLarge),
                    Text(
                      _p.clienteNombre,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              DosisEstadoChip(estado: dosisEstadoDe(_p.estado)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_p.biologicoNombre} · ${_p.etiquetaProxima}',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _vencimiento(hoy),
            style: textTheme.labelMedium?.copyWith(
              color: vencida ? AppColors.destructive : AppColors.textSecondary,
            ),
          ),
          if (enviado != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Recordatorio enviado el ${formatearFecha(aBogota(enviado))}',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'Recordar',
                    icon: Icons.chat_outlined,
                    variant: AppButtonVariant.outline,
                    expand: false,
                    onPressed: conTelefono
                        ? () => _recordar(context, ref)
                        : null,
                  ),
                  if (!conTelefono)
                    Text(
                      'Sin teléfono',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              AppButton(
                label: 'Agendar',
                icon: Icons.event_outlined,
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: () => _agendar(context),
              ),
              AppButton(
                label: 'Registrar',
                icon: Icons.vaccines_outlined,
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: () => _registrar(context, ref),
              ),
              AppButton(
                label: 'Descartar o posponer',
                icon: Icons.snooze,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () => _descartar(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
