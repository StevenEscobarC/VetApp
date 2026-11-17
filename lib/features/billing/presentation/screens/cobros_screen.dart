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
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../domain/entities/cobro.dart';
import '../../domain/numeracion.dart';
import '../cobros_rutas.dart';
import '../providers/cobros_providers.dart';
import '../widgets/cobro_fila.dart';
import '../widgets/resumen_cobros_card.dart';
import '../widgets/tipo_cobro_toggle.dart';

/// Espacio bajo la lista para que el FAB (56) + margen (16) + aire (16) no
/// tape la última tarjeta.
const double _kPaddingInferior = 88.0;

enum _Filtro { todas, pendientes, pagadas }

/// Cobros de la clínica (BILL-01, BILL-04, D-17): resumen del servidor,
/// cotizaciones y cuentas de cobro con su estado, y alta desde el FAB. El
/// tipo y el filtro son estado local de la pantalla.
class CobrosScreen extends ConsumerStatefulWidget {
  const CobrosScreen({super.key, this.tipoInicial = TipoCobro.cuentaCobro});

  /// Pestaña con la que abre (`?tipo=cot` preselecciona Cotizaciones).
  final TipoCobro tipoInicial;

  @override
  ConsumerState<CobrosScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends ConsumerState<CobrosScreen> {
  late TipoCobro _tipo = widget.tipoInicial;
  _Filtro _filtro = _Filtro.todas;

  /// Pendientes y Pagadas se piden al servidor, no se filtran sobre las
  /// últimas [kCobrosLista] (WR-02).
  FiltroCobros get _clave => (
    tipo: _tipo,
    estado: _tipo == TipoCobro.cotizacion
        ? null
        : switch (_filtro) {
            _Filtro.todas => null,
            _Filtro.pendientes => EstadoCobro.pendiente,
            _Filtro.pagadas => EstadoCobro.pagada,
          },
  );

  Future<void> _refrescar() async {
    final clave = _clave;
    ref.invalidate(cobrosProvider(clave));
    ref.invalidate(resumenCobrosProvider);
    await ref.read(cobrosProvider(clave).future).catchError((_) => <Cobro>[]);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cobrosProvider(_clave));
    final puedeEscribir = ref.watch(puedeEscribirProvider);
    final pendientes = ref.watch(resumenCobrosProvider).value?.pendientes ?? 0;
    final cargando = async.isLoading && !async.hasValue;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Cobros',
        actions: [
          IconButton(
            tooltip: 'Servicios y precios',
            constraints: const BoxConstraints.tightFor(
              width: AppSpacing.touchTarget,
              height: AppSpacing.touchTarget,
            ),
            icon: const Icon(Icons.medical_services_outlined),
            onPressed: () => context.push(kRutaServicios),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ResumenCobrosCard(),
                const SizedBox(height: AppSpacing.md),
                TipoCobroToggle(
                  valor: _tipo,
                  habilitado: !cargando,
                  onChanged: (t) => setState(() {
                    _tipo = t;
                    _filtro = _Filtro.todas;
                  }),
                ),
                if (_tipo == TipoCobro.cuentaCobro) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final (f, label) in [
                        (_Filtro.todas, 'Todas'),
                        (
                          _Filtro.pendientes,
                          pendientes > 0
                              ? 'Pendientes ($pendientes)'
                              : 'Pendientes',
                        ),
                        (_Filtro.pagadas, 'Pagadas'),
                      ])
                        AppFilterChip(
                          label: label,
                          selected: _filtro == f,
                          onTap: () {
                            if (cargando) return;
                            setState(() => _filtro = f);
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: async.when(
              skipLoadingOnRefresh: true,
              data: (lista) => _Cuerpo(
                lista: lista,
                tipo: _tipo,
                filtro: _filtro,
                puedeEscribir: puedeEscribir,
                onRefresh: _refrescar,
              ),
              loading: () => const _Esqueleto(),
              error: (_, _) => _Error(onReintentar: _refrescar),
            ),
          ),
        ],
      ),
      floatingActionButton: _botonNuevo(puedeEscribir),
    );
  }

  /// En solo lectura conserva lugar, variante y tamaño; solo cambian el ícono
  /// y la semántica, y el toque abre la hoja de solo lectura.
  Widget _botonNuevo(bool puedeEscribir) {
    final etiqueta = _tipo == TipoCobro.cotizacion
        ? 'Nueva cotización'
        : 'Nueva cuenta de cobro';
    final tipo = _tipo;

    Future<void> abrir() async {
      final ok = await asegurarEscritura(
        context,
        ref,
        plan: ref.read(miPlanProvider).value,
      );
      if (!ok || !mounted) return;
      context.push(rutaNuevoCobro(tipo: tipo));
    }

    final boton = FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      onPressed: abrir,
      icon: Icon(iconoEscritura(puedeEscribir, Icons.add)),
      label: Text(etiqueta),
    );
    if (puedeEscribir) return boton;
    return Semantics(
      button: true,
      label: semanticaEscritura(puedeEscribir, etiqueta),
      onTap: abrir,
      excludeSemantics: true,
      child: boton,
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({
    required this.lista,
    required this.tipo,
    required this.filtro,
    required this.puedeEscribir,
    required this.onRefresh,
  });

  final List<Cobro> lista;
  final TipoCobro tipo;
  final _Filtro filtro;
  final bool puedeEscribir;
  final Future<void> Function() onRefresh;

  Widget _vacio() {
    if (tipo == TipoCobro.cotizacion || filtro == _Filtro.todas) {
      final esCot = tipo == TipoCobro.cotizacion;
      final icono = esCot
          ? Icons.request_quote_outlined
          : Icons.receipt_long_outlined;
      if (!puedeEscribir) {
        return _Vacio(
          icono: icono,
          titulo: 'Aún no hay cobros',
          mensaje: 'Tu clínica todavía no ha registrado cobros.',
        );
      }
      return esCot
          ? _Vacio(
              icono: icono,
              titulo: 'Aún no tienes cotizaciones',
              mensaje:
                  'Envía el precio de una cirugía o tratamiento antes de '
                  'hacerlo. Toca «Nueva cotización».',
            )
          : _Vacio(
              icono: icono,
              titulo: 'Aún no tienes cuentas de cobro',
              mensaje:
                  'Cobra una consulta, un servicio o un producto y '
                  'compártelo por WhatsApp. Toca «Nueva cuenta de cobro» '
                  'para empezar.',
            );
    }
    if (filtro == _Filtro.pendientes) {
      return const _Vacio(
        icono: Icons.check_circle_outline,
        colorIcono: AppColors.success,
        titulo: 'Nada por cobrar',
        mensaje: 'Todas tus cuentas de cobro están pagadas.',
      );
    }
    return const _Vacio(
      icono: Icons.receipt_long_outlined,
      titulo: 'Aún no hay cuentas pagadas',
      mensaje: 'Cuando marques una como pagada aparecerá aquí.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = diaBogota(ref.watch(clockProvider)());
    // El servidor ya filtró por estado.
    final visibles = lista;

    // El vacío también se puede refrescar deslizando.
    if (visibles.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: _vacio(),
            ),
          ),
        ),
      );
    }

    final hayPie = lista.length >= kCobrosLista;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          _kPaddingInferior,
        ),
        itemCount: visibles.length + (hayPie ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          if (i == visibles.length) {
            return Text(
              'Mostrando las últimas $kCobrosLista.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
            );
          }
          return CobroFila(
            key: ValueKey(visibles[i].id),
            cobro: visibles[i],
            hoy: hoy,
          );
        },
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              'No pudimos cargar los cobros. Intenta de nuevo.',
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
