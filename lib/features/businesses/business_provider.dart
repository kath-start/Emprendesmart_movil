import 'package:flutter/foundation.dart';

import '../../models/business.dart';
import '../../models/idea_plan.dart';
import 'business_service.dart';

class BusinessProvider extends ChangeNotifier {
  final BusinessService _businessService;

  BusinessProvider(this._businessService);

  List<Business> businesses = [];
  Business? currentBusiness;
  bool isLoading = false;

  Future<void> loadBusinesses() async {
    isLoading = true;
    notifyListeners();
    try {
      businesses = await _businessService.list();
      currentBusiness = businesses.isNotEmpty ? businesses.first : null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createBusiness({
    required String name,
    required String category,
    String? description,
    String? stage,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final business = await _businessService.create(
        name: name,
        category: category,
        description: description,
        stage: stage,
      );
      businesses = [...businesses, business];
      currentBusiness = business;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateBusiness(
    String businessId, {
    required String name,
    required String category,
    String? description,
    required String stage,
    required String status,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final updated = await _businessService.update(
        businessId,
        name: name,
        category: category,
        description: description,
        stage: stage,
        status: status,
      );
      businesses = [
        for (final business in businesses)
          if (business.id == businessId) updated else business,
      ];
      if (currentBusiness?.id == businessId) currentBusiness = updated;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadLogo(String businessId, Uint8List bytes, {required String contentType}) async {
    _replace(await _businessService.uploadLogo(businessId, bytes, contentType: contentType));
  }

  Future<void> removeLogo(String businessId) async {
    _replace(await _businessService.removeLogo(businessId));
  }

  Future<void> saveIdeaPlan(String businessId, IdeaPlan plan) async {
    _replace(await _businessService.patch(businessId, {'ideaPlan': plan.toJson()}));
  }

  /// Meta de ventas del mes; `null` la quita.
  Future<void> setSalesGoal(String businessId, double? goal) async {
    _replace(await _businessService.patch(businessId, {'monthlySalesGoal': goal}));
  }

  /// Pasa el negocio a otra etapa (p. ej. de IDEA a EARLY al hacer la primera venta).
  Future<void> changeStage(String businessId, String stage) async {
    _replace(await _businessService.patch(businessId, {'stage': stage}));
  }

  void _replace(Business updated) {
    businesses = [
      for (final business in businesses)
        if (business.id == updated.id) updated else business,
    ];
    if (currentBusiness?.id == updated.id) currentBusiness = updated;
    notifyListeners();
  }

  void selectBusiness(Business business) {
    currentBusiness = business;
    notifyListeners();
  }

  void reset() {
    businesses = [];
    currentBusiness = null;
    notifyListeners();
  }
}
