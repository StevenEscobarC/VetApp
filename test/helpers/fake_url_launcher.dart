import 'package:vetapp/core/utils/lanzador_externo.dart';

/// [LanzadorExterno] de prueba: registra cada [Uri] (de ambos métodos) en
/// [abiertos] y el método usado en [metodos]. [abrir] devuelve [resultado];
/// [abrirEnApp] devuelve [resultadoApp] o, si es null, [resultado].
class FakeLanzadorExterno implements LanzadorExterno {
  bool resultado = true;
  bool? resultadoApp;
  final List<Uri> abiertos = [];
  final List<String> metodos = [];

  @override
  Future<bool> abrir(Uri uri) async {
    abiertos.add(uri);
    metodos.add('abrir');
    return resultado;
  }

  @override
  Future<bool> abrirEnApp(Uri uri) async {
    abiertos.add(uri);
    metodos.add('abrirEnApp');
    return resultadoApp ?? resultado;
  }
}
