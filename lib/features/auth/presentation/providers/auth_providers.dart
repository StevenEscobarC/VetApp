import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/auth_failure.dart';

final authRepositoryProvider = Provider<SupabaseAuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Single long-lived subscription to gotrue's `onAuthStateChange`
/// (backed by a ReplaySubject: every new subscription replays every past
/// event). Do NOT subscribe to `authRepositoryProvider.authStateChanges`
/// anywhere else — [AuthProfileNotifier] is the only listener.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Single source of truth for "who is logged in", replacing `AuthGate`'s
/// local `setState`. Watched by both `routerProvider`'s redirect and every
/// data screen (starting with `InicioScreen`).
class AuthProfileNotifier extends AsyncNotifier<AuthProfile?> {
  @override
  Future<AuthProfile?> build() async {
    final repo = ref.watch(authRepositoryProvider);

    ref.listen<AsyncValue<AuthState>>(authStateChangesProvider, (
      previous,
      next,
    ) {
      final event = next.value?.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userUpdated) {
        ref.invalidateSelf();
      }
    });

    if (repo.currentSession == null) return null;
    try {
      return await repo.profileForCurrentUser();
    } on AuthFailure {
      await repo.signOut();
      return null;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted) return;
    state = const AsyncData(null);
  }
}

final authProfileProvider =
    AsyncNotifierProvider<AuthProfileNotifier, AuthProfile?>(
      AuthProfileNotifier.new,
    );
