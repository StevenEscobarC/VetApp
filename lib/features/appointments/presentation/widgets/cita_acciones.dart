import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/lanzador_externo.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/cita_failure.dart';
import '../../domain/entities/cita.dart';
import '../../domain/whatsapp_recordatorio.dart';
import '../providers/citas_providers.dart';

const _errorEstado = 'No pudimos cambiar el estado. Intenta de nuevo.';

/// Cambia el estado de [cita] a [nuevo] y muestra un snackbar con "Deshacer"
/// (6 s) que restaura el estado anterior. Captura las acciones y el messenger
/// ANTES de esperar: el cierre de "Deshacer" nunca toca un widget que pudo
/// desmontarse. Cada snackbar nuevo reemplaza al anterior, así solo el último
/// cambio es deshacible. Devuelve `true` si el cambio se guardó.
Future<bool> cambiarEstadoConDeshacer(
  BuildContext context,
  WidgetRef ref, {
  required Cita cita,
  required EstadoCita nuevo,
  required String mensaje,
  String mensajeError = _errorEstado,
}) async {
  final actions = ref.read(citaActionsProvider);
  final messenger = ScaffoldMessenger.of(context);
  final anterior = cita.estado;
  try {
    await actions.cambiarEstado(cita.id, nuevo);
  } on CitaFailure {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensajeError)));
    return false;
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
  return true;
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

const _errorWhatsApp = 'No pudimos abrir WhatsApp. ¿Está instalado?';

/// Abre el chat de WhatsApp del cliente con el mensaje formal (D-14) y, si el
/// lanzamiento funcionó, marca el recordatorio como enviado con "Deshacer".
/// El número se normaliza al usar (D-16), así que teléfonos antiguos sin
/// normalizar también funcionan.
Future<void> enviarRecordatorioWhatsApp(
  BuildContext context,
  WidgetRef ref,
  Cita cita,
) async {
  final actions = ref.read(citaActionsProvider);
  final messenger = ScaffoldMessenger.of(context);
  final lanzador = ref.read(lanzadorExternoProvider);
  final ahora = ref.read(clockProvider);
  final profile = ref.read(authProfileProvider).asData?.value;

  final telefono = cita.clienteTelefono ?? '';
  final numero = numeroWhatsApp(telefono);
  if (numero == null) {
    mostrarMotivoWhatsApp(messenger, telefono);
    return;
  }
  final mensaje = mensajeRecordatorio(
    cita: cita,
    veterinario: profile?.nombre ?? '',
    clinica: profile?.clinicaNombre,
  );
  final ok = await lanzador.abrir(whatsappUri(numero, mensaje));
  if (!ok) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_errorWhatsApp)));
    return;
  }
  final anterior = cita.recordatorioEnviadoAt;
  try {
    await actions.marcarRecordatorioEnviado(cita.id, ahora());
  } on CitaFailure catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Marcado como recordatorio enviado'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            try {
              await actions.marcarRecordatorioEnviado(cita.id, anterior);
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

/// Muestra por qué no se puede enviar WhatsApp a [telefono].
void mostrarMotivoWhatsApp(ScaffoldMessengerState messenger, String telefono) {
  final motivo = estadoWhatsApp(telefono).motivo;
  if (motivo == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(motivo)));
}

/// "Cómo llegar": abre Google Maps hacia la dirección sin pedir ubicación.
Future<void> abrirComoLlegar(
  BuildContext context,
  WidgetRef ref,
  Cita cita,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref
      .read(lanzadorExternoProvider)
      .abrir(mapsUri(cita.direccion ?? ''));
  if (!ok) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No pudimos abrir Google Maps.')),
      );
  }
}

/// Botón "WhatsApp" de una cita. Si el número no sirve se ve apagado (0.38)
/// pero sigue siendo tocable para explicar el motivo.
Widget botonWhatsApp(
  BuildContext context,
  WidgetRef ref,
  Cita cita, {
  required AppButtonVariant variant,
  bool expand = false,
}) {
  final estado = estadoWhatsApp(cita.clienteTelefono ?? '');
  final boton = AppButton(
    label: 'WhatsApp',
    variant: variant,
    icon: Icons.chat_outlined,
    expand: expand,
    onPressed: estado.habilitado
        ? () => enviarRecordatorioWhatsApp(context, ref, cita)
        : () => mostrarMotivoWhatsApp(
            ScaffoldMessenger.of(context),
            cita.clienteTelefono ?? '',
          ),
  );
  return estado.habilitado ? boton : Opacity(opacity: 0.38, child: boton);
}

/// Botón "Cómo llegar" (solo citas a domicilio).
Widget botonComoLlegar(
  BuildContext context,
  WidgetRef ref,
  Cita cita, {
  required AppButtonVariant variant,
  bool expand = false,
}) => AppButton(
  label: 'Cómo llegar',
  variant: variant,
  icon: Icons.directions_outlined,
  expand: expand,
  onPressed: () => abrirComoLlegar(context, ref, cita),
);

/// Motivo visible cuando WhatsApp no está disponible, más "Agregar teléfono"
/// si el cliente no tiene teléfono. `null` si WhatsApp está habilitado.
Widget? avisoWhatsApp(BuildContext context, Cita cita) {
  final estado = estadoWhatsApp(cita.clienteTelefono ?? '');
  if (estado.habilitado) return null;
  final sinTelefono =
      normalizarTelefono(cita.clienteTelefono ?? '').clase ==
      ClaseTelefono.vacio;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        estado.motivo!,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
      ),
      if (sinTelefono)
        AppButton(
          label: 'Agregar teléfono',
          variant: AppButtonVariant.text,
          expand: false,
          onPressed: () => context.go('/clientes/${cita.clienteId}'),
        ),
    ],
  );
}
