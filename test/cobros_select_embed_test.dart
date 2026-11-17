import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/billing/data/repositories/supabase_cobros_repository.dart';

/// Regresión de 07-08: PostgREST no resuelve el hint por nombre de constraint en
/// una relación de `cobros` consigo misma (400 PGRST200 en vivo). Los embeds de
/// conversión deben usar la columna como hint.
void main() {
  test('el select de cobros no embebe cobros consigo misma (QA F7: PostgREST '
      'lo resuelve al revés y el número llega vacío)', () {
    const s = SupabaseCobrosRepository.kSelectCobro;
    expect(s, isNot(contains('convertida:')));
    expect(s, isNot(contains('origen:')));
    expect(s, isNot(contains('cobros!')));
  });

  test('completarNumerosVinculados pone los números de los documentos '
      'vinculados en la forma plana que ya lee cobroDesdeFila', () {
    final filas = <Map<String, dynamic>>[
      {'id': 'cc3', 'cotizacion_origen_id': 'cot1', 'convertida_en_id': null},
      {'id': 'cot1', 'cotizacion_origen_id': null, 'convertida_en_id': 'cc3'},
      {'id': 'cc9', 'cotizacion_origen_id': null, 'convertida_en_id': null},
    ];
    completarNumerosVinculados(filas, {'cot1': 1, 'cc3': 3});
    expect(filas[0]['cotizacion_origen_numero'], 1);
    expect(filas[1]['convertida_en_numero'], 3);
    expect(filas[2].containsKey('cotizacion_origen_numero'), isFalse);
    expect(idsVinculados(filas), unorderedEquals(['cot1', 'cc3']));
  });
}
