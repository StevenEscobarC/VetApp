import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/captura_foto.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../patients/presentation/providers/mascota_foto_providers.dart';
import '../../domain/clinica.dart';
import '../../domain/clinica_failure.dart';
import '../providers/clinica_providers.dart';
import '../providers/datos_clinica_providers.dart';
import '../widgets/clinica_logo.dart';

const _textoSoloAdmin =
    'Solo los administradores pueden cambiar los datos de la clínica.';

/// Más > Datos de la clínica (D-27): el administrador edita nombre, ciudad,
/// dirección, teléfono y logo; los demás veterinarios lo ven en solo lectura.
class DatosClinicaScreen extends ConsumerWidget {
  const DatosClinicaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinica = ref.watch(miClinicaProvider);
    final puedeEditar = ref.watch(puedeEditarClinicaProvider);
    return Scaffold(
      appBar: const AppTopBar(title: 'Datos de la clínica'),
      // El perfil se relee al volver a la app (4.1), p. ej. tras la galería o
      // la cámara, y eso recarga miClinicaProvider. Mostrar el esqueleto en
      // esa recarga desmontaría el formulario y perdería la vista previa del
      // logo y lo editado (G6): se conservan los datos previos.
      body: clinica.when(
        skipLoadingOnReload: true,
        skipError: true,
        loading: () => const _Esqueleto(),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No pudimos cargar los datos de la clínica. Intenta de nuevo.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Reintentar',
                variant: AppButtonVariant.outline,
                onPressed: () => ref.invalidate(miClinicaProvider),
              ),
            ],
          ),
        ),
        data: (c) {
          if (c == null) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No pudimos cargar los datos de la clínica. Intenta de nuevo.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return puedeEditar
              ? _Formulario(clinica: c)
              : _SoloLectura(clinica: c);
        },
      ),
    );
  }
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.md),
    child: Column(
      children: [
        _Bloque(height: 96),
        SizedBox(height: AppSpacing.sm),
        _Bloque(height: 56),
        SizedBox(height: AppSpacing.sm),
        _Bloque(height: 56),
      ],
    ),
  );
}

class _SoloLectura extends StatelessWidget {
  const _SoloLectura({required this.clinica});

  final Clinica clinica;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget fila(String etiqueta, String valor) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(valor.trim().isEmpty ? '—' : valor, style: textTheme.bodyLarge),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (clinica.logoPath != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ClinicaLogo(logoPath: clinica.logoPath, size: 96),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        fila('Nombre de la clínica', clinica.nombre),
        fila('Ciudad', clinica.ciudad),
        fila('Dirección', clinica.direccion),
        fila('Teléfono', clinica.telefono),
        Text(
          _textoSoloAdmin,
          style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.clinica});

  final Clinica clinica;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  late final TextEditingController _nombre;
  late final TextEditingController _ciudad;
  late final TextEditingController _direccion;
  late final TextEditingController _telefono;
  late Clinica _actual;
  Uint8List? _preview;
  bool _quitar = false;
  bool _guardando = false;
  String? _errorNombre;
  String? _error;

  @override
  void initState() {
    super.initState();
    _actual = widget.clinica;
    _nombre = TextEditingController(text: _actual.nombre);
    _ciudad = TextEditingController(text: _actual.ciudad);
    _direccion = TextEditingController(text: _actual.direccion);
    _telefono = TextEditingController(text: _actual.telefono);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _ciudad.dispose();
    _direccion.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _elegir(FuenteFoto fuente) async {
    final bytes = await ref.read(capturadorFotoProvider)(context, fuente);
    if (bytes == null || !mounted) return;
    try {
      final recortado = await ref.read(recortadorCuadradoProvider)(bytes);
      if (!mounted) return;
      setState(() {
        _preview = recortado;
        _quitar = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'No pudimos procesar la imagen. Prueba con otra.',
      );
    }
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _errorNombre = 'Escribe el nombre de la clínica.');
      return;
    }
    setState(() {
      _errorNombre = null;
      _error = null;
      _guardando = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final nueva = await ref
          .read(guardarDatosClinicaProvider)
          .call(
            actual: _actual,
            nombre: _nombre.text,
            ciudad: _ciudad.text,
            direccion: _direccion.text,
            telefono: _telefono.text,
            nuevoLogo: _preview,
            quitarLogo: _quitar,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Datos de la clínica guardados')),
      );
      if (!mounted) return;
      setState(() {
        _actual = nueva;
        _preview = null;
        _quitar = false;
        _guardando = false;
      });
    } on ClinicaFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hayLogo = _preview != null || (!_quitar && _actual.logoPath != null);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Semantics(
          label: 'Logo de la clínica',
          container: true,
          child: Align(
            alignment: Alignment.centerLeft,
            child: hayLogo
                ? ClinicaLogo(
                    localBytes: _preview,
                    logoPath: _preview == null ? _actual.logoPath : null,
                    size: 96,
                  )
                : _AgregarLogo(
                    onTap: _guardando ? null : () => _elegir(FuenteFoto.galeria),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Aparece en el carné de vacunación que compartes con los dueños.',
          style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            AppButton(
              label: 'Tomar foto',
              icon: Icons.photo_camera_outlined,
              variant: AppButtonVariant.outline,
              expand: false,
              onPressed: _guardando ? null : () => _elegir(FuenteFoto.camara),
            ),
            AppButton(
              label: 'Elegir de galería',
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: _guardando ? null : () => _elegir(FuenteFoto.galeria),
            ),
            if (hayLogo)
              AppButton(
                label: 'Quitar logo',
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: _guardando
                    ? null
                    : () => setState(() {
                        _preview = null;
                        _quitar = true;
                      }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Nombre de la clínica',
          controller: _nombre,
          errorText: _errorNombre,
          maxLength: 120,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Ciudad',
          controller: _ciudad,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Dirección',
          controller: _direccion,
          maxLength: 160,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Teléfono',
          controller: _telefono,
          keyboardType: TextInputType.phone,
          maxLength: 30,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_error != null) ...[
          Text(
            _error!,
            style: textTheme.bodyLarge?.copyWith(color: AppColors.destructive),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: 'Guardar cambios',
          isLoading: _guardando,
          onPressed: _guardar,
        ),
      ],
    );
  }
}

class _AgregarLogo extends StatelessWidget {
  const _AgregarLogo({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 96,
    child: AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate_outlined),
          const SizedBox(height: AppSpacing.xs),
          Text('Agregar logo', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    ),
  );
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );
}
