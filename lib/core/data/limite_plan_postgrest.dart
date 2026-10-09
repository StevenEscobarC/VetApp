import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/limite_plan.dart';

/// Traduce un error de PostgREST a un [LimitePlan] (`LP001`..`LP004`). Los
/// triggers del servidor levantan `errcode` y `hint` iguales al código, así
/// que primero se mira `code` y, si el SDK lo trae como `P0001`, el `hint`.
/// Solo lo importan los repositorios de la capa de datos.
LimitePlan? limitePlanDe(PostgrestException e) =>
    _desdeCodigo(e.code) ?? _desdeCodigo(e.hint);

LimitePlan? _desdeCodigo(String? codigo) => switch (codigo) {
  'LP001' => LimitePlan.pacientes,
  'LP002' => LimitePlan.miembros,
  'LP003' => LimitePlan.funcion,
  'LP004' => LimitePlan.soloLectura,
  _ => null,
};
