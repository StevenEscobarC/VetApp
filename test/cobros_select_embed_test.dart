import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/billing/data/repositories/supabase_cobros_repository.dart';

/// Regresión de 07-08: PostgREST no resuelve el hint por nombre de constraint en
/// una relación de `cobros` consigo misma (400 PGRST200 en vivo). Los embeds de
/// conversión deben usar la columna como hint.
void main() {
  test('el select de cobros usa la columna como hint en los embeds de conversión', () {
    const s = SupabaseCobrosRepository.kSelectCobro;
    expect(s, contains('convertida:cobros!convertida_en_id(numero)'));
    expect(s, contains('origen:cobros!cotizacion_origen_id(numero)'));
    expect(s, isNot(contains('cobros_convertida_en_fkey')));
    expect(s, isNot(contains('cobros_cotizacion_origen_fkey')));
  });
}
