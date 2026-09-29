import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/consulta_failure.dart';
import '../providers/consultas_providers.dart';

/// "Nueva consulta" (HIST-01) — create-only form, alcanzable únicamente
/// desde el botón "Nueva consulta" de la ficha (`/pacientes/:id`,
/// `/clientes/:id/mascotas/:mascotaId`): [mascotaId] siempre llega conocido,
/// nunca se re-pregunta, misma disciplina que `MascotaFormScreen`. Solo
/// Diagnóstico y Tratamiento son obligatorios (D-03) — anamnesis, examen
/// físico (incl. peso) y evolución viven detrás de "Agregar más detalles" y
/// nunca bloquean el guardado. Sin diálogo de confirmación al volver: es un
/// formulario de solo-creación, igual que todos los demás en esta app.
class ConsultaFormScreen extends ConsumerStatefulWidget {
  const ConsultaFormScreen({super.key, required this.mascotaId});

  final String mascotaId;

  @override
  ConsumerState<ConsultaFormScreen> createState() =>
      _ConsultaFormScreenState();
}

class _ConsultaFormScreenState extends ConsumerState<ConsultaFormScreen> {
  final _diagnosticoCtrl = TextEditingController();
  final _tratamientoCtrl = TextEditingController();
  final _anamnesisCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _temperaturaCtrl = TextEditingController();
  final _frecuenciaCardiacaCtrl = TextEditingController();
  final _frecuenciaRespiratoriaCtrl = TextEditingController();
  final _mucosasCtrl = TextEditingController();
  final _evolucionCtrl = TextEditingController();

  bool _detallesExpandidos = false;
  bool _loading = false;
  String? _error;
  String? _pesoError;
  String? _temperaturaError;
  String? _frecuenciaCardiacaError;
  String? _frecuenciaRespiratoriaError;

  @override
  void initState() {
    super.initState();
    _diagnosticoCtrl.addListener(_onCamposCambiaron);
    _tratamientoCtrl.addListener(_onCamposCambiaron);
  }

  @override
  void dispose() {
    _diagnosticoCtrl.dispose();
    _tratamientoCtrl.dispose();
    _anamnesisCtrl.dispose();
    _pesoCtrl.dispose();
    _temperaturaCtrl.dispose();
    _frecuenciaCardiacaCtrl.dispose();
    _frecuenciaRespiratoriaCtrl.dispose();
    _mucosasCtrl.dispose();
    _evolucionCtrl.dispose();
    super.dispose();
  }

  void _onCamposCambiaron() => setState(() {});

  bool get _puedeGuardar =>
      !_loading &&
      _diagnosticoCtrl.text.trim().isNotEmpty &&
      _tratamientoCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_loading) return;
    final peso = parsearPeso(_pesoCtrl.text);
    final temperatura = parsearNumeroPositivo(
      _temperaturaCtrl.text,
      maximo: 999.9,
    );
    final frecuenciaCardiaca = parsearNumeroPositivo(
      _frecuenciaCardiacaCtrl.text,
      entero: true,
    );
    final frecuenciaRespiratoria = parsearNumeroPositivo(
      _frecuenciaRespiratoriaCtrl.text,
      entero: true,
    );

    if (peso.error != null ||
        temperatura.error != null ||
        frecuenciaCardiaca.error != null ||
        frecuenciaRespiratoria.error != null) {
      setState(() {
        _pesoError = peso.error == null ? null : kErrorNumericoInvalido;
        _temperaturaError = temperatura.error == null
            ? null
            : kErrorNumericoInvalido;
        _frecuenciaCardiacaError = frecuenciaCardiaca.error == null
            ? null
            : kErrorNumericoInvalido;
        _frecuenciaRespiratoriaError = frecuenciaRespiratoria.error == null
            ? null
            : kErrorNumericoInvalido;
        _detallesExpandidos = true;
      });
      return;
    }

    setState(() {
      _pesoError = null;
      _temperaturaError = null;
      _frecuenciaCardiacaError = null;
      _frecuenciaRespiratoriaError = null;
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(registrarConsultaProvider)(
        mascotaId: widget.mascotaId,
        diagnostico: _diagnosticoCtrl.text,
        tratamiento: _tratamientoCtrl.text,
        anamnesis: _anamnesisCtrl.text,
        evolucion: _evolucionCtrl.text,
        pesoKg: peso.valor,
        temperaturaC: temperatura.valor,
        frecuenciaCardiaca: frecuenciaCardiaca.valor?.toInt(),
        frecuenciaRespiratoria: frecuenciaRespiratoria.valor?.toInt(),
        mucosas: _mucosasCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta guardada')),
      );
      context.pop();
    } on ConsultaFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppTopBar(title: 'Nueva consulta'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Diagnóstico *',
              controller: _diagnosticoCtrl,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Tratamiento *',
              controller: _tratamientoCtrl,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () =>
                  setState(() => _detallesExpandidos = !_detallesExpandidos),
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
                      _detallesExpandidos
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_detallesExpandidos) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Anamnesis',
                controller: _anamnesisCtrl,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Examen físico', style: textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Peso (kg)',
                controller: _pesoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                errorText: _pesoError,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Temperatura (°C)',
                controller: _temperaturaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                errorText: _temperaturaError,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Frecuencia cardíaca (lpm)',
                controller: _frecuenciaCardiacaCtrl,
                keyboardType: TextInputType.number,
                errorText: _frecuenciaCardiacaError,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Frecuencia respiratoria (rpm)',
                controller: _frecuenciaRespiratoriaCtrl,
                keyboardType: TextInputType.number,
                errorText: _frecuenciaRespiratoriaError,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: 'Mucosas', controller: _mucosasCtrl),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Evolución',
                controller: _evolucionCtrl,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (_error != null) ...[
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: 'Guardar consulta',
              onPressed: _puedeGuardar ? _submit : null,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
