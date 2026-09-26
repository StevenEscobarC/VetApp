import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/entities/cliente.dart';
import '../providers/clientes_providers.dart';

/// Primera pantalla real de Clientes (CLI-03, D-06): lista + búsqueda
/// instantánea contra Supabase, reemplazando `ComingSoonScreen` en
/// `/clientes`.
class ClientesListScreen extends ConsumerStatefulWidget {
  const ClientesListScreen({super.key});

  @override
  ConsumerState<ClientesListScreen> createState() =>
      _ClientesListScreenState();
}

class _ClientesListScreenState extends ConsumerState<ClientesListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesProvider);
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: const AppTopBar(title: 'Clientes'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppTextField(
              label: 'Buscar clientes',
              hideLabel: true,
              controller: _searchController,
              hintText: 'Buscar por nombre o teléfono',
              onChanged: (value) {
                setState(() {});
                ref.read(clientesProvider.notifier).search(value);
              },
            ),
          ),
          Expanded(
            child: clientesAsync.when(
              data: (clientes) =>
                  _ClientesBody(clientes: clientes, query: query),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('No pudimos cargar la lista. Intenta de nuevo.'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clientes/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo cliente'),
      ),
    );
  }
}

class _ClientesBody extends ConsumerWidget {
  const _ClientesBody({required this.clientes, required this.query});

  final List<Cliente> clientes;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    if (clientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                query.isEmpty
                    ? 'Aún no tienes clientes'
                    : 'No encontramos clientes con «$query»',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                query.isEmpty
                    ? 'Registra tu primer cliente para empezar a llevar sus '
                          'mascotas.'
                    : 'Verifica el nombre o teléfono e intenta de nuevo.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(clientesProvider.notifier).refrescar(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: clientes.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final cliente = clientes[index];
          return AppCard(
            onTap: () => context.push('/clientes/${cliente.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nombre,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  cliente.telefono,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _mascotasLabel(cliente.numeroMascotas),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _mascotasLabel(int numero) {
    if (numero == 0) return 'Sin mascotas';
    if (numero == 1) return '1 mascota';
    return '$numero mascotas';
  }
}
