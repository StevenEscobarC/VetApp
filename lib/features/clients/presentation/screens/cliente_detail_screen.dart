import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../patients/domain/entities/mascota.dart';
import '../../../patients/presentation/providers/mascotas_providers.dart';
import '../../domain/cliente_failure.dart';
import '../../domain/entities/cliente.dart';
import '../providers/clientes_providers.dart';
import '../widgets/vinculacion_sheet.dart';

/// Ficha de cliente (CLI-02: ver/editar; CLI-04: sus mascotas; CLI-05: lado
/// veterinario de la vinculación de cuenta). Los campos siempre están
/// editables (sin un botón "Editar" separado — menos toques, per D-01) y
/// "Guardar cambios" es el único CTA con acento de la pantalla.
class ClienteDetailScreen extends ConsumerStatefulWidget {
  const ClienteDetailScreen({super.key, required this.clienteId});

  final String clienteId;

  @override
  ConsumerState<ClienteDetailScreen> createState() =>
      _ClienteDetailScreenState();
}

class _ClienteDetailScreenState extends ConsumerState<ClienteDetailScreen> {
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  /// Última versión guardada (o recién cargada), usada como base para medir
  /// si algo cambió y para conservar los campos no editables (perfilesId,
  /// código de vinculación) al construir el payload de `actualizar`.
  Cliente? _original;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _nombreCtrl,
      _telefonoCtrl,
      _correoCtrl,
      _direccionCtrl,
      _notasCtrl,
    ]) {
      controller.addListener(_onCamposCambiaron);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _direccionCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _onCamposCambiaron() => setState(() {});

  void _llenarControladores(Cliente cliente) {
    _nombreCtrl.text = cliente.nombre;
    _telefonoCtrl.text = cliente.telefono;
    _correoCtrl.text = cliente.email ?? '';
    _direccionCtrl.text = cliente.direccion ?? '';
    _notasCtrl.text = cliente.notas ?? '';
  }

  bool get _esDirty {
    final original = _original;
    if (original == null) return false;
    return _nombreCtrl.text != original.nombre ||
        _telefonoCtrl.text != original.telefono ||
        _correoCtrl.text != (original.email ?? '') ||
        _direccionCtrl.text != (original.direccion ?? '') ||
        _notasCtrl.text != (original.notas ?? '');
  }

  bool get _correoValido {
    final correo = _correoCtrl.text.trim();
    return correo.isEmpty || correo.contains('@');
  }

  bool get _puedeGuardar =>
      _esDirty &&
      _nombreCtrl.text.trim().isNotEmpty &&
      _telefonoCtrl.text.trim().isNotEmpty &&
      _correoValido;

  Future<void> _guardar() async {
    final original = _original;
    if (original == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final actualizado = Cliente(
      id: original.id,
      clinicaId: original.clinicaId,
      nombre: _nombreCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      email: _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim(),
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      perfilesId: original.perfilesId,
      codigoVinculacion: original.codigoVinculacion,
      codigoExpiraEn: original.codigoExpiraEn,
      numeroMascotas: original.numeroMascotas,
    );

    try {
      final resultado = await ref
          .read(clienteRepositoryProvider)
          .actualizar(actualizado);
      if (!mounted) return;
      setState(() => _original = resultado);
      ref.invalidate(clienteProvider(widget.clienteId));
      ref.read(clientesProvider.notifier).refrescar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
    } on ClienteFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clienteAsync = ref.watch(clienteProvider(widget.clienteId));
    final mascotasAsync = ref.watch(
      mascotasDeClienteProvider(widget.clienteId),
    );
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const AppTopBar(title: 'Cliente'),
      body: clienteAsync.when(
        data: (cliente) {
          if (_original == null) {
            _original = cliente;
            _llenarControladores(cliente);
          }
          return _buildBody(context, textTheme, cliente, mascotasAsync);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('No pudimos cargar el cliente. Intenta de nuevo.'),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TextTheme textTheme,
    Cliente cliente,
    AsyncValue<List<Mascota>> mascotasAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cliente.nombre, style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(label: 'Nombre *', controller: _nombreCtrl),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Teléfono *',
            controller: _telefonoCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Correo',
            controller: _correoCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Dirección', controller: _direccionCtrl),
          const SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Notas', controller: _notasCtrl, maxLines: 3),
          const SizedBox(height: AppSpacing.md),
          if (_error != null) ...[
            Text(
              _error!,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'Guardar cambios',
            onPressed: _puedeGuardar ? _guardar : null,
            isLoading: _loading,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Mascotas', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _buildMascotas(mascotasAsync, textTheme),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Nueva mascota',
            icon: Icons.add,
            variant: AppButtonVariant.outline,
            onPressed: () =>
                context.push('/clientes/${widget.clienteId}/nueva-mascota'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildVinculacionRow(context, cliente),
        ],
      ),
    );
  }

  Widget _buildMascotas(
    AsyncValue<List<Mascota>> mascotasAsync,
    TextTheme textTheme,
  ) {
    return mascotasAsync.when(
      data: (mascotas) {
        if (mascotas.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Este cliente no tiene mascotas registradas',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Usa “Nueva mascota” para agregar la primera.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            for (final mascota in mascotas) ...[
              AppCard(
                onTap: () => context.push(
                  '/clientes/${widget.clienteId}/mascotas/${mascota.id}',
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pets),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(mascota.nombre, style: textTheme.bodyLarge),
                    ),
                    Text(
                      mascota.especie.etiqueta,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Text('No pudimos cargar la lista. Intenta de nuevo.'),
    );
  }

  Widget _buildVinculacionRow(BuildContext context, Cliente cliente) {
    if (cliente.tieneVinculacion) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined),
            const SizedBox(width: AppSpacing.sm),
            const Text('Cuenta vinculada'),
          ],
        ),
      );
    }

    return AppCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => VinculacionSheet(
          clienteId: cliente.id,
          clienteNombre: cliente.nombre,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.link),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Vincular cuenta')),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
