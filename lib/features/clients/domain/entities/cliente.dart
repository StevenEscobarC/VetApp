/// Dueño de una o más mascotas, gestionado por el veterinario dentro de su
/// clínica ([clinicaId]). No requiere cuenta propia — [perfilesId] es null
/// hasta que el veterinario genera un código de vinculación (CLI-05) y el
/// dueño lo reclama desde su cuenta CLIENTE (Fase 9). [numeroMascotas] es un
/// agregado de solo lectura calculado en cada consulta (`mascotas(count)`
/// embebido) — nunca una lista almacenada, para que nunca se desincronice de
/// la tabla `mascotas`. [cedula] es opcional y se guarda como solo dígitos
/// (D-24); sale en las cuentas de cobro.
class Cliente {
  const Cliente({
    required this.id,
    required this.clinicaId,
    required this.nombre,
    required this.telefono,
    this.email,
    this.direccion,
    this.notas,
    this.cedula,
    this.perfilesId,
    this.codigoVinculacion,
    this.codigoExpiraEn,
    this.numeroMascotas = 0,
  });

  final String id;
  final String clinicaId;
  final String nombre;
  final String telefono;
  final String? email;
  final String? direccion;
  final String? notas;
  final String? cedula;
  final String? perfilesId;
  final String? codigoVinculacion;
  final DateTime? codigoExpiraEn;
  final int numeroMascotas;

  bool get tieneVinculacion => perfilesId != null;

  Cliente copyWith({
    String? nombre,
    String? telefono,
    String? email,
    String? direccion,
    String? notas,
    String? cedula,
  }) => Cliente(
    id: id,
    clinicaId: clinicaId,
    nombre: nombre ?? this.nombre,
    telefono: telefono ?? this.telefono,
    email: email ?? this.email,
    direccion: direccion ?? this.direccion,
    notas: notas ?? this.notas,
    cedula: cedula ?? this.cedula,
    perfilesId: perfilesId,
    codigoVinculacion: codigoVinculacion,
    codigoExpiraEn: codigoExpiraEn,
    numeroMascotas: numeroMascotas,
  );
}
