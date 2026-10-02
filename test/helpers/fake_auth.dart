import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/main.dart';

import 'fake_citas.dart';
import 'fake_recordatorios.dart';

/// Fake [AuthProfileNotifier] used by widget tests so no test ever touches
/// a real Supabase client. Either returns a fixed [profile] from `build()`
/// or throws a fixed [error] to exercise the AsyncValue.error branch.
class FakeAuthProfileNotifier extends AuthProfileNotifier {
  FakeAuthProfileNotifier({this.profile, this.error});

  final AuthProfile? profile;
  final Object? error;

  @override
  Future<AuthProfile?> build() async {
    if (error != null) throw error!;
    return profile;
  }

  @override
  Future<void> refrescar() async {
    state = AsyncData<AuthProfile?>(profile);
  }

  @override
  Future<void> signOut() async {
    state = const AsyncData<AuthProfile?>(null);
  }
}

const vetProfile = AuthProfile(
  id: 'vet-1',
  nombre: 'Ana Ramírez',
  email: 'ana@vetapp.co',
  rol: 'VETERINARIO',
  telefono: '',
  clinicaId: 'cli-1',
  clinicaNombre: 'Clínica Patitas',
  rolClinica: 'admin',
);

const vetAdminProfile = vetProfile;

const vetColegaProfile = AuthProfile(
  id: 'vet-2',
  nombre: 'Luis Gómez',
  email: 'luis@vetapp.co',
  rol: 'VETERINARIO',
  telefono: '',
  clinicaId: 'cli-1',
  clinicaNombre: 'Clínica Patitas',
  rolClinica: 'veterinario',
);

const vetRetiradoProfile = AuthProfile(
  id: 'vet-3',
  nombre: 'Marta Ruiz',
  email: 'marta@vetapp.co',
  rol: 'VETERINARIO',
  telefono: '',
  clinicaId: 'cli-1',
  rolClinica: 'veterinario',
  activo: false,
);

const clienteProfile = AuthProfile(
  id: 'cli-user-1',
  nombre: 'Carlos Pérez',
  email: 'carlos@vetapp.co',
  rol: 'CLIENTE',
  telefono: '',
  clinicaId: null,
  clinicaNombre: null,
);

/// Boots [VetApp] with [authProfileProvider] overridden by a
/// [FakeAuthProfileNotifier] seeded with [profile] — no live Supabase
/// dependency anywhere in the widget tree.
Widget appUnderTest({AuthProfile? profile}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: profile),
      ),
      citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
      recordatoriosServiceProvider.overrideWithValue(FakeRecordatoriosService()),
    ],
    child: const VetApp(),
  );
}
