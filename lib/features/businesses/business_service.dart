import 'dart:typed_data';

import '../../core/network/api_client.dart';
import '../../models/business.dart';

class BusinessService {
  final ApiClient _apiClient;

  BusinessService(this._apiClient);

  Future<List<Business>> list() async {
    final response = await _apiClient.get('/app/businesses');
    final items = response['data'] as List<dynamic>;
    return items.map((item) => Business.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Business> create({required String name, required String category, String? description, String? stage}) async {
    final response = await _apiClient.post(
      '/app/businesses',
      data: {
        'name': name,
        'category': category,
        if (description != null && description.isNotEmpty) 'description': description,
        'stage': ?stage,
      },
    );
    return Business.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Actualiza solo los campos enviados (p. ej. `ideaPlan` o `stage`).
  Future<Business> patch(String businessId, Map<String, dynamic> fields) async {
    final response = await _apiClient.patch('/app/businesses/$businessId', data: fields);
    return Business.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Business> uploadLogo(String businessId, Uint8List bytes, {required String contentType}) async {
    final response = await _apiClient.postBytes('/app/businesses/$businessId/logo', bytes, contentType: contentType);
    return Business.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Business> removeLogo(String businessId) async {
    final response = await _apiClient.delete('/app/businesses/$businessId/logo');
    return Business.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Business> update(
    String businessId, {
    required String name,
    required String category,
    String? description,
    required String stage,
    required String status,
  }) async {
    final response = await _apiClient.patch(
      '/app/businesses/$businessId',
      data: {
        'name': name,
        'category': category,
        'description': (description == null || description.isEmpty) ? null : description,
        'stage': stage,
        'status': status,
      },
    );
    return Business.fromJson(response['data'] as Map<String, dynamic>);
  }
}
