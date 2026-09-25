import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formato.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/entities/mascota.dart';
import '../providers/mascotas_providers.dart';
import '../widgets/mascota_foto_avatar.dart';

/// Primera pantalla real de Pacientes (PAT-04, D-06): lista + búsqueda
/// instantánea (nombre, dueño o especie) contra Supabase, más chips de
/// especie que filtran el resultado ya cargado en memoria (sin disparar una
/// nueva consulta), reemplazando `ComingSoonScreen` en `/pacientes`. Sin
/// botón "Nuevo paciente": toda mascota se crea siempre desde la ficha de un
/// cliente (D-02/D-03) — ver `02-UI-SPEC.md`.
class PacientesListScreen extends ConsumerStatefulWidget {
  const PacientesListScreen({super.key});

  @override
  ConsumerState<PacientesListScreen> createState() =>
      _PacientesListScreenState();
}

class _PacientesListScreenState extends ConsumerState<PacientesListScreen> {
  final _searchController = TextEditingController();
  Especie? _filtro;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mascotasAsync = ref.watch(mascotasProvider);
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: const AppTopBar(title: 'Pacientes'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppTextField(
              label: 'Buscar pacientes',
              hideLabel: true,
              controller: _searchController,
              hintText: 'Buscar por nombre, dueño o especie',
              onChanged: (value) {
                setState(() {});
                ref.read(mascotasProvider.notifier).search(value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppFilterChip(
                    label: 'Todos',
                    selected: _filtro == null,
                    onTap: () => setState(() => _filtro = null),
                  ),
                  for (final especie in Especie.values) ...[
                    const SizedBox(width: AppSpacing.sm),
                    AppFilterChip(
                      label: especie.etiquetaPlural,
                      selected: _filtro == especie,
                      onTap: () => setState(() => _filtro = especie),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: mascotasAsync.when(
              data: (mascotas) => _PacientesBody(
                mascotas: mascotas,
                query: query,
                filtro: _filtro,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('No pudimos cargar la lista. Intenta de nuevo.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PacientesBody extends ConsumerWidget {
  const _PacientesBody({
    required this.mascotas,
    required this.query,
    required this.filtro,
  });

  final List<Mascota> mascotas;
  final String query;
  final Especie? filtro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final visibles = filtro == null
        ? mascotas
        : mascotas.where((m) => m.especie == filtro).toList();

    if (visibles.isEmpty) {
      final sinBusquedaNiFiltro = query.isEmpty && filtro == null;
      final esListaVacia = mascotas.isEmpty && sinBusquedaNiFiltro;
      final terminoBuscado = query.isNotEmpty ? query : filtro?.etiquetaPlural;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                esListaVacia
                    ? 'Aún no tienes pacientes registrados'
                    : 'No encontramos mascotas con «$terminoBuscado»',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                esListaVacia
                    ? 'Crea tu primer paciente desde la ficha de un cliente.'
                    : 'Verifica el nombre, dueño o especie e intenta de '
                          'nuevo.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(mascotasProvider);
        return ref.read(mascotasProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: visibles.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final mascota = visibles[index];
          final partesSecundarias = [
            if (mascota.raza != null && mascota.raza!.isNotEmpty)
              mascota.raza!,
            if (formatearEdad(mascota.edadEnAnios).isNotEmpty)
              formatearEdad(mascota.edadEnAnios),
          ];
          final secundaria = partesSecundarias.isEmpty
              ? mascota.especie.etiqueta
              : partesSecundarias.join(' · ');

          return AppCard(
            onTap: () => context.push('/pacientes/${mascota.id}'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MascotaFotoAvatar(fotoPath: mascota.fotoPath, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mascota.nombre,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        secundaria,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (mascota.duenoNombre != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          mascota.duenoNombre!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
