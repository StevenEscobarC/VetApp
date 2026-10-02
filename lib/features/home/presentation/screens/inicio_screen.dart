import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../vaccination/presentation/widgets/mascota_search_sheet.dart';
import '../../../vaccination/presentation/widgets/vacunas_pendientes_card.dart';

/// Walking-skeleton Inicio: greets the signed-in vet by real `nombre` and
/// `clinicaNombre` read from [authProfileProvider]. Phase 1 D-01/D-02 kept
/// it free of cards; Phase 5 D-10 explicitly adds the 'Vacunas pendientes'
/// card and the global 'Vacunar' action. The rest of the dashboard (metric
/// cards, próximas citas) stays for Phase 8.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(authProfileProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const AppTopBar(title: 'Inicio'),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sin sesión activa', style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Vuelve a iniciar sesión para ver tu información.',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, ${profile.nombre}',
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      profile.clinicaNombre ?? 'Sin clínica asignada',
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const VacunasPendientesCard(),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Vacunar',
                icon: Icons.vaccines_outlined,
                onPressed: () => showMascotaSearchSheet(context),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text('No pudimos cargar tu perfil. Intenta de nuevo.'),
        ),
      ),
    );
  }
}
