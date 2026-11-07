import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Error de Google/Firebase con el mensaje listo para mostrar.
class FirebaseSignInException implements Exception {
  final String message;

  FirebaseSignInException(this.message);

  @override
  String toString() => message;
}

/// Inicio de sesión con Google y con teléfono (SMS) a través de Firebase Auth.
///
/// Firebase solo comprueba la identidad: el ID token que devuelve se manda al backend
/// (`POST /app/auth/firebase`), que entrega la sesión normal de la app.
class FirebaseSignIn {
  FirebaseSignIn._();

  /// Por ahora solo Android tiene `google-services.json`.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool _ready = false;
  static bool _googleReady = false;

  static Future<void> init() async {
    if (!isSupported || _ready) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (error) {
      debugPrint('No se pudo iniciar Firebase: $error');
    }
  }

  static void _ensureReady() {
    if (!_ready) throw FirebaseSignInException('Este acceso no está disponible en este dispositivo.');
  }

  /// Abre el selector de cuentas de Google. Devuelve el ID token de Firebase, o null si el usuario canceló.
  static Future<String?> google() async {
    _ensureReady();
    final google = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        await google.initialize();
        _googleReady = true;
      }
      final account = await google.authenticate();
      final googleToken = account.authentication.idToken;
      if (googleToken == null) throw FirebaseSignInException('Google no devolvió tu cuenta. Inténtalo de nuevo.');
      final credential = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleToken),
      );
      return await credential.user?.getIdToken();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled || error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      debugPrint('Google Sign-In: ${error.code} ${error.description}');
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw FirebaseSignInException(
          'El acceso con Google aún no está configurado. Falta el SHA-1 o activar Google en Firebase.',
        );
      }
      throw FirebaseSignInException('No se pudo entrar con Google. Inténtalo de nuevo.');
    } on FirebaseAuthException catch (error) {
      throw FirebaseSignInException(authErrorMessage(error));
    }
  }

  /// Envía el SMS con el código. [phoneNumber] en formato internacional: "+51929020723".
  /// En Android el código a veces se lee solo: entonces se llama [onAutoVerified] con el ID token.
  static Future<void> sendSmsCode({
    required String phoneNumber,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String idToken) onAutoVerified,
    required void Function(String message) onError,
  }) async {
    _ensureReady();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      verificationFailed: (error) => onError(authErrorMessage(error)),
      verificationCompleted: (credential) async {
        try {
          final result = await FirebaseAuth.instance.signInWithCredential(credential);
          final token = await result.user?.getIdToken();
          if (token != null) onAutoVerified(token);
        } on FirebaseAuthException catch (error) {
          onError(authErrorMessage(error));
        }
      },
    );
  }

  /// Comprueba el código de 6 dígitos y devuelve el ID token de Firebase.
  static Future<String> confirmSmsCode({required String verificationId, required String code}) async {
    _ensureReady();
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
      );
      final token = await result.user?.getIdToken();
      if (token == null) throw FirebaseSignInException('No se pudo verificar el código. Inténtalo de nuevo.');
      return token;
    } on FirebaseAuthException catch (error) {
      throw FirebaseSignInException(authErrorMessage(error));
    }
  }

  /// ID token vigente del usuario ya verificado (p. ej. al completar el perfil tras el SMS).
  static Future<String?> currentIdToken() async {
    if (!_ready) return null;
    return FirebaseAuth.instance.currentUser?.getIdToken(true);
  }

  /// Al cerrar sesión en la app, para que la próxima vez Google vuelva a preguntar la cuenta.
  static Future<void> signOut() async {
    if (!_ready) return;
    try {
      await FirebaseAuth.instance.signOut();
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('Error al cerrar sesión en Firebase: $error');
    }
  }

  static String authErrorMessage(FirebaseAuthException error) {
    debugPrint('Firebase Auth: ${error.code} ${error.message}');
    return switch (error.code) {
      'invalid-phone-number' => 'El número no es válido. Revísalo e inténtalo de nuevo.',
      'invalid-verification-code' => 'El código no es correcto.',
      'session-expired' || 'code-expired' => 'El código venció. Pide uno nuevo.',
      'too-many-requests' => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
      'quota-exceeded' => 'Se alcanzó el límite de SMS por hoy. Inténtalo más tarde.',
      'network-request-failed' => 'Sin conexión a internet.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      'operation-not-allowed' => 'Este método de acceso no está activado en Firebase.',
      'billing-not-enabled' => 'El envío de SMS requiere activar la facturación (plan Blaze) en Firebase.',
      'app-not-authorized' ||
      'missing-client-identifier' ||
      'invalid-app-credential' => 'La app no está autorizada en Firebase. Falta agregar el SHA-1/SHA-256.',
      _ => 'No se pudo completar el acceso. Inténtalo de nuevo.',
    };
  }
}
