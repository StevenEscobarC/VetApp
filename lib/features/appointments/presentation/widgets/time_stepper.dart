import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';

/// Selector de hora en pasos de 15 min con botones grandes (D-06): nunca un
/// reloj analógico. [minutos] son minutos desde la medianoche de Bogotá.
/// Mantener presionado repite el paso cada 150 ms.
class TimeStepper extends StatelessWidget {
  const TimeStepper({
    super.key,
    required this.minutos,
    required this.onCambio,
    this.habilitado = true,
    this.ayuda,
    this.fin,
  });

  static const minimo = 6 * 60;
  static const maximo = 22 * 60;
  static const paso = 15;

  /// Alto/ancho de los botones: objetivo táctil grande para uso con una mano.
  static const double _boton = 64;

  final int? minutos;
  final ValueChanged<int> onCambio;
  final bool habilitado;
  final String? ayuda;

  /// Texto "Termina a las ..." ya formateado (null lo oculta).
  final String? fin;

  static String formato(int minutos) =>
      hora12(DateTime.utc(2000, 1, 1, minutos ~/ 60, minutos % 60));

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final m = minutos;
    final activo = habilitado && m != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PasoBoton(
              icono: Icons.remove,
              etiqueta: 'Restar 15 minutos',
              onPaso: activo && m > minimo ? () => onCambio(m - paso) : null,
            ),
            Text(
              m == null ? '—' : formato(m),
              style: textTheme.displaySmall?.copyWith(fontSize: 28),
            ),
            _PasoBoton(
              icono: Icons.add,
              etiqueta: 'Sumar 15 minutos',
              onPaso: activo && m < maximo ? () => onCambio(m + paso) : null,
            ),
          ],
        ),
        if (ayuda != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            ayuda!,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (fin != null)
          Text(
            fin!,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// Minutos desde medianoche de la hora de pared de Bogotá de [instante].
int minutosDelDia(DateTime instante) {
  final b = aBogota(instante);
  return b.hour * 60 + b.minute;
}

class _PasoBoton extends StatefulWidget {
  const _PasoBoton({
    required this.icono,
    required this.etiqueta,
    required this.onPaso,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onPaso;

  @override
  State<_PasoBoton> createState() => _PasoBotonState();
}

class _PasoBotonState extends State<_PasoBoton> {
  Timer? _repetir;

  void _parar() {
    _repetir?.cancel();
    _repetir = null;
  }

  @override
  void dispose() {
    _parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.etiqueta,
      button: true,
      child: Tooltip(
        message: widget.etiqueta,
        child: GestureDetector(
          onLongPressStart: widget.onPaso == null
              ? null
              : (_) => _repetir = Timer.periodic(
                  const Duration(milliseconds: 150),
                  (_) => widget.onPaso?.call(),
                ),
          onLongPressEnd: (_) => _parar(),
          onLongPressCancel: _parar,
          child: SizedBox(
            width: TimeStepper._boton,
            height: TimeStepper._boton,
            child: OutlinedButton(
              onPressed: widget.onPaso,
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: Icon(widget.icono),
            ),
          ),
        ),
      ),
    );
  }
}
