import '../../core/network/api_client.dart';
import '../../models/alert.dart';
import '../../models/recommendation.dart';

class SignalService {
  final ApiClient _apiClient;

  SignalService(this._apiClient);

  Future<List<Alert>> listAlerts(String businessId) async {
    final response = await _apiClient.get('/app/businesses/$businessId/alerts');
    final items = response['data'] as List<dynamic>;
    return items.map((item) => Alert.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Recommendation>> listRecommendations(String businessId) async {
    final response = await _apiClient.get('/app/businesses/$businessId/recommendations');
    final items = response['data'] as List<dynamic>;
    return items.map((item) => Recommendation.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Pide a la IA nuevas recomendaciones a partir del inventario y las ventas del negocio.
  Future<List<Recommendation>> generateRecommendations(String businessId) async {
    final response = await _apiClient.post(
      '/app/businesses/$businessId/recommendations/generate',
      receiveTimeout: const Duration(seconds: 70),
    );
    final items = response['data'] as List<dynamic>;
    return items.map((item) => Recommendation.fromJson(item as Map<String, dynamic>)).toList();
  }
}
