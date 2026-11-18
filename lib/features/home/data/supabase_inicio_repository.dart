import 'package:supabase_flutter/supabase_flutter.dart';

import '../../inventory/data/repositories/supabase_inventario_repository.dart'
    show esErrorDeRed;
import '../domain/inicio_failure.dart';
import '../domain/resumen_inicio.dart';

/// Lectura sin señal: no se perdió nada, así que no se habla de cambios
/// (D-14, mismo texto que las lecturas de cobros).
const String kMensajeSinConexionLectura =
    'Sin conexión. Inténtalo de nuevo cuando tengas señal.';

const String kErrorResumenInicio = 'No pudimos cargar el resumen del mes.';

/// Acceso concreto a Supabase para las cifras de Inicio. Solo lectura y
/// solo por RPC: `inicio_resumen` valida la clínica en el servidor, el
/// cliente no filtra nada.
class SupabaseInicioRepository {
  SupabaseInicioRepository(this._client);

  final SupabaseClient _client;

  /// Cifras del mes en curso; una respuesta vacía da todo en cero.
  Future<ResumenInicio> resumen() => _run(() async {
    final r = _filas(await _client.rpc('inicio_resumen'));
    if (r.isEmpty) return const ResumenInicio();
    final f = r.first;
    return ResumenInicio(
      consultasMes: (f['consultas_mes'] as num?)?.toInt() ?? 0,
      ingresosMes: (f['ingresos_mes'] as num?)?.toInt() ?? 0,
      pacientesNuevos: (f['pacientes_nuevos_mes'] as num?)?.toInt() ?? 0,
    );
  });

  Future<T> _run<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PostgrestException {
      throw const InicioFailure(kErrorResumenInicio);
    } catch (e) {
      if (esErrorDeRed(e)) {
        throw const InicioFailure(
          kMensajeSinConexionLectura,
          sinConexion: true,
        );
      }
      throw const InicioFailure(kErrorResumenInicio);
    }
  }

  List<Map<String, dynamic>> _filas(Object? r) => [
    for (final f in (r as List? ?? const [])) f as Map<String, dynamic>,
  ];
}
