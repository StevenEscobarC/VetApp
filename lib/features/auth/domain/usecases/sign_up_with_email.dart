import '../entities/veterinario.dart';
import '../repositories/auth_repository.dart';

class SignUpWithEmail {
  const SignUpWithEmail(this._repository);

  final AuthRepository _repository;

  Future<Veterinario> call({
    required String email,
    required String password,
    required String nombre,
    required String telefono,
  }) {
    return _repository.signUpWithEmail(
      email: email,
      password: password,
      nombre: nombre,
      telefono: telefono,
    );
  }
}
