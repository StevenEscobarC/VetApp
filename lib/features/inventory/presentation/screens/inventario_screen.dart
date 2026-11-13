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
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../core/utils/compartir.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../domain/entities/producto.dart';
import '../../domain/pedido_whatsapp.dart';
import '../inventario_routes.dart';
import '../providers/inventario_providers.dart';
import '../widgets/producto_fila.dart';
import '../widgets/resumen_bajos_strip.dart';

/// Espacio bajo la lista para que el FAB (56) + margen (16) + aire (16) no
/// tape la última fila.
const double _kPaddingInferior = 88.0;

/// Lista de inventario de la clínica (INV-01, INV-02): búsqueda local,
/// filas con insignias de estado y alta desde el FAB.
class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key, this.filtroBajosInicial = false});

  /// Entra con el filtro "Bajos" (desde Inicio o `?filtro=bajos`).
  final bool filtroBajosInicial;

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

enum _Filtro { todos, bajos, vencePronto }

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  final _busquedaCtrl = TextEditingController();
  late _Filtro _filtro = widget.filtroBajosInicial
      ? _Filtro.bajos
      : _Filtro.todos;

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
    final hoy = diaBogota(ref.watch(clockProvider)());

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
          if (productosAsync.hasValue)
            _Cabecera(
              productos: productosAsync.requireValue,
              hoy: hoy,
              filtro: _filtro,
              hayBusqueda: consulta.isNotEmpty,
              onFiltro: (f) => setState(() => _filtro = f),
            ),
          Expanded(
            child: productosAsync.when(
              skipLoadingOnRefresh: true,
              data: (productos) => _Cuerpo(
                productos: productos,
                consulta: consulta,
                filtro: _filtro,
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

bool _porVencer(Producto p, DateTime hoy) =>
    p.vencePronto(hoy) || p.vencido(hoy);

/// Filtros, tira de alerta y pedido por WhatsApp, fijos sobre la lista.
class _Cabecera extends ConsumerWidget {
  const _Cabecera({
    required this.productos,
    required this.hoy,
    required this.filtro,
    required this.hayBusqueda,
    required this.onFiltro,
  });

  final List<Producto> productos;
  final DateTime hoy;
  final _Filtro filtro;
  final bool hayBusqueda;
  final ValueChanged<_Filtro> onFiltro;

  String _etiqueta(String base, int n) => n > 0 ? '$base ($n)' : base;

  /// Compartir no es una escritura: nunca se bloquea por solo lectura.
  Future<void> _pedir(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final texto = mensajePedidoStock(
      productos: productos,
      clinica: ref.read(authProfileProvider).value?.clinicaNombre,
    );
    try {
      await ref.read(compartidorProvider).compartirTexto(texto);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos abrir el menú de compartir.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bajos = productos.where((p) => p.bajo).length;
    final porVencer = productos.where((p) => _porVencer(p, hoy)).length;
    final muestraTira = filtro == _Filtro.todos && !hayBusqueda && bajos > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppFilterChip(
                label: 'Todos',
                selected: filtro == _Filtro.todos,
                onTap: () => onFiltro(_Filtro.todos),
              ),
              AppFilterChip(
                label: _etiqueta('Bajos', bajos),
                selected: filtro == _Filtro.bajos,
                onTap: () => onFiltro(_Filtro.bajos),
              ),
              AppFilterChip(
                label: _etiqueta('Vence pronto', porVencer),
                selected: filtro == _Filtro.vencePronto,
                onTap: () => onFiltro(_Filtro.vencePronto),
              ),
            ],
          ),
          if (muestraTira) ...[
            const SizedBox(height: AppSpacing.md),
            ResumenBajosStrip(
              bajos: bajos,
              onVerBajos: () => onFiltro(_Filtro.bajos),
            ),
          ],
          if (filtro == _Filtro.bajos && bajos > 0) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Pedir por WhatsApp',
              variant: AppButtonVariant.outline,
              icon: Icons.share_outlined,
              expand: true,
              onPressed: () => _pedir(context, ref),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pedimos lo necesario para llegar al doble del mínimo.',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({
    required this.productos,
    required this.consulta,
    required this.filtro,
    required this.puedeEscribir,
    required this.onRefresh,
  });

  final List<Producto> productos;
  final String consulta;
  final _Filtro filtro;
  final bool puedeEscribir;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = diaBogota(ref.watch(clockProvider)());
    final q = consulta.toLowerCase();
    final visibles = [
      for (final p in productos)
        if ((q.isEmpty || p.nombre.toLowerCase().contains(q)) &&
            switch (filtro) {
              _Filtro.todos => true,
              _Filtro.bajos => p.bajo,
              _Filtro.vencePronto => _porVencer(p, hoy),
            })
          p,
    ];
    if (filtro == _Filtro.vencePronto) {
      visibles.sort((a, b) => a.vencimiento!.compareTo(b.vencimiento!));
    } else {
      visibles.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
    }

    if (visibles.isEmpty) {
      if (consulta.isEmpty && productos.isNotEmpty) {
        if (filtro == _Filtro.bajos) {
          return const _Vacio(
            icono: Icons.check_circle_outline,
            colorIcono: AppColors.success,
            titulo: 'Nada por reabastecer',
            mensaje: 'Todos tus productos están en el mínimo o por encima.',
          );
        }
        if (filtro == _Filtro.vencePronto) {
          return const _Vacio(
            icono: Icons.check_circle_outline,
            colorIcono: AppColors.success,
            titulo: 'Nada por vencer pronto',
            mensaje: 'Ningún producto vence en los próximos 30 días.',
          );
        }
      }
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
    this.colorIcono = AppColors.textSecondary,
  });

  final IconData icono;
  final Color colorIcono;
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
              child: Icon(icono, size: 32, color: colorIcono),
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
