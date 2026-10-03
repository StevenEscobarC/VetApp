import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../core/widgets/status/dosis_estado_chip.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patients/domain/entities/mascota.dart';
import '../../../patients/presentation/providers/mascotas_providers.dart';
import '../../../patients/presentation/widgets/mascota_foto_avatar.dart';
import '../../domain/estado_dosis_ui.dart';
import '../providers/registrar_dosis_providers.dart';
import '../providers/vacuna_providers.dart';
import '../vacunacion_routes.dart';
import 'dosis_registrada_snackbar.dart';

/// Punto de entrada global "Vacunar" (D-05c): elige una mascota con
/// búsqueda instantánea y abre el formulario de dosis. Al volver con una
/// dosis registrada muestra la confirmación con "Compartir carné".
Future<void> showMascotaSearchSheet(BuildContext context) async {
  final elegida = await showModalBottomSheet<_Eleccion>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.95,
      child: MascotaSearchSheet(),
    ),
  );
  if (elegida == null || !context.mounted) return;
  final router = GoRouter.of(context);
  if (elegida.registrarNuevo) {
    router.push('/clientes/nuevo');
    return;
  }
  final id = elegida.mascotaId!;
  final r = await router.push<DosisRegistrada>(
    rutaRegistrarDosis(mascotaId: id),
  );
  if (r == null || !context.mounted) return;
  mostrarDosisRegistrada(
    context,
    r,
    // Ruta de primer nivel: la acción del snackbar puede dispararse desde
    // una ruta raíz (p. ej. `/vacunas`), donde empujar una del shell rompe.
    onCompartir: () => router.push(rutaCarne(id, compartir: true)),
  );
}

class _Eleccion {
  const _Eleccion.mascota(String this.mascotaId) : registrarNuevo = false;
  const _Eleccion.nuevo() : mascotaId = null, registrarNuevo = true;

  final String? mascotaId;
  final bool registrarNuevo;
}

class MascotaSearchSheet extends ConsumerStatefulWidget {
  const MascotaSearchSheet({super.key});

  @override
  ConsumerState<MascotaSearchSheet> createState() => _MascotaSearchSheetState();
}

class _MascotaSearchSheetState extends ConsumerState<MascotaSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  List<Mascota>? _resultados;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _buscar(q));
  }

  Future<void> _buscar(String q) async {
    final seq = ++_seq;
    try {
      final perfil = await ref.read(authProfileProvider.future);
      final clinicaId = perfil?.clinicaId;
      if (clinicaId == null) throw StateError('sin clínica');
      final lista = await ref
          .read(mascotaRepositoryProvider)
          .buscar(q, clinicaId: clinicaId);
      if (!mounted || seq != _seq) return;
      setState(() {
        _resultados = lista;
        _error = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _resultados = null;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resumen = ref.watch(resumenVacunasMascotasProvider).asData?.value;
    final lista = _resultados;

    Widget cuerpo;
    if (_error) {
      cuerpo = Center(
        child: Text(
          'No pudimos cargar la lista. Intenta de nuevo.',
          style: textTheme.bodyLarge,
        ),
      );
    } else if (lista == null) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (lista.isEmpty) {
      cuerpo = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No encontramos esa mascota.', style: textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Registrar paciente nuevo',
                variant: AppButtonVariant.outline,
                onPressed: () =>
                    Navigator.of(context).pop(const _Eleccion.nuevo()),
              ),
            ],
          ),
        ),
      );
    } else {
      cuerpo = ListView.builder(
        itemCount: lista.length,
        itemBuilder: (context, i) {
          final m = lista[i];
          final r = resumen?[m.id];
          final secundaria = [
            m.especie.etiqueta,
            if (m.duenoNombre != null) m.duenoNombre!,
          ].join(' · ');
          return InkWell(
            onTap: () => Navigator.of(context).pop(_Eleccion.mascota(m.id)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    MascotaFotoAvatar(fotoPath: m.fotoPath, size: 40),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.nombre,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            secundaria,
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (r != null && (r.vencidas > 0 || r.proximas > 0))
                      DosisEstadoChip(
                        estado: dosisEstadoDe(r.peor),
                        compact: true,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('¿A quién vacuna?', style: textTheme.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppTextField(
              label: 'Buscar mascota o dueño',
              hideLabel: true,
              controller: _controller,
              hintText: 'Buscar mascota o dueño',
              autofocus: true,
              onChanged: _onChanged,
            ),
          ),
          Expanded(child: cuerpo),
        ],
      ),
    );
  }
}
