import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../domain/auth_failure.dart';
import '../providers/auth_providers.dart';
import 'auth_scaffold.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _email = TextEditingController();
  String? _message;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(_email.text);
      if (mounted) {
        setState(
          () => _message = 'Revisa tu correo para crear una nueva contraseña.',
        );
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Recuperar contraseña',
    subtitle: 'Te enviaremos un enlace seguro a tu correo.',
    error: _message,
    children: [
      AppTextField(
        label: 'Correo electrónico',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 20),
      AppButton(
        label: 'Enviar enlace',
        onPressed: _submit,
        isLoading: _loading,
      ),
    ],
  );
}
