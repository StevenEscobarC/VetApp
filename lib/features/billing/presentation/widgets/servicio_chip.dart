import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Píldora de borde que agrega una línea al tocarla (UI-SPEC §3): `+` y
/// "Consulta · $ 50.000". Sin acento: el acento del formulario es el CTA.
/// Con [precio] `null` muestra solo el nombre (chip "Otro"). Con
/// [habilitado] en `false` se dibuja igual y no responde.
class ServicioChip extends StatelessWidget {
  const ServicioChip({
    super.key,
    required this.nombre,
    required this.onTap,
    this.precio,
    this.habilitado = true,
  });

  final String nombre;

  /// Precio ya formateado ("$ 50.000").
  final String? precio;
  final VoidCallback onTap;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final texto = precio == null ? nombre : '$nombre · $precio';
    return Semantics(
      button: true,
      enabled: habilitado,
      label: precio == null ? 'Agregar $nombre' : 'Agregar $nombre, $precio',
      excludeSemantics: true,
      onTap: habilitado ? onTap : null,
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 16, color: AppColors.foreground),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
