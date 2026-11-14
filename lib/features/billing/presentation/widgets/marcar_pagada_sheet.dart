import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../domain/cobro_failure.dart';
import '../../domain/entities/cobro.dart';
import '../providers/cobros_providers.dart';

/// Hoja "Marcar como pagada" (UI-SPEC §4.1, D-15): pide solo el método,
/// sin preselección para no guardar un método equivocado, y la fecha (hoy
/// por defecto). No hay Deshacer: una cuenta pagada vuelve atrás solo
/// anulándola.
Future<void> showMarcarPagadaSheet(BuildContext context, Cobro cobro) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MarcarPagadaSheet(cobro: cobro, messenger: messenger),
  );
}

class _MarcarPagadaSheet extends ConsumerStatefulWidget {
  const _MarcarPagadaSheet({required this.cobro, required this.messenger});

  final Cobro cobro;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_MarcarPagadaSheet> createState() => _MarcarPagadaSheetState();
}

class _MarcarPagadaSheetState extends ConsumerState<_MarcarPagadaSheet> {
  MetodoPago? _metodo;

  /// `null` = hoy (el servidor usa su fecha de Bogotá).
  DateTime? _fecha;
  bool _guardando = false;
  bool _cambio = false;
  String? _error;

  DateTime get _hoy => diaBogota(ref.read(clockProvider)());

  Future<void> _cambiarFecha() async {
    final hoy = _hoy;
    final f = widget.cobro.fecha;
    var desde = DateTime(f.year, f.month, f.day);
    final hasta = DateTime(hoy.year, hoy.month, hoy.day);
    if (desde.isAfter(hasta)) desde = hasta;
    final actual = _fecha ?? hoy;
    final elegida = await showDatePicker(
      context: context,
      firstDate: desde,
      lastDate: hasta,
      initialDate: DateTime(actual.year, actual.month, actual.day),
    );
    if (elegida == null || !mounted) return;
    final dia = DateTime.utc(elegida.year, elegida.month, elegida.day);
    setState(() => _fecha = dia == hoy ? null : dia);
  }

  Future<void> _confirmar() async {
    final metodo = _metodo;
    if (metodo == null || _guardando || _cambio) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final cobro = widget.cobro;
    try {
      await ref
          .read(cobrosActionsProvider)
          .marcarPagado(cobro: cobro, metodo: metodo, fecha: _fecha);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${cobro.numeroTexto} marcada como pagada.')),
        );
    } on CobroFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      if (await manejarLimitePlan(context, ref, e)) return;
      if (!mounted) return;
      setState(() {
        switch (e.tipo) {
          case ErrorCobro.sinConexion:
            _error =
                'Sin conexión, el pago no se guardó. Inténtalo de nuevo '
                'cuando tengas señal.';
          case ErrorCobro.estadoInvalido:
            _cambio = true;
            _error =
                'Esta cuenta de cobro cambió. Actualiza para ver su estado.';
          default:
            _error = 'No pudimos guardar el pago. Intenta de nuevo.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = widget.cobro;
    final hoy = diaBogota(ref.watch(clockProvider)());
    final fecha = _fecha;
    final fechaTexto = fecha == null
        ? 'Hoy, ${formatearFecha(hoy)}'
        : formatearFecha(fecha);
    final listo = _metodo != null && !_cambio;
    final muted = t.labelLarge?.copyWith(color: AppColors.textMuted);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Marcar como pagada', style: t.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${c.numeroTexto} · ${formatearCop(c.totalCop)}',
              style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Método de pago', style: t.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in MetodoPago.values)
                  AppFilterChip(
                    label: m.etiqueta,
                    selected: _metodo == m,
                    onTap: () => setState(() => _metodo = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: Row(
                children: [
                  Text('Fecha de pago', style: t.labelLarge),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(fechaTexto, style: t.bodyLarge)),
                  TextButton(
                    onPressed: _guardando ? null : _cambiarFecha,
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: t.labelLarge?.copyWith(color: AppColors.destructive),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Confirmar pago',
              isLoading: _guardando,
              onPressed: listo ? _confirmar : null,
            ),
            if (_metodo == null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Elige cómo pagó.', style: muted),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
