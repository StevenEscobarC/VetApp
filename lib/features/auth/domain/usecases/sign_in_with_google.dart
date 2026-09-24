import '../entities/veterinario.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  const SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  Future<Veterinario> call() => _repository.signInWithGoogle();
}
