import '../entities/veterinario.dart';
import '../repositories/auth_repository.dart';

class WatchCurrentVeterinario {
  const WatchCurrentVeterinario(this._repository);

  final AuthRepository _repository;

  Stream<Veterinario?> call() => _repository.watchCurrentVeterinario();
}
