import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/entities/consulta.dart';
import '../../domain/formato_consulta.dart';
import '../providers/consultas_providers.dart';

/// Línea de tiempo de historia clínica (HIST-02) en la ficha del paciente:
/// más reciente primero, ordenada de forma defensiva por [Consulta.fecha]
/// — nunca se confía en el orden que entrega la fuente de datos (mismo
/// criterio que `_HistorialPeso`). Cada tarjeta se expande en el mismo
/// lugar (sin navegación, sin pantalla nueva) al registro completo.
/// Append-only por construcción (HIST-04): ninguna tarjeta ofrece editar
/// ni borrar — una corrección siempre aparece como una consulta nueva
/// arriba de esta misma lista.
class HistoriaClinicaTimeline extends ConsumerWidget {
  const HistoriaClinicaTimeline({super.key, required this.mascotaId});

  final String mascotaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultasAsync = ref.watch(consultasProvider(mascotaId));
    final textTheme = Theme.of(context).textTheme;

    return consultasAsync.when(
      data: (consultas) {
        if (consultas.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aún no hay consultas registradas',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Usa “Nueva consulta” para agregar la primera.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        }

        final ordenadas = List<Consulta>.of(consultas)
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

        return Column(
          children: [
            for (var i = 0; i < ordenadas.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _ConsultaCard(consulta: ordenadas[i]),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text(
        'No pudimos cargar la historia clínica. Intenta de nuevo.',
      ),
    );
  }
}

/// Tarjeta de una consulta: colapsada muestra solo fecha + diagnóstico;
/// tocarla en cualquier parte (toda la tarjeta es el área tocable, per
/// `AppCard.onTap`) la expande en el mismo lugar al registro completo.
/// Estado puramente local (`_expandida`) — sin `IconButton`, sin ícono de
/// editar/borrar, sin gesto de long-press ni swipe (HIST-04).
class _ConsultaCard extends StatefulWidget {
  const _ConsultaCard({required this.consulta});

  final Consulta consulta;

  @override
  State<_ConsultaCard> createState() => _ConsultaCardState();
}

class _ConsultaCardState extends State<_ConsultaCard> {
  bool _expandida = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final consulta = widget.consulta;

    return AppCard(
      onTap: () => setState(() => _expandida = !_expandida),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatearFecha(consulta.fecha),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Icon(
                _expandida
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: AppColors.textMuted,
              ),
            ],
          ),
          Text(
            consulta.diagnostico,
            style: textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_expandida) ..._detalle(textTheme, consulta),
        ],
      ),
    );
  }

  /// Orden fijo (UI-SPEC "Consulta timeline entry"): Anamnesis, Examen
  /// físico, Diagnóstico (repetido en full), Tratamiento, Evolución. Nunca
  /// una línea vacía — "Sin registrar" cubre cualquier campo opcional sin
  /// llenar.
  List<Widget> _detalle(TextTheme textTheme, Consulta consulta) {
    final examen = consulta.examenFisico;

    return [
      const SizedBox(height: AppSpacing.sm),
      Text('Anamnesis', style: textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Text(
        consulta.anamnesis ?? 'Sin registrar',
        style: textTheme.bodyLarge?.copyWith(
          color: consulta.anamnesis == null ? AppColors.textMuted : null,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (examen.estaVacio)
        Text('Examen físico: Sin registrar', style: textTheme.bodyLarge)
      else ...[
        Text('Examen físico', style: textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        for (final linea in lineasExamenFisico(examen))
          Text(linea, style: textTheme.bodyLarge),
      ],
      const SizedBox(height: AppSpacing.sm),
      Text('Diagnóstico', style: textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Text(consulta.diagnostico, style: textTheme.bodyLarge),
      const SizedBox(height: AppSpacing.sm),
      Text('Tratamiento', style: textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Text(consulta.tratamiento, style: textTheme.bodyLarge),
      const SizedBox(height: AppSpacing.sm),
      Text('Evolución', style: textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Text(
        consulta.evolucion ?? 'Sin registrar',
        style: textTheme.bodyLarge?.copyWith(
          color: consulta.evolucion == null ? AppColors.textMuted : null,
        ),
      ),
    ];
  }
}
