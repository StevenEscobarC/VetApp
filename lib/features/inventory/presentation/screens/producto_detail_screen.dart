import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../../domain/entities/movimiento_stock.dart';
import '../../domain/entities/producto.dart';
import '../../domain/inventario_failure.dart';
import '../../domain/stock.dart';
import '../inventario_routes.dart';
import '../providers/inventario_providers.dart';
import '../widgets/ajuste_sheet.dart';
import '../widgets/ajuste_stock.dart';
import '../widgets/insignia_stock.dart';
import '../widgets/movimiento_tile.dart';

/// Detalle de un producto (INV-01, INV-03): estado actual, ajustes de stock,
/// historial de los últimos movimientos y, para el administrador, archivar.
/// La cantidad que se muestra es siempre la que devuelve el servidor.
class ProductoDetailScreen extends ConsumerWidget {
  const ProductoDetailScreen({super.key, required this.productoId});

  final String productoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productoProvider(productoId));
    final puede = ref.watch(puedeEscribirProvider);

    Future<void> editar() async {
      if (!await asegurarEscritura(context, ref)) return;
      if (!context.mounted) return;
      await context.push(rutaEditarProducto(productoId));
    }

    final accionEditar = ControlEscritura(
      puedeEscribir: puede,
      label: 'Editar producto',
      onTap: editar,
      child: IconButton(
        tooltip: 'Editar producto',
        constraints: const BoxConstraints.tightFor(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
        ),
        icon: Icon(iconoEscritura(puede, Icons.edit_outlined)),
        onPressed: editar,
      ),
    );

    final Widget cuerpo;
    final producto = async.value;
    if (producto != null && !producto.archivado) {
      cuerpo = _Contenido(producto: producto);
    } else if (async.hasError && !async.hasValue) {
      cuerpo = _Mensaje(
        texto: 'No pudimos cargar el producto. Intenta de nuevo.',
        boton: 'Reintentar',
        onPressed: () => ref.invalidate(productoProvider(productoId)),
      );
    } else if (async.hasValue) {
      cuerpo = _Mensaje(
        texto: 'Este producto ya no está disponible.',
        boton: 'Volver al inventario',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(rutaInventario()),
      );
    } else {
      cuerpo = const _Esqueleto();
    }

    return Scaffold(
      appBar: AppTopBar(
        title: 'Producto',
        actions: producto != null && !producto.archivado
            ? [accionEditar]
            : null,
      ),
      body: SafeArea(child: cuerpo),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.texto,
    required this.boton,
    required this.onPressed,
  });

  final String texto;
  final String boton;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
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
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.alto});

  final double alto;

  @override
  Widget build(BuildContext context) => Container(
    height: alto,
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.md),
    child: Column(
      children: [
        _Bloque(alto: 200),
        SizedBox(height: AppSpacing.md),
        _Bloque(alto: 56),
        SizedBox(height: AppSpacing.md),
        _Bloque(alto: 56),
        SizedBox(height: AppSpacing.md),
        _Bloque(alto: 56),
      ],
    ),
  );
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = diaBogota(ref.watch(clockProvider)());
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _Cabecera(producto: producto, hoy: hoy),
        const SizedBox(height: AppSpacing.lg),
        _Detalles(producto: producto, hoy: hoy),
        const SizedBox(height: AppSpacing.lg),
        _Historial(producto: producto),
        if (ref.watch(puedeAdministrarInventarioProvider)) ...[
          const SizedBox(height: AppSpacing.lg),
          _AccionArchivar(producto: producto),
        ],
      ],
    );
  }
}

class _Cabecera extends ConsumerStatefulWidget {
  const _Cabecera({required this.producto, required this.hoy});

  final Producto producto;
  final DateTime hoy;

  @override
  ConsumerState<_Cabecera> createState() => _CabeceraState();
}

class _CabeceraState extends ConsumerState<_Cabecera> {
  bool _enVuelo = false;

  Future<void> _descontar() async {
    if (_enVuelo) return;
    setState(() => _enVuelo = true);
    try {
      if (!await asegurarEscritura(context, ref)) return;
      if (!mounted) return;
      await descontarUno(context, ref, widget.producto);
    } finally {
      if (mounted) setState(() => _enVuelo = false);
    }
  }

