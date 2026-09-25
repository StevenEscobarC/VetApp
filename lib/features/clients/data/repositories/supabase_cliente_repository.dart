import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/busqueda.dart';
import '../../domain/cliente_failure.dart';
import '../../domain/entities/cliente.dart';

/// Acceso concreto a Supabase para `clientes`. Sigue el mismo patrón de
/// manejo de errores en dos niveles que `SupabaseAuthRepository` — sin una
/// interfaz `domain/repositories/`, por consistencia con el resto del código
/// ya construido en la Fase 1 (auth no tiene una tampoco).
class SupabaseClienteRepository {
  SupabaseClienteRepository(this._client);

  final SupabaseClient _client;

  /// Clientes de [clinicaId] que coinciden con [query] por nombre o
  /// teléfono (`query` vacío devuelve todos, ordenados por nombre). Cada
  /// fila incluye `numeroMascotas`, un conteo de solo lectura de sus
  /// mascotas asociadas.
  Future<List<Cliente>> buscar(
    String query, {
    required String clinicaId,
  }) async {
    try {
      var builder = _client
          .from('clientes')
          .select('*, mascotas(count)')
          .eq('clinica_id', clinicaId);
      final filtro = filtroOrIlike(
        columnas: ['nombre', 'telefono'],
        query: query,
      );
      if (filtro != null) {
        builder = builder.or(filtro);
      }
      final rows = await builder.order('nombre');
      return (rows as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ClienteFailure(_messageFor(e));
    } catch (_) {
      throw const ClienteFailure(
        'No pudimos cargar la lista. Intenta de nuevo.',
      );
    }
  }

  Cliente _fromRow(Map<String, dynamic> row) {
    final mascotas = row['mascotas'] as List?;
    final numeroMascotas = (mascotas != null && mascotas.isNotEmpty)
        ? (mascotas.first['count'] as int? ?? 0)
        : 0;
    final direccion = row['direccion'] as String?;
    final notas = row['notas'] as String?;
    final codigoExpiraEn = row['codigo_expira_en'] as String?;
    return Cliente(
      id: row['id'] as String,
      clinicaId: row['clinica_id'] as String,
      nombre: row['nombre'] as String,
      telefono: row['telefono'] as String,
      email: row['email'] as String?,
      direccion: (direccion == null || direccion.isEmpty) ? null : direccion,
      notas: (notas == null || notas.isEmpty) ? null : notas,
      perfilesId: row['perfiles_id'] as String?,
      codigoVinculacion: row['codigo_vinculacion'] as String?,
      codigoExpiraEn: codigoExpiraEn == null
          ? null
          : DateTime.parse(codigoExpiraEn),
      numeroMascotas: numeroMascotas,
    );
  }

  /// Traducciones centralizadas de `PostgrestException.code` a mensajes en
  /// español — agregar nuevos códigos aquí, nunca inline en un call site.
  String _messageFor(PostgrestException e) {
    switch (e.code) {
      case '42501':
        return 'No tienes permiso para realizar esta acción.';
      case '23505':
        return 'Ya existe un cliente con estos datos.';
      case 'PGRST116':
        return 'No encontramos el cliente.';
      default:
        return 'No fue posible completar la solicitud. Intenta de nuevo.';
    }
  }
}
