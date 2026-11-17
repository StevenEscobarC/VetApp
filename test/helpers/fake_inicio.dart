import 'dart:async';

import 'package:vetapp/features/home/data/supabase_inicio_repository.dart';
import 'package:vetapp/features/home/domain/resumen_inicio.dart';

/// Reemplazo en memoria de [SupabaseInicioRepository]: devuelve
/// [resumenData], lanza [error] si está asignado y registra cada lectura en
/// [llamadas]. Si [bloqueo] está asignado, espera a que se complete antes de
/// responder (sirve para fijar el estado de carga en tests de widget).
class FakeInicioRepository implements SupabaseInicioRepository {
  FakeInicioRepository({
    this.resumenData = const ResumenInicio(),
    this.error,
    this.bloqueo,
  });

  ResumenInicio resumenData;
  Object? error;
  Completer<void>? bloqueo;
  final llamadas = <String>[];

  @override
  Future<ResumenInicio> resumen() async {
    llamadas.add('resumen');
    final b = bloqueo;
    if (b != null) await b.future;
    final e = error;
    if (e != null) throw e;
    return resumenData;
  }
}
