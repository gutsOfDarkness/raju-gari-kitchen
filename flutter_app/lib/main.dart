import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/menu_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_confirmation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'providers/auth_provider.dart';
import 'services/logger_service.dart';

void main() {
  runZonedGuarded(() {
    LoggerService.info('[App] Starting Crave Delivery application');
    
    FlutterError.onError = (FlutterErrorDetails details) {
      LoggerService.error('[Flutter Error]', details.exception, details.stack);
    };
    
    runApp(const ProviderScope(child: FoodDeliveryApp()));
    
    LoggerService.info('[App] Application initialized successfully');
  }, (error, stack) {
    LoggerService.error('[Uncaught Error]', error, stack);
  });
}

/// Main application widget
class FoodDeliveryApp extends ConsumerWidget {
  const FoodDeliveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LoggerService.debug('[FoodDeliveryApp] build() called');
    
    return MaterialApp(
      title: 'Food Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.orangeAccent,
          surface: Color(0xFF1E1E1E),
          background: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white10, width: 1),
          ),
        ),
      ),
      home: const AuthAwareHome(),
      onGenerateRoute: (settings) {
        LoggerService.info('[Router] Navigating to: ${settings.name}');
        
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
              settings: settings,
            );
          case '/signup':
            return MaterialPageRoute(
              builder: (context) => const SignupScreen(),
              settings: settings,
            );
          case '/menu':
            return MaterialPageRoute(
              builder: (context) => const MenuScreen(),
              settings: settings,
            );
          case '/cart':
            return MaterialPageRoute(
              builder: (context) => const CartScreen(),
              settings: settings,
            );
          case '/checkout':
            return MaterialPageRoute(
              builder: (context) => const CheckoutScreen(),
              settings: settings,
            );
          case '/order-confirmation':
            return MaterialPageRoute(
              builder: (context) => const OrderConfirmationScreen(),
              settings: settings,
            );
          default:
            LoggerService.warning('[Router] Unknown route: ${settings.name}');
            return MaterialPageRoute(
              builder: (context) => const MenuScreen(),
              settings: settings,
            );
        }
      },
    );
  }
}

/// Authentication-aware home widget
/// Shows menu if authenticated, login screen otherwise
class AuthAwareHome extends ConsumerWidget {
  const AuthAwareHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    // Show login screen if not authenticated
    // Show menu screen if authenticated
    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }
    
    return authState.isAuthenticated ? const MenuScreen() : const LoginScreen();
  }
}