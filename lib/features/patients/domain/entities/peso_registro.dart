/// Entrada del historial de peso de una [Mascota] (PAT-05) — append-only:
/// `mascota_pesos` no tiene política de `update`/`delete` (RLS), así que
/// una corrección se registra siempre como una fila nueva, nunca editando
/// ni borrando una existente (02-RESEARCH.md Pitfall 2, T-02-PESO). Sin
/// `copyWith` a propósito: no existe un caso de uso legítimo para
/// "modificar" un registro ya guardado.
class PesoRegistro {
  const PesoRegistro({
    required this.id,
    required this.mascotaId,
    required this.pesoKg,
    required this.registradoEn,
  });

  final String id;
  final String mascotaId;
  final double pesoKg;
  final DateTime registradoEn;
}
