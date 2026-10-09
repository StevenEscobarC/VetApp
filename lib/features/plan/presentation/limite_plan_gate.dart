import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/limite_plan.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/mi_plan.dart';
import 'providers/plan_providers.dart';
import 'widgets/limite_plan_sheet.dart';

/// Verificaciones previas y manejo de fallos de límite del plan. Todas son
/// cortesía de UX: si el plan no se puede leer se PERMITE la acción (el
/// servidor, con los triggers `LP00x`, es la autoridad).

bool _esAdmin(WidgetRef ref) =>
    ref.read(authProfileProvider).value?.esAdmin ?? false;

/// Usa [plan] si ya viene observado; si no lo lee una vez del repositorio.
/// `null` ante cualquier error. No lee el provider del plan (podría no estar
/// observado por la pantalla que llama).
Future<MiPlan?> _planOLeer(WidgetRef ref, MiPlan? plan) async {
  if (plan != null) return plan;
  try {
    return await ref.read(planRepositoryProvider).miPlan();
  } catch (_) {
    return null;
  }
}

/// `false` y hoja de solo lectura si el servidor dice que no se puede
/// escribir.
Future<bool> asegurarEscritura(
  BuildContext context,
  WidgetRef ref, {
  MiPlan? plan,
}) async {
  final esAdmin = _esAdmin(ref);
  final p = await _planOLeer(ref, plan);
  if (p == null || p.puedeEscribir) return true;
  if (!context.mounted) return false;
  unawaited(
    mostrarLimitePlanSheet(
      context,
      limite: LimitePlan.soloLectura,
      plan: p,
      esAdmin: esAdmin,
    ),
  );
  return false;
}

/// Escritura primero; luego, `false` y hoja de pacientes si el plan llegó a
/// su tope de pacientes.
Future<bool> asegurarNuevoPaciente(
  BuildContext context,
  WidgetRef ref, {
  MiPlan? plan,
}) async {
  final esAdmin = _esAdmin(ref);
  final p = await _planOLeer(ref, plan);
  if (p == null) return true;
  if (!context.mounted) return false;
  if (!p.puedeEscribir) {
    unawaited(
      mostrarLimitePlanSheet(
        context,
        limite: LimitePlan.soloLectura,
        plan: p,
        esAdmin: esAdmin,
      ),
    );
    return false;
  }
  if (p.pacientesAlTope) {
    unawaited(
      mostrarLimitePlanSheet(
        context,
        limite: LimitePlan.pacientes,
        plan: p,
        esAdmin: esAdmin,
      ),
    );
    return false;
  }
  return true;
}

/// `false` y hoja de la función si el plan no incluye [funcion].
Future<bool> asegurarFuncionPro(
  BuildContext context,
  WidgetRef ref,
  FuncionPro funcion, {
  MiPlan? plan,
}) async {
  final esAdmin = _esAdmin(ref);
  final p = await _planOLeer(ref, plan);
  if (p == null) return true;
  final permitida = switch (funcion) {
    FuncionPro.logo => p.logoPermitido,
    FuncionPro.protocolos => p.protocolosPropiosPermitidos,
  };
  if (permitida) return true;
  if (!context.mounted) return false;
  unawaited(
    mostrarLimitePlanSheet(
      context,
      limite: LimitePlan.funcion,
      funcion: funcion,
      plan: p,
      esAdmin: esAdmin,
    ),
  );
  return false;
}

/// Respaldo del servidor: si [error] lleva un [LimitePlan] refresca el plan,
/// abre la hoja correspondiente (el formulario y sus datos quedan intactos) y
/// devuelve `true`. Si no es un límite devuelve `false` sin mostrar nada.
Future<bool> manejarLimitePlan(
  BuildContext context,
  WidgetRef ref,
  Object error, {
  FuncionPro? funcion,
}) async {
  final limite = limiteDe(error);
  if (limite == null) return false;
  final esAdmin = _esAdmin(ref);
  ref.invalidate(miPlanProvider);
  final p = await _planOLeer(ref, null);
  if (!context.mounted) return true;
  unawaited(
    mostrarLimitePlanSheet(
      context,
      limite: limite,
      funcion: funcion,
      plan: p,
      esAdmin: esAdmin,
    ),
  );
  return true;
}

/// Ícono de un control de escritura: candado si el usuario está en solo
/// lectura (el control conserva lugar, variante y tamaño).
IconData iconoEscritura(bool puedeEscribir, IconData icono) =>
    puedeEscribir ? icono : Icons.lock_outline;

/// Etiqueta de accesibilidad de un control de escritura.
String semanticaEscritura(bool puedeEscribir, String label) =>
    puedeEscribir ? label : '$label, bloqueado, solo lectura';
