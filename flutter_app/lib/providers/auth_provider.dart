import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';

/// Authentication state
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final String? userId;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.userId,
    this.name,
    this.email,
    this.phoneNumber,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    String? userId,
    String? name,
    String? email,
    String? phoneNumber,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Authentication provider
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService apiService;

  AuthNotifier(this.apiService) : super(const AuthState()) {
    _loadSavedAuth();
  }

  /// Load saved authentication from shared preferences
  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');
      final name = prefs.getString('user_name');
      final email = prefs.getString('user_email');
      final phoneNumber = prefs.getString('user_phone');

      if (token != null && userId != null) {
        apiService.setAuthToken(token);
        state = AuthState(
          isAuthenticated: true,
          token: token,
          userId: userId,
          name: name,
          email: email,
          phoneNumber: phoneNumber,
        );
      }
    } catch (e) {
      debugPrint('Failed to load saved auth: $e');
    }
  }

  /// Save authentication to shared preferences
  Future<void> _saveAuth({
    required String token,
    required String userId,
    required String name,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_id', userId);
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('user_phone', phoneNumber);
    } catch (e) {
      debugPrint('Failed to save auth: $e');
    }
  }

  /// Clear saved authentication
  Future<void> _clearAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_phone');
    } catch (e) {
      debugPrint('Failed to clear auth: $e');
    }
  }

  /// Register with email and password
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiService.register(
        email: email,
        password: password,
        name: name,
        phoneNumber: phoneNumber,
      );

      apiService.setAuthToken(response.token);
      await _saveAuth(
        token: response.token,
        userId: response.userId,
        name: response.name,
        email: response.email,
        phoneNumber: response.phoneNumber,
      );

      state = AuthState(
        isAuthenticated: true,
        token: response.token,
        userId: response.userId,
        name: response.name,
        email: response.email,
        phoneNumber: response.phoneNumber,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Login with email and password
  Future<void> emailLogin({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiService.emailLogin(
        email: email,
        password: password,
      );

      apiService.setAuthToken(response.token);
      await _saveAuth(
        token: response.token,
        userId: response.userId,
        name: response.name,
        email: response.email,
        phoneNumber: response.phoneNumber,
      );

      state = AuthState(
        isAuthenticated: true,
        token: response.token,
        userId: response.userId,
        name: response.name,
        email: response.email,
        phoneNumber: response.phoneNumber,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Send OTP to phone number
  Future<void> sendOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await apiService.sendOTP(phoneNumber);
      state = state.copyWith(isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send OTP: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Verify OTP and login
  Future<void> verifyOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiService.verifyOTP(phoneNumber, otp);

      apiService.setAuthToken(response.token);
      await _saveAuth(
        token: response.token,
        userId: response.userId,
        name: response.name,
        email: response.email,
        phoneNumber: response.phoneNumber,
      );

      state = AuthState(
        isAuthenticated: true,
        token: response.token,
        userId: response.userId,
        name: response.name,
        email: response.email,
        phoneNumber: response.phoneNumber,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'OTP verification failed: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    apiService.clearAuthToken();
    await _clearAuth();
    state = const AuthState();
  }
}

/// API service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  // Change this URL to your backend URL
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  return ApiService(baseUrl: baseUrl);
});

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthNotifier(apiService);
});
