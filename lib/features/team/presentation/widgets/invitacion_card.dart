import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/compartir.dart';
import '../../../../core/utils/lanzador_externo.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../domain/codigo_invitacion.dart';
import '../../domain/invitacion.dart';
import '../../domain/team_failure.dart';
import '../providers/team_providers.dart';

/// Código de invitación vigente con su vigencia y las acciones Compartir,
/// Copiar y Revocar (solo el administrador la ve).
class InvitacionCard extends ConsumerWidget {
  const InvitacionCard({
    super.key,
    required this.invitacion,
    required this.clinicaNombre,
  });

  final Invitacion invitacion;
  final String clinicaNombre;

  Future<void> _compartir(BuildContext context, WidgetRef ref) async {
    final mensaje = mensajeInvitacion(
      clinica: clinicaNombre,
      codigo: invitacion.codigo,
      expiraEn: invitacion.expiraEn,
    );
    try {
      await ref.read(compartidorProvider).compartirTexto(mensaje);
    } catch (_) {
      // Sin hoja nativa: WhatsApp. Se usa encodeComponent y no
      // queryParameters, que emitiría '+' por cada espacio.
      await ref
          .read(lanzadorExternoProvider)
          .abrir(
            Uri.parse('https://wa.me/?text=${Uri.encodeComponent(mensaje)}'),
          );
    }
  }

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: formatearCodigoInvitacion(invitacion.codigo)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  Future<void> _revocar(BuildContext context, WidgetRef ref) async {
    final codigo = formatearCodigoInvitacion(invitacion.codigo);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Revocar este código?'),
        content: Text('Nadie podrá usar el código $codigo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          AppButton(
            label: 'Revocar',
            variant: AppButtonVariant.destructive,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(teamActionsProvider).revocarInvitacion(invitacion.id);
      messenger.showSnackBar(const SnackBar(content: Text('Código revocado')));
    } on TeamFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ahora = ref.watch(clockProvider)();
    final restante = invitacion.expiraEn.difference(ahora);
    final porVencer = restante <= const Duration(hours: 6);
    final colorVigencia = porVencer ? AppColors.warning : AppColors.success;
    final codigo = formatearCodigoInvitacion(invitacion.codigo);
    final letras = invitacion.codigo.split('');
    final hablado = '${letras.take(4).join(' ')}, ${letras.skip(4).join(' ')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Código de invitación', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Center(
              child: Semantics(
                label: hablado,
                excludeSemantics: true,
                child: SelectableText(
                  codigo,
                  textAlign: TextAlign.center,
                  style: textTheme.displaySmall?.copyWith(
                    letterSpacing: 2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                porVencer ? Icons.warning_amber_outlined : Icons.schedule,
                size: 16,
                color: colorVigencia,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  textoVigenciaInvitacion(invitacion.expiraEn, ahora),
                  textAlign: TextAlign.center,
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Compartir código',
                  icon: Icons.share_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: () => _compartir(context, ref),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Copiar código',
                  icon: Icons.content_copy_outlined,
                  variant: AppButtonVariant.outline,
                  onPressed: () => _copiar(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Revocar código',
            variant: AppButtonVariant.destructive,
            onPressed: () => _revocar(context, ref),
          ),
        ],
      ),
    );
  }
}
