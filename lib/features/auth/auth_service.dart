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

  /// Google o SMS: canjea el ID token de Firebase por la sesión de la app.
  /// Devuelve null si es un teléfono nuevo y faltan nombre y correo para crear la cuenta.
  Future<AuthResult?> firebaseLogin({
    required String idToken,
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    final response = await _apiClient.post(
      '/app/auth/firebase',
      data: {
        'idToken': idToken,
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    final data = response['data'] as Map<String, dynamic>;
    if (data['needsProfile'] == true) return null;
    final result = AuthResult.fromJson(data);
    await _tokenStorage.saveTokens(accessToken: result.accessToken, refreshToken: result.refreshToken);
    return result;
  }

  Future<Entrepreneur> me() async {
    final response = await _apiClient.get('/app/auth/me');
    return Entrepreneur.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Actualiza los datos personales. Un texto vacío borra un dato opcional (teléfono, país, ciudad).
  Future<Entrepreneur> updateProfile(Map<String, String> fields) async {
    final response = await _apiClient.patch('/app/auth/me', data: fields);
    return Entrepreneur.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Entrepreneur> changeEmail({required String newEmail, required String password}) async {
    final response = await _apiClient.post(
      '/app/auth/change-email',
      data: {'newEmail': newEmail, 'password': password},
    );
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
