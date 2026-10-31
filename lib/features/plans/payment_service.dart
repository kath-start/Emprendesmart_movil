import '../../core/network/api_client.dart';
import '../../core/utils/decimal.dart';

class YapeSettings {
  final String? qrUrl;
  final String? holderName;
  final String? phone;
  final Map<String, double> prices;

  const YapeSettings({this.qrUrl, this.holderName, this.phone, required this.prices});

  factory YapeSettings.fromJson(Map<String, dynamic> json) {
    final prices = (json['prices'] as Map<String, dynamic>? ?? {});
    return YapeSettings(
      qrUrl: json['yapeQrUrl'] as String?,
      holderName: json['yapeHolderName'] as String?,
      phone: json['yapePhone'] as String?,
      prices: prices.map((plan, price) => MapEntry(plan, parseNum(price).toDouble())),
    );
  }
}

class PlanPayment {
  final String id;
  final String plan;
  final double amount;
  final String payerName;
  final String status;
  final String? rejectedReason;
  final DateTime createdAt;

  const PlanPayment({
    required this.id,
    required this.plan,
    required this.amount,
    required this.payerName,
    required this.status,
    this.rejectedReason,
    required this.createdAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';

  factory PlanPayment.fromJson(Map<String, dynamic> json) => PlanPayment(
    id: json['id'] as String,
    plan: json['plan'] as String,
    amount: parseNum(json['amount']).toDouble(),
    payerName: json['payerName'] as String,
    status: json['status'] as String,
    rejectedReason: json['rejectedReason'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Pago de planes por Yape: el emprendedor ve el QR, yapea y avisa con el nombre de su Yape.
/// El backend lo confirma solo cuando el celular del negocio recibe la notificación de Yape.
class PaymentService {
  final ApiClient _apiClient;

  PaymentService(this._apiClient);

  Future<YapeSettings> getSettings() async {
    final response = await _apiClient.get('/app/payments/settings');
    return YapeSettings.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<PlanPayment>> listMine() async {
    final response = await _apiClient.get('/app/payments');
    final items = response['data'] as List<dynamic>;
    return items.map((item) => PlanPayment.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<PlanPayment> create({required String plan, required String payerName}) async {
    final response = await _apiClient.post('/app/payments', data: {'plan': plan, 'payerName': payerName});
    return PlanPayment.fromJson(response['data'] as Map<String, dynamic>);
  }
}
