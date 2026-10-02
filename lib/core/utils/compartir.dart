import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Abre la hoja nativa de compartir con un texto. Es una interfaz para que
/// los widgets y las pruebas nunca toquen el canal de plataforma de
/// `share_plus`; la reutilizará la Fase 5 (enlace del carné).
abstract class Compartidor {
  /// Comparte [texto]; lanza si la hoja nativa no está disponible.
  Future<void> compartirTexto(String texto);
}

/// Implementación con `share_plus` (API `SharePlus.instance` de >= 11).
class SharePlusCompartidor implements Compartidor {
  @override
  Future<void> compartirTexto(String texto) async {
    await SharePlus.instance.share(ShareParams(text: texto));
  }
}

final compartidorProvider = Provider<Compartidor>(
  (ref) => SharePlusCompartidor(),
);
