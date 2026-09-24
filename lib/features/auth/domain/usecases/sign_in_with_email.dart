import '../entities/veterinario.dart';
import '../repositories/auth_repository.dart';

class SignInWithEmail {
  const SignInWithEmail(this._repository);

  final AuthRepository _repository;

  Future<Veterinario> call({required String email, required String password}) {
    return _repository.signInWithEmail(email: email, password: password);
  }
}
