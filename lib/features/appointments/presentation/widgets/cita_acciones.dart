import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../domain/cita_failure.dart';
import '../../domain/entities/cita.dart';
import '../providers/citas_providers.dart';

const _errorEstado = 'No pudimos cambiar el estado. Intenta de nuevo.';

/// Cambia el estado de [cita] a [nuevo] y muestra un snackbar con "Deshacer"
/// (6 s) que restaura el estado anterior. Captura las acciones y el messenger
/// ANTES de esperar: el cierre de "Deshacer" nunca toca un widget que pudo
/// desmontarse. Cada snackbar nuevo reemplaza al anterior, así solo el último
/// cambio es deshacible.
Future<void> cambiarEstadoConDeshacer(
  BuildContext context,
  WidgetRef ref, {
  required Cita cita,
  required EstadoCita nuevo,
  required String mensaje,
}) async {
  final actions = ref.read(citaActionsProvider);
  final messenger = ScaffoldMessenger.of(context);
  final anterior = cita.estado;
  try {
    await actions.cambiarEstado(cita.id, nuevo);
  } on CitaFailure {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_errorEstado)));
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            try {
              await actions.cambiarEstado(cita.id, anterior);
            } on CitaFailure {
              messenger.showSnackBar(
                const SnackBar(content: Text(_errorEstado)),
              );
            }
          },
        ),
      ),
    );
}

/// "¿Cancelar esta cita?" — la cita nunca se borra, solo pasa a cancelada.
Future<bool> confirmarCancelacion(BuildContext context, Cita cita) async {
  final cuando = aBogota(cita.fechaHora);
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Cancelar esta cita?'),
      content: Text(
        '${cita.nombresMascotas} el ${diaCorto(cuando)} a las ${hora12(cuando)} '
        'La cita quedará como cancelada y no se borra.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Volver'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Cancelar cita'),
        ),
      ],
    ),
  );
  return r ?? false;
}

enum _Accion { pendiente, noAsistio, cancelar, editar }

/// Hoja "Más acciones" de una cita no terminal.
Future<void> mostrarMasAcciones(
  BuildContext context,
  WidgetRef ref,
  Cita cita,
) async {
  final accion = await showModalBottomSheet<_Accion>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cita.estado == EstadoCita.confirmada) ...[
              AppButton(
                label: 'Marcar como pendiente',
                variant: AppButtonVariant.outline,
                icon: Icons.schedule_outlined,
                onPressed: () => Navigator.of(ctx).pop(_Accion.pendiente),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: 'No asistió',
              variant: AppButtonVariant.outline,
              icon: Icons.person_off_outlined,
              onPressed: () => Navigator.of(ctx).pop(_Accion.noAsistio),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                ),
                onPressed: () => Navigator.of(ctx).pop(_Accion.cancelar),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar cita'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Editar',
              variant: AppButtonVariant.text,
              icon: Icons.edit_outlined,
              onPressed: () => Navigator.of(ctx).pop(_Accion.editar),
            ),
          ],
        ),
      ),
    ),
  );
  if (accion == null || !context.mounted) return;
  switch (accion) {
    case _Accion.pendiente:
      await cambiarEstadoConDeshacer(
        context,
        ref,
        cita: cita,
        nuevo: EstadoCita.pendiente,
        mensaje: 'Cita marcada como pendiente',
      );
    case _Accion.noAsistio:
      await cambiarEstadoConDeshacer(
        context,
        ref,
        cita: cita,
        nuevo: EstadoCita.noAsistio,
        mensaje: 'Marcada como no asistió',
      );
    case _Accion.cancelar:
      if (!await confirmarCancelacion(context, cita) || !context.mounted) {
        return;
      }
      await cambiarEstadoConDeshacer(
        context,
        ref,
        cita: cita,
        nuevo: EstadoCita.cancelada,
        mensaje: 'Cita cancelada',
      );
    case _Accion.editar:
      context.push('/agenda/${cita.id}/editar');
  }
}
