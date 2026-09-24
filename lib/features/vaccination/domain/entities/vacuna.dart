/// Biológicos comunes en la práctica veterinaria colombiana.
/// `otro` cubre casos no listados (ej. vacunas felinas específicas,
/// bordetella, leishmaniasis en zonas endémicas).
enum TipoBiologico {
  antirrabica,
  polivalenteOctuple,
  polivalenteSextuple,
  parvovirus,
  moquilloCanino,
  leptospirosis,
  tripleFelina,
  leucemiaFelina,
  desparasitacionInterna,
  desparasitacionExterna,
  otro,
}

/// Registro individual de vacunación/desparasitación. La lista de
/// [Vacuna] de una mascota, ordenada por fecha, compone su carné digital.
class Vacuna {
  const Vacuna({
    required this.id,
    required this.mascotaId,
    required this.veterinarioId,
    required this.tipo,
    this.nombreComercial,
    required this.fechaAplicacion,
    this.proximaDosis,
    this.lote,
  });

  final String id;
  final String mascotaId;
  final String veterinarioId;
  final TipoBiologico tipo;
  final String? nombreComercial;
  final DateTime fechaAplicacion;
  final DateTime? proximaDosis;
  final String? lote;

  bool get requiereRefuerzoProximo {
    if (proximaDosis == null) return false;
    final diasRestantes = proximaDosis!.difference(DateTime.now()).inDays;
    return diasRestantes <= 7;
  }
}
