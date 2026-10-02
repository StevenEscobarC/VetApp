import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/clinica_logo_datasource.dart';
import '../../data/repositories/supabase_clinica_repository.dart';
import '../../domain/clinica.dart';

final clinicaRepositoryProvider = Provider<SupabaseClinicaRepository>((ref) {
  return SupabaseClinicaRepository(ref.watch(supabaseClientProvider));
});

final clinicaLogoDatasourceProvider = Provider<ClinicaLogoDatasource>((ref) {
  return ClinicaLogoDatasource(ref.watch(supabaseClientProvider));
});

/// Datos de la clínica del usuario actual; null si no tiene clínica.
final miClinicaProvider = FutureProvider.autoDispose<Clinica?>((ref) async {
  final perfil = await ref.watch(authProfileProvider.future);
  final clinicaId = perfil?.clinicaId;
  if (clinicaId == null) return null;
  return ref.watch(clinicaRepositoryProvider).miClinica(clinicaId);
});

/// URL firmada para la ruta [path] del logo; se recalcula en cada suscripción.
final clinicaLogoUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, path) {
      return ref.watch(clinicaLogoDatasourceProvider).signedUrlFor(path);
    });
