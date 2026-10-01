import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/entities/cita.dart';
import '../providers/citas_providers.dart';
import '../widgets/cita_acciones.dart';

/// "Completar cita" (D-17, D-18): lista cada mascota de la cita con
/// "Registrar consulta" u "Omitir". Completar NO es una transacción con las
/// consultas (cada una ya quedó guardada y es solo-append): "Finalizar cita"
/// únicamente cambia el estado de la cita, y salir sin finalizar deja la cita
/// como estaba.
class CompletarCitaScreen extends ConsumerStatefulWidget {
  const CompletarCitaScreen({super.key, required this.citaId});

  final String citaId;

  @override
  ConsumerState<CompletarCitaScreen> createState() =>
      _CompletarCitaScreenState();
}

enum _Boton { finalizar, sinConsulta }

class _CompletarCitaScreenState extends ConsumerState<CompletarCitaScreen> {
  final Set<String> _omitidas = {};
  _Boton? _finalizando;

  Future<void> _finalizar(Cita cita, _Boton boton) async {
    if (_finalizando != null) return;
    if (cita.estado == EstadoCita.completada) {
      context.pop();
      return;
    }
    setState(() => _finalizando = boton);
    final dia = diaBogota(cita.fechaHora);
    final destino =
        '/agenda?dia=${dia.year.toString().padLeft(4, '0')}-'
        '${dia.month.toString().padLeft(2, '0')}-'
        '${dia.day.toString().padLeft(2, '0')}';
    final ok = await cambiarEstadoConDeshacer(
      context,
      ref,
      cita: cita,
      nuevo: EstadoCita.completada,
      mensaje: 'Cita completada',
      mensajeError: 'No pudimos completar la cita. Intenta de nuevo.',
    );
    if (!mounted) return;
    setState(() => _finalizando = null);
    if (ok) context.go(destino);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(citaProvider(widget.citaId));
    return Scaffold(
      appBar: const AppTopBar(title: 'Completar cita'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No pudimos cargar la cita. Intenta de nuevo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Reintentar',
                  variant: AppButtonVariant.outline,
                  expand: false,
                  onPressed: () =>
                      ref.invalidate(citaProvider(widget.citaId)),
                ),
              ],
            ),
          ),
        ),
        data: _contenido,
      ),
    );
  }

  Widget _contenido(Cita cita) {
    final textTheme = Theme.of(context).textTheme;
    final registradas = cita.mascotasConConsulta;
    bool resuelta(MascotaDeCita m) =>
        registradas.contains(m.id) || _omitidas.contains(m.id);
    final hayPendientes = cita.mascotas.any((m) => !resuelta(m));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Registrar la consulta?', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Puedes registrarla ahora o completar la cita sin consulta.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final m in cita.mascotas)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _MascotaCard(
                mascota: m,
                registrada: registradas.contains(m.id),
                omitida: _omitidas.contains(m.id),
                onRegistrar: () => context.push(
                  '/agenda/${cita.id}/completar/consulta/${m.id}',
                ),
                onOmitir: () => setState(() => _omitidas.add(m.id)),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (hayPendientes) ...[
            AppButton(
              label: 'Completar sin consulta',
              variant: AppButtonVariant.text,
              isLoading: _finalizando == _Boton.sinConsulta,
              onPressed: _finalizando != null
                  ? null
                  : () {
                      setState(() {
                        for (final m in cita.mascotas) {
                          if (!registradas.contains(m.id)) {
                            _omitidas.add(m.id);
                          }
                        }
                      });
                      _finalizar(cita, _Boton.sinConsulta);
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'Finalizar cita',
            isLoading: _finalizando == _Boton.finalizar,
            onPressed: hayPendientes || _finalizando != null
                ? null
                : () => _finalizar(cita, _Boton.finalizar),
          ),
        ],
      ),
    );
  }
}

class _MascotaCard extends StatelessWidget {
  const _MascotaCard({
    required this.mascota,
    required this.registrada,
    required this.omitida,
    required this.onRegistrar,
    required this.onOmitir,
  });

  final MascotaDeCita mascota;
  final bool registrada;
  final bool omitida;
  final VoidCallback onRegistrar;
  final VoidCallback onOmitir;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final estado = registrada
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Consulta registrada',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
          )
        : Text(
            omitida ? 'Omitida' : 'Pendiente',
            style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceMuted,
                child: Icon(
                  mascota.especie == 'gato' ? Icons.pets : Icons.pets_outlined,
                  size: 18,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(mascota.nombre, style: textTheme.bodyLarge)),
              estado,
            ],
          ),
          if (!registrada) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: AppButton(
                    label: 'Registrar consulta',
                    variant: AppButtonVariant.outline,
                    expand: false,
                    onPressed: onRegistrar,
                  ),
                ),
                if (!omitida)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: AppButton(
                      label: 'Omitir',
                      variant: AppButtonVariant.text,
                      expand: false,
                      onPressed: onOmitir,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
