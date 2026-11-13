import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../domain/entities/producto.dart';
import '../../domain/inventario_failure.dart';
import '../../domain/stock.dart';
import '../inventario_routes.dart';
import '../providers/inventario_providers.dart';

const String _kSoloAdminMinimoPrecios =
    'Solo el administrador puede cambiar el mínimo y los precios.';

const String _kErrorGenerico =
    'No pudimos completar la operación. Intenta de nuevo.';

/// Alta de producto en un solo paso (INV-01, D-10): nombre, unidad, cantidad
/// inicial y mínimo; categoría, vencimiento y precios van en "Agregar más
/// detalles". La cantidad nueva la decide el servidor vía `crear_producto`.
class ProductoFormScreen extends ConsumerStatefulWidget {
  const ProductoFormScreen({super.key, this.productoId});

  /// Con id edita ese producto; sin id crea uno nuevo.
  final String? productoId;

  @override
  ConsumerState<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends ConsumerState<ProductoFormScreen> {
  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _minimoCtrl = TextEditingController(text: '$kMinimoPorDefecto');
  final _vencimientoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _nombreFocus = FocusNode();
  final _cantidadFocus = FocusNode();
  final _minimoFocus = FocusNode();
  final _precioFocus = FocusNode();
  final _costoFocus = FocusNode();

  Unidad _unidad = Unidad.unidad;
  CategoriaProducto _categoria = CategoriaProducto.medicamento;
  bool _detalles = false;
  bool _guardando = false;
  bool _guardandoOtro = false;
  bool _precargado = false;

  String? _errNombre;
  String? _errCantidad;
  String? _errMinimo;
  String? _errVencimiento;
  String? _errPrecio;
  String? _errCosto;

  @override
  void initState() {
    super.initState();
    _precioFocus.addListener(() => _agruparAlSalir(_precioFocus, _precioCtrl));
    _costoFocus.addListener(() => _agruparAlSalir(_costoFocus, _costoCtrl));
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl,
      _cantidadCtrl,
      _minimoCtrl,
      _vencimientoCtrl,
      _precioCtrl,
      _costoCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _nombreFocus,
      _cantidadFocus,
      _minimoFocus,
      _precioFocus,
      _costoFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Al perder el foco un precio válido se muestra con puntos de miles.
  void _agruparAlSalir(FocusNode foco, TextEditingController ctrl) {
    if (foco.hasFocus) return;
    final r = parsearCop(ctrl.text);
    final v = r.valor;
    if (r.error == null && v != null) ctrl.text = formatearMiles(v);
  }

  /// Entero obligatorio de [texto] (cantidad o mínimo), con su error.
  ({int? valor, String? error}) _entero(String texto, String vacio) {
    final t = texto.trim();
    if (t.isEmpty) return (valor: null, error: vacio);
    final n = int.tryParse(t);
    if (n == null || n > kCantidadMaxima) {
      return (valor: null, error: 'La cantidad máxima es 1.000.000.');
    }
    return (valor: n, error: null);
  }

  Future<void> _guardar({required bool otro}) async {
    if (_guardando) return;

    final nombre = _nombreCtrl.text.trim();
    final cantidad = _entero(
      _cantidadCtrl.text,
      'Escribe la cantidad (puede ser 0).',
    );
    final minimo = _entero(
      _minimoCtrl.text,
      'Escribe el mínimo (puede ser 0).',
    );
    final fecha = parsearFecha(_vencimientoCtrl.text, permitirFuturo: true);
    final precio = parsearCop(_precioCtrl.text);
    final costo = parsearCop(_costoCtrl.text);

    setState(() {
      _errNombre = nombre.isEmpty ? 'Escribe el nombre del producto.' : null;
      _errCantidad = cantidad.error;
      _errMinimo = minimo.error;
      _errVencimiento = fecha.error == null
          ? null
          : 'Escribe una fecha válida (dd/mm/aaaa).';
      _errPrecio = precio.error;
      _errCosto = costo.error;
    });
    if ([
      _errNombre,
      _errCantidad,
      _errMinimo,
      _errVencimiento,
      _errPrecio,
      _errCosto,
    ].any((e) => e != null)) {
      // Los errores de detalles solo se ven con la sección abierta.
      if (!_detalles &&
          (_errVencimiento != null ||
              _errPrecio != null ||
              _errCosto != null)) {
        setState(() => _detalles = true);
      }
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _guardando = true;
      _guardandoOtro = otro;
    });
    try {
      await ref
          .read(inventarioActionsProvider)
          .crear(
            nombre: nombre,
            unidad: _unidad,
            cantidad: cantidad.valor!,
            minimo: minimo.valor!,
            categoria: _categoria,
            vencimiento: fecha.valor,
            precioVentaCop: precio.valor,
            costoCop: costo.valor,
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              otro
                  ? '«$nombre» agregado. Puedes seguir con el siguiente.'
                  : '«$nombre» agregado al inventario.',
            ),
          ),
        );
      if (!mounted) return;
      if (otro) {
        _reiniciar();
      } else {
        router.pop();
      }
    } on InventarioFailure catch (e) {
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      if (!mounted) return;
      if (e.tipo == ErrorInventario.nombreDuplicado) {
        setState(() => _errNombre = 'Ya tienes un producto con ese nombre.');
      } else {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(_kErrorGenerico)));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  bool get _esEdicion => widget.productoId != null;

