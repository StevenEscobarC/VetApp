import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/lanzador_externo.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../appointments/domain/whatsapp_recordatorio.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clients/presentation/providers/clientes_providers.dart';
import '../../data/services/cobro_pdf_service.dart';
import '../../domain/cobro_failure.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/whatsapp_cobro.dart';
import '../providers/cobro_pdf_providers.dart';
import '../providers/cobros_providers.dart';

/// Hoja "Enviar al cliente" (UI-SPEC §4.3, D-16): PDF por WhatsApp con el
/// mensaje formal, chat de WhatsApp al +57 del cliente y menú nativo con el
/// PDF solo. No publica nada en la web y nunca se bloquea por el plan:
/// compartir no es una escritura.
Future<void> showEnviarCobroSheet(BuildContext context, Cobro cobro) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EnviarCobroSheet(cobro: cobro),
  );
}

enum _Accion { pdfWhatsApp, chat, compartir }

class _EnviarCobroSheet extends ConsumerStatefulWidget {
  const _EnviarCobroSheet({required this.cobro});

  final Cobro cobro;

  @override
  ConsumerState<_EnviarCobroSheet> createState() => _EnviarCobroSheetState();
}

class _EnviarCobroSheetState extends ConsumerState<_EnviarCobroSheet> {
  _Accion? _ocupado;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  String _mensaje(Cobro c, ClinicaCobroPdf clinica) {
    final perfil = ref.read(authProfileProvider).asData?.value;
    return mensajeCobroWhatsApp(
      cliente: c.clienteNombre,
      numero: c.numeroTexto,
      totalCop: c.totalCop,
      clinica: clinica.nombre,
      veterinario: perfil?.nombre ?? '',
      mascota: c.mascotaNombre,
      esCotizacion: c.esCotizacion,
      pagada: c.pagada,
      validaHasta: c.validaHasta,
    );
  }

  /// Marca la acción en curso; `false` si ya hay otra (toques repetidos).
  bool _empezar(_Accion a) {
    if (_ocupado != null) return false;
    setState(() => _ocupado = a);
    return true;
  }

  void _terminar() {
    if (mounted) setState(() => _ocupado = null);
  }

  /// Datos del PDF sin un error viejo en caché: si la carga anterior falló
  /// (p. ej. sin red), el toque vuelve a pedirlos (WR-05).
  Future<({Cobro cobro, ClinicaCobroPdf clinica})> _datos() {
    final p = datosPdfCobroProvider(widget.cobro.id);
    if (ref.read(p).hasError) ref.invalidate(p);
    return ref.read(p.future);
  }

  /// Tras un fallo el error no se queda en caché: el próximo intento relee.
  void _olvidarError() =>
      ref.invalidate(datosPdfCobroProvider(widget.cobro.id));

  Future<void> _compartirPdf({required bool conMensaje}) async {
    if (!_empezar(conMensaje ? _Accion.pdfWhatsApp : _Accion.compartir)) {
      return;
    }
    try {
      final datos = await _datos();
      final bytes = await ref
          .read(cobroPdfServiceProvider)
          .generar(
            cobro: datos.cobro,
            clinica: datos.clinica,
            generadoEn: ref.read(clockProvider)(),
          );
      await ref.read(compartirCobroProvider)(
        bytes: bytes,
        filename: CobroPdfService.nombreArchivo(datos.cobro),
        texto: conMensaje ? _mensaje(datos.cobro, datos.clinica) : null,
      );
    } on CobroFailure catch (e) {
      if (!mounted) return;
      if (e.tipo == ErrorCobro.sinConexion) _olvidarError();
      _aviso(e.message);
    } finally {
      _terminar();
    }
  }

  Future<void> _chat(String numero) async {
    if (!_empezar(_Accion.chat)) return;
    try {
      final datos = await _datos();
      final ok = await ref
          .read(lanzadorExternoProvider)
          .abrirEnApp(
            whatsappUri(numero, _mensaje(datos.cobro, datos.clinica)),
          );
      if (!ok && mounted) {
        _aviso('No pudimos abrir WhatsApp. Usa «Compartir PDF».');
      }
    } on CobroFailure catch (e) {
      if (!mounted) return;
      final sinRed = e.tipo == ErrorCobro.sinConexion;
      if (sinRed) _olvidarError();
      _aviso(
        sinRed ? e.message : 'No pudimos abrir WhatsApp. Usa «Compartir PDF».',
      );
    } finally {
      _terminar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = widget.cobro;
    // Precarga los datos del documento mientras la hoja está abierta.
    ref.watch(datosPdfCobroProvider(c.id));
    // Firma del mensaje: se observa para tenerla lista al tocar.
    ref.watch(authProfileProvider);
    final clienteId = c.clienteId;
    final telefono = clienteId == null
        ? null
        : ref.watch(clienteProvider(clienteId)).asData?.value.telefono;
    final numero = telefono == null ? null : numeroWhatsApp(telefono);
    final formateado = numero == null
        ? null
        : normalizarTelefono(telefono!).formateado;
    final estadoChat = telefono == null ? null : estadoWhatsApp(telefono);
    final chatHabilitado = estadoChat?.habilitado == true && numero != null;

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
            Text('Enviar ${c.numeroTexto}', style: t.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Para ${c.clienteNombre}',
              style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            _Fila(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Enviar PDF por WhatsApp',
              detalle: _ocupado == _Accion.pdfWhatsApp
                  ? 'Generando PDF…'
                  : formateado == null
                  ? 'Elige WhatsApp y el chat de ${c.clienteNombre}'
                  : 'Elige WhatsApp y el chat de ${c.clienteNombre} '
                        '($formateado)',
              cargando: _ocupado == _Accion.pdfWhatsApp,
              onTap: () => _compartirPdf(conMensaje: true),
            ),
            if (clienteId != null)
              _Fila(
                icon: Icons.chat_outlined,
                label: 'Abrir chat de WhatsApp',
                detalle: chatHabilitado ? formateado : estadoChat?.motivo,
                cargando: _ocupado == _Accion.chat,
                onTap: chatHabilitado ? () => _chat(numero) : null,
              ),
            _Fila(
              icon: Icons.ios_share,
              label: 'Compartir PDF',
              detalle: _ocupado == _Accion.compartir ? 'Generando PDF…' : null,
              cargando: _ocupado == _Accion.compartir,
              onTap: () => _compartirPdf(conMensaje: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de la hoja (56dp). Deshabilitada cambia de color, nunca de opacidad.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.icon,
    required this.label,
    this.detalle,
    this.onTap,
    this.cargando = false,
  });

  final IconData icon;
  final String label;
  final String? detalle;
  final VoidCallback? onTap;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final habilitada = onTap != null;
    final color = habilitada ? AppColors.foreground : AppColors.textMuted;
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
                    Text(label, style: t.bodyLarge?.copyWith(color: color)),
                    if (detalle != null)
                      Text(
                        detalle!,
                        style: t.labelLarge?.copyWith(
                          color: AppColors.textMuted,
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
              else
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
