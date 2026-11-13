import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../domain/entities/producto.dart';
import '../inventario_routes.dart';
import '../providers/inventario_providers.dart';
import '../widgets/producto_fila.dart';

/// Espacio bajo la lista para que el FAB (56) + margen (16) + aire (16) no
/// tape la última fila.
const double _kPaddingInferior = 88.0;

/// Lista de inventario de la clínica (INV-01, INV-02): búsqueda local,
/// filas con insignias de estado y alta desde el FAB.
class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _refrescar() async {
    ref.invalidate(productosProvider);
    ref.invalidate(resumenInventarioProvider);
    await ref.read(productosProvider.future).catchError((_) => <Producto>[]);
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosProvider);
    final puedeEscribir = ref.watch(puedeEscribirProvider);
    final consulta = _busquedaCtrl.text.trim();

    return Scaffold(
      appBar: const AppTopBar(title: 'Inventario'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppTextField(
              label: 'Buscar producto',
              hideLabel: true,
              controller: _busquedaCtrl,
              hintText: 'Buscar producto',
              prefixIcon: Icons.search,
              textCapitalization: TextCapitalization.sentences,
              enabled: !productosAsync.isLoading || productosAsync.hasValue,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: productosAsync.when(
              skipLoadingOnRefresh: true,
              data: (productos) => _Cuerpo(
                productos: productos,
                consulta: consulta,
                puedeEscribir: puedeEscribir,
                onRefresh: _refrescar,
              ),
              loading: () => const _Esqueleto(),
              error: (_, _) =>
                  _Error(onReintentar: () => ref.invalidate(productosProvider)),
            ),
          ),
        ],
      ),
      floatingActionButton: _botonNuevoProducto(puedeEscribir),
    );
  }

  /// En solo lectura conserva lugar, variante y tamaño; solo cambian el ícono
  /// y la semántica, y el toque abre la hoja de solo lectura.
  Widget _botonNuevoProducto(bool puedeEscribir) {
    Future<void> abrir() async {
      final ok = await asegurarEscritura(
        context,
        ref,
        plan: ref.read(miPlanProvider).value,
      );
      if (!ok || !mounted) return;
      context.push(kRutaNuevoProducto);
    }

    final boton = FloatingActionButton.extended(
      onPressed: abrir,
      icon: Icon(iconoEscritura(puedeEscribir, Icons.add)),
      label: const Text('Nuevo producto'),
    );
    if (puedeEscribir) return boton;
    return Semantics(
      button: true,
      label: semanticaEscritura(puedeEscribir, 'Nuevo producto'),
      onTap: abrir,
      excludeSemantics: true,
      child: boton,
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({
    required this.productos,
    required this.consulta,
    required this.puedeEscribir,
    required this.onRefresh,
  });

  final List<Producto> productos;
  final String consulta;
  final bool puedeEscribir;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = consulta.toLowerCase();
    final visibles = [
      for (final p in productos)
        if (q.isEmpty || p.nombre.toLowerCase().contains(q)) p,
    ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    if (visibles.isEmpty) {
      if (productos.isNotEmpty || consulta.isNotEmpty) {
        return _Vacio(
          icono: Icons.search,
          titulo: 'No encontramos productos con «$consulta»',
          mensaje: 'Revisa el nombre o crea un producto nuevo.',
        );
      }
      return puedeEscribir
          ? const _Vacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'Aún no tienes productos',
              mensaje:
                  'Registra tus medicamentos e insumos para saber cuándo '
                  'reabastecer. Toca «Nuevo producto» para empezar.',
            )
          : const _Vacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'Aún no hay productos',
              mensaje: 'Tu clínica todavía no ha registrado productos.',
            );
    }

    final hoy = diaBogota(ref.watch(clockProvider)());
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          _kPaddingInferior,
        ),
        itemCount: visibles.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) => ProductoFila(
          key: ValueKey(visibles[i].id),
          producto: visibles[i],
          hoy: hoy,
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.mensaje,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 32, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              titulo,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              mensaje,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No pudimos cargar el inventario. Intenta de nuevo.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Reintentar',
              variant: AppButtonVariant.outline,
              expand: false,
              onPressed: onReintentar,
            ),
          ],
        ),
      ),
    );
  }
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => AppCard(
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
    );
  }
}
