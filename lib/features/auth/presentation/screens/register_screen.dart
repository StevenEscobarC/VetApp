import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/chips/app_filter_chip.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../team/domain/codigo_invitacion.dart';
import '../../../team/presentation/widgets/codigo_invitacion_field.dart';
import '../../domain/auth_failure.dart';
import '../providers/auth_providers.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _clinic = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _clinicPhone = TextEditingController();
  final _codigo = TextEditingController();
  bool _conCodigo = false;
  String? _codigoError;
  String _role = 'CLIENTE';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _clinic.dispose();
    _city.dispose();
    _address.dispose();
    _clinicPhone.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.length < 8) {
      setState(
        () => _error =
            'Completa nombre, correo y una contraseña de 8 caracteres.',
      );
      return;
    }
    final usaCodigo = _role == 'VETERINARIO' && _conCodigo;
    if (usaCodigo && !esCodigoInvitacionCompleto(_codigo.text)) {
      setState(() {
        _error = null;
        _codigoError =
            'Ese código no es válido. Revísalo e inténtalo de nuevo.';
      });
      return;
    }
    if (_role == 'VETERINARIO' && !usaCodigo && _clinic.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el nombre de tu clínica.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _codigoError = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signUp(
        email: _email.text,
        password: _password.text,
        nombre: _name.text,
        telefono: _phone.text,
        rol: _role,
        clinicaNombre: _role == 'VETERINARIO' && !usaCodigo
            ? _clinic.text
            : null,
        ciudad: _role == 'VETERINARIO' && !usaCodigo ? _city.text : null,
        direccion: _role == 'VETERINARIO' && !usaCodigo ? _address.text : null,
        clinicaTelefono: _role == 'VETERINARIO' && !usaCodigo
            ? _clinicPhone.text
            : null,
        codigoInvitacion: usaCodigo ? _codigo.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada. Revisa tu correo para confirmarla.'),
          ),
        );
        if (context.canPop()) context.pop();
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() {
          if (usaCodigo) {
            _codigoError = error.message;
          } else {
            _error = error.message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Crear cuenta',
    subtitle: 'Solo necesitamos unos datos para comenzar.',
    error: _error,
    children: [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'CLIENTE',
            label: Text('Dueño de mascota'),
            icon: Icon(Icons.pets),
          ),
          ButtonSegment(
            value: 'VETERINARIO',
            label: Text('Veterinario'),
            icon: Icon(Icons.local_hospital),
          ),
        ],
        selected: {_role},
        onSelectionChanged: (value) => setState(() => _role = value.first),
      ),
      if (_role == 'VETERINARIO') ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppFilterChip(
                label: 'Crear mi clínica',
                selected: !_conCodigo,
                onTap: () => setState(() {
                  _conCodigo = false;
                  _codigo.clear();
                  _codigoError = null;
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppFilterChip(
                label: 'Tengo un código',
                selected: _conCodigo,
                onTap: () => setState(() => _conCodigo = true),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      AppTextField(label: 'Nombre completo', controller: _name),
      const SizedBox(height: 16),
      AppTextField(
        label: 'Correo electrónico',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      AppTextField(
        label: 'Teléfono',
        controller: _phone,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 16),
      AppTextField(
        label: 'Contraseña',
        controller: _password,
        obscureText: true,
        hintText: 'Mínimo 8 caracteres',
      ),
      if (_role == 'VETERINARIO' && _conCodigo) ...[
        const SizedBox(height: 24),
        CodigoInvitacionField(controller: _codigo, errorText: _codigoError),
      ],
      if (_role == 'VETERINARIO' && !_conCodigo) ...[
        const SizedBox(height: 24),
        Text(
          'Datos de la clínica',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        AppTextField(label: 'Nombre de la clínica', controller: _clinic),
        const SizedBox(height: 16),
        AppTextField(label: 'Ciudad', controller: _city),
        const SizedBox(height: 16),
        AppTextField(label: 'Dirección', controller: _address),
        const SizedBox(height: 16),
        AppTextField(label: 'Teléfono de la clínica', controller: _clinicPhone),
      ],
      const SizedBox(height: 24),
      AppButton(label: 'Crear cuenta', onPressed: _submit, isLoading: _loading),
    ],
  );
}
