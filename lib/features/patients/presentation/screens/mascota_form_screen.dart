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
import '../../../../core/widgets/media/app_photo_picker.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clients/presentation/providers/clientes_providers.dart';
import '../../domain/entities/mascota.dart';
import '../../domain/mascota_failure.dart';
import '../providers/mascota_foto_providers.dart';
import '../providers/mascotas_providers.dart';
import '../widgets/mascota_campos_section.dart';
import '../widgets/mascota_foto_avatar.dart';

/// Formulario standalone de mascota (D-03, PAT-01/PAT-02), reutilizado en dos
/// modos exactamente exclusivos: crear ([clienteId], dueño ya conocido desde
/// `ClienteDetailScreen` — nunca se re-pide) y editar ([mascotaId], desde
/// `MascotaDetailScreen`). Comparte [MascotaCamposSection] con
/// `NuevoClienteMascotaScreen` (Plan 04) para que ambos flujos luzcan/se
/// comporten igual. En modo edición el campo de peso nunca se muestra — el
/// historial de peso es append-only (PAT-05), nunca se edita desde la ficha.
class MascotaFormScreen extends ConsumerStatefulWidget {
  const MascotaFormScreen({super.key, this.clienteId, this.mascotaId})
    : assert(
        (clienteId == null) != (mascotaId == null),
        'Pass exactly one of clienteId (create) or mascotaId (edit).',
      );

  final String? clienteId;
  final String? mascotaId;

  bool get esEdicion => mascotaId != null;

  @override
  ConsumerState<MascotaFormScreen> createState() => _MascotaFormScreenState();
}

class _MascotaFormScreenState extends ConsumerState<MascotaFormScreen> {
  final _nombreCtrl = TextEditingController();
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

  /// Solo se usa en modo edición: la versión recién cargada, para llenar los
  /// controladores una sola vez y como base del check de "algo cambió".
  Mascota? _original;

