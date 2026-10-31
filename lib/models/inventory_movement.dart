import '../core/utils/decimal.dart';

class InventoryMovement {
  final String id;
  final String productId;
  final String type;
  final int quantity;
  final String? note;
  final DateTime occurredAt;

  InventoryMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.note,
    required this.occurredAt,
  });

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    return InventoryMovement(
      id: json['id'] as String,
      productId: json['productId'] as String,
      type: json['type'] as String,
      quantity: parseNum(json['quantity']).toInt(),
      note: json['note'] as String?,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }
}
