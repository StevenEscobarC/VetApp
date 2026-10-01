import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/cita_failure.dart';
import '../../domain/entities/cita.dart';

/// Acceso concreto a Supabase para `citas` (lado lectura). Sin método de
/// borrado: cancelar una cita es un cambio de estado, no un `delete`.
/// Confía solo en RLS para aislar por clínica — no filtra en el cliente.
class SupabaseCitaRepository {
  SupabaseCitaRepository(this._client);

  final SupabaseClient _client;

  /// Los hints de relación fijan las FKs compuestas (misma clínica) para
  /// que PostgREST no sea ambiguo entre varias relaciones posibles.
  static const _select =
      '*, clientes!citas_cliente_misma_clinica_fkey(nombre, telefono, direccion), '
      'cita_mascotas(mascotas!cita_mascotas_mascota_fkey(id, nombre, especie, foto_path)), '
      'consultas(mascota_id)';

  /// Citas con `fecha_hora` en `[inicioUtc, finUtc)`, por hora ascendente.
  Future<List<Cita>> entre(DateTime inicioUtc, DateTime finUtc) async {
    try {
      final rows = await _client
          .from('citas')
          .select(_select)
          .gte('fecha_hora', inicioUtc.toUtc().toIso8601String())
          .lt('fecha_hora', finUtc.toUtc().toIso8601String())
          .order('fecha_hora');
      return (rows as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw CitaFailure(_messageFor(e));
    } catch (_) {
      throw const CitaFailure('No pudimos cargar la agenda. Intenta de nuevo.');
    }
  }

  /// Una cita por [id]; lanza [CitaFailure] si ya no existe.
  Future<Cita> obtener(String id) async {
    try {
      final row = await _client
          .from('citas')
          .select(_select)
          .eq('id', id)
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw CitaFailure(_messageFor(e));
    } catch (_) {
      throw const CitaFailure('No pudimos cargar la cita. Intenta de nuevo.');
    }
  }

  /// Crea una cita para [clienteId] con una o varias mascotas vía el RPC
  /// `crear_cita` (valida dueño/clínica en el servidor). Devuelve el id.
  /// `notas` y `direccion` se envían como '' (no null): las columnas son
  /// `not null default ''`.
  Future<String> crear({
    required String clienteId,
    required List<String> mascotaIds,
    required DateTime fechaHora,
    required int duracionMin,
    required ModalidadCita modalidad,
    required String direccion,
    required String motivo,
    required String notas,
  }) async {
    try {
      final id = await _client.rpc(
        'crear_cita',
        params: {
          'p_cliente_id': clienteId,
          'p_mascota_ids': mascotaIds,
          'p_fecha_hora': fechaHora.toUtc().toIso8601String(),
          'p_duracion_min': duracionMin,
          'p_modalidad': modalidad.valor,
          'p_direccion':
              modalidad == ModalidadCita.domicilio ? direccion.trim() : '',
          'p_motivo': motivo.trim(),
          'p_notas': notas.trim(),
        },
      );
      return id as String;
    } on PostgrestException catch (e) {
      throw CitaFailure(_messageFor(e));
    } catch (_) {
      throw const CitaFailure('No pudimos guardar la cita. Intenta de nuevo.');
    }
  }

  Cita _fromRow(Map<String, dynamic> row) {
    final cliente = row['clientes'] as Map<String, dynamic>?;
    final mascotas = ((row['cita_mascotas'] as List?) ?? const [])
        .map((e) => (e as Map<String, dynamic>)['mascotas'])
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => MascotaDeCita(
            id: m['id'] as String,
            nombre: m['nombre'] as String,
            especie: m['especie'] as String,
            fotoPath: m['foto_path'] as String?,
          ),
        )
        .toList();
    final conConsulta = ((row['consultas'] as List?) ?? const [])
        .map((e) => (e as Map<String, dynamic>)['mascota_id'])
        .whereType<String>()
        .toSet();

    return Cita(
      id: row['id'] as String,
      clinicaId: row['clinica_id'] as String,
      clienteId: row['cliente_id'] as String,
      veterinarioId: row['veterinario_id'] as String,
      fechaHora: DateTime.parse(row['fecha_hora'] as String).toUtc(),
      duracionMin: (row['duracion_min'] as num).toInt(),
      modalidad: ModalidadCita.desdeValor(row['modalidad'] as String),
      direccion: row['direccion'] as String?,
      motivo: row['motivo'] as String,
      notas: row['notas'] as String?,
      estado: EstadoCita.desdeValor(row['estado'] as String),
      recordatorioEnviadoAt: row['recordatorio_enviado_at'] == null
          ? null
          : DateTime.parse(row['recordatorio_enviado_at'] as String).toUtc(),
      clienteNombre: (cliente?['nombre'] as String?) ?? '',
      clienteTelefono: cliente?['telefono'] as String?,
      clienteDireccion: cliente?['direccion'] as String?,
      mascotas: mascotas,
      mascotasConConsulta: conConsulta,
    );
  }

  /// Traducciones centralizadas de `PostgrestException.code` a mensajes en
  /// español — agregar nuevos códigos aquí, nunca inline en un call site.
  String _messageFor(PostgrestException e) {
    switch (e.code) {
      case 'PGRST116':
        return 'Esta cita ya no existe.';
      case '42501':
        return 'No tienes permiso para gestionar citas.';
      case '23503':
        return 'El cliente o la mascota no existe en tu clínica.';
      case '23514':
        final m = e.message.toLowerCase();
        if (m.contains('domicilio')) {
          return 'Escribe la dirección para la visita a domicilio.';
        }
        if (m.contains('mascota')) return 'Elige al menos una mascota.';
        if (m.contains('editar')) {
          return 'Solo se pueden editar citas pendientes o confirmadas.';
        }
        return 'Revisa los datos de la cita.';
      case '23505':
        return 'Ya registraste una consulta para esta mascota en esta cita.';
      default:
        return 'No pudimos guardar la cita. Intenta de nuevo.';
    }
  }
}
