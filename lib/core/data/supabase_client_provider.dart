import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The ONLY place in the app allowed to touch `Supabase.instance.client`.
/// Every repository provider must derive its client from this provider
/// instead of constructing a repository with `Supabase.instance.client`
/// inline (the anti-pattern the old `auth_screens.dart` widgets used).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
