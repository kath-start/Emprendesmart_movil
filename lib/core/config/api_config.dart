import 'package:flutter/foundation.dart';

/// Configuración de acceso a la API de EmprendeSmart.
class ApiConfig {
  ApiConfig._();

  /// Backend local (ver D:\Emprende-Smart-Web\backend, `npm run dev`).
  ///
  /// - Web / Windows: `localhost`, porque corren en la misma máquina que el backend.
  /// - Emulador Android: `10.0.2.2`, que es como el emulador ve a la computadora
  ///   (su propio `localhost` es el emulador).
  /// - Teléfono físico: pasa la IP de red local de la computadora, por ejemplo
  ///   `flutter run --dart-define=API_BASE_URL=http://192.168.1.50:4000/api/v1`.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }
}
