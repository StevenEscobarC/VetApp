import 'package:vetapp/core/utils/lanzador_externo.dart';

/// [LanzadorExterno] de prueba: registra cada [Uri] y devuelve [resultado].
class FakeLanzadorExterno implements LanzadorExterno {
  bool resultado = true;
  final List<Uri> abiertos = [];

  @override
  Future<bool> abrir(Uri uri) async {
    abiertos.add(uri);
    return resultado;
  }
}
