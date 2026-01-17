import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item.dart';
import '../providers/cart_provider.dart';
import '../services/logger_service.dart';

class MenuItemCard extends ConsumerWidget {
  final MenuItem item;
  final bool isGrid;

  const MenuItemCard({
    super.key,
    required this.item,
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final quantity = cartState.getQuantity(item.id);
    
    LoggerService.debug('[MenuItemCard] Building card for ${item.name}, current quantity: $quantity');

    return Card(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: isGrid 
        ? _buildGridLayout(context, ref, quantity)
        : _buildListLayout(context, ref, quantity),
    );
  }

  Widget _buildGridLayout(BuildContext context, WidgetRef ref, int quantity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         AspectRatio(
           aspectRatio: 16/9,
           child: item.imageUrl != null
               ? (item.imageUrl!.startsWith('http')
                   ? Image.network(
                       item.imageUrl!,
                       fit: BoxFit.cover,
                       errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                     )
                   : Image.asset(
                       item.imageUrl!,
                       fit: BoxFit.cover,
                       errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                     ))
               : _buildPlaceholderImage(),
         ),
         Padding(
           padding: const EdgeInsets.all(12),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Expanded(
                     child: Text(
                       item.name,
                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 4),
               Text(
                 item.description,
                 style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                 maxLines: 2,
                 overflow: TextOverflow.ellipsis,
               ),
               const SizedBox(height: 12),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(
                     item.formattedPrice,
                     style: const TextStyle(
                       fontWeight: FontWeight.bold,
                       fontSize: 16,
                       color: Colors.orange,
                     ),
                   ),
                   _buildAddButton(context, ref, quantity),
                 ],
               ),
             ],
           ),
         ),
      ],
    );
  }

  Widget _buildListLayout(BuildContext context, WidgetRef ref, int quantity) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 100,
              height: 100,
           child: item.imageUrl != null
               ? (item.imageUrl!.startsWith('http') 
                   ? Image.network(
                       item.imageUrl!,
                       fit: BoxFit.cover,
                       errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                     )
                   : Image.asset(
                       item.imageUrl!,
                       fit: BoxFit.cover,
                       errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                     ))
               : _buildPlaceholderImage(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.formattedPrice,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange,
                      ),
                    ),
                    _buildAddButton(context, ref, quantity),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref, int quantity) {
     LoggerService.debug('[MenuItemCard] _buildAddButton called for ${item.name}, quantity: $quantity');
     
     if (quantity == 0) {
       return SizedBox(
         height: 36,
         child: ElevatedButton(
           onPressed: () {
             LoggerService.info('[MenuItemCard] ADD button pressed for ${item.name} (id: ${item.id})');
             LoggerService.debug('[MenuItemCard] Current cart state before add: ${ref.read(cartProvider).itemCount} items');
             
             ref.read(cartProvider.notifier).addItem(item);
             
             LoggerService.info('[MenuItemCard] addItem() called, cart should update in-place');
             
             // Show a brief snackbar confirmation
             ScaffoldMessenger.of(context).clearSnackBars();
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('${item.name} added to cart'),
                 duration: const Duration(milliseconds: 800),
                 behavior: SnackBarBehavior.floating,
                 backgroundColor: Colors.green.shade700,
               ),
             );
           },
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.orange,
             foregroundColor: Colors.black,
             elevation: 0,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
             padding: const EdgeInsets.symmetric(horizontal: 16),
           ),
           child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold)),
         ),
       );
     }
     
     LoggerService.debug('[MenuItemCard] Showing quantity counter for ${item.name}: $quantity');
     
     return Container(
       decoration: BoxDecoration(
         color: Colors.grey.shade900,
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.white24),
       ),
       height: 36,
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           IconButton(
             icon: const Icon(Icons.remove, size: 16, color: Colors.white),
             onPressed: () {
               LoggerService.info('[MenuItemCard] REMOVE button pressed for ${item.name}');
               ref.read(cartProvider.notifier).removeItem(item.id);
             },
             padding: EdgeInsets.zero,
             constraints: const BoxConstraints(minWidth: 32),
           ),
           Text(
             '$quantity',
             style: const TextStyle(
               fontWeight: FontWeight.bold,
               color: Colors.orange,
             ),
           ),
           IconButton(
             icon: const Icon(Icons.add, size: 16, color: Colors.white),
             onPressed: () {
               LoggerService.info('[MenuItemCard] INCREMENT button pressed for ${item.name}');
               ref.read(cartProvider.notifier).addItem(item);
             },
              padding: EdgeInsets.zero,
             constraints: const BoxConstraints(minWidth: 32),
           ),
         ],
       ),
     );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(Icons.restaurant_menu, color: Colors.white10, size: 32),
      ),
    );
  }
}
