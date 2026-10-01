import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../providers/recordatorios_providers.dart';

/// Etiqueta legible de la anticipación global del recordatorio (D-12).
String etiquetaAnticipacion(int minutos) => switch (minutos) {
  15 => '15 minutos antes',
  30 => '30 minutos antes',
  120 => '2 horas antes',
  _ => '1 hora antes',
};

const _opciones = [15, 30, 60, 120];

class RecordatoriosScreen extends ConsumerWidget {
  const RecordatoriosScreen({super.key});

  Future<void> _elegir(BuildContext context, WidgetRef ref, int minutos) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(anticipacionRecordatorioProvider.notifier).cambiar(minutos);
      messenger.showSnackBar(
        const SnackBar(content: Text('Recordatorio actualizado')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No pudimos guardar el ajuste. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final actual = ref.watch(anticipacionRecordatorioProvider).value ?? 60;
    final permiso = ref.watch(permisoNotificacionesProvider).value ?? true;

    return Scaffold(
      appBar: const AppTopBar(title: 'Recordatorios'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Avisarme antes de cada cita', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Se aplica a todas tus citas.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!permiso) ...[
            Row(
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Recordatorios desactivados',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(recordatoriosServiceProvider).abrirAjustes(),
                  child: const Text('Abrir ajustes'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          for (final m in _opciones) ...[
            AppCard(
              onTap: () => _elegir(context, ref, m),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        etiquetaAnticipacion(m),
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    if (m == actual)
                      const Icon(Icons.check, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