  @override
  void initState() {
    super.initState();
    for (final controller in [_nombreCtrl, _razaCtrl, _fechaCtrl, _pesoCtrl]) {
      controller.addListener(_onCamposCambiaron);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _razaCtrl.dispose();
    _fechaCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  void _onCamposCambiaron() => setState(() {});

  Future<void> _capturar(FuenteFoto fuente) async {
    final capturador = ref.read(capturadorFotoProvider);
    final bytes = await capturador(context, fuente);
    if (bytes != null && mounted) setState(() => _fotoBytes = bytes);
  }

  void _llenarControladores(Mascota mascota) {
    _nombreCtrl.text = mascota.nombre;
    _especie = mascota.especie;
    _razaCtrl.text = mascota.raza ?? '';
    _fechaCtrl.text = mascota.fechaNacimiento == null
        ? ''
        : formatearFecha(mascota.fechaNacimiento!);
    _detallesExpandidos =
        mascota.raza != null || mascota.fechaNacimiento != null;
  }

  bool get _esDirtyEdicion {
    final original = _original;
    if (original == null) return false;
    return _nombreCtrl.text.trim() != original.nombre ||
        _especie != original.especie ||
        _razaCtrl.text.trim() != (original.raza ?? '') ||
        _fechaCtrl.text.trim() !=
            (original.fechaNacimiento == null
                ? ''
                : formatearFecha(original.fechaNacimiento!)) ||
        _fotoBytes != null;
  }

  bool get _puedeGuardar {
    final nombreValido = _nombreCtrl.text.trim().isNotEmpty && _especie != null;
    if (!nombreValido) return false;
    return widget.esEdicion ? _esDirtyEdicion : true;
  }

  Future<void> _submitCrear(String clienteId) async {
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
      final mascotaId = await ref
          .read(mascotaRepositoryProvider)
          .registrarMascota(
            duenoId: clienteId,
            nombre: _nombreCtrl.text.trim(),
            especie: _especie!,
            raza: _razaCtrl.text,
            fechaNacimiento: fecha.valor,
            pesoKg: peso.valor,
          );

      // La mascota ya quedó guardada: una falla al subir la foto nunca debe
      // bloquear el alta ni deshacer lo ya creado (mismo patrón que
      // NuevoClienteMascotaScreen).
      final foto = _fotoBytes;
      if (foto != null) {
        try {
          final clinicaId = (await ref.read(
            authProfileProvider.future,
          ))?.clinicaId;
          if (clinicaId != null) {
            final path = await ref
                .read(mascotaFotoDatasourceProvider)
                .upload(
                  clinicaId: clinicaId,
                  mascotaId: mascotaId,
                  bytes: foto,
                );
            await ref
                .read(mascotaRepositoryProvider)
                .actualizarFotoPath(mascotaId, path);
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
      ref.invalidate(mascotasDeClienteProvider(clienteId));
      ref.invalidate(clienteProvider(clienteId));
      ref.read(clientesProvider.notifier).refrescar();
      ref.read(mascotasProvider.notifier).refrescar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mascota guardada')));
      context.pop();
    } on MascotaFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitEditar(Mascota original) async {
    final fecha = parsearFecha(_fechaCtrl.text);
    if (fecha.error != null) {
      setState(() => _fechaError = fecha.error);
      return;
    }

    setState(() {
      _fechaError = null;
      _loading = true;
      _error = null;
    });

    final actualizada = Mascota(
      id: original.id,
      duenoId: original.duenoId,
      clinicaId: original.clinicaId,
      nombre: _nombreCtrl.text.trim(),
      especie: _especie!,
      raza: _razaCtrl.text.trim().isEmpty ? null : _razaCtrl.text.trim(),
      fechaNacimiento: fecha.valor,
      fotoPath: original.fotoPath,
      duenoNombre: original.duenoNombre,
    );

    try {
      await ref.read(mascotaRepositoryProvider).actualizar(actualizada);

      // Reemplazo de foto (si el vet tomó una nueva): sube, actualiza
      // foto_path y solo entonces intenta borrar la anterior en su propio
      // try/catch que ignora fallos (T-02-32) — mismo orden que
      // MascotaDetailScreen._cambiarFoto.
      final foto = _fotoBytes;
      if (foto != null) {
        try {
          final path = await ref
              .read(mascotaFotoDatasourceProvider)
              .upload(
                clinicaId: original.clinicaId,
                mascotaId: original.id,
                bytes: foto,
              );
          await ref
              .read(mascotaRepositoryProvider)
              .actualizarFotoPath(original.id, path);

          final fotoAnterior = original.fotoPath;
          if (fotoAnterior != null) {
            try {
              await ref
                  .read(mascotaFotoDatasourceProvider)
                  .eliminar(fotoAnterior);
            } catch (_) {
              // Best-effort (T-02-32): perder el objeto viejo nunca bloquea
              // el flujo ni se le reporta al vet.
            }
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
      ref.invalidate(mascotaProvider(original.id));
      ref.read(mascotasProvider.notifier).refrescar();
      ref.invalidate(mascotasDeClienteProvider(original.duenoId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
      context.pop();
    } on MascotaFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.esEdicion) {
      final mascotaAsync = ref.watch(mascotaProvider(widget.mascotaId!));
      return Scaffold(
        appBar: const AppTopBar(title: 'Editar mascota'),
        body: mascotaAsync.when(
          data: (mascota) {
            if (_original == null) {
              _original = mascota;
              _llenarControladores(mascota);
            }
            return _buildForm(context, mascotaOriginal: mascota);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text('No pudimos cargar la mascota. Intenta de nuevo.'),
          ),
        ),
      );
    }

    final clienteAsync = ref.watch(clienteProvider(widget.clienteId!));
    return Scaffold(
      appBar: const AppTopBar(title: 'Nueva mascota'),
      body: clienteAsync.when(
        data: (cliente) => _buildForm(context, duenoNombre: cliente.nombre),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('No pudimos cargar el cliente. Intenta de nuevo.'),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context, {
    String? duenoNombre,
    Mascota? mascotaOriginal,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final esEdicion = widget.esEdicion;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!esEdicion) ...[
            Text('Dueño: ${duenoNombre ?? ''}', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppCard(
            child: MascotaCamposSection(
              nombreController: _nombreCtrl,
              especie: _especie,
              onEspecieChanged: (e) => setState(() => _especie = e),
              razaController: _razaCtrl,
              fechaController: _fechaCtrl,
              pesoController: esEdicion ? null : _pesoCtrl,
              fechaError: _fechaError,
              pesoError: _pesoError,
              detallesExpandidos: _detallesExpandidos,
              onToggleDetalles: () =>
                  setState(() => _detallesExpandidos = !_detallesExpandidos),
              foto: esEdicion && _fotoBytes == null
                  ? MascotaFotoAvatar(
                      fotoPath: mascotaOriginal?.fotoPath,
                      size: 96,
                      onTomarFoto: () => _capturar(FuenteFoto.camara),
                      onElegirGaleria: () => _capturar(FuenteFoto.galeria),
                    )
                  : AppPhotoPicker(
                      localBytes: _fotoBytes,
                      size: 96,
                      onTomarFoto: () => _capturar(FuenteFoto.camara),
                      onElegirGaleria: () => _capturar(FuenteFoto.galeria),
                    ),
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
            label: esEdicion ? 'Guardar cambios' : 'Nueva mascota',
            onPressed: !_puedeGuardar
                ? null
                : () => esEdicion
                      ? _submitEditar(mascotaOriginal!)
                      : _submitCrear(widget.clienteId!),
            isLoading: _loading,
          ),
        ],
      ),
    );
  }
}
