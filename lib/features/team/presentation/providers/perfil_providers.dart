import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../data/repositories/supabase_perfil_repository.dart';

final perfilRepositoryProvider = Provider<SupabasePerfilRepository>((ref) {
  return SupabasePerfilRepository(ref.watch(supabaseClientProvider));
});