  /// Rellena los campos una sola vez con el producto cargado (modo edición).
  void _precargar(Producto p) {
    if (_precargado) return;
    _precargado = true;
    _nombreCtrl.text = p.nombre;
    _minimoCtrl.text = '${p.minimo}';
    final v = p.vencimiento;
    _vencimientoCtrl.text = v == null ? '' : formatearFecha(v);
    final pv = p.precioVentaCop;
    _precioCtrl.text = pv == null ? '' : formatearMiles(pv);
    final c = p.costoCop;
    _costoCtrl.text = c == null ? '' : formatearMiles(c);
    _categoria = p.categoria;
    _detalles = true;
  }

  /// Guarda los cambios. El administrador edita todo; el resto de veterinarios
  /// solo nombre, categoría y vencimiento, y se reenvían sin cambios el mínimo
  /// y los precios (el servidor es la autoridad, 42501).
  Future<void> _guardarEdicion(Producto original) async {
    if (_guardando) return;
    final admin = ref.read(puedeAdministrarInventarioProvider);
    final nombre = _nombreCtrl.text.trim();
    final fecha = parsearFecha(_vencimientoCtrl.text, permitirFuturo: true);
    final minimo = admin
        ? _entero(_minimoCtrl.text, 'Escribe el mínimo (puede ser 0).')
        : (valor: original.minimo, error: null);
    final precio = admin
        ? parsearCop(_precioCtrl.text)
        : (valor: original.precioVentaCop, error: null);
    final costo = admin
        ? parsearCop(_costoCtrl.text)
        : (valor: original.costoCop, error: null);

    setState(() {
      _errNombre = nombre.isEmpty ? 'Escribe el nombre del producto.' : null;
      _errMinimo = minimo.error;
      _errVencimiento = fecha.error == null
          ? null
          : 'Escribe una fecha válida (dd/mm/aaaa).';
      _errPrecio = precio.error;
      _errCosto = costo.error;
    });
    if ([
      _errNombre,
      _errMinimo,
      _errVencimiento,
      _errPrecio,
      _errCosto,
    ].any((e) => e != null)) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _guardando = true);
    try {
      await ref
          .read(inventarioActionsProvider)
          .actualizar(
            id: original.id,
            nombre: nombre,
            categoria: _categoria,
            vencimiento: fecha.valor,
            minimo: minimo.valor!,
            precioVentaCop: precio.valor,
            costoCop: costo.valor,
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Cambios guardados.')));
      router.pop();
    } on InventarioFailure catch (e) {
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      if (!mounted) return;
      switch (e.tipo) {
        case ErrorInventario.nombreDuplicado:
          setState(() => _errNombre = 'Ya tienes un producto con ese nombre.');
        case ErrorInventario.sinPermiso:
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Solo el administrador de la clínica puede hacer esto.',
              ),
            ),
          );
        case ErrorInventario.noDisponible:
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Ese producto ya no está disponible.'),
            ),
          );
        default:
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(_kErrorGenerico)));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _filaSoloLectura(String etiqueta, String valor) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          Text(valor, style: textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _edicion(Producto p) {
    _precargar(p);
    final textTheme = Theme.of(context).textTheme;
    final admin = ref.watch(puedeAdministrarInventarioProvider);
    final soloDigitos = [FilteringTextInputFormatter.digitsOnly];
    final dinero = [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))];

    return Scaffold(
      appBar: const AppTopBar(title: 'Editar producto'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Nombre del producto',
                    controller: _nombreCtrl,
                    focusNode: _nombreFocus,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 80,
                    textInputAction: TextInputAction.next,
                    errorText: _errNombre,
                    onChanged: (_) {
                      if (_errNombre != null) setState(() => _errNombre = null);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _filaSoloLectura('Unidad de conteo', p.unidad.chip),
                  _ayuda('No se puede cambiar.'),
                  _ayuda(
                    'Para cambiar la cantidad usa Ajustar stock en el '
                    'detalle.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (admin)
                    AppTextField(
                      label: 'Stock mínimo',
                      controller: _minimoCtrl,
                      focusNode: _minimoFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: soloDigitos,
                      maxLength: 7,
                      textInputAction: TextInputAction.next,
                      helperText:
                          'Te avisamos cuando queden menos de esta cantidad.',
                      errorText: _errMinimo,
                      onChanged: (_) {
                        if (_errMinimo != null) {
                          setState(() => _errMinimo = null);
                        }
                      },
                    )
                  else
                    _filaSoloLectura('Stock mínimo', formatearMiles(p.minimo)),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: () => setState(() => _detalles = !_detalles),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.touchTarget,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Más detalles',
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          Icon(
                            _detalles ? Icons.expand_less : Icons.expand_more,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_detalles) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Categoría', style: textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    _selectorCategoria(),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Vencimiento (opcional)',
                      controller: _vencimientoCtrl,
                      hintText: 'dd/mm/aaaa',
                      prefixIcon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                      ],
                      maxLength: 10,
                      helperText: 'Un solo vencimiento por producto.',
                      errorText: _errVencimiento,
                      onChanged: (_) {
                        if (_errVencimiento != null) {
                          setState(() => _errVencimiento = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (admin) ...[
                      AppTextField(
                        label: 'Precio de venta (opcional)',
                        controller: _precioCtrl,
                        focusNode: _precioFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: dinero,
                        prefixText: '\$ ',
                        helperText: 'En pesos, sin decimales.',
                        errorText: _errPrecio,
                        onChanged: (_) {
                          if (_errPrecio != null) {
                            setState(() => _errPrecio = null);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Costo (opcional)',
                        controller: _costoCtrl,
                        focusNode: _costoFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: dinero,
                        prefixText: '\$ ',
                        helperText: 'En pesos, sin decimales.',
                        errorText: _errCosto,
                        onChanged: (_) {
                          if (_errCosto != null) {
                            setState(() => _errCosto = null);
                          }
                        },
                      ),
                    ] else ...[
                      if (p.precioVentaCop != null) ...[
                        _filaSoloLectura(
                          'Precio de venta',
                          formatearCop(p.precioVentaCop!),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (p.costoCop != null) ...[
                        _filaSoloLectura('Costo', formatearCop(p.costoCop!)),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ],
                  if (!admin) _ayuda(_kSoloAdminMinimoPrecios),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Guardar cambios',
                isLoading: _guardando,
                onPressed: _guardando ? null : () => _guardarEdicion(p),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Estados de carga del producto en modo edición.
  Widget _edicionCargando(AsyncValue<Producto?> async) {
    final Widget cuerpo;
    if (async.hasError && !async.hasValue) {
      cuerpo = _mensaje(
        'No pudimos cargar el producto. Intenta de nuevo.',
        'Reintentar',
        () => ref.invalidate(productoProvider(widget.productoId!)),
      );
    } else if (async.hasValue) {
      cuerpo = _mensaje(
        'Este producto ya no está disponible.',
        'Volver al inventario',
        () => GoRouter.of(context).canPop()
            ? GoRouter.of(context).pop()
            : GoRouter.of(context).go(rutaInventario()),
      );
    } else {
      cuerpo = const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: const AppTopBar(title: 'Editar producto'),
      body: cuerpo,
    );
  }

  Widget _mensaje(String texto, String boton, VoidCallback onPressed) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: boton,
            variant: AppButtonVariant.outline,
            expand: false,
            onPressed: onPressed,
          ),
        ],
      ),
    ),
  );

  /// Deja el formulario listo para el siguiente producto: conserva unidad y
  /// categoría y devuelve el foco al nombre.
  void _reiniciar() {
    setState(() {
      _nombreCtrl.clear();
      _cantidadCtrl.clear();
      _minimoCtrl.text = '$kMinimoPorDefecto';
      _vencimientoCtrl.clear();
      _precioCtrl.clear();
      _costoCtrl.clear();
      _errNombre = _errCantidad = _errMinimo = null;
      _errVencimiento = _errPrecio = _errCosto = null;
    });
    _nombreFocus.requestFocus();
  }

  Widget _selectorUnidad() => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final u in Unidad.values)
        AppFilterChip(
          label: u.chip,
          selected: _unidad == u,
          onTap: () => setState(() => _unidad = u),
        ),
    ],
  );

  Widget _selectorCategoria() => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final c in CategoriaProducto.values)
        AppFilterChip(
          label: c.etiqueta,
          selected: _categoria == c,
          onTap: () => setState(() => _categoria = c),
        ),
    ],
  );

  Widget _ayuda(String texto) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(
      texto,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_esEdicion) {
      final async = ref.watch(productoProvider(widget.productoId!));
      final p = async.value;
      if (p != null && !p.archivado) return _edicion(p);
      return _edicionCargando(async);
    }
    final textTheme = Theme.of(context).textTheme;
    final soloDigitos = [FilteringTextInputFormatter.digitsOnly];
    final dinero = [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))];

    return Scaffold(
      appBar: const AppTopBar(title: 'Nuevo producto'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Nombre del producto',
                    controller: _nombreCtrl,
                    focusNode: _nombreFocus,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 80,
                    textInputAction: TextInputAction.next,
                    errorText: _errNombre,
                    onChanged: (_) {
                      if (_errNombre != null) setState(() => _errNombre = null);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Unidad de conteo', style: textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  _selectorUnidad(),
                  _ayuda(
                    'Cuentas siempre en esta unidad. No se puede cambiar '
                    'después.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Cantidad inicial',
                    controller: _cantidadCtrl,
                    focusNode: _cantidadFocus,
                    hintText: '0',
                    keyboardType: TextInputType.number,
                    inputFormatters: soloDigitos,
                    maxLength: 7,
                    textInputAction: TextInputAction.next,
                    errorText: _errCantidad,
                    onChanged: (_) {
                      if (_errCantidad != null) {
                        setState(() => _errCantidad = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Stock mínimo',
                    controller: _minimoCtrl,
                    focusNode: _minimoFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: soloDigitos,
                    maxLength: 7,
                    textInputAction: TextInputAction.done,
                    helperText:
                        'Te avisamos cuando queden menos de esta cantidad.',
                    errorText: _errMinimo,
                    onChanged: (_) {
                      if (_errMinimo != null) setState(() => _errMinimo = null);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: () => setState(() => _detalles = !_detalles),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.touchTarget,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Agregar más detalles',
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          Icon(
                            _detalles ? Icons.expand_less : Icons.expand_more,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_detalles) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Categoría', style: textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    _selectorCategoria(),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Vencimiento (opcional)',
                      controller: _vencimientoCtrl,
                      hintText: 'dd/mm/aaaa',
                      prefixIcon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                      ],
                      maxLength: 10,
                      helperText: 'Un solo vencimiento por producto.',
                      errorText: _errVencimiento,
                      onChanged: (_) {
                        if (_errVencimiento != null) {
                          setState(() => _errVencimiento = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Precio de venta (opcional)',
                      controller: _precioCtrl,
                      focusNode: _precioFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: dinero,
                      prefixText: '\$ ',
                      helperText: 'En pesos, sin decimales.',
                      errorText: _errPrecio,
                      onChanged: (_) {
                        if (_errPrecio != null) {
                          setState(() => _errPrecio = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Costo (opcional)',
                      controller: _costoCtrl,
                      focusNode: _costoFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: dinero,
                      prefixText: '\$ ',
                      helperText: 'En pesos, sin decimales.',
                      errorText: _errCosto,
                      onChanged: (_) {
                        if (_errCosto != null) setState(() => _errCosto = null);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Este inventario es de control interno de tu clínica.',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'Guardar producto',
                    isLoading: _guardando && !_guardandoOtro,
                    onPressed: _guardando ? null : () => _guardar(otro: false),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Guardar y agregar otro',
                    variant: AppButtonVariant.outline,
                    isLoading: _guardando && _guardandoOtro,
                    onPressed: _guardando ? null : () => _guardar(otro: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
