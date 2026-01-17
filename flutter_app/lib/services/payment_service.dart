import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

export 'package:razorpay_flutter/razorpay_flutter.dart';

/// Payment service handling Razorpay integration
class PaymentService {
  late Razorpay _razorpay;
  final ApiService apiService;
  
  // Callbacks
  Function(PaymentSuccessResponse)? _onSuccess;
  Function(PaymentFailureResponse)? _onFailure;
  
  // Current order context
  String? currentOrderId;

  PaymentService({required this.apiService}) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    LoggerService.info('[PaymentService] Initialized');
  }

  /// Start payment flow
  Future<void> startPayment({
    required CreateOrderResponse orderDetails,
    required String userPhone,
    required String userEmail,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
  }) async {
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    currentOrderId = orderDetails.backendOrderId;

    var options = {
      'key': orderDetails.keyId,
      'amount': orderDetails.amount, // in the smallest currency sub-unit
      'name': 'Raju Gari Kitchen',
      'description': 'Order #${orderDetails.receipt}',
      'order_id': orderDetails.razorpayOrderId,
      'prefill': {
        'contact': userPhone,
        'email': userEmail
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      LoggerService.info('[PaymentService] Opening Razorpay for Order ${orderDetails.backendOrderId}');
      _razorpay.open(options);
    } catch (e) {
      LoggerService.error('[PaymentService] Error starting payment', e);
      _onFailure?.call(PaymentFailureResponse(
        Razorpay.PAYMENT_CANCELLED, 
        'Failed to start payment: $e',
        null
      ));
    }
  }
  
  /// Verify payment with backend
  Future<PaymentVerificationResult> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    LoggerService.info('[PaymentService] Verifying payment for Order $orderId');
    return await apiService.verifyPayment(
      orderId: orderId,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    LoggerService.info('[PaymentService] Payment Success: ${response.paymentId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    LoggerService.error('[PaymentService] Payment Failure: ${response.code} - ${response.message}');
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    LoggerService.info('[PaymentService] External Wallet: ${response.walletName}');
    // Treat as success or handle specifically if needed
  }

  void dispose() {
    _razorpay.clear();
    LoggerService.info('[PaymentService] Disposed');
  }
}
