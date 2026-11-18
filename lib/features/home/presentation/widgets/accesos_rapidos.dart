import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../appointments/presentation/agenda_routes.dart';
import '../../../billing/presentation/cobros_rutas.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../../../vaccination/presentation/widgets/mascota_search_sheet.dart';
import 'inicio_colores.dart';

/// Diámetro del círculo de color de cada acceso (UI-SPEC §4).
const double _kCirculo = 56;

/// Accesos rápidos de Inicio (DASH-03, D-10): Paciente · Cita · Cobro ·
/// Vacunar. En solo lectura cada uno conserva su relleno, cambia el ícono por
/// el candado y abre la hoja explicativa sin ejecutar la acción (D-11).
class AccesosRapidos extends ConsumerWidget {
  const AccesosRapidos({super.key});

  Future<void> _paciente(BuildContext context, WidgetRef ref) async {
    // Escritura primero y luego el tope de pacientes, como toda entrada.
    if (!await asegurarNuevoPaciente(
      context,
      ref,
      plan: ref.read(miPlanProvider).value,
    )) {
      return;
    }
    if (!context.mounted) return;
    unawaited(context.push('/clientes/nuevo'));
  }

  Future<void> _escribir(
    BuildContext context,
    WidgetRef ref,
    void Function() accion,
  ) async {
    if (!await asegurarEscritura(
      context,
      ref,
      plan: ref.read(miPlanProvider).value,
    )) {
      return;
    }
    if (!context.mounted) return;
    accion();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puede = ref.watch(puedeEscribirProvider);
    final items = [
      AccesoRapido(
        label: 'Paciente',
        semantica: 'Nuevo paciente',
        icono: Icons.person_add_alt_1_outlined,
        relleno: AppColors.primary,
        puedeEscribir: puede,
        onTap: () => _paciente(context, ref),
      ),
      AccesoRapido(
        label: 'Cita',
        semantica: 'Nueva cita',
        icono: Icons.event_outlined,
        relleno: AppColors.success,
        puedeEscribir: puede,
        onTap: () => _escribir(
          context,
          ref,
          () => unawaited(context.push(rutaNuevaCita())),
        ),
      ),
      AccesoRapido(
        label: 'Cobro',
        semantica: 'Nueva cuenta de cobro',
        icono: Icons.receipt_long_outlined,
        relleno: AppColors.textSecondary,
        puedeEscribir: puede,
        onTap: () => _escribir(
          context,
          ref,
          () => unawaited(context.push(rutaNuevoCobro())),
        ),
      ),
      AccesoRapido(
        label: 'Vacunar',
        semantica: 'Vacunar',
        icono: Icons.vaccines_outlined,
        relleno: AppColors.primaryStrong,
        puedeEscribir: puede,
        onTap: () => _escribir(
          context,
          ref,
          () => unawaited(showMascotaSearchSheet(context)),
        ),
      ),
    ];

    // Por encima de 1,3x las 4 etiquetas no caben en una fila: 2×2.
    final grande = MediaQuery.textScalerOf(context).scale(16) > 20.8;
    final rejilla = grande
        ? LayoutBuilder(
            builder: (context, constraints) => Wrap(
              children: [
                for (final i in items)
                  SizedBox(width: constraints.maxWidth / 2, child: i),
              ],
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final i in items) Expanded(child: i)],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Accesos rápidos',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: InicioColores.principal(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        rejilla,
      ],
    );
  }
}

/// Un acceso rápido: círculo de color con ícono blanco y etiqueta debajo.
/// [relleno] no depende del modo (UI-SPEC Color). [semantica] es lo que oye
/// el lector de pantalla ("Nueva cuenta de cobro", no solo "Cobro").
class AccesoRapido extends StatelessWidget {
  const AccesoRapido({
    super.key,
    required this.label,
    required this.semantica,
    required this.icono,
    required this.relleno,
    required this.onTap,
    required this.puedeEscribir,
  });

  final String label;
  final String semantica;
  final IconData icono;
  final Color relleno;
  final VoidCallback onTap;
  final bool puedeEscribir;

  @override
  Widget build(BuildContext context) {
    final contenido = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppSpacing.touchTarget,
          minHeight: AppSpacing.touchTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _kCirculo,
                height: _kCirculo,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: relleno,
                ),
                child: Icon(
                  iconoEscritura(puedeEscribir, icono),
                  size: 24,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: InicioColores.secundario(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return ControlEscritura(
      puedeEscribir: puedeEscribir,
      label: semantica,
      onTap: onTap,
      child: puedeEscribir
          ? Semantics(
              button: true,
              label: semantica,
              onTap: onTap,
              excludeSemantics: true,
              child: contenido,
            )
          : contenido,
    );
  }
}
