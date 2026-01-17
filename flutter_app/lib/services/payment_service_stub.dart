class PaymentSuccessResponse {
 final String? paymentId;
 final String? orderId;
 final String? signature;


 PaymentSuccessResponse({this.paymentId, this.orderId, this.signature});
}


class PaymentFailureResponse {
 final int? code;
 final String? message;


 PaymentFailureResponse({this.code, this.message});
}


class ExternalWalletResponse {
 final String? walletName;


 ExternalWalletResponse({this.walletName});
}


class Razorpay {
 static const EVENT_PAYMENT_SUCCESS = 'payment.success';
 static const EVENT_PAYMENT_ERROR = 'payment.error';
 static const EVENT_EXTERNAL_WALLET = 'payment.external_wallet';


 void on(String event, Function callback) {}
 void open(Map<String, dynamic> options) {
   throw UnsupportedError('Razorpay is not supported on web');
 }
 void clear() {}
}




