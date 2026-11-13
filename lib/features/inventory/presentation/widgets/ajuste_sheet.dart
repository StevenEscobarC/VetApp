import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../domain/entities/movimiento_stock.dart';
import '../../domain/entities/producto.dart';
import '../../domain/inventario_failure.dart';
import '../../domain/stock.dart';
import '../providers/inventario_providers.dart';
import 'ajuste_stock.dart';

/// Abre la hoja "Ajustar stock" (UI-SPEC §3). El mensajero se captura antes
/// de abrirla para poder mostrar el resultado cuando la hoja ya se cerró.
Future<void> mostrarAjusteSheet(
  BuildContext context, {
  required Producto producto,
  required MotivoMovimiento motivoInicial,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (_) => AjusteSheet(
      producto: producto,
      motivoInicial: motivoInicial,
      messenger: messenger,
    ),
  );
}

/// Ajuste manual de cantidad con motivo. El `delta` se calcula aquí solo para
/// enviarlo; la cantidad mostrada después es la que devuelve el servidor.
class AjusteSheet extends ConsumerStatefulWidget {
  const AjusteSheet({
    super.key,
    required this.producto,
    required this.motivoInicial,
    required this.messenger,
  });

  final Producto producto;
  final MotivoMovimiento motivoInicial;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<AjusteSheet> createState() => _AjusteSheetState();
}

class _AjusteSheetState extends ConsumerState<AjusteSheet> {
  final _ctrl = TextEditingController();
  late MotivoMovimiento _motivo = widget.motivoInicial;
  bool _tocado = false;
  bool _guardando = false;
  bool _noDisponible = false;
  String? _errorServidor;

  Producto get _p => widget.producto;

  @override
  void initState() {
    super.initState();
    if (_motivo == MotivoMovimiento.conteo) _precargarConteo();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _precargarConteo() {
    final t = '${_p.cantidad}';
    _ctrl.value = TextEditingValue(
      text: t,
      selection: TextSelection(baseOffset: 0, extentOffset: t.length),
    );
  }

  void _elegirMotivo(MotivoMovimiento m) {
    if (_guardando || m == _motivo) return;
    setState(() {
      _motivo = m;
      _tocado = false;
      _errorServidor = null;
      if (m == MotivoMovimiento.conteo) {
        _precargarConteo();
      } else {
        _ctrl.clear();
      }
    });
  }

  bool get _esConteo => _motivo == MotivoMovimiento.conteo;

  int? get _n => _ctrl.text.isEmpty ? null : int.tryParse(_ctrl.text);

  String get _etiquetaCampo => switch (_motivo) {
    MotivoMovimiento.compra => 'Cantidad que entra',
    MotivoMovimiento.conteo => 'Cantidad contada',
    _ => 'Cantidad que sale',
  };

  /// Mensaje de validación, o `null` si la cantidad es aplicable (o aún no se
  /// ha escrito nada).
  String? get _errorValidacion {
    final n = _n;
    if (n == null) {
      return !_esConteo && _tocado ? 'Escribe una cantidad mayor que 0.' : null;
    }
    if (n > kCantidadMaxima) return 'La cantidad máxima es 1.000.000.';
    if (_esConteo) {
      return n == _p.cantidad ? 'Es la misma cantidad que hay ahora.' : null;
    }
    if (n == 0) return 'Escribe una cantidad mayor que 0.';
    if (_motivo != MotivoMovimiento.compra && n > _p.cantidad) {
      return 'No puedes dejar el stock por debajo de 0.';
    }
    return null;
  }

  bool get _valido => _n != null && _errorValidacion == null;

  /// Cambio de stock a enviar al servidor.
  int get _delta {
    final n = _n ?? 0;
    return switch (_motivo) {
      MotivoMovimiento.compra => n,
      MotivoMovimiento.conteo => n - _p.cantidad,
      _ => -n,
    };
  }

  /// Vista previa de cortesía ("Quedarán m"); la autoridad es el servidor.
  int get _quedarian => _esConteo ? (_n ?? 0) : _p.cantidad + _delta;

  void _paso(int d) {
    if (_guardando) return;
    final nuevo = ((_n ?? 0) + d).clamp(0, kCantidadMaxima);
    setState(() {
      _tocado = true;
      _errorServidor = null;
      _ctrl.text = '$nuevo';
    });
  }

  Future<void> _aplicar() async {
    if (_guardando || _noDisponible || !_valido) return;
    final delta = _delta;
    final motivo = _motivo;
    final producto = _p;
    if (delta.abs() > kAjusteGrande) {
      final ok = await confirmarAjusteGrande(
        context,
        producto: producto,
        delta: delta,
        cantidadNueva: _quedarian,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _guardando = true;
      _errorServidor = null;
    });
    final actions = ref.read(inventarioActionsProvider);
    try {
      final r = await actions.ajustar(
        producto: producto,
        delta: delta,
        motivo: motivo,
      );
      if (mounted) Navigator.of(context).pop();
      mostrarResultadoAjuste(
        widget.messenger,
        actions,
        producto: producto,
        delta: delta,
        motivo: motivo,
        resultado: r,
      );
    } on InventarioFailure catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      if (await manejarLimitePlan(context, ref, e)) return;
      if (!mounted) return;
      setState(() {
        _errorServidor = textoErrorEnHoja(e);
        if (e.tipo == ErrorInventario.noDisponible) _noDisponible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = _p;
    final error = _errorServidor ?? _errorValidacion;
    final puedeAplicar = _valido && !_noDisponible;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ajustar stock', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${p.nombre} · hay ${formatearMiles(p.cantidad)} '
                    '${p.unidad.etiqueta(p.cantidad)}',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Motivo', style: textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final m in MotivoMovimiento.ajustables)
                        AppFilterChip(
                          label: m.etiqueta,
                          selected: _motivo == m,
                          onTap: () => _elegirMotivo(m),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Paso(
                        icono: Icons.remove,
                        tooltip: 'Quitar 1',
                        onPressed: _guardando ? null : () => _paso(-1),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          label: _etiquetaCampo,
                          controller: _ctrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 7,
                          textAlign: TextAlign.center,
                          autofocus: true,
                          enabled: !_guardando,
                          onChanged: (_) => setState(() {
                            _tocado = true;
                            _errorServidor = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _Paso(
                        icono: Icons.add,
                        tooltip: 'Sumar 1',
                        onPressed: _guardando ? null : () => _paso(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (error != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 20,
                          color: AppColors.destructive,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            error,
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.destructive,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_valido)
                    Text(
                      'Quedarán ${formatearMiles(_quedarian)} '
                      '${p.unidad.etiqueta(_quedarian)}',
                      style: textTheme.labelLarge,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Aplicar ajuste',
            isLoading: _guardando,
            onPressed: puedeAplicar ? _aplicar : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.text,
            onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.icono,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: IconButton.outlined(
      icon: Icon(icono),
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
      ),
      onPressed: onPressed,
    ),
  );
}
