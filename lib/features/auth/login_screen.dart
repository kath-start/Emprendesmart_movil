import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import 'auth_provider.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_layout.dart';
import 'widgets/social_sign_in_buttons.dart';

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
              style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Inicia sesión para continuar a tu negocio.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 28),
            AuthTextField(
              controller: _emailController,
              hint: 'Correo electrónico o número',
              icon: Icons.person_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Ingresa tu correo o número';
                if (text.contains('@')) return null;
                return text.replaceAll(RegExp(r'\D'), '').length >= 6 ? null : 'Ingresa un correo o número válido';
              },
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _passwordController,
              hint: 'Contraseña',
              icon: Icons.lock_rounded,
              obscureText: _obscurePassword,
              onFieldSubmitted: (_) => isLoading ? null : _submit(),
              suffix: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  color: const Color(0xFF0D2A6B),
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Ingresa tu contraseña' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  height: 26,
                  width: 26,
                  child: Checkbox(
                    value: _rememberMe,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    activeColor: AppTheme.primary,
                    onChanged: (value) => setState(() => _rememberMe = value ?? true),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Recordar sesión', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  initialEmail: _emailController.text.contains('@')
                                      ? _emailController.text.trim()
                                      : null,
                                ),
                              ),
                            ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        foregroundColor: AppTheme.primary,
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('¿Olvidaste tu contraseña?', textAlign: TextAlign.end),
                    ),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[const SizedBox(height: 8), AuthErrorBanner(message: _errorMessage!)],
            const SizedBox(height: 24),
            AuthPrimaryButton(label: 'Iniciar sesión', loading: isLoading, onPressed: isLoading ? null : _submit),
            const SizedBox(height: 24),
            const AuthOrDivider(),
            const SizedBox(height: 20),
            const SocialSignInButtons(),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('¿No tienes una cuenta?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Regístrate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
