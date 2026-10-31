import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/product.dart';

/// Foto del producto con un marcador de posición si no tiene o si no carga.
class ProductImage extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;

  const ProductImage({super.key, required this.url, this.size = 72, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFFEAF1FD),
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined, color: AppTheme.primary.withValues(alpha: 0.6), size: size * 0.42),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url!.isEmpty
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
              ),
      ),
    );
  }
}

enum StockLevel { inStock, low, out }

StockLevel stockLevelOf(Product product) {
  if (product.isOutOfStock) return StockLevel.out;
  if (product.isLowStock) return StockLevel.low;
  return StockLevel.inStock;
}

/// Etiqueta de color: En stock (verde), Stock bajo (naranja), Sin stock (rojo).
class StockBadge extends StatelessWidget {
  final StockLevel level;

  const StockBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (level) {
      StockLevel.inStock => ('En stock', const Color(0xFF16A34A), Icons.circle),
      StockLevel.low => ('Stock bajo', const Color(0xFFF59E0B), Icons.error_rounded),
      StockLevel.out => ('Sin stock', const Color(0xFFEF4444), Icons.error_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: level == StockLevel.inStock ? 10 : 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
