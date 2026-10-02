import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/status/dosis_estado_chip.dart';
import '../../domain/entities/carne.dart';
import '../../domain/estado_dosis_ui.dart';
import '../providers/registrar_dosis_providers.dart';
import '../providers/vacuna_providers.dart';
import '../vacunacion_routes.dart';
import '../widgets/biologico_group_header.dart';
import '../widgets/carne_clinica_header.dart';
import '../widgets/compartir_carne_sheet.dart';
import '../widgets/dosis_registrada_snackbar.dart';
import '../widgets/dosis_card.dart';

/// Carné de vacunación completo de una mascota (`/pacientes/:id/carne`):
/// biológicos agrupados por urgencia, dosis vigente + Historial y las
/// acciones fijas abajo. El encabezado queda como primer hijo de la lista
/// para que 05-16 pueda anteponer el membrete de la clínica sin tocar el resto.
class CarneScreen extends ConsumerStatefulWidget {
  const CarneScreen({
    super.key,
    required this.mascotaId,
    this.abrirCompartir = false,
  });

  final String mascotaId;

  /// Abre la hoja "Compartir carné" tras el primer frame (`?compartir=1`).
  final bool abrirCompartir;

  @override
  ConsumerState<CarneScreen> createState() => _CarneScreenState();
}

class _CarneScreenState extends ConsumerState<CarneScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.abrirCompartir) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _compartir();
      });
    }
  }

  void _compartir() =>
      showCompartirCarneSheet(context, mascotaId: widget.mascotaId);

  Future<void> _registrar() async {
    final r = await context.push<DosisRegistrada>(
      rutaRegistrarDosis(mascotaId: widget.mascotaId),
    );
    if (r != null && mounted) {
      mostrarDosisRegistrada(context, r, onCompartir: _compartir);
    }
  }

  void _compartirDesdeBoton(int activas) {
    if (activas == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Registra al menos una dosis para compartir el carné'),
          ),
        );
      return;
    }
    _compartir();
  }

  @override
  Widget build(BuildContext context) {
    final carneAsync = ref.watch(carneProvider(widget.mascotaId));
    final activas = carneAsync.maybeWhen(
      data: (c) => c.dosis.where((d) => !d.anulada).length,
      orElse: () => 0,
    );
    return Scaffold(
      appBar: AppTopBar(
        title: 'Carné de vacunación',
        actions: [
          if (carneAsync.hasValue)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  '$activas dosis',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: carneAsync.when(
              data: (carne) => _Contenido(carne: carne),
              loading: () => const _Esqueleto(),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No pudimos cargar el carné. Intenta de nuevo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Reintentar',
                        variant: AppButtonVariant.outline,
                        expand: false,
                        onPressed: () => ref.invalidate(
                          carneProvider(widget.mascotaId),
                        ),
                      ),
                    ],
                  ),
                ),
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
                    label: 'Compartir carné',
                    icon: Icons.share_outlined,
                    variant: AppButtonVariant.outline,
                    onPressed: () => _compartirDesdeBoton(activas),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Registrar dosis',
                    icon: Icons.add,
                    onPressed: _registrar,
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

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

int _rango(EstadoCarne e) => switch (e) {
  EstadoCarne.vencida => 0,
  EstadoCarne.proxima => 1,
  _ => 2,
};

class _Contenido extends StatelessWidget {
  const _Contenido({required this.carne});

  final Carne carne;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final activas = carne.dosis.where((d) => !d.anulada).length;

    if (carne.biologicos.isEmpty && activas == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceMuted,
                ),
                child: const Icon(Icons.vaccines_outlined, size: 32),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Sin vacunas registradas', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Registra la primera dosis de ${carne.mascotaNombre} o la '
                'que ya trae en su carné de papel.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final grupos = [...carne.biologicos]
      ..sort((a, b) {
        final r = _rango(a.estado).compareTo(_rango(b.estado));
        return r != 0 ? r : a.biologicoNombre.compareTo(b.biologicoNombre);
      });
    final peor = carne.peorEstado;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        CarneClinicaHeader(carne: carne),
        if (activas >= 1 && peor != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                DosisEstadoChip(estado: dosisEstadoDe(peor)),
                if (carne.pendientes > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${carne.pendientes} pendientes',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final b in grupos) ...[
          _Grupo(carne: carne, biologico: b),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _Grupo extends StatefulWidget {
  const _Grupo({required this.carne, required this.biologico});

  final Carne carne;
  final BiologicoCarne biologico;

  @override
  State<_Grupo> createState() => _GrupoState();
}

class _GrupoState extends State<_Grupo> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final carne = widget.carne;
    final b = widget.biologico;
    final todas = carne.historialDe(b.codigoProtocolo);
    final vigente = todas.where((d) => d.id == b.ultimaDosisId).firstOrNull;
    final otras = todas.where((d) => d.id != vigente?.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BiologicoGroupHeader(
          nombre: b.biologicoNombre,
          tipo: b.tipo,
          estado: dosisEstadoDe(b.estado),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (vigente != null)
          DosisCard(
            dosis: vigente,
            biologico: b,
            mascotaId: carne.mascotaId,
            hoy: carne.hoy,
          ),
        if (otras.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => _abierto = !_abierto),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: Row(
                children: [
                  Text(
                    'Historial (${otras.length})',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(_abierto ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_abierto)
            for (final d in otras) ...[
              DosisCard(
                dosis: d,
                mascotaId: carne.mascotaId,
                hoy: carne.hoy,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ],
    );
  }
}
