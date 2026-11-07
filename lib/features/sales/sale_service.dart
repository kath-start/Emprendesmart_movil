import '../../core/network/api_client.dart';
import '../../models/alert.dart';
import '../../models/sale.dart';
import '../../models/sales_insights.dart';
import '../../models/sales_summary.dart';

class CreateSaleResult {
  final Sale sale;
  final List<Alert> alerts;

  CreateSaleResult({required this.sale, required this.alerts});
}

class SaleService {
  final ApiClient _apiClient;

  SaleService(this._apiClient);

  Future<List<Sale>> list(String businessId) async {
    // El backend pagina de 20 en 20 por defecto; pedimos el máximo para los totales del historial.
    final response = await _apiClient.get('/app/businesses/$businessId/sales?limit=100');
    final items = response['data'] as List<dynamic>;
    return items.map((item) => Sale.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<SalesSummary> summary(String businessId) async {
    final response = await _apiClient.get('/app/businesses/$businessId/sales/summary');
    return SalesSummary.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<SalesInsights> insights(String businessId) async {
    final response = await _apiClient.get('/app/businesses/$businessId/sales/insights');
    return SalesInsights.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Sale> getById(String businessId, String saleId) async {
    final response = await _apiClient.get('/app/businesses/$businessId/sales/$saleId');
    return Sale.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<CreateSaleResult> create(
    String businessId, {
    required List<Map<String, dynamic>> items,
    String? notes,
    String? paymentMethod,
  }) async {
    final response = await _apiClient.post(
      '/app/businesses/$businessId/sales',
      data: {'items': items, 'notes': ?notes, 'paymentMethod': ?paymentMethod},
    );
    final data = response['data'] as Map<String, dynamic>;
    final rawAlerts = data['alerts'] as List<dynamic>? ?? [];
    return CreateSaleResult(
      sale: Sale.fromJson(data),
      alerts: rawAlerts.map((alert) => Alert.fromJson(alert as Map<String, dynamic>)).toList(),
    );
  }
}
