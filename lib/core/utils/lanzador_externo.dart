import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre enlaces en apps externas (WhatsApp, Maps). Es una interfaz para que
/// los widgets se puedan probar sin la plataforma.
abstract class LanzadorExterno {
  Future<bool> abrir(Uri uri);
}

/// Implementación con `url_launcher`. Llama a `launchUrl` directamente (sin
/// `canLaunchUrl`), así no hace falta declarar `<queries>` en Android; devuelve
/// `false` ante cualquier fallo.
class UrlLauncherLanzador implements LanzadorExterno {
  @override
  Future<bool> abrir(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final lanzadorExternoProvider = Provider<LanzadorExterno>(
  (ref) => UrlLauncherLanzador(),
);
