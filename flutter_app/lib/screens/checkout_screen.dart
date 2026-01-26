import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../services/payment_service.dart';
import '../services/api_service.dart';
import '../models/order.dart';

/// Checkout screen handling order creation and payment flow.
/// Implements proper Razorpay integration with backend verification.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late PaymentService _paymentService;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final apiService = ref.read(apiServiceProvider);
    _paymentService = PaymentService(apiService: apiService);
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  /// Initiate checkout process
  Future<void> _startCheckout() async {
    final cartState = ref.read(cartProvider);
    if (cartState.isEmpty) {
      _showSnackBar('Cart is empty', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Step 1: Create order on backend
      final apiService = ref.read(apiServiceProvider);
      final authState = ref.read(authProvider);
      final orderResponse = await apiService.createOrder(cartState.items);

      // Step 2: Start Razorpay payment flow
      await _paymentService.startPayment(
        orderDetails: orderResponse,
        userPhone: authState.phoneNumber ?? '',
        userEmail: authState.email ?? '',
        onSuccess: _handlePaymentSuccess,
        onFailure: _handlePaymentFailure,
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Failed to initiate checkout: $e';
      });
      _showSnackBar(_error!, isError: true);
    }

  }

  /// Handle Razorpay success callback.
  /// CRITICAL: Do NOT assume payment is successful here.
  /// Must verify with backend using signature.
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('Payment success callback - verifying with backend...');

    try {
      // CRITICAL: Verify payment with backend
      final result = await _paymentService.verifyPayment(
        orderId: _paymentService.currentOrderId!,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );

      if (result.success) {
        // Payment confirmed by backend - clear cart and show success
        ref.read(cartProvider.notifier).clearCart();
        
        setState(() {
          _isProcessing = false;
        });

        _showSnackBar('Payment successful! Order confirmed.', isError: false);
        
        // Navigate to order confirmation
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            '/order-confirmation',
            arguments: result.orderId,
          );
        }
      } else {
        // Backend rejected payment
        setState(() {
          _error = result.message;
          _isProcessing = false;
        });
        _showSnackBar('Payment verification failed: ${result.message}', isError: true);
      }
    } catch (e) {
      setState(() {
        _error = 'Payment verification failed. Please contact support.';
        _isProcessing = false;
      });
      _showSnackBar(_error!, isError: true);
    }
  }

  /// Handle payment failure
  void _handlePaymentFailure(PaymentFailureResponse response) {
    debugPrint('Payment failed: ${response.code} - ${response.message}');

    setState(() {
      _error = response.message ?? 'Payment failed. Please try again.';
      _isProcessing = false;
    });

    _showSnackBar(_error!, isError: true);
  }

  /// Show snackbar message
  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: cartState.isEmpty
          ? const Center(
              child: Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Payment Options',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Payment Methods Placeholder
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.credit_card, color: Colors.orange),
                          title: const Text('Credit/Debit Card', style: TextStyle(color: Colors.white)),
                          trailing: Radio(value: true, groupValue: true, onChanged: (_) {}, activeColor: Colors.orange),
                        ),
                        const Divider(color: Colors.white10),
                        ListTile(
                          leading: const Icon(Icons.payment, color: Colors.orange),
                          title: const Text('UPI', style: TextStyle(color: Colors.white)),
                          trailing: Radio(value: false, groupValue: true, onChanged: (_) {}, activeColor: Colors.orange),
                        ),
                        const Divider(color: Colors.white10),
                         ListTile(
                          leading: const Icon(Icons.money, color: Colors.orange),
                          title: const Text('Cash on Delivery', style: TextStyle(color: Colors.white)),
                          trailing: Radio(value: false, groupValue: true, onChanged: (_) {}, activeColor: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                   
                   // Order Summary Brief
                   Text(
                     'Order Summary',
                     style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                   ),
                   const SizedBox(height: 8),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const Text(
                         'Total Amount to Pay',
                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                       ),
                       Text(
                         cartState.formattedTotal,
                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                       ),
                     ],
                   ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Added to prevent column from taking full height
                      children: [
                        // Order summary
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total (${cartState.itemCount} items)',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              cartState.formattedTotal,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Pay button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _startCheckout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Pay Now',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
      );
  }
}