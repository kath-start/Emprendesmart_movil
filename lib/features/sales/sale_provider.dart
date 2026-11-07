import 'package:flutter/foundation.dart';

import '../../models/sale.dart';
import 'sale_service.dart';

class SaleProvider extends ChangeNotifier {
  final SaleService _saleService;

  SaleProvider(this._saleService);

  List<Sale> sales = [];
  bool isLoading = false;

  Future<void> loadSales(String businessId) async {
    isLoading = true;
    notifyListeners();
    try {
      sales = await _saleService.list(businessId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Sale> getSaleById(String businessId, String saleId) => _saleService.getById(businessId, saleId);

  Future<CreateSaleResult> createSale(
    String businessId, {
    required List<Map<String, dynamic>> items,
    String? notes,
    String? paymentMethod,
  }) async {
    final result = await _saleService.create(businessId, items: items, notes: notes, paymentMethod: paymentMethod);
    sales = [result.sale, ...sales];
    notifyListeners();
    return result;
  }

  void reset() {
    sales = [];
    notifyListeners();
  }
}
