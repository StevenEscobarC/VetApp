import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/inputs/app_text_field.dart';
import '../../home/home_screen.dart';
import '../data/repositories/supabase_auth_repository.dart';
import '../domain/auth_failure.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
final supabaseConfigured =
    _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SupabaseAuthRepository _repository;
  AuthProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (supabaseConfigured) {
      _repository = SupabaseAuthRepository(Supabase.instance.client);
      _loadSession();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadSession() async {
    final session = _repository.currentSession;
    if (session != null) {
      try {
        _profile = await _repository.profileForCurrentUser();
      } on AuthFailure {
        await _repository.signOut();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!supabaseConfigured) return const LoginScreen();
    if (_profile == null) {
      return LoginScreen(
        onAuthenticated: (profile) => setState(() => _profile = profile),
      );
    }
    return _profile!.esVeterinario
        ? const _VeterinarianHome()
        : const ClientHomeScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onAuthenticated});

  final ValueChanged<AuthProfile>? onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!supabaseConfigured) {
      setState(() => _error = 'Configura Supabase para iniciar sesión.');
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Ingresa tu correo y contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await SupabaseAuthRepository(
        Supabase.instance.client,
      ).signIn(email: _email.text, password: _password.text);
      if (mounted) widget.onAuthenticated?.call(profile);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
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
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          ),
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
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: const Text('Crear cuenta'),
        ),
      ),
    ],
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _clinic = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _clinicPhone = TextEditingController();
  String _role = 'CLIENTE';
  bool _loading = false;
  String? _error;

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
    if (_role == 'VETERINARIO' && _clinic.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el nombre de tu clínica.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseAuthRepository(Supabase.instance.client).signUp(
        email: _email.text,
        password: _password.text,
        nombre: _name.text,
        telefono: _phone.text,
        rol: _role,
        clinicaNombre: _role == 'VETERINARIO' ? _clinic.text : null,
        ciudad: _role == 'VETERINARIO' ? _city.text : null,
        direccion: _role == 'VETERINARIO' ? _address.text : null,
        clinicaTelefono: _role == 'VETERINARIO' ? _clinicPhone.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada. Revisa tu correo para confirmarla.'),
          ),
        );
        Navigator.pop(context);
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
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
      if (_role == 'VETERINARIO') ...[
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

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  String? _message;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await SupabaseAuthRepository(
        Supabase.instance.client,
      ).resetPassword(_email.text);
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
  Widget build(BuildContext context) => _AuthScaffold(
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

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    this.error,
  });

  final String title;
  final String subtitle;
  final String? error;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pets, size: 42),
                const SizedBox(height: 28),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 28),
                if (error != null) ...[
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _VeterinarianHome extends StatelessWidget {
  const _VeterinarianHome();

  @override
  Widget build(BuildContext context) => const HomeScreen();
}

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis mascotas')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Aún no tienes mascotas registradas.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Agrégalas para consultar su historial y agendar citas.'),
        const SizedBox(height: 24),
        AppButton(label: 'Agregar mascota', icon: Icons.add, onPressed: () {}),
        const SizedBox(height: 12),
        AppButton(
          label: 'Agendar cita',
          icon: Icons.calendar_month,
          variant: AppButtonVariant.outline,
          onPressed: () {},
        ),
      ],
    ),
  );
}
