import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../providers/cart_provider.dart';

/// Provider for menu items with loading state
final menuProvider = FutureProvider<List<MenuItem>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return await apiService.getMenu();
});

/// Provider for selected category
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Menu screen displaying available food items.
/// Implements optimistic cart updates with immediate UI feedback.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuProvider);
    final cartState = ref.watch(cartProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Menu'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          // Cart button with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => Navigator.pushNamed(context, '/checkout'),
              ),
              if (cartState.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '${cartState.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: menuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load menu: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(menuProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (menuItems) {
          // Get unique categories
          final categories = <String>{};
          for (final item in menuItems) {
            categories.add(item.category);
          }
          final sortedCategories = categories.toList()..sort();

          // If no category selected, show category cards
          if (selectedCategory == null) {
            return _buildCategoryCards(context, ref, sortedCategories, cartState);
          }

          // Otherwise, show filtered items for selected category
          final filteredItems = menuItems.where((item) => item.category == selectedCategory).toList();
          return _buildItemsList(context, ref, filteredItems, cartState, selectedCategory, sortedCategories);
        },
      ),
      // Floating cart summary
      bottomNavigationBar: cartState.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cartState.itemCount} items',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            cartState.formattedTotal,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/checkout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('View Cart'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryCards(
    BuildContext context,
    WidgetRef ref,
    List<String> categories,
    CartState cartState,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final categoryIcons = {
          'Breakfast': Icons.breakfast_dining,
          'Fast Food': Icons.fastfood,
          'Drinks': Icons.local_drink,
        };

        return GestureDetector(
          onTap: () {
            ref.read(selectedCategoryProvider.notifier).state = category;
          },
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.shade400,
                    Colors.orange.shade600,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    categoryIcons[category] ?? Icons.restaurant,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    WidgetRef ref,
    List<MenuItem> items,
    CartState cartState,
    String selectedCategory,
    List<String> allCategories,
  ) {
    return Column(
      children: [
        // Back button and category title
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  ref.read(selectedCategoryProvider.notifier).state = null;
                },
              ),
              Expanded(
                child: Text(
                  selectedCategory,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildMenuItem(context, ref, items[index], cartState);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuList(
    BuildContext context,
    WidgetRef ref,
    List<MenuItem> menuItems,
    CartState cartState,
  ) {
    // Group items by category
    final categories = <String, List<MenuItem>>{};
    for (final item in menuItems) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories.keys.elementAt(index);
        final items = categories[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            // Items in category
            ...items.map((item) => _buildMenuItem(context, ref, item, cartState)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    WidgetRef ref,
    MenuItem item,
    CartState cartState,
  ) {
    final quantity = cartState.getQuantity(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
            ),
            const SizedBox(width: 12),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.formattedPrice,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            // Add to cart button / quantity control
            Column(
              children: [
                if (quantity == 0)
                  ElevatedButton(
                    onPressed: () {
                      // OPTIMISTIC UPDATE: UI updates immediately
                      ref.read(cartProvider.notifier).addItem(item);
                      _showAddedSnackBar(context, item.name);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text('ADD'),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: () {
                            ref.read(cartProvider.notifier).removeItem(item.id);
                          },
                          color: Colors.orange,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        Text(
                          '$quantity',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () {
                            ref.read(cartProvider.notifier).addItem(item);
                          },
                          color: Colors.orange,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood, color: Colors.orange, size: 32),
    );
  }

  void _showAddedSnackBar(BuildContext context, String itemName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$itemName added to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }
}
