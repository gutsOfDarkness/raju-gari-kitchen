import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';

/// Cart state containing items and loading/error status
class CartState {
  final List<CartItem> items;
  final bool isLoading;
  final String? error;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  /// Total cart amount in paisa
  int get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);

  /// Formatted total string
  String get formattedTotal => '₹${(totalAmount / 100.0).toStringAsFixed(2)}';

  /// Total item count
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Check if cart is empty
  bool get isEmpty => items.isEmpty;

  /// Get quantity for a specific menu item
  int getQuantity(String menuItemId) {
    try {
      final item = items.firstWhere((e) => e.menuItem.id == menuItemId);
      return item.quantity;
    } catch (e) {
      return 0;
    }
  }

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Cart controller using Riverpod's Notifier pattern.
/// Implements OPTIMISTIC UPDATES for smooth UX:
/// 1. Update UI immediately on user action
/// 2. Fire API call in background
/// 3. Rollback state if API fails
class CartNotifier extends Notifier<CartState> {
  // Store previous state for rollback on API failure
  CartState? _previousState;

  @override
  CartState build() {
    return const CartState();
  }

  /// Add item to cart with OPTIMISTIC UPDATE
  /// UI updates immediately, then syncs with server
  Future<void> addItem(MenuItem menuItem, {int quantity = 1}) async {
    // Save current state for potential rollback
    _previousState = state;

    // OPTIMISTIC UPDATE: Update UI immediately
    final currentItems = List<CartItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.menuItem.id == menuItem.id,
    );

    if (existingIndex >= 0) {
      // Item exists, increment quantity
      final existing = currentItems[existingIndex];
      currentItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      // New item, add to cart
      currentItems.add(CartItem(menuItem: menuItem, quantity: quantity));
    }

    // Update state optimistically
    state = state.copyWith(items: currentItems, error: null);

    // In a real app, you might sync with server here
    // For local cart, no server sync needed until checkout
    // If server sync was required:
    // try {
    //   await _syncCartWithServer(currentItems);
    // } catch (e) {
    //   // ROLLBACK on failure
    //   state = _previousState!;
    //   state = state.copyWith(error: 'Failed to add item. Please try again.');
    // }
  }

  /// Remove one quantity of item from cart with OPTIMISTIC UPDATE
  Future<void> removeItem(String menuItemId) async {
    _previousState = state;

    final currentItems = List<CartItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.menuItem.id == menuItemId,
    );

    if (existingIndex < 0) return;

    final existing = currentItems[existingIndex];
    if (existing.quantity > 1) {
      // Decrement quantity
      currentItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity - 1,
      );
    } else {
      // Remove item completely
      currentItems.removeAt(existingIndex);
    }

    state = state.copyWith(items: currentItems, error: null);
  }

  /// Remove item completely from cart
  Future<void> removeItemCompletely(String menuItemId) async {
    _previousState = state;

    final currentItems = List<CartItem>.from(state.items);
    currentItems.removeWhere((item) => item.menuItem.id == menuItemId);

    state = state.copyWith(items: currentItems, error: null);
  }

  /// Update item quantity directly
  Future<void> updateQuantity(String menuItemId, int quantity) async {
    if (quantity <= 0) {
      await removeItemCompletely(menuItemId);
      return;
    }

    _previousState = state;

    final currentItems = List<CartItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.menuItem.id == menuItemId,
    );

    if (existingIndex >= 0) {
      currentItems[existingIndex] = currentItems[existingIndex].copyWith(
        quantity: quantity,
      );
      state = state.copyWith(items: currentItems, error: null);
    }
  }

  /// Clear entire cart
  void clearCart() {
    state = const CartState();
  }

  /// Set loading state
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Set error state
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  /// Rollback to previous state (used when API fails)
  void rollback(String errorMessage) {
    if (_previousState != null) {
      state = _previousState!.copyWith(error: errorMessage);
    }
  }
}

/// Provider for cart state
final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});

/// Provider for API service
final apiServiceProvider = Provider<ApiService>((ref) {
  // Allow overriding API URL via build arguments/environment
  const envUrl = String.fromEnvironment('API_URL');
  if (envUrl.isNotEmpty) {
    return ApiService(baseUrl: envUrl);
  }

  // Get the host from the current window location
  // This allows the app to work on both desktop (localhost) and mobile (network IP)
  final host = html.window.location.hostname ?? 'localhost';
  final baseUrl = 'http://$host:8080';
  return ApiService(baseUrl: baseUrl);
});
