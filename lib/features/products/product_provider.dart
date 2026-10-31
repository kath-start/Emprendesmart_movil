import 'package:flutter/foundation.dart';

import '../../models/inventory_movement.dart';
import '../../models/product.dart';
import 'product_service.dart';

class ProductProvider extends ChangeNotifier {
  final ProductService _productService;

  ProductProvider(this._productService);

  List<Product> products = [];
  bool isLoading = false;

  Future<void> loadProducts(String businessId) async {
    isLoading = true;
    notifyListeners();
    try {
      products = await _productService.list(businessId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createProduct(
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
  }) async {
    final product = await _productService.create(
      businessId,
      name: name,
      price: price,
      cost: cost,
      stock: stock,
      lowStockThreshold: lowStockThreshold,
      category: category,
      unit: unit,
      sku: sku,
      imageUrl: imageUrl,
    );
    products = [product, ...products];
    notifyListeners();
  }

  Future<void> updateProduct(
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
    final updated = await _productService.update(
      businessId,
      productId,
      name: name,
      price: price,
      cost: cost,
      lowStockThreshold: lowStockThreshold,
      category: category,
      unit: unit,
      sku: sku,
      imageUrl: imageUrl,
      status: status,
    );
    products = [
      for (final product in products)
        if (product.id == productId) updated else product,
    ];
    notifyListeners();
  }

  /// Busca en los productos cargados el que tenga este código de barras.
  Product? findByBarcode(String barcode) {
    final scanned = _normalizeBarcode(barcode);
    for (final product in products) {
      final sku = product.sku;
      if (sku != null && sku.trim().isNotEmpty && _normalizeBarcode(sku) == scanned) return product;
    }
    return null;
  }

  /// Un mismo empaque puede leerse como UPC-A (12 dígitos) o EAN-13 (con un 0 delante):
  /// en códigos solo numéricos se ignoran los ceros a la izquierda. Los alfanuméricos
  /// se comparan sin distinguir mayúsculas.
  static String _normalizeBarcode(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return trimmed.toUpperCase();
  }

  Future<String> uploadImage(String businessId, Uint8List bytes, {required String contentType}) =>
      _productService.uploadImage(businessId, bytes, contentType: contentType);

  Future<void> deleteProduct(String businessId, String productId) async {
    await _productService.delete(businessId, productId);
    products = products.where((product) => product.id != productId).toList();
    notifyListeners();
  }

  Future<List<InventoryMovement>> listMovements(String businessId, String productId) =>
      _productService.listMovements(businessId, productId);

  Future<void> createMovement(
    String businessId,
    String productId, {
    required String type,
    required int quantity,
    String? note,
  }) async {
    await _productService.createMovement(businessId, productId, type: type, quantity: quantity, note: note);
    await loadProducts(businessId);
  }

  void reset() {
    products = [];
    notifyListeners();
  }
}
