import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/inicio_failure.dart';
import 'inicio_colores.dart';

/// Error de un solo bloque de Inicio (D-14, UI-SPEC §7): el resto de la
/// pantalla sigue funcionando. Neutro, nunca rojo, porque una lectura fallida
/// no es destructiva. Solo muestra [InicioFailure.message] (texto fijo de la
/// capa de datos), nunca el texto crudo de una excepción.
class BloqueError extends StatelessWidget {
  const BloqueError({
    super.key,
    required this.failure,
    required this.onReintentar,
    this.cargando = false,
  });

  final InicioFailure failure;
  final VoidCallback onReintentar;

  /// Spinner en "Reintentar" mientras corre el reintento.
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final color = InicioColores.secundario(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              failure.sinConexion ? Icons.wifi_off : Icons.error_outline,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                failure.message,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: color),
              ),
            ),
          ),
          AppButton(
            label: 'Reintentar',
            variant: AppButtonVariant.text,
            expand: false,
            isLoading: cargando,
            onPressed: onReintentar,
          ),
        ],
      ),
    );
  }
}
