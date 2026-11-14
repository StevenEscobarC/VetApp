import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../domain/cobro_failure.dart';
import '../../domain/entities/servicio.dart';
import '../providers/cobros_providers.dart';

const String _kSinPermiso =
    'Solo el administrador de la clínica puede hacer esto.';

/// Hoja "Nuevo servicio" / "Editar servicio" (D-06). Con [servicio] edita y
/// ofrece "Quitar servicio", que archiva (nunca borra): los cobros ya emitidos
/// conservan su descripción y precio copiados. [nombreSugerido] viene de las
/// sugerencias del estado vacío: solo el nombre, nunca un precio inventado.
Future<void> showServicioSheet(
  BuildContext context, {
  Servicio? servicio,
  String? nombreSugerido,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ServicioSheet(
      servicio: servicio,
      nombreSugerido: nombreSugerido,
      messenger: messenger,
    ),
  );
}

class _ServicioSheet extends ConsumerStatefulWidget {
  const _ServicioSheet({
    required this.servicio,
    required this.nombreSugerido,
    required this.messenger,
  });

  final Servicio? servicio;
  final String? nombreSugerido;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_ServicioSheet> createState() => _ServicioSheetState();
}

class _ServicioSheetState extends ConsumerState<_ServicioSheet> {
  late final _nombreCtrl = TextEditingController(
    text: widget.servicio?.nombre ?? widget.nombreSugerido ?? '',
  );
  late final _precioCtrl = TextEditingController(
    text: widget.servicio == null ? '' : '${widget.servicio!.precioCop}',
  );
  String? _errNombre;
  String? _errPrecio;
  bool _guardando = false;

  bool get _esEdicion => widget.servicio != null;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  void _avisar(String texto) {
    widget.messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Límite del plan primero (abre su hoja y conserva los datos); luego el
  /// mensaje en línea o en un aviso.
  Future<void> _manejar(CobroFailure e) async {
    if (await manejarLimitePlan(context, ref, e)) return;
    if (!mounted) return;
    switch (e.tipo) {
      case ErrorCobro.nombreDuplicado:
        setState(() => _errNombre = 'Ya tienes un servicio con ese nombre.');
      case ErrorCobro.sinPermiso:
        _avisar(_kSinPermiso);
      default:
        _avisar(e.message);
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final nombre = _nombreCtrl.text.trim();
    final precio = parsearCop(_precioCtrl.text);
    final errPrecio = _precioCtrl.text.trim().isEmpty
        ? 'Escribe el precio (puede ser 0).'
        : precio.error;
    setState(() {
      _errNombre = nombre.isEmpty ? 'Escribe el nombre del servicio.' : null;
      _errPrecio = errPrecio;
    });
    if (_errNombre != null || _errPrecio != null) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(cobrosActionsProvider)
          .guardarServicio(
            id: widget.servicio?.id,
            nombre: nombre,
            precioCop: precio.valor!,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _avisar('«$nombre» guardado.');
    } on CobroFailure catch (e) {
      if (mounted) await _manejar(e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _quitar() async {
    final servicio = widget.servicio!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar «${servicio.nombre}»?'),
        content: const Text(
          'Ya no aparecerá al cobrar. Los cobros anteriores no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await ref.read(cobrosActionsProvider).archivarServicio(servicio.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      _avisar('«${servicio.nombre}» quitado.');
    } on CobroFailure catch (e) {
      if (mounted) await _manejar(e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Con un nombre sugerido el foco va al precio, que es lo que falta.
    final enfocarPrecio = !_esEdicion && widget.nombreSugerido != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _esEdicion ? 'Editar servicio' : 'Nuevo servicio',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nombre del servicio',
              controller: _nombreCtrl,
              autofocus: !enfocarPrecio,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              errorText: _errNombre,
              enabled: !_guardando,
              onChanged: (_) {
                if (_errNombre != null) setState(() => _errNombre = null);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Precio',
              controller: _precioCtrl,
              autofocus: enfocarPrecio,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 9,
              prefixText: '\$ ',
              helperText:
                  'En pesos, sin decimales. Es el precio sugerido; en cada '
                  'cobro se puede cambiar.',
              errorText: _errPrecio,
              enabled: !_guardando,
              onChanged: (_) {
                if (_errPrecio != null) setState(() => _errPrecio = null);
              },
              onFieldSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Guardar servicio',
              isLoading: _guardando,
              onPressed: _guardar,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Cancelar',
              variant: AppButtonVariant.text,
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            ),
            if (_esEdicion) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
                ),
                onPressed: _guardando ? null : _quitar,
                child: const Text('Quitar servicio'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
