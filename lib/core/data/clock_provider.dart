import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reloj inyectable: el código de agenda nunca llama `DateTime.now()`
/// directamente, así los tests pueden congelar "Hoy" y el "en N min" de la
/// banner de próxima cita.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
