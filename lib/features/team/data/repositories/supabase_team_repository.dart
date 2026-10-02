import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/codigo_invitacion.dart';
import '../../domain/invitacion.dart';
import '../../domain/miembro.dart';
import '../../domain/team_failure.dart';

/// Acceso concreto a Supabase para el equipo de la clínica. Mismo patrón de
/// errores en dos niveles que los demás repositorios.
class SupabaseTeamRepository {
  SupabaseTeamRepository(this._client);

  final SupabaseClient _client;

  /// Veterinarios de [clinicaId] (activos y retirados) por antigüedad. El
  /// filtro de clínica es obligatorio: `perfiles_select` también devuelve
  /// autores de otras clínicas (D-13) que no son miembros.
  Future<List<Miembro>> miembros(String clinicaId) async {
    try {
      final rows = await _client
          .from('perfiles')
          .select('id, nombre, rol_clinica, activo, matricula, created_at')
          .eq('clinica_id', clinicaId)
          .eq('rol', 'VETERINARIO')
          .order('created_at');
      return (rows as List).map((r) {
        final row = r as Map<String, dynamic>;
        return Miembro(
          id: row['id'] as String,
          nombre: row['nombre'] as String? ?? '',
          rolClinica: row['rol_clinica'] as String? ?? 'veterinario',
          activo: row['activo'] as bool? ?? true,
          matricula: row['matricula'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e));
    } catch (_) {
      throw const TeamFailure('No pudimos cargar el equipo. Intenta de nuevo.');
    }
  }

  /// Invitación vigente (sin usar, sin revocar, no vencida) de [clinicaId], o
  /// `null`. Solo el administrador puede leerla (RLS).
  Future<Invitacion?> invitacionVigente(String clinicaId) async {
    try {
      final row = await _client
          .from('clinica_invitaciones')
          .select('id, codigo, expira_en')
          .eq('clinica_id', clinicaId)
          .isFilter('usada_por', null)
          .eq('revocada', false)
          .gt('expira_en', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return _invitacionDe(row);
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e));
    } catch (_) {
      throw const TeamFailure('No pudimos cargar el equipo. Intenta de nuevo.');
    }
  }

  /// Genera un código nuevo; el servidor revoca el vigente anterior.
  Future<Invitacion> generarInvitacion() async {
    try {
      final rows = await _client.rpc('generar_invitacion_clinica');
      return _invitacionDe((rows as List).first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e, fallback: _fallbackGenerar));
    } catch (_) {
      throw const TeamFailure(_fallbackGenerar);
    }
  }

  Future<void> revocarInvitacion(String id) async {
    try {
      await _client.rpc('revocar_invitacion', params: {'p_id': id});
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e, fallback: _fallbackRevocar));
    } catch (_) {
      throw const TeamFailure(_fallbackRevocar);
    }
  }

  /// Citas abiertas (pendiente/confirmada) de [veterinarioId] desde [desde].
  /// RLS deja leer las citas de toda la clínica.
  Future<int> contarCitasAbiertas(String veterinarioId, DateTime desde) async {
    try {
      final rows = await _client
          .from('citas')
          .select('id')
          .eq('veterinario_id', veterinarioId)
          .inFilter('estado', ['pendiente', 'confirmada'])
          .gte('fecha_hora', desde.toUtc().toIso8601String());
      return (rows as List).length;
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e, fallback: _fallbackCambio));
    } catch (_) {
      throw const TeamFailure(_fallbackCambio);
    }
  }

  /// Retira (desactiva) a [miembroId]; devuelve cuántas citas se reasignaron.
  Future<int> retirarMiembro(String miembroId, {String? reasignarA}) async {
    try {
      final res = await _client.rpc(
        'retirar_miembro',
        params: {'p_miembro': miembroId, 'p_reasignar_a': reasignarA},
      );
      return (res as num).toInt();
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e, fallback: _fallbackCambio));
    } catch (_) {
      throw const TeamFailure(_fallbackCambio);
    }
  }

  /// [rol]: `admin` o `veterinario`.
  Future<void> cambiarRol(String miembroId, String rol) async {
    try {
      await _client.rpc(
        'cambiar_rol_miembro',
        params: {'p_miembro': miembroId, 'p_rol': rol},
      );
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e, fallback: _fallbackCambio));
    } catch (_) {
      throw const TeamFailure(_fallbackCambio);
    }
  }

  /// Crea una clínica vacía para un veterinario sin clínica activa (D-05).
  Future<void> crearMiClinica(String nombre) async {
    try {
      await _client.rpc('crear_mi_clinica', params: {'p_nombre': nombre.trim()});
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e, fallback: _fallbackCrear));
    } catch (_) {
      throw const TeamFailure(_fallbackCrear);
    }
  }

  /// Une al veterinario a otra clínica con un código de invitación.
  Future<void> unirseAClinica(String codigo) async {
    try {
      await _client.rpc(
        'unirse_a_clinica',
        params: {'p_codigo': normalizarCodigoInvitacion(codigo)},
      );
    } on PostgrestException catch (e) {
      throw TeamFailure(_messageFor(e, fallback: _fallbackUnirse));
    } catch (_) {
      throw const TeamFailure(_fallbackUnirse);
    }
  }

  static const _fallbackCrear =
      'No pudimos crear la clínica. Intenta de nuevo.';
  static const _fallbackUnirse =
      'No pudimos unirte a la clínica. Intenta de nuevo.';
  static const _fallbackCambio =
      'No pudimos completar el cambio. Intenta de nuevo.';
  static const _fallbackGenerar =
      'No pudimos generar el código. Intenta de nuevo.';
  static const _fallbackRevocar =
      'No pudimos revocar el código. Intenta de nuevo.';

  Invitacion _invitacionDe(Map<String, dynamic> row) => Invitacion(
    id: row['id'] as String,
    codigo: row['codigo'] as String,
    expiraEn: DateTime.parse(row['expira_en'] as String).toUtc(),
  );

  String _messageFor(
    PostgrestException error, {
    String fallback = 'No pudimos cargar el equipo. Intenta de nuevo.',
  }) {
    final msg = error.message.toLowerCase();
    if (msg.contains('al menos un administrador')) {
      return 'La clínica debe tener al menos un administrador.';
    }
    if (msg.contains('ya no está en tu clínica')) {
      return 'Ese veterinario ya no está en tu clínica.';
    }
    if (msg.contains('ya venció')) {
      return 'Ese código ya venció. Pídele al administrador uno nuevo.';
    }
    if (msg.contains('ya fue utilizado')) {
      return 'Ese código ya fue utilizado. Pídele al administrador uno nuevo.';
    }
    if (msg.contains('no es válido')) {
      return 'Ese código no es válido. Revísalo e inténtalo de nuevo.';
    }
    if (msg.contains('ya tiene datos')) {
      return 'Tu clínica ya tiene datos; no se pueden fusionar clínicas. '
          'Regístrate con otro correo para unirte.';
    }
    if (msg.contains('ya perteneces')) {
      return 'Ya perteneces a una clínica activa.';
    }
    if (error.code == '42501') return 'Solo un administrador puede hacer esto.';
    return fallback;
  }
}
