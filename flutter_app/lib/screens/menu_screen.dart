import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../providers/cart_provider.dart';
import '../widgets/video_header.dart';
import '../widgets/menu_item_card.dart';
import '../services/logger_service.dart';


/// Provider for menu items with loading state
final menuProvider = FutureProvider<List<MenuItem>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return await apiService.getMenu();
});


/// Provider for selected category
final selectedCategoryProvider = StateProvider<String?>((ref) => null);


/// Provider for expanded categories (showing all items)
final expandedCategoriesProvider = StateProvider<Set<String>>((ref) => {});


/// Menu screen displaying available food items.
/// Implements optimistic cart updates with immediate UI feedback.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuProvider);
    final cartState = ref.watch(cartProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final expandedCategories = ref.watch(expandedCategoriesProvider);

    // Log build to debug rebuild issues
    LoggerService.debug('MenuScreen build called. Cart items: ${cartState.itemCount}');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Raju Gari Kitchen', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Cart button with badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/cart'),
                ),
                if (cartState.itemCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${cartState.itemCount}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: menuAsync.when(
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


              return _buildCategoriesWithItems(
                context,
                ref,
                menuItems,
                sortedCategories,
                cartState,
                expandedCategories,
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: cartState.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: const Border(top: BorderSide(color: Colors.white10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${cartState.itemCount} items',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                              Text(
                                cartState.formattedTotal,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/cart'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'View Cart',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }


  Widget _buildCategoriesWithItems(
    BuildContext context,
    WidgetRef ref,
    List<MenuItem> allItems,
    List<String> categories,
    CartState cartState,
    Set<String> expandedCategories,
  ) {
    // Calculate layout parameters once
    final width = MediaQuery.of(context).size.width;
    // Max constraints is 1200, so use that as effective width if larger
    final effectiveWidth = width > 1200 ? 1200 : width;
    
    int crossAxisCount = effectiveWidth > 900 ? 3 : (effectiveWidth > 600 ? 2 : 1);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length + 1, // +1 for video section
      itemBuilder: (context, index) {
        // Banner section at index 0
        if (index == 0) {
          return _buildBannerSection(context);
        }

        // Adjust category index
        final categoryIndex = index - 1;
        final category = categories[categoryIndex];
        final categoryItems = allItems.where((item) => item.category == category).toList();
        final isExpanded = expandedCategories.contains(category);
        final displayItems = isExpanded ? categoryItems : categoryItems.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: Colors.orange.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Icon(
                      _getCategoryIcon(category),
                      size: 24,
                      color: Colors.orange,
                    ),
                   ),
                  const SizedBox(width: 12),
                  Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  if (categoryItems.length > 3)
                    TextButton(
                      onPressed: () {
                         final notifier = ref.read(expandedCategoriesProvider.notifier);
                         if (isExpanded) {
                           notifier.state = expandedCategories..remove(category);
                         } else {
                           notifier.state = {...expandedCategories, category};
                         }
                      },
                      child: Text(isExpanded ? 'Show Less' : 'See All'),
                    ),
                ],
              ),
            ),
            
            // Items Layout
            if (crossAxisCount == 1)
               Column(
                 children: displayItems.map((item) => MenuItemCard(
                   key: ValueKey(item.id),
                   item: item, 
                   isGrid: false
                 )).toList(),
               )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: displayItems.map((item) {
                   return SizedBox(
                     width: (effectiveWidth - 32 - (16 * (crossAxisCount - 1))) / crossAxisCount, // 32 for padding
                     child: MenuItemCard(
                       key: ValueKey(item.id),
                       item: item, 
                       isGrid: true
                     ),
                   );
                }).toList(),
              ),

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }


  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Breakfast':
        return Icons.breakfast_dining;
      case 'Fast Food':
        return Icons.fastfood;
      case 'Drinks':
        return Icons.local_drink;
      default:
        return Icons.restaurant;
    }
  }


  Widget _buildBannerSection(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 24),
      // Temporarily replacing VideoHeader to debug black screen issue
      // If this fixes it, the video player or codec is the issue.
      child: VideoHeader(
        videoAsset: 'assets/videos/promo.mp4',
        height: 350,
      ),
    );
  }
}
