import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patients/domain/entities/mascota.dart';
import '../../../patients/presentation/providers/mascotas_providers.dart';
import '../../../patients/presentation/widgets/mascota_foto_avatar.dart';
import '../../domain/duraciones.dart';
import '../../domain/entities/carne.dart';
import '../../domain/entities/protocolo.dart';
import '../../domain/vacuna_failure.dart';
import '../providers/registrar_dosis_providers.dart';
import '../providers/vacuna_providers.dart';
import '../widgets/biologico_picker_sheet.dart';
import '../widgets/duracion_chips.dart';
import '../widgets/proxima_preview.dart';

/// Biológico efectivo del formulario (catálogo u "Otro").
typedef _Seleccion = ({
  String codigo,
  String nombre,
  int? duracion,
  bool sinRefuerzo,
  Protocolo? protocolo,
});

/// "Registrar dosis" (VAC-01, VAC-02): único destino de todos los puntos de
/// entrada (ficha, alertas, completar cita, "Vacunar"). Solo biológico y
/// fecha son obligatorios (D-06); la próxima fecha la calcula el servidor y
/// se muestra de solo lectura (D-02). Nunca se escribe una fecha a mano.
class RegistrarDosisScreen extends ConsumerStatefulWidget {
  const RegistrarDosisScreen({
    super.key,
    required this.mascotaId,
    this.codigoInicial,
    this.citaId,
    this.categoria,
  });

  final String mascotaId;

  /// Código de protocolo preseleccionado (alertas, tarjeta de dosis).
  final String? codigoInicial;

  /// Cita desde la que se abre (D-22); viaja con la dosis.
  final String? citaId;

  /// 'vacunacion' abre el selector; 'desparasitacion' preselecciona
  /// 'desp_interna'.
  final String? categoria;

  @override
  ConsumerState<RegistrarDosisScreen> createState() =>
      _RegistrarDosisScreenState();
}

