import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetapp/core/data/limite_plan_postgrest.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/patients/domain/mascota_failure.dart';

class _Fallo implements Exception, ConLimitePlan {
  const _Fallo(this.limite);

  @override
  final LimitePlan? limite;
}

void main() {
  group('limitePlanDe', () {
    test('mapea LP001..LP004 por code', () {
      expect(
        limitePlanDe(const PostgrestException(message: 'x', code: 'LP001')),
        LimitePlan.pacientes,
      );
      expect(
        limitePlanDe(const PostgrestException(message: 'x', code: 'LP002')),
        LimitePlan.miembros,
      );
      expect(
        limitePlanDe(const PostgrestException(message: 'x', code: 'LP003')),
        LimitePlan.funcion,
      );
      expect(
        limitePlanDe(const PostgrestException(message: 'x', code: 'LP004')),
        LimitePlan.soloLectura,
      );
    });

    test('cae al hint cuando el code es P0001', () {
      expect(
        limitePlanDe(
          const PostgrestException(message: 'x', code: 'P0001', hint: 'LP004'),
        ),
        LimitePlan.soloLectura,
      );
      expect(
        limitePlanDe(
          const PostgrestException(message: 'x', code: 'P0001', hint: 'LP001'),
        ),
        LimitePlan.pacientes,
      );
    });

    test('otros códigos no son un límite de plan', () {
      expect(
        limitePlanDe(const PostgrestException(message: 'x', code: '23505')),
        isNull,
      );
      expect(limitePlanDe(const PostgrestException(message: 'x')), isNull);
    });
  });

  group('limiteDe', () {
    test('lee el límite de un ConLimitePlan', () {
      expect(
        limiteDe(const _Fallo(LimitePlan.pacientes)),
        LimitePlan.pacientes,
      );
    });

    test('lee el límite de un MascotaFailure', () {
      expect(
        limiteDe(const MascotaFailure('x', limite: LimitePlan.pacientes)),
        LimitePlan.pacientes,
      );
      expect(limiteDe(const MascotaFailure('x')), isNull);
    });

    test('devuelve null para otros errores o sin límite', () {
      expect(limiteDe(Exception('x')), isNull);
      expect(limiteDe(const _Fallo(null)), isNull);
    });
  });
}
