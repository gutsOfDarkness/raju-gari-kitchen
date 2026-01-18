import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/menu_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_confirmation_screen.dart';
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
class FoodDeliveryApp extends StatelessWidget {
  const FoodDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        LoggerService.info('[Router] Navigating to: ${settings.name}');
        
        switch (settings.name) {
          case '/':
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
