import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../cobros_rutas.dart';
import '../providers/cobros_providers.dart';
import 'estado_cobro_chip.dart';

/// Botón de entrada para cobrar desde otra pantalla (cita, consulta,
/// cliente). Vive en cobros y las demás features lo importan. Crear un cobro
/// es una escritura: en solo lectura conserva lugar, variante y tamaño, cambia
/// el ícono por el candado y abre la hoja del plan sin navegar (D-19).
class CobrarBoton extends ConsumerWidget {
  const CobrarBoton({
    super.key,
    required this.ruta,
    this.label = 'Cobrar',
    this.icono = Icons.receipt_long_outlined,
    this.variant = AppButtonVariant.outline,
  });

  /// Ruta del formulario (normalmente `rutaNuevoCobro(...)`).
  final String ruta;
  final String label;
  final IconData icono;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puedeEscribir = ref.watch(puedeEscribirProvider);

    Future<void> abrir() async {
      final ok = await asegurarEscritura(
        context,
        ref,
        plan: ref.read(miPlanProvider).value,
      );
      if (!ok || !context.mounted) return;
      context.push(ruta);
    }

    return ControlEscritura(
      puedeEscribir: puedeEscribir,
      label: label,
      onTap: abrir,
      child: AppButton(
        label: label,
        icon: iconoEscritura(puedeEscribir, icono),
        variant: variant,
        onPressed: abrir,
      ),
    );
  }
}

/// Estado de cobro de una cita o consulta: si ya tiene una cuenta de cobro
/// activa muestra la fila "Cobrada: CC-0012" con su estado, que abre el
/// detalle; si no (o mientras carga, o si la lectura falla) muestra
/// [siNoHay], normalmente un [CobrarBoton]. Nunca bloquea la pantalla que
/// lo contiene. Leer no es escribir: la fila nunca lleva candado.
class CobroVinculadoFila extends ConsumerWidget {
  const CobroVinculadoFila({
    super.key,
    this.citaId,
    this.consultaId,
    required this.siNoHay,
  });

  final String? citaId;
  final String? consultaId;
  final Widget siNoHay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vinculado = ref
        .watch(cobroVinculadoProvider((citaId: citaId, consultaId: consultaId)))
        .value;
    if (vinculado == null) return siNoHay;

    final texto = 'Cobrada: ${vinculado.numeroTexto}';
    return Semantics(
      button: true,
      label: '$texto, ${vinculado.estado.etiqueta}. Abrir detalle.',
      excludeSemantics: true,
      onTap: () => context.push(rutaCobro(vinculado.id)),
      child: InkWell(
        onTap: () => context.push(rutaCobro(vinculado.id)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  texto,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              ?EstadoCobroChip.para(vinculado.estado),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
