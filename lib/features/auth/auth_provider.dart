import 'package:flutter/foundation.dart';

import '../../models/entrepreneur.dart';
import 'auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService);

  AuthStatus status = AuthStatus.unknown;
  Entrepreneur? entrepreneur;
  bool isLoading = false;

  Future<void> tryAutoLogin() async {
    try {
      entrepreneur = await _authService.me();
      status = AuthStatus.authenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Vuelve a leer el perfil (ej. después de que se confirma el pago de un plan).
  Future<void> refreshProfile() async {
    entrepreneur = await _authService.me();
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.login(email: email, password: password);
      entrepreneur = result.entrepreneur;
      status = AuthStatus.authenticated;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String? country,
    String? city,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phone: phone,
        country: country,
        city: city,
      );
      entrepreneur = result.entrepreneur;
      status = AuthStatus.authenticated;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return _authService.changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  Future<void> resetPassword({required String email, required String newPassword}) =>
      _authService.resetPassword(email: email, newPassword: newPassword);

  Future<void> logout() async {
    await _authService.logout();
    entrepreneur = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Llamado por ApiClient cuando el refresh token también expiró.
  void handleSessionExpired() {
    entrepreneur = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
