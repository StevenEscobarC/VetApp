import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import 'inicio_colores.dart';

/// Saludo de Inicio (UI-SPEC §1): reemplaza la barra superior, como en el
/// mockup. Con [nombre] `null` el perfil sigue cargando y las líneas 2-3 son
/// barras de esqueleto. Un solo nodo de semántica, marcado como encabezado.
class InicioEncabezado extends StatelessWidget {
  const InicioEncabezado({super.key, this.nombre, this.clinica});

  final String? nombre;
  final String? clinica;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nombre = this.nombre;
    final clinica = this.clinica ?? 'Sin clínica asignada';
    final tenue = InicioColores.tenue(context);

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hola,',
          style: t.bodyLarge?.copyWith(
            color: InicioColores.secundario(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (nombre == null) ...[
          _Barra(
            key: const ValueKey('encabezado-esqueleto-nombre'),
            ancho: 160,
            alto: 28,
          ),
          const SizedBox(height: AppSpacing.xs),
          _Barra(
            key: const ValueKey('encabezado-esqueleto-clinica'),
            ancho: 120,
            alto: 16,
          ),
        ] else ...[
          Text(
            nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.displaySmall?.copyWith(
              color: InicioColores.principal(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: tenue),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  clinica,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelLarge?.copyWith(color: tenue),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Semantics(
      header: true,
      label: nombre == null ? 'Hola,' : 'Hola, $nombre. $clinica',
      excludeSemantics: true,
      child: contenido,
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({super.key, required this.ancho, required this.alto});

  final double ancho;
  final double alto;

  @override
  Widget build(BuildContext context) => Container(
    width: ancho,
    height: alto,
    decoration: BoxDecoration(
      color: InicioColores.esqueleto(context),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
  );
}
