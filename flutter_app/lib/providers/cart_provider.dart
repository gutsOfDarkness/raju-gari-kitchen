import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

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
  String get formattedTotal => 'Rs.${(totalAmount / 100.0).toStringAsFixed(2)}';

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
  
  /// Debug string representation
  String toDebugString() {
    final itemsStr = items.map((i) => '${i.menuItem.name}(${i.quantity})').join(', ');
    return 'CartState{items: [$itemsStr], total: $formattedTotal, count: $itemCount}';
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
    LoggerService.debug('[CartNotifier] build() called, initializing empty cart');
    return const CartState();
  }

  /// Add item to cart with OPTIMISTIC UPDATE
  /// UI updates immediately, then syncs with server
  Future<void> addItem(MenuItem menuItem, {int quantity = 1}) async {
    LoggerService.info('[CartNotifier] addItem() called for ${menuItem.name} (id: ${menuItem.id}), quantity: $quantity');
    LoggerService.debug('[CartNotifier] Current state before add: ${state.toDebugString()}');
    
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
      final newQuantity = existing.quantity + quantity;
      currentItems[existingIndex] = existing.copyWith(quantity: newQuantity);
      LoggerService.info('[CartNotifier] Incremented existing item. ${menuItem.name}: ${existing.quantity} -> $newQuantity');
    } else {
      // New item, add to cart
      currentItems.add(CartItem(menuItem: menuItem, quantity: quantity));
      LoggerService.info('[CartNotifier] Added new item to cart: ${menuItem.name}');
    }

    // Update state optimistically
    state = state.copyWith(items: currentItems, error: null);
    LoggerService.info('[CartNotifier] State updated. New state: ${state.toDebugString()}');
  }

  /// Remove one quantity of item from cart with OPTIMISTIC UPDATE
  Future<void> removeItem(String menuItemId) async {
    LoggerService.info('[CartNotifier] removeItem() called for id: $menuItemId');
    LoggerService.debug('[CartNotifier] Current state before remove: ${state.toDebugString()}');
    
    _previousState = state;

    final currentItems = List<CartItem>.from(state.items);
    final existingIndex = currentItems.indexWhere(
      (item) => item.menuItem.id == menuItemId,
    );

    if (existingIndex < 0) {
      LoggerService.warning('[CartNotifier] Item not found in cart, nothing to remove');
      return;
    }

    final existing = currentItems[existingIndex];
    if (existing.quantity > 1) {
      // Decrement quantity
      final newQuantity = existing.quantity - 1;
      currentItems[existingIndex] = existing.copyWith(quantity: newQuantity);
      LoggerService.info('[CartNotifier] Decremented item. ${existing.menuItem.name}: ${existing.quantity} -> $newQuantity');
    } else {
      // Remove item completely
      currentItems.removeAt(existingIndex);
      LoggerService.info('[CartNotifier] Removed item completely: ${existing.menuItem.name}');
    }

    state = state.copyWith(items: currentItems, error: null);
    LoggerService.info('[CartNotifier] State updated. New state: ${state.toDebugString()}');
  }

  /// Remove item completely from cart
  Future<void> removeItemCompletely(String menuItemId) async {
    LoggerService.info('[CartNotifier] removeItemCompletely() called for id: $menuItemId');
    _previousState = state;

    final currentItems = List<CartItem>.from(state.items);
    final removedItem = currentItems.where((item) => item.menuItem.id == menuItemId).firstOrNull;
    currentItems.removeWhere((item) => item.menuItem.id == menuItemId);

    if (removedItem != null) {
      LoggerService.info('[CartNotifier] Removed item completely: ${removedItem.menuItem.name}');
    }
    
    state = state.copyWith(items: currentItems, error: null);
    LoggerService.debug('[CartNotifier] State updated. New state: ${state.toDebugString()}');
  }

  /// Update item quantity directly
  Future<void> updateQuantity(String menuItemId, int quantity) async {
    LoggerService.info('[CartNotifier] updateQuantity() called for id: $menuItemId, new quantity: $quantity');
    
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
      final existing = currentItems[existingIndex];
      currentItems[existingIndex] = existing.copyWith(quantity: quantity);
      state = state.copyWith(items: currentItems, error: null);
      LoggerService.info('[CartNotifier] Updated quantity for ${existing.menuItem.name} to $quantity');
    }
  }

  /// Clear entire cart
  void clearCart() {
    LoggerService.info('[CartNotifier] clearCart() called');
    state = const CartState();
    LoggerService.debug('[CartNotifier] Cart cleared');
  }

  /// Set loading state
  void setLoading(bool loading) {
    LoggerService.debug('[CartNotifier] setLoading($loading)');
    state = state.copyWith(isLoading: loading);
  }

  /// Set error state
  void setError(String? error) {
    LoggerService.error('[CartNotifier] setError: $error');
    state = state.copyWith(error: error);
  }

  /// Rollback to previous state (used when API fails)
  void rollback(String errorMessage) {
    LoggerService.warning('[CartNotifier] Rolling back state due to: $errorMessage');
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
    LoggerService.info('[ApiService] Using environment API_URL: $envUrl');
    return ApiService(baseUrl: envUrl);
  }

  // Get the host from the current window location
  final host = html.window.location.hostname ?? 'localhost';
  final baseUrl = 'http://$host:8080';
  LoggerService.info('[ApiService] Using dynamic API URL: $baseUrl');
  return ApiService(baseUrl: baseUrl);
});
