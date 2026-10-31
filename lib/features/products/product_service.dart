import 'dart:typed_data';

import '../../core/network/api_client.dart';
import '../../models/inventory_movement.dart';
import '../../models/product.dart';

class ProductService {
  final ApiClient _apiClient;

  ProductService(this._apiClient);

  Future<List<Product>> list(String businessId) async {
    // El backend pagina de 20 en 20 por defecto; pedimos el máximo para tener el catálogo completo.
    final response = await _apiClient.get('/app/businesses/$businessId/products?limit=100');
    final items = response['data'] as List<dynamic>;
    return items.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Product> create(
    String businessId, {
    required String name,
    required double price,
    double? cost,
    int stock = 0,
    int lowStockThreshold = 5,
    String? category,
    String? unit,
    String? sku,
    String? imageUrl,
    String? description,
  }) async {
    final response = await _apiClient.post(
      '/app/businesses/$businessId/products',
      data: {
        'name': name,
        'price': price,
        'cost': ?cost,
        'stock': stock,
        'lowStockThreshold': lowStockThreshold,
        if (category != null && category.isNotEmpty) 'category': category,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        if (sku != null && sku.isNotEmpty) 'sku': sku,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return Product.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Product> update(
    String businessId,
    String productId, {
    required String name,
    required double price,
    double? cost,
    required int lowStockThreshold,
    String? category,
    String? unit,
    String? sku,
    String? imageUrl,
    String? status,
  }) async {
    final response = await _apiClient.patch(
      '/app/businesses/$businessId/products/$productId',
      data: {
        'name': name,
        'price': price,
        'cost': cost,
        'lowStockThreshold': lowStockThreshold,
        'category': (category == null || category.isEmpty) ? null : category,
        'unit': (unit == null || unit.isEmpty) ? null : unit,
        'sku': (sku == null || sku.isEmpty) ? null : sku,
        'imageUrl': (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
        'status': ?status,
      },
    );
    return Product.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Sube una foto y devuelve su URL pública.
  Future<String> uploadImage(String businessId, Uint8List bytes, {required String contentType}) async {
    final response = await _apiClient.postBytes(
      '/app/businesses/$businessId/products/images',
      bytes,
      contentType: contentType,
    );
    return (response['data'] as Map<String, dynamic>)['imageUrl'] as String;
  }

  Future<void> delete(String businessId, String productId) async {
    await _apiClient.delete('/app/businesses/$businessId/products/$productId');
  }

  Future<List<InventoryMovement>> listMovements(String businessId, String productId) async {
    final response = await _apiClient.get('/app/businesses/$businessId/products/$productId/inventory-movements');
    final items = response['data'] as List<dynamic>;
    return items.map((item) => InventoryMovement.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<InventoryMovement> createMovement(
    String businessId,
    String productId, {
    required String type,
    required int quantity,
    String? note,
  }) async {
    final response = await _apiClient.post(
      '/app/businesses/$businessId/products/$productId/inventory-movements',
      data: {'type': type, 'quantity': quantity, 'note': ?note},
    );
    return InventoryMovement.fromJson(response['data'] as Map<String, dynamic>);
  }
}
