import 'package:flutter/material.dart';
import '../models/order.dart';
import 'api_service.dart';


class PaymentService {
 final ApiService _apiService;
  String? get currentOrderId => _currentOrderId;
 String? _currentOrderId;


 PaymentService({required ApiService apiService}) : _apiService = apiService;


 Future<CreateOrderResponse> startPayment({
   required CreateOrderResponse orderDetails,
   required String userPhone,
   String? userEmail,
   Function(dynamic)? onSuccess,
   Function(dynamic)? onFailure,
   Function(dynamic)? onExternalWallet,
 }) async {
   _currentOrderId = orderDetails.orderId;
  
   debugPrint('[PaymentService Web] Payment not supported on web platform');
   debugPrint('[PaymentService Web] Order ID: ${orderDetails.orderId}');
  
   if (onFailure != null) {
     onFailure({'message': 'Payment not supported on web platform'});
   }
  
   return orderDetails;
 }


 Future<PaymentVerificationResult> verifyPayment({
   required String orderId,
   required String razorpayOrderId,
   required String razorpayPaymentId,
   required String razorpaySignature,
 }) async {
   return await _apiService.verifyPayment(
     orderId: orderId,
     razorpayOrderId: razorpayOrderId,
     razorpayPaymentId: razorpayPaymentId,
     razorpaySignature: razorpaySignature,
   );
 }


 String? getCurrentOrderId() => _currentOrderId;


 void dispose() {
 }
}




