import 'package:vetapp/core/utils/compartir.dart';

/// [Compartidor] de prueba: registra los textos en [compartidos] y lanza
/// [error] si está definido.
class FakeCompartidor implements Compartidor {
  FakeCompartidor({this.error});

  Object? error;
  final List<String> compartidos = [];

  @override
  Future<void> compartirTexto(String texto) async {
    if (error != null) throw error!;
    compartidos.add(texto);
  }
}
