import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/notifications/notification_service.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/businesses/business_provider.dart';
import 'features/businesses/business_service.dart';
import 'features/businesses/create_business_screen.dart';
import 'features/home/home_screen.dart';
import 'features/products/product_provider.dart';
import 'features/products/product_service.dart';
import 'features/sales/sale_provider.dart';
import 'features/sales/sale_service.dart';
import 'features/yape/yape_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<TokenStorage>.value(value: tokenStorage),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) {
            final authProvider = AuthProvider(AuthService(apiClient, tokenStorage));
            apiClient.onSessionExpired = authProvider.handleSessionExpired;
            return authProvider;
          },
        ),
        ChangeNotifierProvider<BusinessProvider>(create: (_) => BusinessProvider(BusinessService(apiClient))),
        ChangeNotifierProvider<ProductProvider>(create: (_) => ProductProvider(ProductService(apiClient))),
        ChangeNotifierProvider<SaleProvider>(create: (_) => SaleProvider(SaleService(apiClient))),
        // Empieza a leer los Yapes al abrir la app, sin esperar a que se abra su pantalla.
        ChangeNotifierProvider<YapeProvider>(create: (_) => YapeProvider()..start(), lazy: false),
      ],
      child: MaterialApp(
        title: 'EmprendeSmart',
        navigatorKey: NotificationService.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _businessesRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<AuthProvider>().status;

    if (authStatus == AuthStatus.unknown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authStatus == AuthStatus.unauthenticated) {
      if (_businessesRequested) {
        _businessesRequested = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<BusinessProvider>().reset();
          context.read<ProductProvider>().reset();
          context.read<SaleProvider>().reset();
        });
      }
      return const LoginScreen();
    }

    if (!_businessesRequested) {
      _businessesRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BusinessProvider>().loadBusinesses();
      });
    }

    final businessProvider = context.watch<BusinessProvider>();
    if (businessProvider.isLoading && businessProvider.businesses.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (businessProvider.currentBusiness == null) {
      return const CreateBusinessScreen();
    }

    return const HomeScreen();
  }
}
