import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/captura_foto.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../core/widgets/media/app_photo_picker.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patients/domain/entities/mascota.dart';
import '../../../patients/domain/mascota_failure.dart';
import '../../../patients/presentation/providers/mascota_foto_providers.dart';
import '../../../patients/presentation/providers/mascotas_providers.dart';
import '../../../patients/presentation/widgets/mascota_campos_section.dart';
import '../providers/clientes_providers.dart';

/// Combined create flow (D-02): the vet registers a new dueño and su
/// primera mascota in one continuous scroll, both sections always visible
/// with no intermediate navigation step between them — calling the atomic
/// `registrar_cliente_con_mascota` RPC exactly once on submit. This is the
/// phase's primary path (CLI-01, PAT-01 create half).
class NuevoClienteMascotaScreen extends ConsumerStatefulWidget {
  const NuevoClienteMascotaScreen({super.key});

  @override
  ConsumerState<NuevoClienteMascotaScreen> createState() =>
      _NuevoClienteMascotaScreenState();
}

class _NuevoClienteMascotaScreenState
    extends ConsumerState<NuevoClienteMascotaScreen> {
  final _clienteNombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _mascotaNombreCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();

  Especie? _especie;
  Uint8List? _fotoBytes;
  bool _detallesExpandidos = false;
  bool _loading = false;
  String? _error;
  String? _fechaError;
  String? _pesoError;

  @override
  void initState() {
    super.initState();
    _clienteNombreCtrl.addListener(_onCamposCambiaron);
    _telefonoCtrl.addListener(_onCamposCambiaron);
    _mascotaNombreCtrl.addListener(_onCamposCambiaron);
  }

  @override
  void dispose() {
    _clienteNombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _mascotaNombreCtrl.dispose();
    _razaCtrl.dispose();
    _fechaCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  void _onCamposCambiaron() => setState(() {});

  bool get _puedeGuardar =>
      _clienteNombreCtrl.text.trim().isNotEmpty &&
      _telefonoCtrl.text.trim().isNotEmpty &&
      _mascotaNombreCtrl.text.trim().isNotEmpty &&
      _especie != null;

  Future<void> _capturar(FuenteFoto fuente) async {
    final capturador = ref.read(capturadorFotoProvider);
    final bytes = await capturador(context, fuente);
    if (bytes != null && mounted) setState(() => _fotoBytes = bytes);
  }

  Future<void> _submit() async {
    final fecha = parsearFecha(_fechaCtrl.text);
    final peso = parsearPeso(_pesoCtrl.text);
    if (fecha.error != null || peso.error != null) {
      setState(() {
        _fechaError = fecha.error;
        _pesoError = peso.error;
      });
      return;
    }

    setState(() {
      _fechaError = null;
      _pesoError = null;
      _loading = true;
      _error = null;
    });

    try {
      final resultado = await ref
          .read(mascotaRepositoryProvider)
          .registrarClienteConMascota(
            clienteNombre: _clienteNombreCtrl.text.trim(),
            clienteTelefono: _telefonoCtrl.text.trim(),
            mascotaNombre: _mascotaNombreCtrl.text.trim(),
            mascotaEspecie: _especie!,
            mascotaRaza: _razaCtrl.text,
            mascotaFechaNacimiento: fecha.valor,
            mascotaPesoKg: peso.valor,
          );

      // Los registros ya se guardaron: una falla al subir la foto nunca
      // debe bloquear el alta ni deshacer lo ya creado.
      final foto = _fotoBytes;
      if (foto != null) {
        try {
          // `.future` (no `ref.watch(authProfileProvider)` anywhere in this
          // screen) awaits the AsyncNotifier's build() instead of racing it
          // — `ref.read(authProfileProvider).value` would return null here
          // if this is the first read of the provider in the whole app.
          final clinicaId = (await ref.read(authProfileProvider.future))
              ?.clinicaId;
          if (clinicaId != null) {
            final path = await ref
                .read(mascotaFotoDatasourceProvider)
                .upload(
                  clinicaId: clinicaId,
                  mascotaId: resultado.mascotaId,
                  bytes: foto,
                );
            await ref
                .read(mascotaRepositoryProvider)
                .actualizarFotoPath(resultado.mascotaId, path);
          }
        } on MascotaFailure {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No pudimos subir la foto. Intenta de nuevo.'),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      ref.read(clientesProvider.notifier).refrescar();
      ref.read(mascotasProvider.notifier).refrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente y mascota guardados')),
      );
      context.pop();
    } on MascotaFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppTopBar(title: 'Nuevo cliente'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datos del dueño', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Nombre *',
                    controller: _clienteNombreCtrl,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Teléfono *',
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datos de la mascota', style: textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  MascotaCamposSection(
                    nombreController: _mascotaNombreCtrl,
                    especie: _especie,
                    onEspecieChanged: (e) => setState(() => _especie = e),
                    razaController: _razaCtrl,
                    fechaController: _fechaCtrl,
                    pesoController: _pesoCtrl,
                    fechaError: _fechaError,
                    pesoError: _pesoError,
                    detallesExpandidos: _detallesExpandidos,
                    onToggleDetalles: () => setState(
                      () => _detallesExpandidos = !_detallesExpandidos,
                    ),
                    foto: AppPhotoPicker(
                      localBytes: _fotoBytes,
                      size: 96,
                      onTomarFoto: () => _capturar(FuenteFoto.camara),
                      onElegirGaleria: () => _capturar(FuenteFoto.galeria),
                    ),
                  ),
                ],
              ),
            ),
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
              label: 'Guardar cliente y mascota',
              onPressed: _puedeGuardar ? _submit : null,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
