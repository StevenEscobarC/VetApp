/// Servicio del catálogo de la clínica con su tarifa base en pesos enteros.
/// La tarifa solo sugiere el precio de la línea; cambiarla nunca altera
/// documentos ya emitidos (D-14).
class Servicio {
  const Servicio({
    required this.id,
    required this.nombre,
    required this.precioCop,
  });

  final String id;
  final String nombre;
  final int precioCop;
}
