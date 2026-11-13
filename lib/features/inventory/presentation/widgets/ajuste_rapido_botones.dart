import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../../domain/entities/movimiento_stock.dart';
import '../../domain/entities/producto.dart';
import 'ajuste_sheet.dart';
import 'ajuste_stock.dart';

enum _Pulsado { menos, mas }

/// Botones "−1" y "+" de la fila (UI-SPEC §2.1). El bloqueo en vuelo vive aquí
/// (estado por fila): mientras hay una petición ambos se deshabilitan y el
/// pulsado muestra un spinner, así que no hay ráfagas de toques dobles. En
/// solo lectura (plan) muestran candado y abren la hoja del plan.
class AjusteRapidoBotones extends ConsumerStatefulWidget {
  const AjusteRapidoBotones({super.key, required this.producto});

  final Producto producto;

  @override
  ConsumerState<AjusteRapidoBotones> createState() =>
      _AjusteRapidoBotonesState();
}

class _AjusteRapidoBotonesState extends ConsumerState<AjusteRapidoBotones> {
  _Pulsado? _enVuelo;

  Future<void> _ejecutar(_Pulsado cual, Future<void> Function() accion) async {
    if (_enVuelo != null) return;
    setState(() => _enVuelo = cual);
    try {
      if (!await asegurarEscritura(context, ref)) return;
      if (!mounted) return;
      await accion();
    } finally {
      if (mounted) setState(() => _enVuelo = null);
    }
  }

  Future<void> _descontar() => _ejecutar(
    _Pulsado.menos,
    () => descontarUno(context, ref, widget.producto),
  );

  Future<void> _agregar() async {
    // La hoja es modal y gestiona su propio estado: el bloqueo de la fila solo
    // cubre la verificación previa.
    if (_enVuelo != null) return;
    setState(() => _enVuelo = _Pulsado.mas);
    bool puede;
    try {
      puede = await asegurarEscritura(context, ref);
    } finally {
      if (mounted) setState(() => _enVuelo = null);
    }
    if (!puede || !mounted) return;
    await mostrarAjusteSheet(
      context,
      producto: widget.producto,
      motivoInicial: MotivoMovimiento.compra,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final puede = ref.watch(puedeEscribirProvider);
    final sinStock = p.cantidad <= 0;
    final enVuelo = _enVuelo != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Boton(
          botonKey: const ValueKey('ajuste-menos-uno'),
          puedeEscribir: puede,
          semantica: sinStock && puede
              ? 'Descontar 1, no hay stock'
              : 'Descontar 1',
          semanticaConNombre: 'Descontar 1 de ${p.nombre}',
          bloqueado: puede && sinStock,
          enVuelo: enVuelo,
          cargando: _enVuelo == _Pulsado.menos,
          icono: Icons.remove,
          etiqueta: '1',
          onTap: _descontar,
        ),
        const SizedBox(width: AppSpacing.sm),
        _Boton(
          botonKey: const ValueKey('ajuste-mas'),
          puedeEscribir: puede,
          semantica: 'Agregar stock',
          semanticaConNombre: 'Agregar stock a ${p.nombre}',
          bloqueado: false,
          enVuelo: enVuelo,
          cargando: _enVuelo == _Pulsado.mas,
          icono: Icons.add,
          onTap: _agregar,
        ),
      ],
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({
    required this.botonKey,
    required this.puedeEscribir,
    required this.semantica,
    required this.semanticaConNombre,
    required this.bloqueado,
    required this.enVuelo,
    required this.cargando,
    required this.icono,
    required this.onTap,
    this.etiqueta,
  });

  final Key botonKey;
  final bool puedeEscribir;

  /// Etiqueta base (sin producto); con candado se le añade "bloqueado".
  final String semantica;
  final String semanticaConNombre;

  /// Deshabilitado por regla de negocio (p. ej. sin stock).
  final bool bloqueado;
  final bool enVuelo;
  final bool cargando;
  final IconData icono;
  final String? etiqueta;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final activo = !bloqueado && !enVuelo;
    final boton = SizedBox.square(
      dimension: AppSpacing.touchTarget,
      child: OutlinedButton(
        key: botonKey,
        onPressed: activo ? onTap : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppSpacing.touchTarget),
          fixedSize: const Size.square(AppSpacing.touchTarget),
          disabledBackgroundColor: bloqueado ? AppColors.surfaceMuted : null,
          disabledForegroundColor: bloqueado ? AppColors.placeholder : null,
        ),
        child: cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconoEscritura(puedeEscribir, icono), size: 20),
                  if (etiqueta != null && puedeEscribir)
                    Text(
                      etiqueta!,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                ],
              ),
      ),
    );
    if (!puedeEscribir) {
      return ControlEscritura(
        puedeEscribir: false,
        label: semantica,
        onTap: onTap,
        child: boton,
      );
    }
    return Semantics(
      button: true,
      enabled: activo,
      label: bloqueado ? semantica : semanticaConNombre,
      onTap: activo ? onTap : null,
      excludeSemantics: true,
      child: boton,
    );
  }
}
