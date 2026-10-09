import 'package:flutter_riverpod/misc.dart';
import 'package:vetapp/features/plan/data/repositories/supabase_plan_repository.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/plan/presentation/providers/plan_providers.dart';

/// In-memory [SupabasePlanRepository] stand-in; [error] is thrown by
/// [miPlan] so tests can exercise the error branch. [llamadas] counts reads.
class FakePlanRepository implements SupabasePlanRepository {
  FakePlanRepository({MiPlan? plan, this.error}) : plan = plan ?? planBeta;

  MiPlan plan;
  Object? error;
  int llamadas = 0;

  @override
  Future<MiPlan> miPlan() async {
    llamadas++;
    if (error != null) throw error!;
    return plan;
  }
}

/// Plan sin límites y con escritura permitida: el valor por defecto para que
/// los tests de otras pantallas no tropiecen con el plan.
final MiPlan planBeta = MiPlan(
  plan: PlanTipo.beta,
  origen: OrigenPlan.beta,
  estado: EstadoPlan.sinVencimiento,
  fundador: false,
  pacientesCount: 42,
  veterinariosActivos: 2,
  logoPermitido: true,
  logoGuardado: false,
  protocolosPropiosPermitidos: true,
  puedeEscribir: true,
  pruebaClinicaDisponible: false,
  pruebaClinicaMiembros: 5,
  hayColegas: true,
  clinicaNombre: 'Clínica Patitas',
);

final MiPlan planGratis = MiPlan(
  plan: PlanTipo.gratis,
  origen: OrigenPlan.gratis,
  estado: EstadoPlan.sinVencimiento,
  fundador: false,
  pacientesCount: 42,
  pacientesMax: 50,
  veterinariosActivos: 1,
  miembrosMax: 1,
  logoPermitido: false,
  logoGuardado: false,
  protocolosPropiosPermitidos: false,
  puedeEscribir: true,
  pruebaClinicaDisponible: true,
  pruebaClinicaMiembros: 5,
  hayColegas: false,
  clinicaNombre: 'Clínica Patitas',
);

final MiPlan planGratisAlTope = planGratis.copyWith(pacientesCount: 50);

final MiPlan planProTrial = MiPlan(
  plan: PlanTipo.pro,
  origen: OrigenPlan.pruebaPro,
  estado: EstadoPlan.vigente,
  fundador: false,
  vigenteHasta: DateTime.utc(2026, 10, 31),
  diasRestantes: 12,
  pacientesCount: 42,
  veterinariosActivos: 1,
  miembrosMax: 1,
  logoPermitido: true,
  logoGuardado: false,
  protocolosPropiosPermitidos: true,
  puedeEscribir: true,
  pruebaClinicaDisponible: true,
  pruebaClinicaMiembros: 5,
  hayColegas: false,
  clinicaNombre: 'Clínica Patitas',
);

final MiPlan planClinicaTrial = MiPlan(
  plan: PlanTipo.clinica,
  origen: OrigenPlan.pruebaClinica,
  estado: EstadoPlan.vigente,
  fundador: false,
  vigenteHasta: DateTime.utc(2026, 10, 31),
  diasRestantes: 12,
  pacientesCount: 42,
  veterinariosActivos: 2,
  miembrosMax: 5,
  logoPermitido: true,
  logoGuardado: true,
  protocolosPropiosPermitidos: true,
  puedeEscribir: true,
  pruebaClinicaDisponible: false,
  pruebaClinicaMiembros: 5,
  hayColegas: true,
  clinicaNombre: 'Clínica Patitas',
);

final MiPlan planProPagadoFundador = MiPlan(
  plan: PlanTipo.pro,
  origen: OrigenPlan.pagado,
  estado: EstadoPlan.sinVencimiento,
  fundador: true,
  pacientesCount: 120,
  veterinariosActivos: 1,
  miembrosMax: 1,
  logoPermitido: true,
  logoGuardado: true,
  protocolosPropiosPermitidos: true,
  puedeEscribir: true,
  pruebaClinicaDisponible: true,
  pruebaClinicaMiembros: 5,
  hayColegas: false,
  clinicaNombre: 'Clínica Patitas',
);

final MiPlan planGracia = MiPlan(
  plan: PlanTipo.clinica,
  origen: OrigenPlan.pagado,
  estado: EstadoPlan.gracia,
  fundador: false,
  vigenteHasta: DateTime.utc(2026, 9, 30),
  graciaHasta: DateTime.utc(2026, 10, 15),
  diasRestantes: 9,
  pacientesCount: 80,
  veterinariosActivos: 3,
  miembrosMax: 3,
  logoPermitido: true,
  logoGuardado: true,
  protocolosPropiosPermitidos: true,
  puedeEscribir: true,
  pruebaClinicaDisponible: false,
  pruebaClinicaMiembros: 5,
  hayColegas: true,
  clinicaNombre: 'Clínica Patitas',
);

final MiPlan planSoloLectura = MiPlan(
  plan: PlanTipo.gratis,
  origen: OrigenPlan.gratis,
  estado: EstadoPlan.sinVencimiento,
  fundador: false,
  ultimoVencimiento: DateTime.utc(2026, 9, 1),
  ultimoOrigen: OrigenPlan.pagado,
  pacientesCount: 42,
  pacientesMax: 50,
  veterinariosActivos: 2,
  miembrosMax: 1,
  logoPermitido: false,
  logoGuardado: true,
  protocolosPropiosPermitidos: false,
  puedeEscribir: false,
  pruebaClinicaDisponible: false,
  pruebaClinicaMiembros: 5,
  hayColegas: true,
  clinicaNombre: 'Clínica Patitas',
);

/// Overrides listos para cualquier test que renderice algo que lea el plan.
List<Override> planOverrides({MiPlan? plan, Object? error}) => [
  planRepositoryProvider.overrideWithValue(
    FakePlanRepository(plan: plan, error: error),
  ),
];
