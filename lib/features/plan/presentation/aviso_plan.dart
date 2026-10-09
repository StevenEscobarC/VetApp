import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mi_plan.dart';
import 'plan_textos.dart';

/// Variantes del aviso de Inicio, en el orden de prioridad de UI-SPEC §3.
/// [ultimosDias] cubre prueba Pro, prueba Clínica, plan pago y Beta con fecha.
enum TipoAviso {
  soloLectura,
  gracia,
  pacientesTope,
  ultimosDias,
  pacientes80,
  miembros80,
}

/// Aviso suave de plan que muestra Inicio: como mucho uno a la vez.
class AvisoPlan {
  const AvisoPlan({
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.descartable,
    required this.icono,
  });

  final TipoAviso tipo;
  final String titulo;
  final String mensaje;

  /// Las variantes de prioridad 1-3 nunca se pueden descartar.
  final bool descartable;
  final IconData icono;
}

/// Mínimo de cupos para avisar de veterinarios al 80 %: con planes de 1, 2 o 3
/// cupos nunca hay aviso (un veterinario solo siempre va en 1 de 1).
const int _kMinimoCuposAviso = 5;

String _cuando(int dias) => switch (dias) {
  0 => 'termina hoy',
  1 => 'termina mañana',
  _ => 'termina en $dias días',
};

String _diasGracia(int dias) => switch (dias) {
  0 => 'Hoy es el último día de gracia.',
  1 => 'Tienes 1 día de gracia.',
  _ => 'Tienes $dias días de gracia.',
};

/// Aviso que corresponde a [plan] o `null` si no hay ninguno. Los únicos
/// cálculos son los umbrales de presentación (80 % de pacientes, 80 % de
/// cupos desde 5, 7 días); fechas y días vienen del servidor.
AvisoPlan? avisoPlanPara(MiPlan plan, {required bool esAdmin}) {
  // 1. Solo lectura.
  if (!plan.puedeEscribir) {
    return const AvisoPlan(
      tipo: TipoAviso.soloLectura,
      titulo: 'Tu cuenta está en solo lectura',
      mensaje:
          'Puedes ver todo, pero no crear ni editar. Habla con el '
          'administrador de tu clínica.',
      descartable: false,
      icono: Icons.lock_outline,
    );
  }

  // 2. Gracia.
  if (plan.estado == EstadoPlan.gracia) {
    final dias = _diasGracia(plan.diasRestantes ?? 0);
    return AvisoPlan(
      tipo: TipoAviso.gracia,
      titulo: esAdmin ? 'Tu plan venció' : 'El plan de tu clínica venció',
      mensaje: esAdmin
          ? (plan.hayColegas
                ? '$dias Después, tus colegas quedarán en solo lectura.'
                : '$dias Después volverás al plan Gratis.')
          : '$dias Avisa al administrador para renovarlo.',
      descartable: false,
      icono: Icons.schedule,
    );
  }

  // 3. Pacientes al 100 %.
  final maxPacientes = plan.pacientesMax;
  if (plan.pacientesAlTope) {
    return AvisoPlan(
      tipo: TipoAviso.pacientesTope,
      titulo: 'Llegaste a los $maxPacientes pacientes',
      mensaje:
          'Sigues atendiendo con normalidad. Para registrar más pacientes, '
          'activa Pro.${esAdmin ? '' : ' Avisa al administrador.'}',
      descartable: false,
      icono: Icons.pets_outlined,
    );
  }

  // 4. Últimos 7 días de prueba, plan pago o Beta con fecha.
  final dias = plan.diasRestantes;
  final conFecha =
      plan.esPrueba ||
      plan.origen == OrigenPlan.pagado ||
      plan.plan == PlanTipo.beta;
  if (plan.estado == EstadoPlan.vigente &&
      dias != null &&
      dias <= kDiasAlerta &&
      conFecha) {
    return _ultimosDias(plan, dias, esAdmin);
  }

  // 5. Pacientes entre 80 % y 99 %.
  if (maxPacientes != null && plan.pacientesCount * 100 >= maxPacientes * 80) {
    return AvisoPlan(
      tipo: TipoAviso.pacientes80,
      titulo: 'Vas en ${plan.pacientesCount} de $maxPacientes pacientes',
      mensaje: 'Con Pro registras pacientes ilimitados.',
      descartable: true,
      icono: Icons.pets_outlined,
    );
  }

  // 6. Veterinarios al 80 %, solo con 5 cupos o más.
  final cupos = plan.miembrosMax;
  if (cupos != null &&
      cupos >= _kMinimoCuposAviso &&
      plan.veterinariosActivos * 100 >= cupos * 80) {
    return AvisoPlan(
      tipo: TipoAviso.miembros80,
      titulo: 'Vas en ${plan.veterinariosActivos} de $cupos veterinarios',
      mensaje: esAdmin
          ? 'Escríbenos por WhatsApp si necesitan más cupos.'
          : 'Avisa al administrador si necesitan más cupos.',
      descartable: true,
      icono: Icons.info_outline,
    );
  }

  return null;
}

AvisoPlan _ultimosDias(MiPlan plan, int dias, bool esAdmin) {
  final cuando = _cuando(dias);
  final String titulo;
  final String mensaje;
  if (plan.plan == PlanTipo.beta) {
    titulo = esAdmin
        ? 'Tu acceso Beta $cuando'
        : 'El acceso Beta de tu clínica $cuando';
    mensaje = !esAdmin
        ? 'Avisa al administrador de tu clínica para activar un plan.'
        : plan.hayColegas
        ? 'Después pasarás al plan Gratis y tus colegas quedarán en solo '
              'lectura. No pierdes ningún dato.'
        : 'Después pasarás al plan Gratis. No pierdes ningún dato. '
              'Escríbenos por WhatsApp para activar tu plan.';
  } else if (plan.origen == OrigenPlan.pruebaClinica) {
    titulo = 'Tu prueba Clínica $cuando';
    mensaje = plan.hayColegas
        ? 'Después tendrás 15 días de gracia; luego tus colegas quedarán en '
              'solo lectura.'
        : 'Al terminar volverás a tu plan anterior. No pierdes ningún dato.';
  } else if (plan.origen == OrigenPlan.pruebaPro) {
    titulo = 'Tu prueba Pro $cuando';
    mensaje = 'Al terminar volverás al plan Gratis. No pierdes ningún dato.';
  } else {
    titulo = 'Tu plan $cuando';
    mensaje = esAdmin
        ? 'Escríbenos por WhatsApp para renovarlo.'
        : 'Avisa al administrador de tu clínica para renovarlo.';
  }
  return AvisoPlan(
    tipo: TipoAviso.ultimosDias,
    titulo: titulo,
    mensaje: mensaje,
    descartable: true,
    icono: Icons.schedule,
  );
}

/// Avisos que el usuario cerró en esta sesión. Solo en memoria: al reabrir la
/// app el aviso vuelve mientras la condición siga vigente.
class AvisosDescartados extends Notifier<Set<TipoAviso>> {
  @override
  Set<TipoAviso> build() => const {};

  void descartar(TipoAviso tipo) => state = {...state, tipo};
}

final avisosDescartadosProvider =
    NotifierProvider<AvisosDescartados, Set<TipoAviso>>(AvisosDescartados.new);
