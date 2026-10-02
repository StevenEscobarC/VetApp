import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/vaccination/domain/whatsapp_vacunas.dart';

void main() {
  final fecha = DateTime.utc(2026, 10, 5);

  test('recordatorio próxima', () {
    expect(
      mensajeRecordatorioVacuna(
        dueno: 'María',
        mascota: 'Luna',
        biologico: 'Antirrábica',
        proximaFecha: fecha,
        vencida: false,
        veterinario: 'Dr(a). Laura',
        clinica: 'Clínica Sol',
      ),
      'Buen día, María. Le escribe Dr(a). Laura de Clínica Sol. Le '
      'recordamos que Luna tiene programada su antirrábica para el '
      '05/10/2026. Si desea, podemos agendar una cita. Quedamos atentos.',
    );
  });

  test('recordatorio vencida', () {
    final m = mensajeRecordatorioVacuna(
      dueno: 'María',
      mascota: 'Luna',
      biologico: 'Antirrábica',
      proximaFecha: fecha,
      vencida: true,
      veterinario: 'Dr(a). Laura',
      clinica: 'Clínica Sol',
    );
    expect(m, contains('tenía programada su antirrábica el 05/10/2026'));
    expect(m, contains('ya está vencida'));
  });

  test('sin clínica omite el fragmento', () {
    final m = mensajeRecordatorioVacuna(
      dueno: 'María',
      mascota: 'Luna',
      biologico: 'Antirrábica',
      proximaFecha: fecha,
      vencida: false,
      veterinario: 'Dr(a). Laura',
    );
    expect(m, contains('Le escribe Dr(a). Laura. Le recordamos'));
  });

  test('carné por WhatsApp', () {
    final m = mensajeCarneWhatsApp(
      dueno: 'María',
      mascota: 'Luna',
      url: 'https://x.test/c/abc',
      veterinario: 'Dr(a). Laura',
      clinica: 'Clínica Sol',
    );
    expect(m, contains('https://x.test/c/abc'));
    expect(m, startsWith('Buen día, María. Le compartimos el carné de '));
    expect(m, endsWith('Dr(a). Laura, Clínica Sol.'));
  });

  test('compartir carné', () {
    expect(
      mensajeCompartirCarne(mascota: 'Luna', url: 'https://x.test/c/abc'),
      'Carné de vacunación de Luna: https://x.test/c/abc',
    );
  });
}
