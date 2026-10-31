import 'package:flutter/foundation.dart';

import '../../models/alert.dart';
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

  Future<List<Alert>> createSale(String businessId, {required List<Map<String, dynamic>> items, String? notes}) async {
    final result = await _saleService.create(businessId, items: items, notes: notes);
    sales = [result.sale, ...sales];
    notifyListeners();
    return result.alerts;
  }

  void reset() {
    sales = [];
    notifyListeners();
  }
}
