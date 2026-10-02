import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/dosis_estado_chip.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../domain/entities/carne.dart';
import '../../domain/estado_dosis_ui.dart';
import 'anular_dosis_sheet.dart';

/// Tarjeta de una dosis del carné. La dosis vigente de un biológico recibe su
/// [biologico] (estado y próxima fecha derivados por el servidor, D-02: aquí
/// nunca se calculan fechas); las del Historial van sin él y más compactas.
/// Las anuladas se muestran tachadas y sin acciones (D-08).
class DosisCard extends StatelessWidget {
  const DosisCard({
    super.key,
    required this.dosis,
    required this.mascotaId,
    required this.hoy,
    this.biologico,
  });

  final DosisCarne dosis;
  final String mascotaId;
  final DateTime hoy;
  final BiologicoCarne? biologico;

  String? get _etiqueta =>
      dosis.etiquetaDosis ?? (dosis.esRefuerzo ? 'Refuerzo' : null);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final anulada = dosis.anulada;
    final bio = anulada ? null : biologico;
    final estado = bio == null ? null : dosisEstadoDe(bio.estado);
    final proxima = bio?.proximaFecha;
    final vencida = bio?.estado == EstadoCarne.vencida;

    final colorStripe = anulada
        ? AppColors.border
        : switch (estado) {
            DosisEstado.vencida => AppColors.destructive,
            DosisEstado.proxima => AppColors.warning,
            DosisEstado.alDia => AppColors.success,
            _ => AppColors.border,
          };
    final colorTexto = anulada ? AppColors.textMuted : null;
    final tachado = anulada ? TextDecoration.lineThrough : null;
    final estiloCuerpo = textTheme.bodyLarge?.copyWith(
      color: colorTexto,
      decoration: tachado,
    );
    final estiloLabel = textTheme.labelMedium?.copyWith(
      color: anulada ? AppColors.textMuted : AppColors.textSecondary,
      decoration: tachado,
    );
    final etiqueta = _etiqueta;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _semantica(estado, proxima),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: colorStripe,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    top: AppSpacing.sm,
                    bottom: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (etiqueta != null)
                                  _Tag(texto: etiqueta, anulada: anulada),
                                if (anulada)
                                  const DosisEstadoChip(
                                    estado: DosisEstado.anulada,
                                    compact: true,
                                  )
                                else if (estado != null)
                                  DosisEstadoChip(estado: estado),
                                if (dosis.externa)
                                  const DosisEstadoChip(
                                    estado: DosisEstado.externa,
                                    compact: true,
                                  ),
                              ],
                            ),
                          ),
                          if (!anulada)
                            PopupMenuButton<String>(
                              tooltip: 'Más acciones',
                              icon: const Icon(Icons.more_vert),
                              padding: const EdgeInsets.all(12),
                              onSelected: (_) => showAnularDosisSheet(
                                context,
                                dosis,
                                mascotaId: mascotaId,
                              ),
                              itemBuilder: (_) => [
                                PopupMenuItem<String>(
                                  value: 'anular',
                                  child: Text(
                                    'Anular dosis',
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: AppColors.destructive,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox(width: AppSpacing.md),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aplicada: ${formatearFecha(dosis.fechaAplicacion)}',
                              style: estiloCuerpo,
                            ),
                            if (bio != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                proxima == null
                                    ? 'Sin refuerzo'
                                    : 'Próxima: ${formatearFecha(proxima)}',
                                style: estiloCuerpo,
                              ),
                              if (vencida && proxima != null)
                                Text(
                                  textoVencimiento(proxima, hoy),
                                  style: textTheme.labelMedium?.copyWith(
                                    color: AppColors.destructive,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                            if (_producto != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(_producto!, style: estiloLabel),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                            _Atribucion(dosis: dosis, estilo: estiloLabel),
                            if (anulada) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Anulada: ${dosis.motivoAnulacion ?? ''}',
                                style: textTheme.labelMedium?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (dosis.anuladaAt != null)
                                Text(
                                  formatearFecha(aBogota(dosis.anuladaAt!)),
                                  style: textTheme.labelMedium?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? get _producto {
    final p = dosis.producto;
    final l = dosis.lote;
    final tieneP = p != null && p.isNotEmpty;
    final tieneL = l != null && l.isNotEmpty;
    if (!tieneP && !tieneL) return null;
    return [
      if (tieneP) 'Producto: $p',
      if (tieneL) 'Lote: $l',
    ].join(' · ');
  }

  String _semantica(DosisEstado? estado, DateTime? proxima) {
    final partes = <String>[
      dosis.biologicoNombre,
      ?_etiqueta,
      if (dosis.anulada) 'anulada' else ?_etiquetaEstado(estado),
      'aplicada el ${formatearFecha(dosis.fechaAplicacion)}',
      if (!dosis.anulada && proxima != null)
        'próxima el ${formatearFecha(proxima)}',
      if (dosis.veterinario != null) 'aplicó ${dosis.veterinario!.nombre}',
    ];
    return partes.join(', ');
  }

  String? _etiquetaEstado(DosisEstado? e) => switch (e) {
    DosisEstado.alDia => 'al día',
    DosisEstado.proxima => 'próxima',
    DosisEstado.vencida => 'vencida',
    _ => null,
  };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.texto, required this.anulada});

  final String texto;
  final bool anulada;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: anulada ? AppColors.textMuted : null,
        ),
      ),
    );
  }
}

/// Quién aplicó la dosis: en un certificado siempre con matrícula (D-09);
/// veterinarios inactivos se marcan "(retirado)"; las externas citan la
/// clínica de origen (D-07).
class _Atribucion extends StatelessWidget {
  const _Atribucion({required this.dosis, required this.estilo});

  final DosisCarne dosis;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    if (dosis.externa) {
      final c = dosis.clinicaExterna;
      return Text(
        (c == null || c.isEmpty)
            ? 'Aplicada en otra clínica'
            : 'Aplicada en $c',
        style: estilo,
      );
    }
    final vet = dosis.veterinario;
    if (vet == null) return const SizedBox.shrink();
    final mat = vet.matricula;
    final texto =
        'Aplicó: Dr(a). ${vet.nombre}'
        '${(mat == null || mat.isEmpty) ? '' : ' · Mat. $mat'}';
    return Row(
      children: [
        VetAvatar(nombre: vet.nombre, size: 24, retirado: !vet.activo),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: texto,
              children: [
                if (!vet.activo)
                  TextSpan(
                    text: ' (retirado)',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
            style: estilo,
          ),
        ),
      ],
    );
  }
}
