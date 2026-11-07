import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:emprende_smart/core/network/api_client.dart';
import 'package:emprende_smart/core/storage/token_storage.dart';
import 'package:emprende_smart/features/auth/auth_provider.dart';
import 'package:emprende_smart/features/auth/auth_service.dart';
import 'package:emprende_smart/features/auth/login_screen.dart';

void main() {
  testWidgets('Muestra el formulario de inicio de sesión', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);
    final authProvider = AuthProvider(AuthService(apiClient, tokenStorage));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TokenStorage>.value(value: tokenStorage),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Inicia sesión'), findsWidgets);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
