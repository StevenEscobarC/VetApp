import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../inventory/domain/entities/producto.dart';
import '../../../inventory/presentation/providers/inventario_providers.dart';
import '../../../inventory/presentation/widgets/insignia_stock.dart';

/// Abre la hoja "Agregar producto" (UI-SPEC §3.1) y devuelve el producto
/// tocado, o `null` si se cierra. Solo lista productos activos (D-14). En una
/// cuenta de cobro un producto agotado no se puede elegir; en una cotización
/// sí, porque nunca descuenta inventario (D-11).
Future<Producto?> showProductoCobroSheet(
  BuildContext context, {
  required bool esCuentaCobro,
}) => showModalBottomSheet<Producto>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: AppColors.surface,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * 0.9,
  ),
  builder: (_) => ProductoCobroSheet(esCuentaCobro: esCuentaCobro),
);

String _sinAcentos(String s) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i < 0 ? c : a[i]);
  }
  return b.toString();
}

/// Selector de productos del inventario con búsqueda local sobre
/// [productosProvider] (ya trae solo activos).
class ProductoCobroSheet extends ConsumerStatefulWidget {
  const ProductoCobroSheet({super.key, required this.esCuentaCobro});

  final bool esCuentaCobro;

  @override
  ConsumerState<ProductoCobroSheet> createState() => _ProductoCobroSheetState();
}

class _ProductoCobroSheetState extends ConsumerState<ProductoCobroSheet> {
  final _busquedaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Existencias frescas al abrir: el "agotado" no se decide con una cifra
    // vieja en caché (WR-03).
    Future.microtask(() {
      if (mounted) ref.invalidate(productosProvider);
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Widget _mensaje(String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Text(
      texto,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
    ),
  );

  Widget _cuerpo(AsyncValue<List<Producto>> productos) {
    if (productos.isLoading && !productos.hasValue) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              key: ValueKey('esqueleto-producto-$i'),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
        ],
      );
    }
    if (productos.hasError && !productos.hasValue) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mensaje('No pudimos cargar el inventario.'),
          AppButton(
            label: 'Reintentar',
            variant: AppButtonVariant.text,
            onPressed: () => ref.invalidate(productosProvider),
          ),
        ],
      );
    }
    final todos = [...?productos.value]
      ..removeWhere((p) => p.archivado)
      ..sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
    if (todos.isEmpty) {
      return _mensaje('Aún no tienes productos en el inventario.');
    }
    final q = _busquedaCtrl.text.trim();
    final qn = _sinAcentos(q);
    final lista = [
      for (final p in todos)
        if (qn.isEmpty || _sinAcentos(p.nombre).contains(qn)) p,
    ];
    if (lista.isEmpty) return _mensaje('No encontramos productos con «$q»');
    return ListView.builder(
      shrinkWrap: true,
      itemCount: lista.length,
      itemBuilder: (_, i) => _FilaProducto(
        producto: lista[i],
        bloqueado: widget.esCuentaCobro && lista[i].cantidad <= 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final productos = ref.watch(productosProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Agregar producto', style: t.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Buscar producto',
            hideLabel: true,
            hintText: 'Buscar producto',
            prefixIcon: Icons.search,
            autofocus: true,
            controller: _busquedaCtrl,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(child: _cuerpo(productos)),
        ],
      ),
    );
  }
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({required this.producto, required this.bloqueado});

  final Producto producto;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = producto;
    final precio = p.precioVentaCop;
    final detalle =
        'Quedan ${formatearMiles(p.cantidad)} ${p.unidad.etiqueta(p.cantidad)}'
        ' · ${precio == null ? 'Sin precio' : formatearCop(precio)}';
    final fila = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyLarge,
                ),
                Text(
                  detalle,
                  style: t.labelLarge?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (bloqueado) ...[
            const SizedBox(width: AppSpacing.sm),
            const InsigniaStock(estado: EstadoStock.agotado),
          ],
        ],
      ),
    );
    if (bloqueado) {
      return Semantics(
        container: true,
        enabled: false,
        label: '${p.nombre}, agotado, no disponible',
        excludeSemantics: true,
        child: fila,
      );
    }
    return InkWell(onTap: () => Navigator.of(context).pop(p), child: fila);
  }
}
