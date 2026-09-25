import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/busqueda.dart';
import '../../domain/entities/mascota.dart';
import '../../domain/mascota_failure.dart';

/// Búsqueda de mascotas en dos pasos (PAT-04, D-06): PostgREST no combina de
/// forma confiable un filtro sobre una tabla embebida (`clientes.nombre`)
/// con filtros de la propia tabla dentro de un solo `.or()` — por eso primero
/// se resuelven los ids de dueño que matchean por nombre ([resolverDuenos]),
/// y luego se pliegan en el `.or()` de la consulta de mascotas ([consultar])
/// vía `.in.()`. Query vacía nunca resuelve dueños ni agrega un `.or()` —
/// [consultar] se llama directamente con `filtro: null`. Extraída como
/// función top-level (en vez de un método privado) para poder probar la
/// lógica de orquestación sin un `SupabaseClient` real.
Future<List<Mascota>> buscarMascotasEnDosPasos({
  required String query,
  required Future<List<String>> Function(String q) resolverDuenos,
  required Future<List<Mascota>> Function(String? filtro) consultar,
}) async {
  final q = sanitizarBusqueda(query);
  if (q.isEmpty) return consultar(null);
  final ids = await resolverDuenos(q);
  final filtro = filtroOrIlike(
    columnas: ['nombre', 'especie'],
    query: q,
    columnaIn: 'dueno_id',
    valoresIn: ids,
  );
  return consultar(filtro);
}

/// Acceso concreto a Supabase para `mascotas`. Sigue el mismo patrón de
/// manejo de errores en dos niveles que `SupabaseClienteRepository` — sin
/// una interfaz `domain/repositories/`, por consistencia con el resto del
/// código ya construido en la Fase 1 (auth no tiene una tampoco).
class SupabaseMascotaRepository {
  SupabaseMascotaRepository(this._client);

  final SupabaseClient _client;

  static final DateFormat _formatoIso = DateFormat('yyyy-MM-dd');

  /// Registra un cliente nuevo y su primera mascota en una sola llamada
  /// atómica a `registrar_cliente_con_mascota` (D-02) — nunca dos inserts
  /// secuenciales, para no dejar un cliente huérfano si la mascota falla.
  Future<({String clienteId, String mascotaId})> registrarClienteConMascota({
    required String clienteNombre,
    required String clienteTelefono,
    required String mascotaNombre,
    required Especie mascotaEspecie,
    String? mascotaRaza,
    DateTime? mascotaFechaNacimiento,
    double? mascotaPesoKg,
  }) async {
    try {
      final rows = await _client.rpc(
        'registrar_cliente_con_mascota',
        params: {
          'cliente_nombre': clienteNombre.trim(),
          'cliente_telefono': clienteTelefono.trim(),
          'mascota_nombre': mascotaNombre.trim(),
          'mascota_especie': mascotaEspecie.name,
          'mascota_raza': mascotaRaza?.trim() ?? '',
          'mascota_fecha_nacimiento': mascotaFechaNacimiento == null
              ? null
              : _formatoIso.format(mascotaFechaNacimiento),
          'mascota_peso_kg': mascotaPesoKg,
        },
      );
      final row = (rows as List).first as Map<String, dynamic>;
      return (
        clienteId: row['cliente_id'] as String,
        mascotaId: row['mascota_id'] as String,
      );
    } on PostgrestException catch (e) {
      throw MascotaFailure(_messageFor(e));
    } catch (_) {
      throw const MascotaFailure(
        'No pudimos guardar los datos. Intenta de nuevo.',
      );
    }
  }

