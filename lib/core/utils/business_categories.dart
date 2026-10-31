import 'package:flutter/material.dart';

/// Tipos de negocio sugeridos al crear o editar un negocio. La categoría se guarda como texto
/// libre, así que "Otro" permite escribir cualquiera que no esté en la lista.
class BusinessCategory {
  final String name;
  final IconData icon;
  final Color color;

  const BusinessCategory(this.name, this.icon, this.color);
}

class BusinessCategories {
  BusinessCategories._();

  static const all = [
    BusinessCategory('Comida y bebidas', Icons.restaurant_rounded, Color(0xFFF97316)),
    BusinessCategory('Bodega y abarrotes', Icons.local_grocery_store_rounded, Color(0xFF16A34A)),
    BusinessCategory('Ropa y moda', Icons.checkroom_rounded, Color(0xFFDB2777)),
    BusinessCategory('Belleza y cuidado', Icons.spa_rounded, Color(0xFFA855F7)),
    BusinessCategory('Tecnología', Icons.devices_rounded, Color(0xFF2563EB)),
    BusinessCategory('Hogar y decoración', Icons.chair_rounded, Color(0xFFB45309)),
    BusinessCategory('Salud y bienestar', Icons.health_and_safety_rounded, Color(0xFF0D9488)),
    BusinessCategory('Artesanía', Icons.palette_rounded, Color(0xFFE11D48)),
    BusinessCategory('Servicios', Icons.handyman_rounded, Color(0xFF475569)),
    BusinessCategory('Educación', Icons.school_rounded, Color(0xFF4F46E5)),
    BusinessCategory('Mascotas', Icons.pets_rounded, Color(0xFF92400E)),
  ];

  static const other = BusinessCategory('Otro', Icons.category_rounded, Color(0xFF64748B));

  /// Categoría de la lista con ese nombre (sin distinguir mayúsculas), o `null` si es personalizada.
  static BusinessCategory? find(String name) {
    final normalized = name.trim().toLowerCase();
    for (final category in all) {
      if (category.name.toLowerCase() == normalized) return category;
    }
    return null;
  }

  /// Ícono para mostrar cualquier categoría; las personalizadas usan el genérico.
  static BusinessCategory of(String name) => find(name) ?? other;
}
