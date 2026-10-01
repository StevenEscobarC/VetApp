import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/lanzador_externo.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/cita_failure.dart';
import '../../domain/entities/cita.dart';
import '../../domain/whatsapp_recordatorio.dart';
import '../providers/citas_providers.dart';

/// Hoja "Recordar a los de mañana" (D-15): recorre a los clientes de uno en
/// uno. Abre WhatsApp para el actual y, cuando la app vuelve a primer plano
/// (paused/hidden -> resumed mientras se espera), lo marca como enviado y pasa
/// al siguiente. "Marcar como enviado" es el respaldo manual si la detección
/// falla.
class RecordarMananaSheet extends ConsumerStatefulWidget {
  const RecordarMananaSheet({super.key, required this.citas});

  final List<Cita> citas;

  @override
  ConsumerState<RecordarMananaSheet> createState() =>
      _RecordarMananaSheetState();
}

class _RecordarMananaSheetState extends ConsumerState<RecordarMananaSheet>
    with WidgetsBindingObserver {
  late final List<Cita> _citas;
  late final Set<String> _enviados;
  int _marcadosEnSesion = 0;
  bool _esperandoRetorno = false;
  bool _vioPausa = false;

  @override
  void initState() {
    super.initState();
    _citas = [...widget.citas]
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    _enviados = {
      for (final c in _citas)
        if (c.recordatorioEnviadoAt != null) c.id,
    };
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _habilitada(Cita c) =>
      estadoWhatsApp(c.clienteTelefono ?? '').habilitado;

  Cita? get _actual {
    for (final c in _citas) {
      if (!_enviados.contains(c.id) && _habilitada(c)) return c;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_esperandoRetorno) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _vioPausa = true;
    } else if (state == AppLifecycleState.resumed && _vioPausa) {
      final actual = _actual;
      _esperandoRetorno = false;
      _vioPausa = false;
      if (actual != null) _marcar(actual);
    }
  }

  Future<void> _marcar(Cita cita) async {
    final actions = ref.read(citaActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final ahora = ref.read(clockProvider)();
    try {
      await actions.marcarRecordatorioEnviado(cita.id, ahora);
    } on CitaFailure catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _enviados.add(cita.id);
      _marcadosEnSesion++;
    });
  }

  Future<void> _enviar(Cita cita) async {
    final messenger = ScaffoldMessenger.of(context);
    final lanzador = ref.read(lanzadorExternoProvider);
    final profile = ref.read(authProfileProvider).asData?.value;
    final numero = numeroWhatsApp(cita.clienteTelefono ?? '');
    if (numero == null) return;
    final mensaje = mensajeRecordatorio(
      cita: cita,
      veterinario: profile?.nombre ?? '',
      clinica: profile?.clinicaNombre,
    );
    _esperandoRetorno = true;
    _vioPausa = false;
    final ok = await lanzador.abrir(whatsappUri(numero, mensaje));
    if (!ok) {
      _esperandoRetorno = false;
      _vioPausa = false;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No pudimos abrir WhatsApp. ¿Está instalado?'),
          ),
        );
    }
  }

  String _estadoFila(Cita c) {
    if (_enviados.contains(c.id)) return 'Enviado';
    if (!_habilitada(c)) return 'Sin WhatsApp';
    return 'Pendiente de enviar';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actual = _actual;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recordar a los de mañana', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Vamos de uno en uno: abre WhatsApp, envía el mensaje y '
              'vuelve aquí.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final c in _citas)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.clienteNombre} · '
                            '${hora12(aBogota(c.fechaHora))}',
                            style: textTheme.bodyLarge,
                          ),
                          Text(
                            c.nombresMascotas,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _estadoFila(c),
                      style: textTheme.labelLarge?.copyWith(
                        color: _enviados.contains(c.id)
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (actual != null) ...[
              AppButton(
                label: 'Enviar a ${actual.clienteNombre}',
                icon: Icons.chat_outlined,
                onPressed: () => _enviar(actual),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Marcar como enviado',
                variant: AppButtonVariant.text,
                onPressed: () => _marcar(actual),
              ),
              AppButton(
                label: 'Cerrar',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else ...[
              Text(
                _marcadosEnSesion == 0
                    ? 'No hay recordatorios pendientes por enviar.'
                    : _marcadosEnSesion == 1
                    ? 'Listo, recordaste a 1 cliente.'
                    : 'Listo, recordaste a $_marcadosEnSesion clientes.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Cerrar',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