  /// Busca mascotas de [clinicaId] por nombre, especie o nombre de dueño
  /// (PAT-04, D-06) — `query` vacía devuelve todas, ordenadas por nombre. Ver
  /// [buscarMascotasEnDosPasos] para la razón del enfoque de dos pasos (nunca
  /// un único `.or()` mezclando `clientes.nombre` con columnas propias).
  Future<List<Mascota>> buscar(String query, {required String clinicaId}) {
    return buscarMascotasEnDosPasos(
      query: query,
      resolverDuenos: (q) async {
        try {
          final rows = await _client
              .from('clientes')
              .select('id')
              .eq('clinica_id', clinicaId)
              .ilike('nombre', '%$q%')
              .limit(50);
          return (rows as List).map((row) => row['id'] as String).toList();
        } on PostgrestException catch (e) {
          throw MascotaFailure(_messageFor(e));
        } catch (_) {
          throw const MascotaFailure(
            'No pudimos cargar la lista. Intenta de nuevo.',
          );
        }
      },
      consultar: (filtro) async {
        try {
          var builder = _client
              .from('mascotas')
              .select('*, clientes!mascotas_dueno_misma_clinica_fkey(nombre)')
              .eq('clinica_id', clinicaId);
          if (filtro != null) {
            builder = builder.or(filtro);
          }
          final rows = await builder.order('nombre');
          return (rows as List)
              .map((row) => _fromRow(row as Map<String, dynamic>))
              .toList();
        } on PostgrestException catch (e) {
          throw MascotaFailure(_messageFor(e));
        } catch (_) {
          throw const MascotaFailure(
            'No pudimos cargar la lista. Intenta de nuevo.',
          );
        }
      },
    );
  }

  /// Mascotas del cliente [clienteId], ordenadas por nombre. Usada por
  /// `mascotasDeClienteProvider` (Plan 07, CLI-04).
  Future<List<Mascota>> porCliente(String clienteId) async {
    try {
      final rows = await _client
          .from('mascotas')
          .select()
          .eq('dueno_id', clienteId)
          .order('nombre');
      return (rows as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw MascotaFailure(_messageFor(e));
    } catch (_) {
      throw const MascotaFailure(
        'No pudimos cargar la lista. Intenta de nuevo.',
      );
    }
  }

  /// Actualiza `foto_path` tras una subida a Storage exitosa (Plan 05) —
  /// nunca almacena la URL firmada, solo la ruta estable del objeto.
  Future<void> actualizarFotoPath(String mascotaId, String fotoPath) async {
    try {
      await _client
          .from('mascotas')
          .update({'foto_path': fotoPath})
          .eq('id', mascotaId)
          .select('id')
          .single();
    } on PostgrestException catch (e) {
      throw MascotaFailure(_messageFor(e));
    } catch (_) {
      throw const MascotaFailure(
        'No pudimos guardar los datos. Intenta de nuevo.',
      );
    }
  }

  Mascota _fromRow(Map<String, dynamic> row) {
    final raza = row['raza'] as String?;
    final fechaNacimiento = row['fecha_nacimiento'] as String?;
    final clientes = row['clientes'] as Map<String, dynamic>?;
    return Mascota(
      id: row['id'] as String,
      duenoId: row['dueno_id'] as String,
      clinicaId: row['clinica_id'] as String,
      nombre: row['nombre'] as String,
      especie: especieDesdeTexto(row['especie'] as String),
      raza: (raza == null || raza.isEmpty) ? null : raza,
      fechaNacimiento: fechaNacimiento == null
          ? null
          : DateTime.parse(fechaNacimiento),
      fotoPath: row['foto_path'] as String?,
      duenoNombre: clientes?['nombre'] as String?,
    );
  }

  /// Traducciones centralizadas de `PostgrestException.code` a mensajes en
  /// español — agregar nuevos códigos aquí, nunca inline en un call site.
  String _messageFor(PostgrestException e) {
    switch (e.code) {
      case '42501':
        return 'No tienes permiso para realizar esta acción.';
      case '23503':
        return 'El dueño seleccionado no existe en tu clínica.';
      case '23514':
        return 'Revisa los datos ingresados.';
      case 'PGRST116':
        return 'No encontramos la mascota.';
      default:
        return 'No pudimos guardar los datos. Intenta de nuevo.';
    }
  }
}
