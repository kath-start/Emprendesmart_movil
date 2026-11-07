import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../auth_provider.dart';
import '../firebase_sign_in.dart';
import '../phone_login_screen.dart';
import 'auth_layout.dart';

/// "Continuar con Google" y "Continuar con mi número", compartidos por el login y el registro.
class SocialSignInButtons extends StatefulWidget {
  /// Se llama al entrar con éxito (el registro cierra su pantalla).
  final VoidCallback? onSignedIn;

  const SocialSignInButtons({super.key, this.onSignedIn});

  @override
  State<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends State<SocialSignInButtons> {
  bool _googleBusy = false;
  String? _error;

  Future<void> _google() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      final idToken = await FirebaseSignIn.google();
      if (idToken == null) return; // Cerró el selector de cuentas.
      final signedIn = await auth.loginWithFirebase(idToken);
      if (!signedIn) {
        setState(() => _error = 'Tu cuenta de Google no tiene un correo verificado.');
        return;
      }
      widget.onSignedIn?.call();
    } on FirebaseSignInException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _phone() async {
    setState(() => _error = null);
    final signedIn = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PhoneLoginScreen()));
    if (signedIn == true) widget.onSignedIn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _googleBusy || context.watch<AuthProvider>().isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AuthSecondaryButton(
                icon: _googleBusy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const GoogleMark(size: 24),
                label: 'Google',
                onPressed: busy ? null : _google,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AuthSecondaryButton(
                icon: const Icon(Icons.phone_iphone_rounded, color: AppTheme.primary, size: 24),
                label: 'Celular',
                onPressed: busy ? null : _phone,
              ),
            ),
          ],
        ),
        if (_error != null) ...[const SizedBox(height: 12), AuthErrorBanner(message: _error!)],
      ],
    );
  }
}
