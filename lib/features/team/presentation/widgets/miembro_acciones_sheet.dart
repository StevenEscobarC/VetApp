import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/miembro.dart';
import '../../domain/team_failure.dart';
import '../providers/team_providers.dart';
import 'reasignar_citas_sheet.dart';

enum _Accion { hacerAdmin, hacerVet, retirar, dejarAdmin, salir }

const _errorGenerico = 'No pudimos completar el cambio. Intenta de nuevo.';

/// Hoja de acciones de un miembro (solo administradores). En la fila propia
/// ([esYo]) ofrece dejar el cargo o salir, únicamente si [hayOtroAdmin]
/// (D-14); la clínica nunca se queda sin administrador.
Future<void> mostrarAccionesMiembro(
  BuildContext context,
  WidgetRef ref, {
  required Miembro miembro,
  required bool esYo,
  required bool hayOtroAdmin,
}) async {
  final soloAdmin = esYo && !hayOtroAdmin;
  final textTheme = Theme.of(context).textTheme;
  final accion = await showModalBottomSheet<_Accion>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(miembro.nombre, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (soloAdmin)
              Text(
                'Eres el único administrador. Nombra a otro antes de dejar '
                'el cargo.',
                style: textTheme.bodyLarge,
              )
            else if (esYo) ...[
              AppButton(
                label: 'Dejar de ser administrador',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(ctx).pop(_Accion.dejarAdmin),
              ),
              const SizedBox(height: AppSpacing.sm),
              _Destructivo(
                label: 'Salir de la clínica',
                onPressed: () => Navigator.of(ctx).pop(_Accion.salir),
              ),
            ] else ...[
              AppButton(
                label: miembro.esAdmin
                    ? 'Hacer veterinario'
                    : 'Hacer administrador',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(
                  ctx,
                ).pop(miembro.esAdmin ? _Accion.hacerVet : _Accion.hacerAdmin),
              ),
              const SizedBox(height: AppSpacing.sm),
              _Destructivo(
                label: 'Retirar del equipo',
                onPressed: () => Navigator.of(ctx).pop(_Accion.retirar),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (accion == null || !context.mounted) return;
  switch (accion) {
    case _Accion.hacerAdmin:
      await _cambiarRol(context, ref, miembro, 'admin');
    case _Accion.hacerVet:
      await _cambiarRol(context, ref, miembro, 'veterinario');
    case _Accion.dejarAdmin:
      await _dejarCargo(context, ref, miembro);
    case _Accion.retirar:
      await _retirar(context, ref, miembro);
    case _Accion.salir:
      await _salir(context, ref, miembro);
  }
}

class _Destructivo extends StatelessWidget {
  const _Destructivo({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
      onPressed: onPressed,
      icon: const Icon(Icons.person_remove_outlined),
      label: Text(label),
    ),
  );
}

Future<bool> _confirmar(
  BuildContext context, {
  required String titulo,
  required String cuerpo,
  required String accion,
  bool destructivo = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(cuerpo),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Volver'),
        ),
        TextButton(
          style: destructivo
              ? TextButton.styleFrom(foregroundColor: AppColors.destructive)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(accion),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Ejecuta [accion]; muestra [exito] o el mensaje de error en un snackbar.
Future<void> _ejecutar(
  BuildContext context,
  Future<void> Function() accion,
  String exito,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await accion();
    messenger.showSnackBar(SnackBar(content: Text(exito)));
  } on TeamFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text(_errorGenerico)));
  }
}

Future<void> _cambiarRol(
  BuildContext context,
  WidgetRef ref,
  Miembro m,
  String rol,
) async {
  final admin = rol == 'admin';
  final ok = await _confirmar(
    context,
    titulo: admin
        ? '¿Hacer administrador a ${m.nombre}?'
        : '¿Hacer veterinario a ${m.nombre}?',
    cuerpo: admin
        ? 'Podrá invitar, retirar miembros y cambiar roles.'
        : 'Dejará de poder invitar, retirar miembros y cambiar roles.',
    accion: admin ? 'Hacer administrador' : 'Hacer veterinario',
  );
  if (!ok || !context.mounted) return;
  final actions = ref.read(teamActionsProvider);
  await _ejecutar(
    context,
    () => actions.cambiarRol(m.id, rol),
    admin
        ? '${m.nombre} ahora es administrador'
        : '${m.nombre} ahora es veterinario',
  );
}

Future<void> _dejarCargo(BuildContext context, WidgetRef ref, Miembro m) async {
  final ok = await _confirmar(
    context,
    titulo: '¿Dejar de ser administrador?',
    cuerpo: 'Seguirás en la clínica como veterinario.',
    accion: 'Confirmar cambio',
  );
  if (!ok || !context.mounted) return;
  final actions = ref.read(teamActionsProvider);
  await _ejecutar(
    context,
    () => actions.cambiarRol(m.id, 'veterinario'),
    'Ahora eres veterinario',
  );
}

Future<void> _salir(BuildContext context, WidgetRef ref, Miembro m) async {
  final ok = await _confirmar(
    context,
    titulo: '¿Salir de la clínica?',
    cuerpo:
        'Perderás el acceso de inmediato. Tus consultas y registros se '
        'conservan con tu nombre y tus citas próximas pasarán a otro '
        'administrador.',
    accion: 'Salir',
    destructivo: true,
  );
  if (!ok || !context.mounted) return;
  final actions = ref.read(teamActionsProvider);
  // El servidor asigna las citas al administrador más antiguo (D-14).
  await _ejecutar(context, () => actions.retirar(m.id), 'Saliste de la clínica');
}

Future<void> _retirar(BuildContext context, WidgetRef ref, Miembro m) async {
  final actions = ref.read(teamActionsProvider);
  final yoId = ref.read(authProfileProvider).value?.id ?? '';
  final candidatos = ref
      .read(miembrosActivosProvider)
      .where((x) => x.id != m.id)
      .toList();
  final indices = ref.read(indicesColorVetProvider);
  final messenger = ScaffoldMessenger.of(context);

  int n;
  try {
    n = await actions.contarCitasAbiertas(m.id);
  } on TeamFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text(_errorGenerico)));
    return;
  }
  if (!context.mounted) return;

  final ok = await _confirmar(
    context,
    titulo: '¿Retirar a ${m.nombre} del equipo?',
    cuerpo:
        'Perderá el acceso a la clínica de inmediato. Sus consultas y '
        'registros anteriores se conservan con su nombre. Para volver, '
        'necesitará un código de invitación nuevo.',
    accion: 'Retirar',
    destructivo: true,
  );
  if (!ok || !context.mounted) return;

  String? destino;
  if (n > 0 && candidatos.any((x) => x.id != yoId)) {
    destino = await elegirDestinoCitas(
      context,
      nombre: m.nombre,
      n: n,
      candidatos: candidatos,
      yoId: yoId,
      indices: indices,
    );
    // null = "Volver": cancela sin retirar.
    if (destino == null || !context.mounted) return;
  }
  await _ejecutar(
    context,
    () => actions.retirar(m.id, reasignarA: destino),
    '${m.nombre} ya no tiene acceso',
  );
}