class _RegistrarDosisScreenState extends ConsumerState<RegistrarDosisScreen> {
  final _nombreOtroCtrl = TextEditingController();
  final _clinicaCtrl = TextEditingController();
  final _productoCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  String? _codigo;
  bool _otro = false;
  int? _duracion;
  int _duracionOtro = 365;
  bool _sinRefuerzoOtro = false;
  DateTime? _fecha;
  bool _esRefuerzo = false;
  bool _iniciaSerie = false;
  bool _externa = false;
  bool _guardarEnCatalogo = true;
  bool _detalles = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _codigo =
        widget.codigoInicial ??
        (widget.categoria == 'desparasitacion' ? 'desp_interna' : null);
    if (_codigo == null && widget.categoria == 'vacunacion') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirSelector());
    }
  }

  @override
  void dispose() {
    _nombreOtroCtrl.dispose();
    _clinicaCtrl.dispose();
    _productoCtrl.dispose();
    _loteCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  DateTime get _hoy => diaBogota(ref.read(clockProvider)());

  static String _slug(String nombre) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final c in nombre.toLowerCase().split('')) {
      final i = de.indexOf(c);
      b.write(i < 0 ? c : a[i]);
    }
    final s = b
        .toString()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'x' : s;
  }

  _Seleccion? _seleccion(List<Protocolo>? lista) {
    if (_otro) {
      final nombre = _nombreOtroCtrl.text.trim();
      if (nombre.isEmpty) return null;
      return (
        codigo: 'otro:${_slug(nombre)}',
        nombre: nombre,
        duracion: _sinRefuerzoOtro ? null : _duracionOtro,
        sinRefuerzo: _sinRefuerzoOtro,
        protocolo: null,
      );
    }
    Protocolo? p;
    for (final x in lista ?? const <Protocolo>[]) {
      if (x.codigo == _codigo) p = x;
    }
    if (p == null) return null;
    int? duracion;
    if (p.opcionesDuracionDias.isNotEmpty) {
      final op = p.opcionesDuracionDias;
      duracion = _duracion != null && op.contains(_duracion)
          ? _duracion
          : (op.contains(p.intervaloRefuerzoDias)
                ? p.intervaloRefuerzoDias
                : op.first);
    }
    return (
      codigo: p.codigo,
      nombre: p.nombre,
      duracion: duracion,
      sinRefuerzo: false,
      protocolo: p,
    );
  }

  Future<void> _abrirSelector() async {
    final Mascota mascota;
    try {
      mascota = await ref.read(mascotaProvider(widget.mascotaId).future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final r = await showModalBottomSheet<BiologicoElegido>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BiologicoPickerSheet(
        mascotaId: widget.mascotaId,
        especie: mascota.especie.name,
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      final p = r.protocolo;
      _otro = p == null;
      _codigo = p?.codigo;
      _duracion = null;
      _esRefuerzo = false;
      _iniciaSerie = false;
    });
  }

  Future<void> _elegirFecha(Mascota mascota) async {
    final hoy = _hoy;
    final actual = _fecha ?? hoy;
    final nac = mascota.fechaNacimiento;
    final primera = (nac != null && !nac.isAfter(hoy))
        ? DateTime(nac.year, nac.month, nac.day)
        : DateTime(hoy.year - 20, hoy.month, hoy.day);
    var inicial = DateTime(actual.year, actual.month, actual.day);
    if (inicial.isBefore(primera)) inicial = primera;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primera,
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
    );
    if (elegida == null || !mounted) return;
    setState(
      () => _fecha = DateTime.utc(elegida.year, elegida.month, elegida.day),
    );
  }

  Future<void> _guardar(_Seleccion sel, bool esAdmin) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final r = await ref.read(registrarDosisProvider)(
        mascotaId: widget.mascotaId,
        codigo: sel.codigo,
        biologicoNombre: sel.nombre,
        fecha: _fecha ?? _hoy,
        duracionDias: sel.duracion,
        sinRefuerzo: sel.sinRefuerzo,
        esRefuerzo: _esRefuerzo,
        iniciaSerie: _iniciaSerie,
        externa: _externa,
        clinicaExterna: _externa ? _clinicaCtrl.text : null,
        producto: _productoCtrl.text,
        lote: _loteCtrl.text,
        observaciones: _observacionesCtrl.text,
        citaId: widget.citaId,
        guardarEnCatalogo: _otro && esAdmin && _guardarEnCatalogo,
      );
      if (!mounted) return;
      context.pop(r);
    } on VacunaFailure catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mascotaAsync = ref.watch(mascotaProvider(widget.mascotaId));
    return Scaffold(
      appBar: const AppTopBar(title: 'Registrar dosis'),
      body: mascotaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('No pudimos cargar la mascota. Intenta de nuevo.'),
          ),
        ),
        data: _formulario,
      ),
    );
  }

  Widget _formulario(Mascota mascota) {
    final textTheme = Theme.of(context).textTheme;
    final perfil = ref.watch(authProfileProvider).value;
    final esAdmin = perfil?.esAdmin ?? false;
    final protocolos = ref
        .watch(protocolosProvider(mascota.especie.name))
        .asData
        ?.value;
    final sel = _seleccion(protocolos);
    final hoy = _hoy;
    final fecha = _fecha ?? hoy;
    final esHoy = mismoDia(fecha, hoy);
    final carne = ref.watch(carneProvider(widget.mascotaId)).asData?.value;

    AsyncValue<PrevisualizacionDosis?>? preview;
    if (sel != null) {
      preview = ref.watch(
        previsualizacionDosisProvider((
          mascotaId: widget.mascotaId,
          codigo: sel.codigo,
          fecha: fecha,
          duracionDias: sel.duracion,
          sinRefuerzo: sel.sinRefuerzo,
          esRefuerzo: _esRefuerzo,
          iniciaSerie: _iniciaSerie,
        )),
      );
    }

    // Sugerencia (nunca obliga): serie multidosis sin historial en un animal
    // adulto o de edad desconocida (Pitfall 3).
    final p = sel?.protocolo;
    final nac = mascota.fechaNacimiento;
    final sinHistorial =
        carne != null &&
        !carne.biologicos.any((b) => b.codigoProtocolo == sel?.codigo);
    final mostrarRefuerzo =
        p != null &&
        p.dosisSerie > 1 &&
        sinHistorial &&
        (nac == null || hoy.difference(nac).inDays > 112);

    final productos =
        (ref.watch(productosRecientesProvider).asData?.value ??
                const <({String producto, String? lote})>[])
            .where(
              (x) =>
                  _productoCtrl.text.trim().isEmpty ||
                  (x.producto.toLowerCase().contains(
                        _productoCtrl.text.trim().toLowerCase(),
                      ) &&
                      x.producto.toLowerCase() !=
                          _productoCtrl.text.trim().toLowerCase()),
            )
            .toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MascotaFotoAvatar(fotoPath: mascota.fotoPath, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      mascota.nombre,
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_otro) ...[
                  AppTextField(
                    label: 'Nombre del biológico',
                    controller: _nombreOtroCtrl,
                    autofocus: true,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
                  AppButton(
                    label: 'Elegir del catálogo',
                    variant: AppButtonVariant.text,
                    expand: false,
                    onPressed: _abrirSelector,
                  ),
                ] else
                  AppCard(
                    onTap: _abrirSelector,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.touchTarget - AppSpacing.md * 2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Biológico', style: textTheme.labelLarge),
                                Text(
                                  sel?.nombre ?? 'Elige un biológico',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: sel == null
                                        ? AppColors.textMuted
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => _elegirFecha(mascota),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fecha de aplicación',
                              style: textTheme.labelLarge,
                            ),
                            Text(
                              esHoy
                                  ? 'Hoy · ${formatearFecha(fecha)}'
                                  : formatearFecha(fecha),
                              style: textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined),
                    ],
                  ),
                ),
                if (!esHoy) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Fecha pasada: se registrará como dosis histórica.',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (_otro) ...[
                  const SizedBox(height: AppSpacing.md),
                  DuracionChips(
                    titulo: 'Intervalo de refuerzo',
                    opciones: kIntervalosOtro,
                    seleccion: _sinRefuerzoOtro ? null : _duracionOtro,
                    incluirSinRefuerzo: true,
                    onChanged: (d) => setState(() {
                      if (d == null) {
                        _sinRefuerzoOtro = true;
                      } else {
                        _sinRefuerzoOtro = false;
                        _duracionOtro = d;
                      }
                    }),
                  ),
                  if (esAdmin) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Guardar en mi catálogo'),
                      subtitle: const Text('Aparecerá en Más > Protocolos.'),
                      value: _guardarEnCatalogo,
                      onChanged: (v) => setState(() => _guardarEnCatalogo = v),
                    ),
                  ],
                ] else if (p != null && p.opcionesDuracionDias.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  DuracionChips(
                    titulo: 'Duración del producto',
                    opciones: p.opcionesDuracionDias,
                    seleccion: sel!.duracion,
                    onChanged: (d) => setState(() => _duracion = d),
                  ),
                ],
                if (preview != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ProximaPreview(
                    preview: preview,
                    hoy: _hoy,
                    iniciaSerie: _iniciaSerie,
                    onReiniciar: (v) => setState(() => _iniciaSerie = v),
                  ),
                ],
                if (mostrarRefuerzo)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Ya tenía la serie completa (registrar como refuerzo)',
                    ),
                    value: _esRefuerzo,
                    onChanged: (v) => setState(() => _esRefuerzo = v),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aplicada en otra clínica'),
                  value: _externa,
                  onChanged: (v) => setState(() => _externa = v),
                ),
                if (_externa) ...[
                  AppTextField(
                    label: 'Nombre de la clínica (opcional)',
                    controller: _clinicaCtrl,
                    maxLength: 80,
                    helperText: 'Se mostrará diferenciada en el carné.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                InkWell(
                  onTap: () => setState(() => _detalles = !_detalles),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.touchTarget,
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Agregar más detalles',
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        Icon(
                          _detalles
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_detalles) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Producto / marca',
                    controller: _productoCtrl,
                    maxLength: 80,
                    onChanged: (_) => setState(() {}),
                  ),
                  for (final x in productos)
                    InkWell(
                      onTap: () => setState(() {
                        _productoCtrl.text = x.producto;
                        _loteCtrl.text = x.lote ?? '';
                      }),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppSpacing.touchTarget,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                x.producto,
                                style: textTheme.bodyLarge,
                              ),
                            ),
                            if (x.lote != null)
                              Text(
                                'Último lote: ${x.lote}',
                                style: textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Lote',
                    controller: _loteCtrl,
                    maxLength: 40,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Observaciones',
                    controller: _observacionesCtrl,
                    maxLines: 3,
                    maxLength: 500,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
                if (!_externa && perfil != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      VetAvatar(nombre: perfil.nombre, size: 24),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Aplicó: Dr(a). ${perfil.nombre}',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: 'Guardar dosis',
              isLoading: _loading,
              onPressed: sel == null || _loading
                  ? null
                  : () => _guardar(sel, esAdmin),
            ),
          ),
        ),
      ],
    );
  }
}
