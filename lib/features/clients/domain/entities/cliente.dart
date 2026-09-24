/// Dueño de una o más mascotas. Pertenece a un [Veterinario] (tenant).
class Cliente {
  const Cliente({
    required this.id,
    required this.veterinarioId,
    required this.nombre,
    required this.telefono,
    this.email,
    this.direccion,
    this.mascotaIds = const [],
  });

  final String id;
  final String veterinarioId;
  final String nombre;
  final String telefono;
  final String? email;
  final String? direccion;
  final List<String> mascotaIds;

  Cliente copyWith({
    String? nombre,
    String? telefono,
    String? email,
    String? direccion,
    List<String>? mascotaIds,
  }) {
    return Cliente(
      id: id,
      veterinarioId: veterinarioId,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      mascotaIds: mascotaIds ?? this.mascotaIds,
    );
  }
}
