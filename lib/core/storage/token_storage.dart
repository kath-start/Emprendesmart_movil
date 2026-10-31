import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda los tokens de sesión del emprendedor en el almacenamiento seguro del dispositivo.
class TokenStorage {
  static const _accessTokenKey = 'app_access_token';
  static const _refreshTokenKey = 'app_refresh_token';
  static const _rememberedEmailKey = 'app_remembered_email';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveRememberedEmail(String email) => _storage.write(key: _rememberedEmailKey, value: email);

  Future<String?> readRememberedEmail() => _storage.read(key: _rememberedEmailKey);

  Future<void> clearRememberedEmail() => _storage.delete(key: _rememberedEmailKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
