import 'dart:typed_data';

import 'package:vetapp/features/clinic/data/datasources/clinica_logo_datasource.dart';
import 'package:vetapp/features/clinic/data/repositories/supabase_clinica_repository.dart';
import 'package:vetapp/features/clinic/domain/clinica.dart';
import 'package:vetapp/features/clinic/domain/clinica_failure.dart';

/// Datos claramente falsos para tests.
const clinicaDePrueba = Clinica(
  id: '3f2b1c4d-0000-4000-8000-000000000001',
  nombre: 'Veterinaria El Roble',
  ciudad: 'Medellín',
  direccion: 'Cra 70 # 45-12',
  telefono: '3001234567',
  logoPath: null,
);

class FakeClinicaRepository implements SupabaseClinicaRepository {
  FakeClinicaRepository({this.clinica = clinicaDePrueba, this.error});

  Clinica clinica;
  ClinicaFailure? error;

  /// Argumentos nombrados de cada llamada a [actualizar], en orden.
  final List<Map<String, dynamic>> llamadasActualizar = [];

  @override
  Future<Clinica> miClinica(String clinicaId) async {
    if (error != null) throw error!;
    return clinica;
  }

  @override
  Future<Clinica> actualizar({
    required String nombre,
    required String ciudad,
    required String direccion,
    required String telefono,
    String? logoPath,
  }) async {
    llamadasActualizar.add({
      'nombre': nombre,
      'ciudad': ciudad,
      'direccion': direccion,
      'telefono': telefono,
      'logoPath': logoPath,
    });
    if (error != null) throw error!;
    clinica = Clinica(
      id: clinica.id,
      nombre: nombre,
      ciudad: ciudad,
      direccion: direccion,
      telefono: telefono,
      logoPath: logoPath,
    );
    return clinica;
  }
}

class FakeClinicaLogoDatasource implements ClinicaLogoDatasource {
  FakeClinicaLogoDatasource({
    this.errorUpload,
    this.errorEliminar,
    this.bytesDescarga,
    this.urlFirmada = 'https://example.test/signed/logo.jpg?token=t',
  });

  final List<String> subidas = [];
  final List<String> eliminados = [];
  ClinicaFailure? errorUpload;
  ClinicaFailure? errorEliminar;
  Uint8List? bytesDescarga;
  String urlFirmada;

  @override
  Future<String> upload({
    required String clinicaId,
    required Uint8List bytes,
  }) async {
    if (errorUpload != null) throw errorUpload!;
    final ruta = ClinicaLogoDatasource.rutaLogo(
      clinicaId,
      1700000000000 + subidas.length,
    );
    subidas.add(ruta);
    return ruta;
  }

  @override
  Future<String> signedUrlFor(String path) async => urlFirmada;

  @override
  Future<Uint8List> descargar(String path) async =>
      bytesDescarga ?? Uint8List(0);

  @override
  Future<void> eliminar(String path) async {
    if (errorEliminar != null) throw errorEliminar!;
    eliminados.add(path);
  }
}
