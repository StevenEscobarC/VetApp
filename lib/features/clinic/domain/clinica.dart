/// Datos de una clínica. Solo los administradores los editan, siempre a través
/// del RPC `actualizar_clinica`. [logoPath] es la ruta del objeto en el bucket
/// privado `clinica-logos`, nunca una URL (D-26/D-27).
class Clinica {
  const Clinica({
    required this.id,
    required this.nombre,
    required this.ciudad,
    required this.direccion,
    required this.telefono,
    this.logoPath,
  });

  factory Clinica.desdeJson(Map<String, dynamic> json) {
    final logo = json['logo_path'] as String?;
    return Clinica(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? '',
      ciudad: json['ciudad'] as String? ?? '',
      direccion: json['direccion'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      logoPath: (logo == null || logo.isEmpty) ? null : logo,
    );
  }

  final String id;
  final String nombre;
  final String ciudad;
  final String direccion;
  final String telefono;
  final String? logoPath;

  /// [quitarLogo] permite poner [logoPath] en null (copyWith no distingue
  /// "no cambiar" de "null" por sí solo).
  Clinica copyWith({
    String? nombre,
    String? ciudad,
    String? direccion,
    String? telefono,
    String? logoPath,
    bool quitarLogo = false,
  }) {
    return Clinica(
      id: id,
      nombre: nombre ?? this.nombre,
      ciudad: ciudad ?? this.ciudad,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      logoPath: quitarLogo ? null : (logoPath ?? this.logoPath),
    );
  }
}
