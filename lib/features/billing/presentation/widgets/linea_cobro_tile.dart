import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/entities/cobro_item.dart';
import '../providers/borrador_cobro_provider.dart';

/// Línea editable del formulario de cobro (UI-SPEC §3): descripción (campo en
/// las líneas "Otro"), pasos de cantidad, precio unitario y subtotal. El
/// precio base solo se informa ("Precio base $ 50.000"): cambiar el precio
/// de la línea nunca cambia la tarifa (D-07). [notaStock] y [errorStock] los
/// llena 07-11 para las líneas de producto.
class LineaCobroTile extends StatefulWidget {
  const LineaCobroTile({
    super.key,
    required this.linea,
    required this.onCantidad,
    required this.onPrecio,
    required this.onDescripcion,
    required this.onQuitar,
    this.habilitado = true,
    this.autofocusDescripcion = false,
    this.cantidadMaxima = 999,
    this.errorDescripcion,
    this.errorPrecio,
    this.notaStock,
    this.errorStock,
  });

  final LineaBorrador linea;
  final ValueChanged<int> onCantidad;
  final ValueChanged<int?> onPrecio;
  final ValueChanged<String> onDescripcion;
  final VoidCallback onQuitar;
  final bool habilitado;
  final bool autofocusDescripcion;
  final int cantidadMaxima;
  final String? errorDescripcion;
  final String? errorPrecio;
  final String? notaStock;
  final String? errorStock;

  @override
  State<LineaCobroTile> createState() => _LineaCobroTileState();
}

class _LineaCobroTileState extends State<LineaCobroTile> {
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _descripcionCtrl;
  final _cantidadFocus = FocusNode();
  final _precioFocus = FocusNode();
  String? _errorPrecioLocal;

