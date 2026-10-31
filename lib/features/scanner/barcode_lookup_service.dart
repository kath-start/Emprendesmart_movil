import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class BarcodeProductInfo {
  final String name;
  final String? brand;
  final String? category;
  final String? imageUrl;

  BarcodeProductInfo({required this.name, this.brand, this.category, this.imageUrl});

  /// Nombre sugerido para el producto: "Nombre - Marca" si la marca no está ya en el nombre.
  String get suggestedName {
    if (brand == null) return name;
    final lowerName = name.toLowerCase();
    final lowerBrand = brand!.toLowerCase();
    if (lowerName.contains(lowerBrand) || lowerBrand.contains(lowerName)) return name;
    return '$name - $brand';
  }
}

/// Busca datos de productos empaquetados en Open Food Facts (base pública, sin API key).
class BarcodeLookupService {
  final Dio _dio;

  BarcodeLookupService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'https://world.openfoodfacts.org/api/v2',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          // Open Food Facts pide identificar la app; los navegadores no permiten cambiar el User-Agent.
          headers: kIsWeb ? null : {'User-Agent': 'EmprendeSmart/1.0 (app movil)'},
        ),
      );

  /// Devuelve null si el código no está registrado o si falla la consulta.
  Future<BarcodeProductInfo?> lookup(String barcode) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/product/${Uri.encodeComponent(barcode)}.json',
        queryParameters: {'fields': 'product_name,product_name_es,brands,categories,image_front_url,image_url'},
      );
      final data = response.data;
      if (data == null || data['status'] != 1) return null;
      final product = data['product'] as Map<String, dynamic>? ?? {};

      final name = _firstNonEmpty([product['product_name_es'], product['product_name']]);
      if (name == null) return null;
      return BarcodeProductInfo(
        name: name,
        brand: _firstCsvItem(product['brands']),
        category: _lastCsvItem(product['categories']),
        imageUrl: _firstNonEmpty([product['image_front_url'], product['image_url']]),
      );
    } on DioException {
      return null;
    }
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static List<String> _csv(dynamic value) => value is String
      ? value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty && !item.contains(':')).toList()
      : const [];

  static String? _firstCsvItem(dynamic value) {
    final items = _csv(value);
    return items.isEmpty ? null : items.first;
  }

  // La última categoría es la más específica (ej. "Bebidas, Gaseosas, Colas" -> "Colas").
  static String? _lastCsvItem(dynamic value) {
    final items = _csv(value);
    return items.isEmpty ? null : items.last;
  }
}
