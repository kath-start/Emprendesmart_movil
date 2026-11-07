enum YapePaymentStatus { pending, linked, ignored }

/// Un cobro recibido por Yape o Plin, leído de la notificación del teléfono.
///
/// Vive solo en el dispositivo; al asignarle productos se registra una venta con su
/// método de pago y el cobro en sus notas.
class YapePayment {
  final String id;

  /// `yape` o `plin`.
  final String method;
  final String? senderName;
  final double? amount;
  final String message;
  final DateTime receivedAt;
  final YapePaymentStatus status;

  /// Venta a la que se asignó el cobro (cuando [status] es `linked`).
  final String? saleId;
  final String? businessId;

  const YapePayment({
    required this.id,
    required this.message,
    required this.receivedAt,
    this.method = 'yape',
    this.senderName,
    this.amount,
    this.status = YapePaymentStatus.pending,
    this.saleId,
    this.businessId,
  });

  bool get isPending => status == YapePaymentStatus.pending;

  bool get isPlin => method == 'plin';

  String get methodLabel => isPlin ? 'Plin' : 'Yape';

  String get displaySender => senderName ?? 'Pago con $methodLabel';

  /// Texto que se guarda en las notas de la venta.
  String get saleNote {
    final parts = ['Cobro $methodLabel', ?senderName, if (amount != null) 'S/ ${amount!.toStringAsFixed(2)}'];
    return parts.join(' · ');
  }

  /// Crea el cobro a partir de lo que guardó el lector nativo de Android.
  factory YapePayment.fromNotification({
    required String id,
    required String title,
    required String text,
    required DateTime postedAt,
    String source = 'yape',
  }) {
    final message = text.isNotEmpty ? text : title;
    return YapePayment(
      id: id,
      method: source == 'plin' ? 'plin' : 'yape',
      message: message,
      receivedAt: postedAt,
      amount: parseYapeAmount(message) ?? parseYapeAmount(title),
      senderName: parseYapeSender(message) ?? parseYapeSender('$title $text'),
    );
  }

  YapePayment copyWith({YapePaymentStatus? status, String? saleId, String? businessId}) => YapePayment(
    id: id,
    method: method,
    message: message,
    receivedAt: receivedAt,
    senderName: senderName,
    amount: amount,
    status: status ?? this.status,
    saleId: saleId ?? this.saleId,
    businessId: businessId ?? this.businessId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'message': message,
    'receivedAt': receivedAt.toIso8601String(),
    'senderName': senderName,
    'amount': amount,
    'status': status.name,
    'saleId': saleId,
    'businessId': businessId,
  };

  factory YapePayment.fromJson(Map<String, dynamic> json) => YapePayment(
    id: json['id'] as String,
    method: json['method'] as String? ?? 'yape',
    message: json['message'] as String,
    receivedAt: DateTime.parse(json['receivedAt'] as String),
    senderName: json['senderName'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    status: YapePaymentStatus.values.asNameMap()[json['status']] ?? YapePaymentStatus.pending,
    saleId: json['saleId'] as String?,
    businessId: json['businessId'] as String?,
  );
}

/// Monto de "… te envió un pago por S/ 19.90" (acepta "S/." y coma decimal).
double? parseYapeAmount(String text) {
  final match = RegExp(
    r'S/\.?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
  ).firstMatch(text);
  if (match == null) return null;
  var raw = match.group(1)!;
  // "1,250.00" → separador de miles; "19,90" → coma decimal.
  raw = raw.contains('.') ? raw.replaceAll(',', '') : raw.replaceAll(',', '.');
  if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(raw)) raw = raw.replaceAll('.', '');
  return double.tryParse(raw);
}

/// Nombre de quien pagó. Formatos conocidos:
/// - Yape: "Yape! Juan P. Perez te envió un pago por S/ 19.90"
/// - Plin: "Juan Perez te envió S/ 20.00 por Plin", "Recibiste un Plin de Juan Perez por S/ 20.00",
///   "Recibiste S/ 20.00 de Juan Perez"
String? parseYapeSender(String text) {
  final clean = text.trim();
  final sentBy = RegExp(r'^(?:.*?:\s*)?(?:yape!?\s*)?(.+?)\s+te\s+envi[oó]', caseSensitive: false).firstMatch(clean);
  final receivedFrom = RegExp(
    r'recibiste\b.*?\bde\s+(.+?)(?:\s+por\b|\s+con\b|\s*[.,!]|\s*$)',
    caseSensitive: false,
  ).firstMatch(clean);
  final name = (sentBy ?? receivedFrom)?.group(1)?.trim();
  if (name == null || name.isEmpty || name.contains('S/')) return null;
  return name;
}
