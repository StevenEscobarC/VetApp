import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../domain/entities/servicio.dart';
import '../providers/cobros_providers.dart';
import '../widgets/servicio_sheet.dart';

/// Espacio bajo la lista para que el FAB no tape la última fila.
const double _kPaddingInferior = 88.0;

/// Sugerencias del estado vacío del administrador: solo nombres; el precio
/// lo escribe cada clínica (sin semilla, no se inventan tarifas).
const List<String> _kSugerencias = [
  'Consulta',
  'Vacunación',
  'Desparasitación',
  'Cirugía',
];

/// Catálogo de servicios de la clínica (D-06): alimenta los chips de un toque
/// del formulario de cobro. Solo el administrador crea, edita o quita
/// (cortesía: el servidor responde 42501); los demás lo ven en solo lectura.
class ServiciosScreen extends ConsumerWidget {
  const ServiciosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviciosAsync = ref.watch(serviciosProvider);
    final admin = ref.watch(puedeAdministrarServiciosProvider);
    final puedeEscribir = ref.watch(puedeEscribirProvider);
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.labelLarge?.copyWith(color: AppColors.textMuted);

    return Scaffold(
      appBar: const AppTopBar(title: 'Servicios'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Los servicios que agregas con un toque al cobrar. En cada '
                  'cobro puedes cambiar el precio.',
                  style: muted,
                ),
                if (!admin) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Solo el administrador puede cambiar los servicios y '
                    'precios.',
                    style: muted,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: serviciosAsync.when(
              skipLoadingOnRefresh: true,
              data: (servicios) => _Lista(
                servicios: servicios,
                admin: admin,
                onRefresh: () async {
                  ref.invalidate(serviciosProvider);
                  await ref
                      .read(serviciosProvider.future)
                      .catchError((_) => <Servicio>[]);
                },
              ),
              loading: () => const _Esqueleto(),
              error: (_, _) =>
                  _Error(onReintentar: () => ref.invalidate(serviciosProvider)),
            ),
          ),
        ],
      ),
      floatingActionButton: admin
          ? _BotonNuevoServicio(puedeEscribir: puedeEscribir)
          : null,
    );
  }
}

/// En solo lectura (plan) conserva lugar, variante y tamaño; cambia el ícono
/// por el candado y el toque abre la hoja del plan.
class _BotonNuevoServicio extends ConsumerWidget {
  const _BotonNuevoServicio({required this.puedeEscribir});

  final bool puedeEscribir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> abrir() async {
      final ok = await asegurarEscritura(
        context,
        ref,
        plan: ref.read(miPlanProvider).value,
      );
      if (!ok || !context.mounted) return;
      await showServicioSheet(context);
    }

    final boton = FloatingActionButton.extended(
      onPressed: abrir,
      icon: Icon(iconoEscritura(puedeEscribir, Icons.add)),
      label: const Text('Nuevo servicio'),
    );
    if (puedeEscribir) return boton;
    return Semantics(
      button: true,
      label: semanticaEscritura(puedeEscribir, 'Nuevo servicio'),
      onTap: abrir,
      excludeSemantics: true,
      child: boton,
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({
    required this.servicios,
    required this.admin,
    required this.onRefresh,
  });

  final List<Servicio> servicios;
  final bool admin;
  final Future<void> Function() onRefresh;

  Future<void> _sugerir(
    BuildContext context,
    WidgetRef ref,
    String nombre,
  ) async {
    final ok = await asegurarEscritura(
      context,
      ref,
      plan: ref.read(miPlanProvider).value,
    );
    if (!ok || !context.mounted) return;
    await showServicioSheet(context, nombreSugerido: nombre);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (servicios.isEmpty) {
      return admin
          ? _Vacio(
              titulo: 'Aún no tienes servicios',
              mensaje: 'Agrega los que más cobras para cobrarlos con un toque.',
              sugerencias: Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in _kSugerencias)
                    AppFilterChip(
                      label: s,
                      selected: false,
                      onTap: () => _sugerir(context, ref, s),
                    ),
                ],
              ),
            )
          : const _Vacio(
              titulo: 'Aún no hay servicios',
              mensaje:
                  'El administrador de la clínica todavía no los ha agregado.',
            );
    }

    final ordenados = [
      ...servicios,
    ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          _kPaddingInferior,
        ),
        itemCount: ordenados.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _ServicioFila(
          key: ValueKey(ordenados[i].id),
          servicio: ordenados[i],
          onTap: admin
              ? () => showServicioSheet(context, servicio: ordenados[i])
              : null,
        ),
      ),
    );
  }
}

class _ServicioFila extends StatelessWidget {
  const _ServicioFila({super.key, required this.servicio, this.onTap});

  final Servicio servicio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56 - 2 * AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(servicio.nombre, style: textTheme.bodyLarge)),
            const SizedBox(width: AppSpacing.sm),
            Text(formatearCop(servicio.precioCop), style: textTheme.labelLarge),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.titulo, required this.mensaje, this.sugerencias});

  final String titulo;
  final String mensaje;
  final Widget? sugerencias;

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
              child: const Icon(
                Icons.medical_services_outlined,
                size: 32,
                color: AppColors.textSecondary,
              ),
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
            if (sugerencias != null) ...[
              const SizedBox(height: AppSpacing.md),
              sugerencias!,
            ],
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
              'No pudimos cargar los servicios.',
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
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => AppCard(
        child: Container(
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }
}