  LineaBorrador get _l => widget.linea;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl = TextEditingController(text: '${_l.cantidad}');
    final p = _l.precioUnitarioCop;
    _precioCtrl = TextEditingController(
      text: p == null ? '' : formatearMiles(p),
    );
    _descripcionCtrl = TextEditingController(text: _l.descripcion);
    _cantidadFocus.addListener(_alCambiarFocoCantidad);
    _precioFocus.addListener(_alCambiarFocoPrecio);
  }

  @override
  void didUpdateWidget(LineaCobroTile old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_cantidadCtrl.text) != _l.cantidad &&
        !_cantidadFocus.hasFocus) {
      _cantidadCtrl.text = '${_l.cantidad}';
    } else if (_cantidadFocus.hasFocus &&
        old.linea.cantidad != _l.cantidad &&
        int.tryParse(_cantidadCtrl.text) != _l.cantidad) {
      // Cambió por los botones mientras el campo tenía foco.
      _cantidadCtrl.text = '${_l.cantidad}';
    }
    if (!_precioFocus.hasFocus &&
        parsearCop(_precioCtrl.text).valor != _l.precioUnitarioCop &&
        _errorPrecioLocal == null) {
      final p = _l.precioUnitarioCop;
      _precioCtrl.text = p == null ? '' : formatearMiles(p);
    }
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _descripcionCtrl.dispose();
    _cantidadFocus.dispose();
    _precioFocus.dispose();
    super.dispose();
  }

  void _seleccionarTodo(TextEditingController c) =>
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);

  void _alCambiarFocoCantidad() {
    if (_cantidadFocus.hasFocus) {
      _seleccionarTodo(_cantidadCtrl);
    } else if (int.tryParse(_cantidadCtrl.text) != _l.cantidad) {
      _cantidadCtrl.text = '${_l.cantidad}';
    }
  }

  void _alCambiarFocoPrecio() {
    if (_precioFocus.hasFocus) {
      _seleccionarTodo(_precioCtrl);
      return;
    }
    final r = parsearCop(_precioCtrl.text);
    final v = r.valor;
    if (r.error == null && v != null) _precioCtrl.text = formatearMiles(v);
  }

  void _cantidadEscrita(String texto) {
    final n = int.tryParse(texto);
    if (n == null) return;
    final ajustada = n > widget.cantidadMaxima ? widget.cantidadMaxima : n;
    widget.onCantidad(ajustada < 1 ? 1 : ajustada);
  }

  void _precioEscrito(String texto) {
    final r = parsearCop(texto);
    setState(() => _errorPrecioLocal = r.error);
    widget.onPrecio(r.error == null ? r.valor : null);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final desc = _l.descripcion.trim().isEmpty ? 'Otro' : _l.descripcion;
    final habilitado = widget.habilitado;
    final base = _l.precioBaseCop;
    final precio = _l.precioUnitarioCop;
    final esOtro = _l.tipo == TipoLinea.otro;
    final puedeMenos = habilitado && _l.cantidad > 1;
    final puedeMas = habilitado && _l.cantidad < widget.cantidadMaxima;

    return Semantics(
      container: true,
      label:
          '$desc, ${_l.cantidad} por ${formatearMiles(precio ?? 0)} pesos, '
          'subtotal ${formatearMiles(_l.subtotalCop)} pesos',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: esOtro
                      ? AppTextField(
                          key: ValueKey('descripcion-${_l.key}'),
                          label: 'Descripción',
                          hintText: 'Ej. Baño medicado',
                          controller: _descripcionCtrl,
                          maxLength: 80,
                          autofocus: widget.autofocusDescripcion,
                          enabled: habilitado,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          errorText: widget.errorDescripcion,
                          onChanged: widget.onDescripcion,
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            _l.descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyLarge,
                          ),
                        ),
                ),
                Semantics(
                  button: true,
                  enabled: habilitado,
                  label: 'Quitar $desc',
                  excludeSemantics: true,
                  onTap: habilitado ? widget.onQuitar : null,
                  child: IconButton(
                    onPressed: habilitado ? widget.onQuitar : null,
                    icon: const Icon(Icons.close),
                    color: AppColors.foreground,
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.touchTarget,
                      minHeight: AppSpacing.touchTarget,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.notaStock != null)
              Text(
                widget.notaStock!,
                style: t.labelLarge?.copyWith(color: AppColors.textMuted),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cantidad', style: t.labelLarge),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BotonPaso(
                          icono: Icons.remove,
                          etiqueta: 'Disminuir cantidad de $desc',
                          onTap: puedeMenos
                              ? () => widget.onCantidad(_l.cantidad - 1)
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        SizedBox(
                          width: 64,
                          child: AppTextField(
                            key: ValueKey('cantidad-${_l.key}'),
                            label: 'Cantidad de $desc',
                            hideLabel: true,
                            controller: _cantidadCtrl,
                            focusNode: _cantidadFocus,
                            enabled: habilitado,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 3,
                            onChanged: _cantidadEscrita,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _BotonPaso(
                          icono: Icons.add,
                          etiqueta: 'Aumentar cantidad de $desc',
                          onTap: puedeMas
                              ? () => widget.onCantidad(_l.cantidad + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl + AppSpacing.sm,
                  ),
                  child: Text('×', style: t.labelLarge),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    key: ValueKey('precio-${_l.key}'),
                    label: 'Precio unitario',
                    controller: _precioCtrl,
                    focusNode: _precioFocus,
                    enabled: habilitado,
                    prefixText: '\$ ',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 9,
                    textInputAction: TextInputAction.done,
                    errorText: _errorPrecioLocal ?? widget.errorPrecio,
                    helperText: base != null && precio != null && precio != base
                        ? 'Precio base ${formatearCop(base)}'
                        : null,
                    onChanged: _precioEscrito,
                  ),
                ),
              ],
            ),
            if (widget.errorStock != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.destructive,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.errorStock!,
                      style: t.labelLarge?.copyWith(
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Subtotal ${formatearCop(_l.subtotalCop)}',
                style: t.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de paso de 48dp. Deshabilitado no usa opacidad: relleno
/// `surfaceMuted` e icono `placeholder`.
class _BotonPaso extends StatelessWidget {
  const _BotonPaso({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activo = onTap != null;
    return Semantics(
      button: true,
      enabled: activo,
      label: etiqueta,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          decoration: BoxDecoration(
            color: activo ? AppColors.surface : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icono,
            color: activo ? AppColors.foreground : AppColors.placeholder,
          ),
        ),
      ),
    );
  }
}
