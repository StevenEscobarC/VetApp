import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../auth/data/repositories/supabase_auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/team_failure.dart';
import '../providers/perfil_providers.dart';

/// Edición del propio perfil: nombre, teléfono y matrícula profesional
/// opcional (D-11, TEAM-05).
class MiPerfilScreen extends ConsumerStatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  ConsumerState<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends ConsumerState<MiPerfilScreen> {
  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _matricula;
  String? _errorNombre;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController();
    _telefono = TextEditingController();
    _matricula = TextEditingController();
    // El perfil puede seguir cargando al abrir la pantalla: se pre-llena una
    // sola vez, apenas hay datos, sin pisar lo que el usuario ya escribió.
    ref.listenManual(authProfileProvider, (_, next) {
      _prellenar(next.value);
    }, fireImmediately: true);
  }

  bool _prellenado = false;

  void _prellenar(AuthProfile? perfil) {
    if (_prellenado || perfil == null) return;
    _prellenado = true;
    _nombre.text = perfil.nombre;
    _telefono.text = perfil.telefono;
    _matricula.text = perfil.matricula ?? '';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _matricula.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final perfil = ref.read(authProfileProvider).value;
    if (perfil == null) return;
    if (_nombre.text.trim().isEmpty) {
      setState(() => _errorNombre = 'Ingresa tu nombre');
      return;
    }
    setState(() {
      _errorNombre = null;
      _guardando = true;
    });
    final matricula = _matricula.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(perfilRepositoryProvider)
          .actualizarMiPerfil(
            id: perfil.id,
            nombre: _nombre.text,
            telefono: _telefono.text,
            matricula: matricula.isEmpty ? null : matricula,
          );
      ref.invalidate(authProfileProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      if (mounted) {
        if (context.canPop()) context.pop();
        setState(() => _guardando = false);
      }
    } on TeamFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: 'Mi perfil'),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppTextField(
          label: 'Nombre',
          controller: _nombre,
          errorText: _errorNombre,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Teléfono',
          controller: _telefono,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Matrícula profesional (opcional)',
          controller: _matricula,
          hintText: 'Ej. 12345',
          helperText:
              'Se mostrará en tus documentos, como el carné de vacunación.',
          prefixIcon: Icons.badge_outlined,
          maxLength: 20,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Guardar cambios',
          isLoading: _guardando,
          onPressed: _guardar,
        ),
      ],
    ),
  );
}
