import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre enlaces en apps externas (WhatsApp, Maps). Es una interfaz para que
/// los widgets se puedan probar sin la plataforma.
abstract class LanzadorExterno {
  /// Abre el enlace en la app que lo maneje o, si no hay, en el navegador.
  /// Sirve para enlaces donde el respaldo web es aceptable (Maps).
  Future<bool> abrir(Uri uri);

  /// Abre el enlace solo en una app nativa, nunca en un navegador. Devuelve
  /// `false` si solo un navegador puede manejarlo. Se usa para WhatsApp: un
  /// `wa.me` abierto en Chrome no debe contar como recordatorio enviado
  /// (VET-25).
  Future<bool> abrirEnApp(Uri uri);
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

  @override
  Future<bool> abrirEnApp(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

final lanzadorExternoProvider = Provider<LanzadorExterno>(
  (ref) => UrlLauncherLanzador(),
);
