import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../models/order.dart';

/// API Service for communicating with the Go backend.
/// Handles all HTTP requests with proper error handling.
class ApiService {
  final String baseUrl;
  String? _authToken;

  ApiService({required this.baseUrl});

  /// Set the authentication token for protected endpoints
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Clear authentication token on logout
  void clearAuthToken() {
    _authToken = null;
  }

  /// Get default headers including auth token if available
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Fetch menu items from the server
  Future<List<MenuItem>> getMenu() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/menu'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final itemsData = data['data']['items'];
      
      // Handle null items gracefully
      if (itemsData == null) {
        return [];
      }
      
      final items = (itemsData as List<dynamic>)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return items;
    } else {
      throw ApiException('Failed to fetch menu', response.statusCode);
    }
  }

  /// Create an order with cart items
  /// Returns Razorpay order details for checkout
  Future<CreateOrderResponse> createOrder(List<CartItem> items) async {
    final body = jsonEncode({
      'items': items.map((e) => e.toJson()).toList(),
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/orders/create'),
      headers: _headers,
      body: body,
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CreateOrderResponse.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        error['error'] as String? ?? 'Failed to create order',
        response.statusCode,
      );
    }
  }

  /// Verify payment with backend after Razorpay success callback.
  /// CRITICAL: Do NOT assume payment success from client callback alone.
  /// Always verify with backend using signature.
  Future<PaymentVerificationResult> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final body = jsonEncode({
      'order_id': orderId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/orders/verify'),
      headers: _headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultData = data['data'] as Map<String, dynamic>;
      return PaymentVerificationResult(
        success: resultData['success'] as bool,
        orderId: resultData['order_id'] as String,
        status: resultData['status'] as String,
        message: resultData['message'] as String,
      );
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        error['error'] as String? ?? 'Payment verification failed',
        response.statusCode,
      );
    }
  }

  /// Fetch user's order history
  Future<List<Order>> getUserOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/orders'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final orders = (data['data'] as List<dynamic>?)
              ?.map((e) => Order.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return orders;
    } else {
      throw ApiException('Failed to fetch orders', response.statusCode);
    }
  }

  /// Register new user with email and password
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
      'name': name,
      'phone_number': phoneNumber,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/register'),
      headers: _headers,
      body: body,
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultData = data['data'] as Map<String, dynamic>;
      return AuthResponse(
        token: resultData['token'] as String,
        userId: resultData['user_id'] as String,
        name: name,
        email: email,
      );
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        error['error'] as String? ?? 'Registration failed',
        response.statusCode,
      );
    }
  }

  /// Login with email and password
  Future<AuthResponse> emailLogin({
    required String email,
    required String password,
  }) async {
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login/email'),
      headers: _headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultData = data['data'] as Map<String, dynamic>;
      return AuthResponse(
        token: resultData['token'] as String,
        userId: resultData['user_id'] as String,
        name: resultData['name'] as String,
        email: resultData['email'] as String,
      );
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        error['error'] as String? ?? 'Login failed',
        response.statusCode,
      );
    }
  }

  /// Send OTP to phone number for login
  Future<void> sendOTP(String phoneNumber) async {
    final body = jsonEncode({'phone_number': phoneNumber});

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login/phone'),
      headers: _headers,
      body: body,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        error['error'] as String? ?? 'Failed to send OTP',
        response.statusCode,
      );
    }
  }

  /// Verify OTP and get auth token
  Future<AuthResponse> verifyOTP(String phoneNumber, String otp) async {
    final body = jsonEncode({
      'phone_number': phoneNumber,
      'otp': otp,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/verify-otp'),
      headers: _headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultData = data['data'] as Map<String, dynamic>;
      return AuthResponse(
        token: resultData['token'] as String,
        userId: resultData['user_id'] as String,
        name: resultData['name'] as String,
        email: resultData['email'] as String,
      );
    } else {
      final error = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        error['error'] as String? ?? 'OTP verification failed',
        response.statusCode,
      );
    }
  }
}

/// API Exception with status code
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Result of payment verification
class PaymentVerificationResult {
  final bool success;
  final String orderId;
  final String status;
  final String message;

  const PaymentVerificationResult({
    required this.success,
    required this.orderId,
    required this.status,
    required this.message,
  });
}

/// Result of authentication
class AuthResponse {
  final String token;
  final String userId;
  final String name;
  final String email;

  const AuthResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
  });
}

/// Response from create order API
class CreateOrderResponse {
  final String backendOrderId;
  final String razorpayOrderId;
  final String keyId;
  final int amount;
  final String currency;
  final String receipt;

  CreateOrderResponse({
    required this.backendOrderId,
    required this.razorpayOrderId,
    required this.keyId,
    required this.amount,
    required this.currency,
    required this.receipt,
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrderResponse(
      backendOrderId: json['id'] as String,
      razorpayOrderId: json['razorpay_order_id'] as String,
      keyId: json['key_id'] as String,
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      receipt: json['receipt'] as String,
    );
  }
}