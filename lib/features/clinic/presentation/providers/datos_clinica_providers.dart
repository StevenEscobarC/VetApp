import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/recorte_cuadrado.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../vaccination/presentation/providers/vacuna_providers.dart';
import '../../domain/clinica.dart';
import '../../domain/clinica_failure.dart';
import 'clinica_providers.dart';

/// Costura de tests: en producción recorta a cuadrado y comprime a JPEG.
final recortadorCuadradoProvider = Provider<RecortadorCuadrado>(
  (_) => recortarCuadradoJpeg,
);

/// Solo los administradores editan los datos de la clínica (D-27). En una
/// clínica de un solo veterinario ese veterinario es administrador (4.1 D-04).
/// El servidor es la autoridad; esto solo oculta acciones.
final puedeEditarClinicaProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(authProfileProvider).value?.esAdmin ?? false,
);

/// Mismo límite que el bucket `clinica-logos`.
const int kMaxBytesLogo = 1048576;

/// Guarda los datos de la clínica: sube el logo nuevo, llama a
/// `actualizar_clinica` y limpia objetos huérfanos (best effort).
class GuardarDatosClinica {
  GuardarDatosClinica(this._ref);

  final Ref _ref;

  Future<Clinica> call({
    required Clinica actual,
    required String nombre,
    required String ciudad,
    required String direccion,
    required String telefono,
    Uint8List? nuevoLogo,
    bool quitarLogo = false,
  }) async {
    if (nuevoLogo != null && nuevoLogo.length > kMaxBytesLogo) {
      throw const ClinicaFailure(
        'El logo es muy pesado. Prueba con otra imagen.',
      );
    }
    final logos = _ref.read(clinicaLogoDatasourceProvider);
    String? subido;
    if (nuevoLogo != null) {
      subido = await logos.upload(clinicaId: actual.id, bytes: nuevoLogo);
    }

    final Clinica actualizada;
    try {
      actualizada = await _ref
          .read(clinicaRepositoryProvider)
          .actualizar(
            nombre: nombre.trim(),
            ciudad: ciudad.trim(),
            direccion: direccion.trim(),
            telefono: telefono.trim(),
            logoPath: subido ?? (quitarLogo ? null : actual.logoPath),
          );
    } on ClinicaFailure {
      if (subido != null) {
        try {
          await logos.eliminar(subido);
        } catch (_) {}
      }
      rethrow;
    }

    final anterior = actual.logoPath;
    if ((subido != null || quitarLogo) && anterior != null) {
      try {
        await logos.eliminar(anterior);
      } catch (_) {}
    }

    _ref.invalidate(miClinicaProvider);
    // El carné trae nombre y logo de la clínica en su propia respuesta: sin
    // esto, un carné ya cargado sigue sin el logo nuevo (QA Fase 5, G8).
    _ref.invalidate(carneProvider);
    // El nombre de la clínica se usa en Inicio y en las firmas de WhatsApp.
    await _ref.read(authProfileProvider.notifier).refrescar();
    return actualizada;
  }
}

final guardarDatosClinicaProvider = Provider<GuardarDatosClinica>(
  (ref) => GuardarDatosClinica(ref),
);
