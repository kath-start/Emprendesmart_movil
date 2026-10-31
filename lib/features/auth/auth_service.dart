import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../models/entrepreneur.dart';

class AuthResult {
  final Entrepreneur entrepreneur;
  final String accessToken;
  final String refreshToken;

  AuthResult({required this.entrepreneur, required this.accessToken, required this.refreshToken});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      entrepreneur: Entrepreneur.fromJson(json['entrepreneur'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}

class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthService(this._apiClient, this._tokenStorage);

  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String? country,
    String? city,
  }) async {
    final response = await _apiClient.post(
      '/app/auth/register',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (country != null && country.isNotEmpty) 'country': country,
        if (city != null && city.isNotEmpty) 'city': city,
      },
    );
    final result = AuthResult.fromJson(response['data'] as Map<String, dynamic>);
    await _tokenStorage.saveTokens(accessToken: result.accessToken, refreshToken: result.refreshToken);
    return result;
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final response = await _apiClient.post('/app/auth/login', data: {'email': email, 'password': password});
    final result = AuthResult.fromJson(response['data'] as Map<String, dynamic>);
    await _tokenStorage.saveTokens(accessToken: result.accessToken, refreshToken: result.refreshToken);
    return result;
  }

  Future<Entrepreneur> me() async {
    final response = await _apiClient.get('/app/auth/me');
    return Entrepreneur.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _apiClient.post(
      '/app/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  /// Cambia la contraseña de la cuenta con ese correo (sin código de verificación).
  Future<void> resetPassword({required String email, required String newPassword}) async {
    await _apiClient.post('/app/auth/forgot-password/reset', data: {'email': email, 'newPassword': newPassword});
  }

  Future<void> logout() => _tokenStorage.clear();
}
