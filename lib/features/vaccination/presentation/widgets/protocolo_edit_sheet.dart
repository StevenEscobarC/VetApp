import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/duraciones.dart';
import '../../domain/entities/protocolo.dart';
import '../../domain/vacuna_failure.dart';
import '../providers/protocolos_providers.dart';
import 'duracion_chips.dart';

const _intervalosSerie = [14, 21, 28, 30, 90];
const _intervalosRefuerzo = [180, 365, 1095];
const _duraciones = [30, 35, 84, 90, 180, 365, 1095];

List<int> _conActual(List<int> base, Iterable<int?> actuales) {
  final s = {...base, ...actuales.whereType<int>()}.toList()..sort();
  return s;
}

/// Hoja de edición del catálogo (D-01, D-03, D-04). [protocolo] null crea un
/// biológico nuevo de la clínica. Solo chips y stepper: nunca se escribe un
/// número (D-00).
Future<void> showProtocoloEditSheet(
  BuildContext context, {
  Protocolo? protocolo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ProtocoloEditSheet(protocolo: protocolo),
  );
}

class ProtocoloEditSheet extends ConsumerStatefulWidget {
  const ProtocoloEditSheet({super.key, this.protocolo});

  final Protocolo? protocolo;

  @override
  ConsumerState<ProtocoloEditSheet> createState() => _ProtocoloEditSheetState();
}

class _ProtocoloEditSheetState extends ConsumerState<ProtocoloEditSheet> {
  late int _dosis;
  late int _intervalo;
  int? _refuerzo;
  late Set<int> _duracionesSel;
  late TipoDosis _tipo;
  late String _especie; // perro | gato | ambos
  final _nombre = TextEditingController();
  bool _guardando = false;
  String? _errorNombre;
  String? _errorDuraciones;

  Protocolo? get _p => widget.protocolo;
  bool get _nuevo => _p == null;

