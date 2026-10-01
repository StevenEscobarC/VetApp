import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/buttons/app_button.dart';
import '../providers/recordatorios_providers.dart';

/// Pide el permiso de notificaciones y, si el sistema ya no muestra el
/// diálogo (tras dos negativas), lleva al veterinario a los ajustes.
Future<void> activarNotificaciones(WidgetRef ref) async {
  final servicio = ref.read(recordatoriosServiceProvider);
  final concedido = await servicio.solicitarPermiso();
  if (!concedido) await servicio.abrirAjustes();
  ref.invalidate(permisoNotificacionesProvider);
  ref.invalidate(mostrarBannerNotificacionesProvider);
  if (concedido) await ref.read(recordatoriosSyncProvider).sincronizar();
}

/// Explica el recordatorio y pide el permiso en contexto (D-13), una sola
/// vez, justo después de agendar la primera cita. Nunca lanza: un fallo aquí
/// no debe bloquear el guardado ni la navegación.
Future<void> pedirPermisoEnContexto(BuildContext context, WidgetRef ref) async {
  try {
    if (await ref.read(permisoExplicadoProvider.future)) return;
    if (await ref.read(recordatoriosServiceProvider).permisoConcedido()) {
      return;
    }
    await marcarPermisoExplicado(ref);
    if (!context.mounted) return;

    final activar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Te avisamos antes de tus citas?'),
        content: const Text(
          'Te enviaremos un recordatorio en tu celular antes de cada cita '
          'para que no se te pase ninguna.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ahora no'),
          ),
          AppButton(
            label: 'Activar recordatorios',
            expand: false,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (activar == true) await activarNotificaciones(ref);
  } catch (_) {
    // Nunca bloquea el flujo de agendar.
  }
}
