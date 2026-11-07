import '../core/utils/decimal.dart';

class SaleItem {
  final String id;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  /// Solo viene poblado cuando la venta se obtiene por id (ver `SaleService.getById`);
  /// el listado no incluye el nombre del producto.
  final String? productName;

  SaleItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.productName,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return SaleItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      quantity: parseNum(json['quantity']).toInt(),
      unitPrice: parseNum(json['unitPrice']).toDouble(),
      subtotal: parseNum(json['subtotal']).toDouble(),
      productName: product?['name'] as String?,
    );
  }
}

class Sale {
  final String id;
  final String businessId;
  final DateTime soldAt;
  final double total;
  final String? notes;
  final List<SaleItem> items;

  /// efectivo, yape, plin o tarjeta (null en ventas antiguas).
  final String? paymentMethod;

  /// Quién registró la venta (el dueño o alguien de su equipo).
  final String? sellerName;

  Sale({
    required this.id,
    required this.businessId,
    required this.soldAt,
    required this.total,
    this.notes,
    required this.items,
    this.paymentMethod,
    this.sellerName,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final seller = json['seller'] as Map<String, dynamic>?;
    return Sale(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      soldAt: DateTime.parse(json['soldAt'] as String),
      total: parseNum(json['total']).toDouble(),
      notes: json['notes'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      items: rawItems.map((item) => SaleItem.fromJson(item as Map<String, dynamic>)).toList(),
      sellerName: seller == null ? null : '${seller['firstName']} ${seller['lastName']}'.trim(),
    );
  }
}
