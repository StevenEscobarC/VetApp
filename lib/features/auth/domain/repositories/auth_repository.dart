import '../entities/veterinario.dart';

abstract class AuthRepository {
  /// `null` cuando no hay sesión activa. Emite de nuevo cada vez que el
  /// documento `veterinarios/{uid}` cambia (nombre, clínica, etc.).
  Stream<Veterinario?> watchCurrentVeterinario();

  Future<Veterinario> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Veterinario> signUpWithEmail({
    required String email,
    required String password,
    required String nombre,
    required String telefono,
  });

  Future<Veterinario> signInWithGoogle();

  Future<void> signOut();
}
