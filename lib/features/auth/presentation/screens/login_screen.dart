import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/auth_failure.dart';
import '../providers/auth_providers.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signIn(email: _email.text, password: _password.text);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Bienvenido a VetApp',
    subtitle: 'Gestiona tu clínica o cuida la salud de tus mascotas.',
    error: _error,
    children: [
      AppTextField(
        label: 'Correo electrónico',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        hintText: 'tu@correo.com',
      ),
      const SizedBox(height: 16),
      AppTextField(
        label: 'Contraseña',
        controller: _password,
        obscureText: true,
        hintText: 'Mínimo 8 caracteres',
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => context.push('/reset-password'),
          child: const Text('Olvidé mi contraseña'),
        ),
      ),
      AppButton(
        label: 'Iniciar sesión',
        onPressed: _submit,
        isLoading: _loading,
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: () => context.push('/register'),
          child: const Text('Crear cuenta'),
        ),
      ),
    ],
  );
}
