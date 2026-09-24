/// Cuenta del veterinario/clínica que usa la app. Es el tenant raíz:
/// todos los demás datos (clientes, mascotas, citas...) cuelgan de
/// `veterinarios/{id}` en Firestore.
class Veterinario {
  const Veterinario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    this.nombreClinica,
    this.especialidad,
    required this.fechaRegistro,
  });

  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String? nombreClinica;
  final String? especialidad;
  final DateTime fechaRegistro;

  Veterinario copyWith({
    String? nombre,
    String? email,
    String? telefono,
    String? nombreClinica,
    String? especialidad,
  }) {
    return Veterinario(
      id: id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      nombreClinica: nombreClinica ?? this.nombreClinica,
      especialidad: especialidad ?? this.especialidad,
      fechaRegistro: fechaRegistro,
    );
  }
}
