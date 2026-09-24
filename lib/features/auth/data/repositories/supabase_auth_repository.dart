import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_failure.dart';

class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.telefono,
    this.clinicaId,
    this.clinicaNombre,
  });

  final String id;
  final String nombre;
  final String email;
  final String rol;
  final String telefono;
  final String? clinicaId;
  final String? clinicaNombre;

  bool get esVeterinario => rol == 'VETERINARIO';
}

class SupabaseAuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<AuthProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _profileFor(response.user!.id);
    } on AuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible iniciar sesión. Intenta de nuevo.',
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
    required String telefono,
    required String rol,
    String? clinicaNombre,
    String? ciudad,
    String? direccion,
    String? clinicaTelefono,
  }) async {
    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'nombre': nombre.trim(),
          'telefono': telefono.trim(),
          'rol': rol,
          if (clinicaNombre != null) 'clinica_nombre': clinicaNombre.trim(),
          if (ciudad != null) 'clinica_ciudad': ciudad.trim(),
          if (direccion != null) 'clinica_direccion': direccion.trim(),
          if (clinicaTelefono != null)
            'clinica_telefono': clinicaTelefono.trim(),
        },
      );
    } on AuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible crear la cuenta. Intenta de nuevo.',
      );
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible enviar el correo de recuperación.',
      );
    }
  }

  Future<AuthProfile> profileForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No hay una sesión activa.');
    }
    return _profileFor(user.id);
  }

  Future<AuthProfile> _profileFor(String userId) async {
    try {
      final data = await _client
          .from('perfiles')
          .select('id, nombre, rol, telefono, clinica_id, clinicas(nombre)')
          .eq('id', userId)
          .single();
      final clinic = data['clinicas'] as Map<String, dynamic>?;
      return AuthProfile(
        id: data['id'] as String,
        nombre: data['nombre'] as String? ?? '',
        email: _client.auth.currentUser?.email ?? '',
        rol: data['rol'] as String,
        telefono: data['telefono'] as String? ?? '',
        clinicaId: data['clinica_id'] as String?,
        clinicaNombre: clinic?['nombre'] as String?,
      );
    } catch (_) {
      throw const AuthFailure('No encontramos tu perfil. Intenta de nuevo.');
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  String _messageFor(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'Ya existe una cuenta con este correo.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirma tu correo electrónico antes de iniciar sesión.';
    }
    // Dev note: if this fires often during local testing, disable "Confirm
    // email" in Supabase (Authentication > Providers > Email) to stop the
    // rate-limited confirmation emails entirely.
    if (message.contains('rate limit')) {
      return 'Se alcanzó el límite de correos por ahora. Intenta de nuevo en unos minutos.';
    }
    if (message.contains('password')) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (message.contains('email')) return 'Ingresa un correo válido.';
    return 'No fue posible completar la solicitud. Intenta de nuevo.';
  }
}
