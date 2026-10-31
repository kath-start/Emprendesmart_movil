import '../core/utils/decimal.dart';

class Product {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String? category;
  final String? sku;
  final String? imageUrl;
  final String? unit;
  final double price;
  final double? cost;
  final int stock;
  final int lowStockThreshold;
  final String status;

  Product({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.category,
    this.sku,
    this.imageUrl,
    this.unit,
    required this.price,
    this.cost,
    required this.stock,
    required this.lowStockThreshold,
    required this.status,
  });

  bool get isLowStock => stock <= lowStockThreshold;
  bool get isOutOfStock => stock <= 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      sku: json['sku'] as String?,
      imageUrl: json['imageUrl'] as String?,
      unit: json['unit'] as String?,
      price: parseNum(json['price']).toDouble(),
      cost: json['cost'] == null ? null : parseNum(json['cost']).toDouble(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 0,
      status: json['status'] as String,
    );
  }
}
