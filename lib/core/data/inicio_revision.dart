import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contador de "las cifras o las próximas citas de Inicio cambiaron": cada
/// feature lo incrementa tras una escritura exitosa que afecta el resumen
/// (consultas, cobros, pacientes, citas). Vive en `core/` para que ninguna
/// feature tenga que importar `home/` (grafo de imports acíclico, D-13).
class InicioRevision extends Notifier<int> {
  @override
  int build() => 0;

  void incrementar() => state++;
}

final inicioRevisionProvider = NotifierProvider<InicioRevision, int>(
  InicioRevision.new,
);