  Future<void> _abrirSheet(MotivoMovimiento motivo) async {
    if (!await asegurarEscritura(context, ref)) return;
    if (!mounted) return;
    await mostrarAjusteSheet(
      context,
      producto: widget.producto,
      motivoInicial: motivo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final textTheme = Theme.of(context).textTheme;
    final puede = ref.watch(puedeEscribirProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.nombre,
            style: textTheme.headlineSmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (estadosDe(p, widget.hoy).isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: insigniasDe(p, widget.hoy),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatearMiles(p.cantidad),
                    style: textTheme.displaySmall,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                p.unidad.etiqueta(p.cantidad),
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'Mínimo ${formatearMiles(p.minimo)}',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ControlEscritura(
            puedeEscribir: puede,
            label: 'Descontar 1',
            onTap: _descontar,
            child: AppButton(
              label: 'Descontar 1',
              variant: AppButtonVariant.outline,
              icon: iconoEscritura(puede, Icons.remove),
              onPressed: _enVuelo || (puede && p.cantidad <= 0)
                  ? null
                  : _descontar,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ControlEscritura(
            puedeEscribir: puede,
            label: 'Agregar stock',
            onTap: () => _abrirSheet(MotivoMovimiento.compra),
            child: AppButton(
              label: 'Agregar stock',
              icon: iconoEscritura(puede, Icons.add),
              onPressed: () => _abrirSheet(MotivoMovimiento.compra),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ControlEscritura(
            puedeEscribir: puede,
            label: 'Ajustar cantidad',
            onTap: () => _abrirSheet(MotivoMovimiento.conteo),
            child: AppButton(
              label: 'Ajustar cantidad',
              variant: AppButtonVariant.text,
              icon: puede ? null : Icons.lock_outline,
              onPressed: () => _abrirSheet(MotivoMovimiento.conteo),
            ),
          ),
        ],
      ),
    );
  }
}

/// "dd/mm/aaaa · en 12 días" / "hoy" / "mañana" / "venció hace 3 días".
String textoVencimiento(Producto p, DateTime hoy) {
  final v = p.vencimiento;
  final d = p.diasParaVencer(hoy);
  if (v == null || d == null) return '';
  final relativo = switch (d) {
    0 => 'hoy',
    1 => 'mañana',
    -1 => 'venció hace 1 día',
    > 1 => 'en $d días',
    _ => 'venció hace ${-d} días',
  };
  return '${formatearFecha(v)} · $relativo';
}

class _Detalles extends StatelessWidget {
  const _Detalles({required this.producto, required this.hoy});

  final Producto producto;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final filas = <(String, String)>[
      ('Categoría', p.categoria.etiqueta),
      ('Unidad de conteo', p.unidad.chip),
      if (p.vencimiento != null) ('Vencimiento', textoVencimiento(p, hoy)),
      if (p.precioVentaCop != null)
        ('Precio de venta', formatearCop(p.precioVentaCop!)),
      if (p.costoCop != null) ('Costo', formatearCop(p.costoCop!)),
    ];
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    filas[i].$1,
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    filas[i].$2,
                    textAlign: TextAlign.end,
                    style: textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Historial extends ConsumerWidget {
  const _Historial({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(movimientosProvider(producto.id));
    final movs = async.value;

    final Widget cuerpo;
    if (movs != null) {
      if (movs.isEmpty) {
        cuerpo = Text(
          'Aún no hay movimientos.',
          style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        );
      } else {
        cuerpo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in movs) ...[
              MovimientoTile(movimiento: m, unidad: producto.unidad),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (movs.length >= kMovimientosHistorial)
              Text(
                'Mostrando los últimos $kMovimientosHistorial movimientos.',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        );
      }
    } else if (async.hasError) {
      cuerpo = Row(
        children: [
          Expanded(
            child: Text(
              'No pudimos cargar el historial.',
              style: textTheme.bodyLarge,
            ),
          ),
          AppButton(
            label: 'Reintentar',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => ref.invalidate(movimientosProvider(producto.id)),
          ),
        ],
      );
    } else {
      cuerpo = const Column(
        children: [
          _Bloque(alto: 56),
          SizedBox(height: AppSpacing.sm),
          _Bloque(alto: 56),
          SizedBox(height: AppSpacing.sm),
          _Bloque(alto: 56),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de movimientos', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        cuerpo,
      ],
    );
  }
}

/// "Archivar producto" (solo administrador, D-13): confirma, archiva y vuelve
/// a la lista. No borra nada: el historial se conserva y no hay restauración.
class _AccionArchivar extends ConsumerStatefulWidget {
  const _AccionArchivar({required this.producto});

  final Producto producto;

  @override
  ConsumerState<_AccionArchivar> createState() => _AccionArchivarState();
}

class _AccionArchivarState extends ConsumerState<_AccionArchivar> {
  bool _enVuelo = false;

  void _volverALista(GoRouter router) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(rutaInventario());
    }
  }

  Future<void> _archivar() async {
    if (_enVuelo) return;
    if (!await asegurarEscritura(context, ref)) return;
    if (!mounted) return;
    final nombre = widget.producto.nombre;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar producto'),
        content: Text(
          '«$nombre» dejará de aparecer en tu inventario y no podrás ajustar '
          'su stock. El historial de movimientos se conserva. Esta acción no '
          'se puede deshacer desde la app.',
        ),
        actions: [
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: 'Archivar',
            variant: AppButtonVariant.destructive,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    void aviso(String texto) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));

    setState(() => _enVuelo = true);
    try {
      await ref.read(inventarioActionsProvider).archivar(widget.producto.id);
      aviso('«$nombre» archivado.');
      _volverALista(router);
    } on InventarioFailure catch (e) {
      if (mounted && await manejarLimitePlan(context, ref, e)) return;
      switch (e.tipo) {
        case ErrorInventario.sinPermiso:
          aviso('Solo el administrador de la clínica puede hacer esto.');
        case ErrorInventario.noDisponible:
          aviso('Ese producto ya no está disponible.');
          _volverALista(router);
        default:
          aviso('No pudimos completar la operación. Intenta de nuevo.');
      }
    } catch (_) {
      aviso('No pudimos completar la operación. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _enVuelo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final puede = ref.watch(puedeEscribirProvider);
    return ControlEscritura(
      puedeEscribir: puede,
      label: 'Archivar producto',
      onTap: _archivar,
      child: AppButton(
        label: 'Archivar producto',
        variant: AppButtonVariant.destructive,
        icon: iconoEscritura(puede, Icons.archive_outlined),
        isLoading: _enVuelo,
        onPressed: _archivar,
      ),
    );
  }
}
