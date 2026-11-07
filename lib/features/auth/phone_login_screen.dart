import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/countries.dart';
import 'auth_provider.dart';
import 'firebase_sign_in.dart';
import 'widgets/auth_layout.dart';

enum _Step { phone, code, profile }

/// Entrar con el número de celular: SMS con código y, la primera vez, nombre y correo.
/// Devuelve `true` al hacer `pop` si la sesión quedó iniciada.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _profileFormKey = GlobalKey<FormState>();

  _Step _step = _Step.phone;
  String _country = 'Perú';
  String? _verificationId;
  int? _resendToken;
  String? _idToken;
  bool _busy = false;
  String? _error;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  String get _fullPhone => '${countryDialCodes[_country]}${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      setState(() => _error = 'Ingresa tu número de celular.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseSignIn.sendSmsCode(
        phoneNumber: _fullPhone,
        resendToken: resend ? _resendToken : null,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _step = _Step.code;
            _busy = false;
          });
          _startResendCountdown();
        },
        onAutoVerified: (idToken) {
          if (mounted) _finish(idToken);
        },
        onError: (message) {
          if (mounted) {
            setState(() {
              _error = message;
              _busy = false;
            });
          }
        },
      );
    } on FirebaseSignInException catch (error) {
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  Future<void> _confirmCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || _verificationId == null) {
      setState(() => _error = 'Ingresa el código de 6 dígitos.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idToken = await FirebaseSignIn.confirmSmsCode(verificationId: _verificationId!, code: code);
      await _finish(idToken);
    } on FirebaseSignInException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    }
  }

  /// Canjea el token en el backend; si el número es nuevo pasa al paso de perfil.
  Future<void> _finish(String idToken) async {
    _idToken = idToken;
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signedIn = await auth.loginWithFirebase(idToken);
      if (!mounted) return;
      if (signedIn) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _step = _Step.profile;
          _busy = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    }
  }

  Future<void> _createAccount() async {
    if (!_profileFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // El token de Firebase dura 1 hora; se pide uno nuevo por si el usuario tardó.
      final idToken = await FirebaseSignIn.currentIdToken() ?? _idToken!;
      final signedIn = await auth.loginWithFirebase(
        idToken,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      if (signedIn) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'No se pudo crear tu cuenta. Revisa tus datos.';
          _busy = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (title, subtitle) = switch (_step) {
      _Step.phone => ('Entra con tu número', 'Te enviaremos un código por SMS para confirmar que es tuyo.'),
      _Step.code => (
        'Escribe el código',
        'Lo enviamos por SMS al ${countryDialCodes[_country]} ${_phoneController.text}.',
      ),
      _Step.profile => ('Completa tu cuenta', 'Es tu primera vez con este número. Cuéntanos quién eres.'),
    };

    return AuthLayout(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 52,
              height: 4,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          ...switch (_step) {
            _Step.phone => _phoneStep(),
            _Step.code => _codeStep(),
            _Step.profile => _profileStep(),
          },
          if (_error != null) ...[const SizedBox(height: 12), AuthErrorBanner(message: _error!)],
        ],
      ),
    );
  }

  List<Widget> _phoneStep() => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF3FB),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD5DEEC)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _country,
              borderRadius: BorderRadius.circular(16),
              items: [
                for (final entry in countryDialCodes.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
              ],
              selectedItemBuilder: (_) => [
                for (final entry in countryDialCodes.entries)
                  Center(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
              ],
              onChanged: _busy ? null : (value) => setState(() => _country = value!),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AuthTextField(
            controller: _phoneController,
            hint: 'Número de celular',
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _busy ? null : _sendCode(),
          ),
        ),
      ],
    ),
    const SizedBox(height: 20),
    AuthPrimaryButton(label: 'Enviarme el código', loading: _busy, onPressed: _busy ? null : _sendCode),
  ];

  List<Widget> _codeStep() => [
    TextField(
      controller: _codeController,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        if (value.length == 6 && !_busy) _confirmCode();
      },
      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        counterText: '',
        hintText: '••••••',
        hintStyle: const TextStyle(color: Color(0xFFB4C0D3), letterSpacing: 14),
        filled: true,
        fillColor: const Color(0xFFEEF3FB),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFD5DEEC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.6),
        ),
      ),
    ),
    const SizedBox(height: 20),
    AuthPrimaryButton(label: 'Confirmar', loading: _busy, onPressed: _busy ? null : _confirmCode),
    const SizedBox(height: 8),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _step = _Step.phone;
                  _codeController.clear();
                  _error = null;
                }),
          child: const Text('Cambiar número'),
        ),
        const Text('·', style: TextStyle(color: AppTheme.textSecondary)),
        TextButton(
          onPressed: _busy || _resendSeconds > 0 ? null : () => _sendCode(resend: true),
          child: Text(_resendSeconds > 0 ? 'Reenviar en ${_resendSeconds}s' : 'Reenviar código'),
        ),
      ],
    ),
  ];

  List<Widget> _profileStep() => [
    Form(
      key: _profileFormKey,
      child: Column(
        children: [
          AuthTextField(
            controller: _firstNameController,
            hint: 'Nombres',
            icon: Icons.person_rounded,
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _lastNameController,
            hint: 'Apellidos',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Ingresa tus apellidos' : null,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _emailController,
            hint: 'Correo electrónico',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _busy ? null : _createAccount(),
            validator: (value) => (value == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()))
                ? 'Ingresa un correo válido'
                : null,
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    AuthPrimaryButton(label: 'Crear mi cuenta', loading: _busy, onPressed: _busy ? null : _createAccount),
  ];
}
