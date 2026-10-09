import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/status/app_status_chip.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../plan/presentation/limite_plan_gate.dart';
import '../../../plan/presentation/providers/plan_providers.dart';
import '../../../plan/presentation/widgets/control_escritura.dart';
import '../../../team/presentation/providers/team_providers.dart';
import '../../domain/cita_failure.dart';
import '../../domain/entities/cita.dart';
import '../estado_cita_ui.dart';
import '../providers/citas_providers.dart';
import '../widgets/asignar_veterinario_sheet.dart';
import '../widgets/cita_acciones.dart';

const _yaNoExiste = 'Esta cita ya no existe.';

/// Detalle de una cita: cuándo, cliente, motivo, dónde, notas, recordatorio,
/// mascotas y las acciones de estado que corresponden. Las acciones de
/// WhatsApp / Cómo llegar y Completar se agregan en planes posteriores.
class CitaDetailScreen extends ConsumerWidget {
  const CitaDetailScreen({super.key, required this.citaId});

  final String citaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(citaProvider(citaId));
    final cita = async.asData?.value;
    final editable = cita != null && !cita.estado.esTerminal;
    final puede = ref.watch(puedeEscribirProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Cita',
        actions: editable
            ? [
                ControlEscritura(
                  puedeEscribir: puede,
                  label: 'Editar cita',
                  onTap: () =>
                      irSiPuedeEscribir(context, ref, '/agenda/$citaId/editar'),
                  child: IconButton(
                    tooltip: 'Editar cita',
                    icon: Icon(iconoEscritura(puede, Icons.edit_outlined)),
                    onPressed: () => irSiPuedeEscribir(
                      context,
                      ref,
                      '/agenda/$citaId/editar',
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(
          yaNoExiste: error is CitaFailure && error.message == _yaNoExiste,
          onReintentar: () => ref.invalidate(citaProvider(citaId)),
        ),
        data: (c) => _Contenido(cita: c),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.yaNoExiste, required this.onReintentar});

  final bool yaNoExiste;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              yaNoExiste
                  ? _yaNoExiste
                  : 'No pudimos cargar la cita. Intenta de nuevo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            if (yaNoExiste)
              AppButton(
                label: 'Volver a la agenda',
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: () => context.go('/agenda'),
              )
            else
              AppButton(
                label: 'Reintentar',
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: onReintentar,
              ),
          ],
        ),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.cita});

  final Cita cita;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final cuando = aBogota(cita.fechaHora);
    final telefono = normalizarTelefono(cita.clienteTelefono ?? '').formateado;
    final domicilio = cita.modalidad == ModalidadCita.domicilio;
    final dir = cita.direccion ?? '';
    final notas = (cita.notas ?? '').trim();
    final enviado = cita.recordatorioEnviadoAt;
    final multiVet = ref.watch(esClinicaMultiVetProvider);
    final yoId = ref.watch(authProfileProvider).value?.id ?? '';
    final indices = ref.watch(indicesColorVetProvider);
    final nombreVet = cita.veterinarioNombre ?? '';
    final puede = ref.watch(puedeEscribirProvider);

    Widget dato(String etiqueta, Widget valor) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          valor,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cita.nombresMascotas, style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppStatusChip(status: estadoAStatus(cita.estado)),
          ),
          const SizedBox(height: AppSpacing.lg),
          dato(
            'Cuándo',
            Text(
              '${fechaLarga(cuando)} · '
              '${rangoHoras(cuando, aBogota(cita.fin))}',
              style: textTheme.bodyLarge,
            ),
          ),
          dato(
            'Cliente',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cita.clienteNombre, style: textTheme.bodyLarge),
                if (telefono.isNotEmpty)
                  Text(telefono, style: textTheme.bodyMedium),
              ],
            ),
          ),
          if (multiVet) ...[
            dato(
              'Veterinario',
              Row(
                children: [
                  VetAvatar(
                    nombre: nombreVet,
                    indice: indices[cita.veterinarioId] ?? 0,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Dr(a). $nombreVet',
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  if (cita.veterinarioId == yoId) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '(Tú)',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!cita.estado.esTerminal)
              Align(
                alignment: Alignment.centerLeft,
                child: ControlEscritura(
                  puedeEscribir: puede,
                  label: 'Reasignar cita',
                  onTap: () => _reasignar(context, ref, yoId, indices),
                  child: AppButton(
                    label: 'Reasignar cita',
                    variant: AppButtonVariant.text,
                    icon: iconoEscritura(puede, Icons.swap_horiz),
                    expand: false,
                    onPressed: () => _reasignar(context, ref, yoId, indices),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          dato('Motivo', Text(cita.motivo, style: textTheme.bodyLarge)),
          dato(
            'Dónde',
            Text(
              domicilio
                  ? (dir.isNotEmpty ? dir : 'A domicilio')
                  : 'En consultorio',
              style: textTheme.bodyLarge,
            ),
          ),
          dato(
            'Notas',
            Text(
              notas.isEmpty ? 'Sin registrar' : notas,
              style: textTheme.bodyLarge?.copyWith(
                color: notas.isEmpty ? AppColors.textMuted : null,
              ),
            ),
          ),
          dato(
            'Recordatorio',
            Text(
              enviado == null
                  ? 'Sin enviar'
                  : 'Enviado ${fechaHoraCorta(aBogota(enviado))}',
              style: textTheme.bodyLarge,
            ),
          ),
          Text(
            cita.mascotas.length == 1 ? 'Mascota' : 'Mascotas',
            style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final m in cita.mascotas)
            Semantics(
              button: true,
              label: 'Ver a ${m.nombre}',
              child: InkWell(
                onTap: () => context.go('/pacientes/${m.id}'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.surfaceMuted,
                        child: Icon(
                          m.especie == 'gato'
                              ? Icons.pets
                              : Icons.pets_outlined,
                          size: 18,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(m.nombre, style: textTheme.bodyLarge),
                      ),
                      if (cita.estado == EstadoCita.completada) ...[
                        Text(
                          cita.mascotasConConsulta.contains(m.id)
                              ? 'Consulta registrada'
                              : 'Sin consulta',
                          style: textTheme.labelLarge?.copyWith(
                            color: cita.mascotasConConsulta.contains(m.id)
                                ? AppColors.success
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          ..._acciones(context, ref, puede),
        ],
      ),
    );
  }

  /// Elige a otro miembro activo y reasigna con "Deshacer" (6 s). Captura
  /// acciones y messenger antes de esperar, como [cambiarEstadoConDeshacer].
  Future<void> _reasignar(
    BuildContext context,
    WidgetRef ref,
    String yoId,
    Map<String, int> indices,
  ) async {
    final actions = ref.read(citaActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (!await asegurarEscritura(
      context,
      ref,
      plan: ref.read(miPlanProvider).value,
    )) {
      return;
    }
    if (!context.mounted) return;
    final elegido = await elegirVeterinario(
      context,
      activos: ref.read(miembrosActivosProvider),
      seleccionadoId: cita.veterinarioId,
      yoId: yoId,
      indices: indices,
    );
    if (elegido == null || elegido.id == cita.veterinarioId) return;
    final anterior = cita.veterinarioId;
    try {
      await actions.reasignar(cita.id, elegido.id);
    } on CitaFailure catch (e) {
      if (context.mounted && await manejarLimitePlan(context, ref, e)) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Cita reasignada a Dr(a). ${elegido.nombre}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              try {
                await actions.reasignar(cita.id, anterior);
              } on CitaFailure catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
          ),
        ),
      );
  }

  List<Widget> _acciones(BuildContext context, WidgetRef ref, bool puede) {
    const gap = SizedBox(height: AppSpacing.sm);

    /// Mismo control, con semántica de bloqueado en solo lectura.
    Widget lock(String label, VoidCallback onTap, Widget child) =>
        ControlEscritura(
          puedeEscribir: puede,
          label: label,
          onTap: onTap,
          child: child,
        );

    Future<void> cancelarCita() async {
      if (!await asegurarEscritura(
        context,
        ref,
        plan: ref.read(miPlanProvider).value,
      )) {
        return;
      }
      if (!context.mounted) return;
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
    }

    Widget cancelar() => SizedBox(
      width: double.infinity,
      child: lock(
        'Cancelar cita',
        cancelarCita,
        AppButton(
          label: 'Cancelar cita',
          variant: AppButtonVariant.destructive,
          icon: puede ? null : iconoEscritura(puede, Icons.cancel_outlined),
          onPressed: cancelarCita,
        ),
      ),
    );

    Future<void> marcarNoAsistio() => cambiarEstadoConDeshacer(
      context,
      ref,
      cita: cita,
      nuevo: EstadoCita.noAsistio,
      mensaje: 'Marcada como no asistió',
    );

    Widget noAsistio() => lock(
      'No asistió',
      marcarNoAsistio,
      AppButton(
        label: 'No asistió',
        variant: AppButtonVariant.outline,
        icon: puede ? null : iconoEscritura(puede, Icons.person_off_outlined),
        onPressed: marcarNoAsistio,
      ),
    );

    Future<void> confirmar() => cambiarEstadoConDeshacer(
      context,
      ref,
      cita: cita,
      nuevo: EstadoCita.confirmada,
      mensaje: 'Cita confirmada',
    );

    Future<void> reabrir() => cambiarEstadoConDeshacer(
      context,
      ref,
      cita: cita,
      nuevo: EstadoCita.pendiente,
      mensaje: 'Cita reabierta',
    );

    List<Widget> contacto() => [
      botonWhatsApp(
        context,
        ref,
        cita,
        variant: AppButtonVariant.outline,
        expand: true,
      ),
      ?avisoWhatsApp(context, cita),
      gap,
      if (cita.modalidad == ModalidadCita.domicilio) ...[
        botonComoLlegar(
          context,
          ref,
          cita,
          variant: AppButtonVariant.outline,
          expand: true,
        ),
        gap,
      ],
    ];

    Future<void> irACompletar() =>
        irSiPuedeEscribir(context, ref, '/agenda/${cita.id}/completar');

    Widget completar() => lock(
      'Completar cita',
      irACompletar,
      AppButton(
        label: 'Completar cita',
        icon: iconoEscritura(puede, Icons.task_alt_outlined),
        onPressed: irACompletar,
      ),
    );

    switch (cita.estado) {
      case EstadoCita.pendiente:
        return [
          completar(),
          gap,
          lock(
            'Confirmar',
            confirmar,
            AppButton(
              label: 'Confirmar',
              variant: AppButtonVariant.outline,
              icon: iconoEscritura(puede, Icons.check_circle_outline),
              onPressed: confirmar,
            ),
          ),
          gap,
          ...contacto(),
          noAsistio(),
          gap,
          cancelar(),
        ];
      case EstadoCita.confirmada:
        return [completar(), gap, ...contacto(), noAsistio(), gap, cancelar()];
      case EstadoCita.completada:
        return [
          if (cita.mascotas.any(
            (m) => !cita.mascotasConConsulta.contains(m.id),
          )) ...[
            lock(
              'Registrar consulta pendiente',
              irACompletar,
              AppButton(
                label: 'Registrar consulta pendiente',
                variant: AppButtonVariant.outline,
                icon: puede ? null : iconoEscritura(puede, Icons.add),
                onPressed: irACompletar,
              ),
            ),
            gap,
          ],
          AppButton(
            label: 'Ver historia clínica',
            variant: AppButtonVariant.outline,
            onPressed: cita.mascotas.isEmpty
                ? null
                : () => context.go('/pacientes/${cita.mascotas.first.id}'),
          ),
        ];
      case EstadoCita.cancelada:
      case EstadoCita.noAsistio:
        return [
          lock(
            'Reabrir cita',
            reabrir,
            AppButton(
              label: 'Reabrir cita',
              variant: AppButtonVariant.outline,
              icon: puede ? null : iconoEscritura(puede, Icons.replay),
              onPressed: reabrir,
            ),
          ),
        ];
    }
  }
}
