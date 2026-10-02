import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/codigo_invitacion.dart';
import '../../domain/team_failure.dart';
import '../providers/team_providers.dart';
import '../widgets/codigo_invitacion_field.dart';

enum _Modo { ninguno, crear, unirse }

/// Pantalla completa para un veterinario retirado de la clínica (D-05): sin
/// navegación inferior ni botón atrás. Puede crear su propia clínica vacía,
/// unirse a otra con un código nuevo o cerrar sesión.
class AccesoRevocadoScreen extends ConsumerStatefulWidget {
  const AccesoRevocadoScreen({super.key});

  @override
  ConsumerState<AccesoRevocadoScreen> createState() =>
      _AccesoRevocadoScreenState();
}

class _AccesoRevocadoScreenState extends ConsumerState<AccesoRevocadoScreen> {
  _Modo _modo = _Modo.ninguno;
  final _nombre = TextEditingController();
  bool _creando = false;
  String? _errorNombre;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _errorNombre = 'Escribe el nombre de tu clínica.');
      return;
    }
    setState(() {
      _creando = true;
      _errorNombre = null;
    });
    try {
      await ref.read(teamActionsProvider).crearMiClinica(_nombre.text);
    } on TeamFailure catch (e) {
      if (mounted) setState(() => _errorNombre = e.message);
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(authProfileProvider).value;
    final textTheme = Theme.of(context).textTheme;
    final nombre = perfil?.clinicaNombre;
    final titulo = nombre == null || nombre.isEmpty
        ? 'Ya no tienes acceso a la clínica'
        : 'Ya no tienes acceso a $nombre';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Icon(
                            Icons.lock_outline,
                            size: 32,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'El administrador te retiró del equipo. Tus consultas '
                      'siguen en la clínica. Puedes crear tu propia clínica o '
                      'unirte a otra con un código de invitación.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AnimatedSize(
                      duration: MediaQuery.of(context).disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_modo != _Modo.crear)
                            AppButton(
                              label: 'Crear mi propia clínica',
                              onPressed: () =>
                                  setState(() => _modo = _Modo.crear),
                            )
                          else ...[
                            AppTextField(
                              label: 'Nombre de tu clínica',
                              controller: _nombre,
                              errorText: _errorNombre,
                              prefixIcon: Icons.local_hospital_outlined,
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                              label: 'Crear clínica',
                              isLoading: _creando,
                              onPressed: _crear,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          if (_modo != _Modo.unirse)
                            AppButton(
                              label: 'Tengo un código de invitación',
                              variant: AppButtonVariant.outline,
                              onPressed: () =>
                                  setState(() => _modo = _Modo.unirse),
                            )
                          else
                            const UnirseConCodigoForm(),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Cerrar sesión',
                      variant: AppButtonVariant.text,
                      onPressed: () =>
                          ref.read(authProfileProvider.notifier).signOut(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de código + 'Unirme', compartido por 'Acceso revocado' y por Equipo
/// (clínica vacía). Solo captura [TeamFailure]; el éxito refresca el perfil.
class UnirseConCodigoForm extends ConsumerStatefulWidget {
  const UnirseConCodigoForm({super.key});

  @override
  ConsumerState<UnirseConCodigoForm> createState() =>
      _UnirseConCodigoFormState();
}

class _UnirseConCodigoFormState extends ConsumerState<UnirseConCodigoForm> {
  final _codigo = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _unirme() async {
    if (!esCodigoInvitacionCompleto(_codigo.text)) {
      setState(
        () => _error = 'Ese código no es válido. Revísalo e inténtalo de nuevo.',
      );
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(teamActionsProvider).unirseAClinica(_codigo.text);
    } on TeamFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CodigoInvitacionField(controller: _codigo, errorText: _error),
      const SizedBox(height: AppSpacing.md),
      AppButton(label: 'Unirme', isLoading: _cargando, onPressed: _unirme),
    ],
  );
}
