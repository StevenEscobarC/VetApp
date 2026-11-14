import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetapp/features/clinic/data/datasources/clinica_logo_datasource.dart';
import 'package:vetapp/features/clinic/data/repositories/supabase_clinica_repository.dart';
import 'package:vetapp/features/clinic/domain/clinica.dart';

void main() {
  group('Clinica.desdeJson', () {
    test('mapea los seis campos', () {
      final c = Clinica.desdeJson({
        'id': 'c1',
        'nombre': 'Vet Sol',
        'ciudad': 'Cali',
        'direccion': 'Cra 1',
        'telefono': '300',
        'logo_path': 'c1/logo-1700000000000.jpg',
      });
      expect(c.id, 'c1');
      expect(c.nombre, 'Vet Sol');
      expect(c.ciudad, 'Cali');
      expect(c.direccion, 'Cra 1');
      expect(c.telefono, '300');
      expect(c.logoPath, 'c1/logo-1700000000000.jpg');
    });

    test('campos faltantes -> vacío; logo null o vacío -> null', () {
      final a = Clinica.desdeJson({'id': 'c1', 'nombre': 'Vet Sol'});
      expect(a.ciudad, '');
      expect(a.direccion, '');
      expect(a.telefono, '');
      expect(a.logoPath, isNull);
      final b = Clinica.desdeJson({
        'id': 'c1',
        'nombre': 'Vet Sol',
        'logo_path': '',
      });
      expect(b.logoPath, isNull);
    });
  });

  test('paramsActualizarClinica recorta y conserva logo null', () {
    final p = SupabaseClinicaRepository.paramsActualizarClinica(
      nombre: '  Vet Sol ',
      ciudad: ' Cali',
      direccion: '',
      telefono: ' 300 ',
      logoPath: null,
    );
    expect(p.keys.toSet(), {
      'p_nombre',
      'p_ciudad',
      'p_direccion',
      'p_telefono',
      'p_logo_path',
      'p_nit',
    });
    expect(p['p_nombre'], 'Vet Sol');
    expect(p['p_ciudad'], 'Cali');
    expect(p['p_direccion'], '');
    expect(p['p_telefono'], '300');
    expect(p['p_logo_path'], isNull);
  });

  test('mensajeErrorClinica mapea códigos', () {
    String m(String code) =>
        mensajeErrorClinica(PostgrestException(message: 'raw', code: code));
    expect(
      m('42501'),
      'Solo los administradores pueden cambiar los datos de la clínica.',
    );
    expect(
      m('23514'),
      'Revisa los datos: el nombre es obligatorio y el logo debe ser una imagen válida.',
    );
    expect(
      m('XX'),
      'No pudimos guardar los datos de la clínica. Intenta de nuevo.',
    );
  });

  test('mensajeErrorClinica mapea LP003 y LP004 (por code o por hint)', () {
    expect(
      mensajeErrorClinica(PostgrestException(message: 'x', code: 'LP003')),
      'El logo es parte de Pro y Clínica.',
    );
    expect(
      mensajeErrorClinica(
        PostgrestException(message: 'x', code: 'P0001', hint: 'LP003'),
      ),
      'El logo es parte de Pro y Clínica.',
    );
    expect(
      mensajeErrorClinica(PostgrestException(message: 'x', code: 'LP004')),
      'Tu cuenta está en solo lectura. Pide al administrador que active el plan.',
    );
  });

  test('rutaLogo respeta la forma del SQL', () {
    const id = '3f2b1c4d-0000-4000-8000-000000000001';
    final r = ClinicaLogoDatasource.rutaLogo(id, 1700000000000);
    expect(r, '$id/logo-1700000000000.jpg');
    expect(RegExp(r'^[0-9a-f-]{36}/logo-[0-9]{10,16}\.jpg$').hasMatch(r), isTrue);
  });

  group('NIT o cédula de la clínica (D-04)', () {
    Map<String, dynamic> params(String? nit) =>
        SupabaseClinicaRepository.paramsActualizarClinica(
          nombre: 'Vet Sol',
          ciudad: 'Cali',
          direccion: '',
          telefono: '300',
          nit: nit,
        );

    test('p_nit se normaliza; vacío o null -> null', () {
      expect(params(' 900.123.456-7 ')['p_nit'], '900123456-7');
      expect(params('')['p_nit'], isNull);
      expect(params(null)['p_nit'], isNull);
      expect(params(null).containsKey('p_nit'), isTrue);
    });

    test('desdeJson mapea nit; vacío -> null', () {
      expect(
        Clinica.desdeJson({'id': 'c1', 'nit': '900123456-7'}).nit,
        '900123456-7',
      );
      expect(Clinica.desdeJson({'id': 'c1', 'nit': ''}).nit, isNull);
      expect(Clinica.desdeJson({'id': 'c1'}).nit, isNull);
    });

    test('miClinica selecciona nit', () {
      expect(
        SupabaseClinicaRepository.columnasClinica.split(', '),
        contains('nit'),
      );
    });
  });
}
