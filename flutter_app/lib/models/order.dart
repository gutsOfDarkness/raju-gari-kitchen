/// Order status enum matching backend status
enum OrderStatus {
  pending('PENDING'),
  awaitingPayment('AWAITING_PAYMENT'),
  paymentFailed('PAYMENT_FAILED'),
  paid('PAID'),
  accepted('ACCEPTED'),
  delivered('DELIVERED');

  final String value;
  const OrderStatus(this.value);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// Order model representing a customer order
class Order {
  final String id;
  final String userId;
  final OrderStatus status;
  final int totalAmount; // Amount in paisa
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final List<OrderItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.userId,
    required this.status,
    required this.totalAmount,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total formatted in rupees
  String get formattedTotal => '₹${(totalAmount / 100.0).toStringAsFixed(2)}';

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: OrderStatus.fromString(json['status'] as String),
      totalAmount: json['total_amount'] as int,
      razorpayOrderId: json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Order item model
class OrderItem {
  final String id;
  final String orderId;
  final String menuItemId;
  final String name;
  final int price;
  final int quantity;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  int get subtotal => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      menuItemId: json['menu_item_id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      quantity: json['quantity'] as int,
    );
  }
}

/// Response from order creation (for Razorpay checkout)
class CreateOrderResponse {
  final String id;
  final String razorpayOrderId;
  final String keyId;
  final int amount;
  final String currency;
  final String receipt;
  final String name;
  final String description;

  const CreateOrderResponse({
    required this.id,
    required this.razorpayOrderId,
    required this.keyId,
    required this.amount,
    required this.currency,
    required this.receipt,
    required this.name,
    required this.description,
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrderResponse(
      id: json['id'] as String,
      razorpayOrderId: json['razorpay_order_id'] as String,
      keyId: json['key_id'] as String,
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      receipt: json['receipt'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }
}
