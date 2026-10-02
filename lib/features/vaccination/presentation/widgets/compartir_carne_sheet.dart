import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/carne_config.dart';
import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/compartir.dart';
import '../../../../core/utils/lanzador_externo.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../appointments/domain/whatsapp_recordatorio.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinical_history/domain/consulta_failure.dart';
import '../../../clinical_history/presentation/providers/historia_clinica_pdf_providers.dart';
import '../../data/services/carne_pdf_service.dart';
import '../../domain/entities/carne.dart';
import '../../domain/vacuna_failure.dart';
import '../../domain/whatsapp_vacunas.dart';
import '../providers/carne_pdf_providers.dart';
import '../providers/enlace_carne_providers.dart';
import '../providers/vacuna_providers.dart';

/// Hoja "Compartir carné" (D-16, D-17): enlace permanente y revocable por
/// WhatsApp (solo app), menú nativo, PDF y copia. El enlace se crea de forma
/// perezosa la primera vez que se abre.
Future<void> showCompartirCarneSheet(
  BuildContext context, {
  required String mascotaId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CompartirCarneSheet(mascotaId: mascotaId),
  );
}

class _CompartirCarneSheet extends ConsumerStatefulWidget {
  const _CompartirCarneSheet({required this.mascotaId});

  final String mascotaId;

  @override
  ConsumerState<_CompartirCarneSheet> createState() =>
      _CompartirCarneSheetState();
}

class _CompartirCarneSheetState extends ConsumerState<_CompartirCarneSheet> {
  bool _generando = false;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  String _linkCorto(String token) {
    final host = Uri.parse(kCarneBaseUrl).host;
    final cola = token.length <= 4 ? token : token.substring(token.length - 4);
    return '$host/…$cola';
  }

  Future<void> _whatsapp(Carne carne, String token) async {
    final numero = numeroWhatsApp(carne.duenoTelefono);
    if (numero == null) return;
    final profile = ref.read(authProfileProvider).asData?.value;
    final mensaje = mensajeCarneWhatsApp(
      dueno: carne.duenoNombre,
      mascota: carne.mascotaNombre,
      url: urlCarne(token),
      veterinario: firmaVeterinario(profile?.nombre ?? ''),
      clinica: carne.clinicaNombre,
    );
    final ok = await ref
        .read(lanzadorExternoProvider)
        .abrirEnApp(whatsappUri(numero, mensaje));
    if (!ok && mounted) _aviso('No pudimos abrir WhatsApp.');
  }

  Future<void> _compartir(Carne carne, String token) async {
    try {
      await ref
          .read(compartidorProvider)
          .compartirTexto(
            mensajeCompartirCarne(
              mascota: carne.mascotaNombre,
              url: urlCarne(token),
            ),
          );
    } catch (_) {
      if (mounted) _aviso('No pudimos abrir el menú de compartir.');
    }
  }

  Future<void> _pdf(Carne carne) async {
    if (_generando) return;
    setState(() => _generando = true);
    try {
      final ahora = ref.read(clockProvider)();
      final bytes = await ref
          .read(carnePdfServiceProvider)
          .generar(carne: carne, generadoEn: ahora);
      await ref.read(compartirPdfProvider)(
        bytes: bytes,
        filename: CarnePdfService.nombreArchivo(
          carne.mascotaNombre,
          aBogota(ahora),
        ),
      );
    } on VacunaFailure catch (e) {
      if (mounted) _aviso(e.message);
    } on ConsultaFailure catch (e) {
      if (mounted) _aviso(e.message);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _copiar(String token) async {
    await Clipboard.setData(ClipboardData(text: urlCarne(token)));
    if (mounted) _aviso('Enlace copiado');
  }

  Future<void> _regenerar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Regenerar el enlace del carné?'),
        content: const Text(
          'El enlace anterior dejará de funcionar. Quien lo tenga verá un '
          'aviso de enlace no válido. Deberá compartir el nuevo.',
        ),
        actions: [
          AppButton(
            label: 'Volver',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: 'Regenerar',
            variant: AppButtonVariant.destructive,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(regenerarEnlaceCarneProvider)(widget.mascotaId);
      if (mounted) _aviso('Enlace regenerado');
    } on VacunaFailure catch (e) {
      if (mounted) _aviso(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final carneAsync = ref.watch(carneProvider(widget.mascotaId));
    final enlaceAsync = ref.watch(enlaceCarneProvider(widget.mascotaId));
    final carne = carneAsync.asData?.value;
    final token = enlaceAsync.asData?.value;
    final listo = carne != null && token != null;
    final numero = carne == null ? null : numeroWhatsApp(carne.duenoTelefono);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compartir carné de ${carne?.mascotaNombre ?? ''}'.trim(),
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            _lineaEnlace(textTheme, enlaceAsync, carneAsync),
            const SizedBox(height: AppSpacing.md),
            _Fila(
              icon: Icons.chat_outlined,
              label: 'Enviar por WhatsApp al dueño',
              detalle: carne == null
                  ? null
                  : numero == null
                  ? 'Sin teléfono registrado'
                  : 'Dueño: ${carne.duenoNombre} · '
                        '${normalizarTelefono(carne.duenoTelefono).formateado}',
              onTap: listo && numero != null
                  ? () => _whatsapp(carne, token)
                  : null,
            ),
            _Fila(
              icon: Icons.share_outlined,
              label: 'Compartir enlace',
              onTap: listo ? () => _compartir(carne, token) : null,
            ),
            _Fila(
              icon: Icons.picture_as_pdf_outlined,
              label: _generando ? 'Generando PDF...' : 'Descargar PDF',
              cargando: _generando,
              onTap: carne != null && !_generando ? () => _pdf(carne) : null,
            ),
            _Fila(
              icon: Icons.content_copy_outlined,
              label: 'Copiar enlace',
              onTap: listo ? () => _copiar(token) : null,
            ),
            const Divider(height: AppSpacing.lg),
            _Fila(
              icon: Icons.link_off_outlined,
              label: 'Regenerar enlace',
              detalle: 'El enlace anterior dejará de funcionar',
              destructiva: true,
              onTap: listo ? _regenerar : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineaEnlace(
    TextTheme textTheme,
    AsyncValue<String> enlace,
    AsyncValue<Carne> carne,
  ) {
    if (enlace.hasError) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'No pudimos crear el enlace. Intenta de nuevo.',
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ),
          AppButton(
            label: 'Reintentar',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () =>
                ref.invalidate(enlaceCarneProvider(widget.mascotaId)),
          ),
        ],
      );
    }
    final token = enlace.asData?.value;
    if (token == null) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Creando enlace...',
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _linkCorto(token),
          style: textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          'Quien tenga el enlace podrá ver el carné.',
          style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icon,
    required this.label,
    this.detalle,
    this.onTap,
    this.destructiva = false,
    this.cargando = false,
  });

  final IconData icon;
  final String label;
  final String? detalle;
  final VoidCallback? onTap;
  final bool destructiva;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final habilitada = onTap != null || cargando;
    final color = !habilitada
        ? AppColors.textMuted
        : destructiva
        ? AppColors.destructive
        : AppColors.foreground;
    return Semantics(
      enabled: habilitada,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodyLarge?.copyWith(color: color),
                    ),
                    if (detalle != null)
                      Text(
                        detalle!,
                        style: textTheme.labelLarge?.copyWith(
                          color: habilitada
                              ? AppColors.textSecondary
                              : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (cargando)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!destructiva)
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