  @override
  void initState() {
    super.initState();
    final p = _p;
    _dosis = p?.dosisSerie ?? 1;
    _intervalo = p?.intervaloSerieDias ?? 21;
    _refuerzo = p == null ? 365 : p.intervaloRefuerzoDias;
    _duracionesSel = p == null ? {365} : p.opcionesDuracionDias.toSet();
    _tipo = p?.tipo ?? TipoDosis.vacuna;
    _especie = 'ambos';
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  List<String> get _especies => switch (_especie) {
    'perro' => ['perro'],
    'gato' => ['gato'],
    _ => ['perro', 'gato'],
  };

  String _mensaje(Object e) => e is VacunaFailure
      ? e.message
      : 'No pudimos guardar el protocolo. Intenta de nuevo.';

  Future<void> _ejecutar(
    Future<void> Function() accion,
    String exito,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      await accion();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_mensaje(e))));
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _guardar() async {
    final nombre = _nuevo ? _nombre.text.trim() : _p!.nombre;
    setState(() {
      _errorNombre = nombre.isEmpty ? 'Escribe el nombre del biológico.' : null;
      _errorDuraciones = _nuevo && _duracionesSel.isEmpty
          ? 'Elige al menos una duración.'
          : null;
    });
    if (_errorNombre != null || _errorDuraciones != null) return;
    await _ejecutar(() async {
      await ref
          .read(protocolosActionsProvider)
          .guardar(
            codigo: _p?.codigo,
            nombre: nombre,
            tipo: _tipo,
            especies: _nuevo ? _especies : _p!.especies,
            dosisSerie: _dosis,
            intervaloSerieDias: _dosis > 1 ? _intervalo : null,
            intervaloRefuerzoDias: _refuerzo,
            opcionesDuracionDias: (_duracionesSel.toList()..sort()),
          );
    }, 'Protocolo guardado');
  }

  Future<bool> _confirmar({
    required String titulo,
    required String contenido,
    required String accion,
    bool destructiva = true,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(contenido),
        actions: [
          AppButton(
            label: 'Volver',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: accion,
            variant: destructiva
                ? AppButtonVariant.destructive
                : AppButtonVariant.text,
            expand: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _restablecer() async {
    final ok = await _confirmar(
      titulo: '¿Restablecer valores estándar?',
      contenido:
          'Se usarán los intervalos estándar para ${_p!.nombre}. Las dosis '
          'ya registradas no cambian.',
      accion: 'Restablecer',
      destructiva: false,
    );
    if (!ok || !mounted) return;
    await _ejecutar(
      () => ref.read(protocolosActionsProvider).restablecer(_p!.codigo),
      'Valores estándar restablecidos',
    );
  }

  Future<void> _desactivar() async {
    final ok = await _confirmar(
      titulo: '¿Desactivar ${_p!.nombre}?',
      contenido:
          'Ya no aparecerá al registrar dosis. Las dosis ya registradas se '
          'conservan.',
      accion: 'Desactivar',
    );
    if (!ok || !mounted) return;
    await _ejecutar(
      () => ref.read(protocolosActionsProvider).desactivar(_p!.codigo),
      'Biológico desactivado',
    );
  }

  Widget _stepper(TextTheme textTheme) {
    Widget boton(IconData icono, String tip, VoidCallback? onTap) => SizedBox(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      child: IconButton.outlined(
        tooltip: tip,
        icon: Icon(icono),
        onPressed: _guardando ? null : onTap,
      ),
    );
    return Row(
      children: [
        boton(
          Icons.remove,
          'Menos dosis',
          _dosis > 1 ? () => setState(() => _dosis--) : null,
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$_dosis',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall,
          ),
        ),
        boton(
          Icons.add,
          'Más dosis',
          _dosis < 6 ? () => setState(() => _dosis++) : null,
        ),
      ],
    );
  }

  Widget _chipsUnicos<T>({
    required String titulo,
    required List<(String, T)> opciones,
    required T actual,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (label, valor) in opciones)
              AppFilterChip(
                label: label,
                selected: valor == actual,
                onTap: () => onChanged(valor),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = _p;
    final opcionesDuracion = _conActual(_duraciones, _duracionesSel);
    final semanas = p?.edadMinDias == null ? null : p!.edadMinDias! ~/ 7;
    final puedeRestablecer = p != null && p.esSemilla && p.personalizado;
    final puedeDesactivar = p != null && !p.esSemilla;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p?.nombre ?? 'Nuevo biológico',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_nuevo) ...[
              AppTextField(
                label: 'Nombre',
                controller: _nombre,
                maxLength: 80,
                errorText: _errorNombre,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              _chipsUnicos<TipoDosis>(
                titulo: 'Tipo',
                opciones: const [
                  ('Vacuna', TipoDosis.vacuna),
                  (
                    'Desparasitación interna',
                    TipoDosis.desparasitacionInterna,
                  ),
                  (
                    'Desparasitación externa',
                    TipoDosis.desparasitacionExterna,
                  ),
                ],
                actual: _tipo,
                onChanged: (v) => setState(() => _tipo = v),
              ),
              const SizedBox(height: AppSpacing.md),
              _chipsUnicos<String>(
                titulo: 'Especie',
                opciones: const [
                  ('Perro', 'perro'),
                  ('Gato', 'gato'),
                  ('Ambos', 'ambos'),
                ],
                actual: _especie,
                onChanged: (v) => setState(() => _especie = v),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text('Dosis de la serie', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            _stepper(textTheme),
            if (_dosis > 1) ...[
              const SizedBox(height: AppSpacing.md),
              DuracionChips(
                titulo: 'Intervalo entre dosis',
                opciones: _conActual(_intervalosSerie, [_intervalo]),
                seleccion: _intervalo,
                onChanged: (v) => setState(() => _intervalo = v ?? _intervalo),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            DuracionChips(
              titulo: 'Refuerzo',
              opciones: _conActual(_intervalosRefuerzo, [_refuerzo]),
              seleccion: _refuerzo,
              incluirSinRefuerzo: true,
              onChanged: (v) => setState(() => _refuerzo = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Duraciones disponibles al registrar',
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final d in opcionesDuracion)
                  AppFilterChip(
                    label: etiquetaDuracion(d),
                    selected: _duracionesSel.contains(d),
                    onTap: () => setState(() {
                      if (!_duracionesSel.remove(d)) _duracionesSel.add(d);
                    }),
                  ),
              ],
            ),
            if (_errorDuraciones != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _errorDuraciones!,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            ],
            if (semanas != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Edad mínima: $semanas semanas',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Guardar cambios',
              isLoading: _guardando,
              onPressed: _guardar,
            ),
            if (puedeRestablecer) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Restablecer valores estándar',
                variant: AppButtonVariant.text,
                onPressed: _guardando ? null : _restablecer,
              ),
            ],
            if (puedeDesactivar) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Desactivar',
                variant: AppButtonVariant.destructive,
                onPressed: _guardando ? null : _desactivar,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
