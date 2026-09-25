import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../../core/utils/captura_foto.dart';
import '../../data/datasources/mascota_foto_datasource.dart';

final mascotaFotoDatasourceProvider = Provider<MascotaFotoDatasource>((ref) {
  return MascotaFotoDatasource(ref.watch(supabaseClientProvider));
});

/// URL firmada para el `foto_path` [path] — `autoDispose.family` porque una
/// URL firmada solo tiene sentido mientras la pantalla que la pidió está
/// visible; se recalcula desde cero en cada nueva suscripción.
final mascotaFotoUrlProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  path,
) {
  return ref.watch(mascotaFotoDatasourceProvider).signedUrlFor(path);
});

/// Seam de test: por defecto, la captura/compresión real (D-05); los tests
/// lo sobreescriben con `capturadorFalso` (test/helpers/fake_fotos.dart) sin
/// tocar cámara/galería/permission_handler reales.
final capturadorFotoProvider = Provider<CapturadorFoto>((ref) {
  return capturarFotoComprimida;
});
