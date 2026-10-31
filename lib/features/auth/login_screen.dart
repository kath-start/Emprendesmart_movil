import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import 'auth_provider.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    context.read<TokenStorage>().readRememberedEmail().then((email) {
      if (email != null && mounted) {
        setState(() => _emailController.text = email);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);
    final email = _emailController.text.trim();
    final tokenStorage = context.read<TokenStorage>();
    try {
      await context.read<AuthProvider>().login(email: email, password: _passwordController.text);
      if (_rememberMe) {
        await tokenStorage.saveRememberedEmail(email);
      } else {
        await tokenStorage.clearRememberedEmail();
      }
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature estará disponible próximamente.')));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final textTheme = Theme.of(context).textTheme;

    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¡Bienvenido!',
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Inicia sesión para continuar a tu negocio.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => (value == null || !value.contains('@')) ? 'Ingresa un email válido' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onFieldSubmitted: (_) => isLoading ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu contraseña' : null,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (value) => setState(() => _rememberMe = value ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Recordar sesión', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const Spacer(),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(
                              initialEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
                            ),
                          ),
                        ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ],
            ),
            if (_errorMessage != null) ...[const SizedBox(height: 8), AuthErrorBanner(message: _errorMessage!)],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Iniciar sesión'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            const AuthOrDivider(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => _showComingSoon('El acceso con Google'),
              icon: const GoogleMark(),
              label: const Text('Continuar con Google'),
            ),
            const SizedBox(height: 20),
            const Text(
              '¿No tienes una cuenta?',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            Center(
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('Regístrate aquí', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
