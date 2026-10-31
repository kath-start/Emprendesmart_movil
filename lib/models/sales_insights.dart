import '../core/utils/decimal.dart';

class ProductPerformance {
  final String id;
  final String name;
  final String? imageUrl;
  final int units;
  final double revenue;

  ProductPerformance({required this.id, required this.name, this.imageUrl, required this.units, required this.revenue});

  factory ProductPerformance.fromJson(Map<String, dynamic> json) => ProductPerformance(
    id: json['id'] as String,
    name: json['name'] as String,
    imageUrl: json['imageUrl'] as String?,
    units: parseNum(json['units']).toInt(),
    revenue: parseNum(json['revenue']).toDouble(),
  );
}

class SellerPerformance {
  final String name;
  final double total;
  final int count;

  SellerPerformance({required this.name, required this.total, required this.count});

  factory SellerPerformance.fromJson(Map<String, dynamic> json) => SellerPerformance(
    name: json['name'] as String,
    total: parseNum(json['total']).toDouble(),
    count: parseNum(json['count']).toInt(),
  );
}

/// Indicadores del mes (hora Perú) que usa el inicio de las etapas Inicio, Crecimiento y Consolidado.
class SalesInsights {
  final double? goal;
  final double monthTotal;
  final int monthCount;
  final double avgTicket;
  final double profit;

  /// `false` si algún producto vendido no tiene costo registrado (la ganancia es parcial).
  final bool profitComplete;
  final double lastMonthTotal;
  final int lastMonthCount;
  final List<ProductPerformance> topProducts;
  final ProductPerformance? slowProduct;

  /// Total vendido este mes por día de la semana (0 = lunes).
  final List<double> weekday;
  final List<SellerPerformance> sellers;
  final int productsCount;
  final int salesAllTime;
  final int productsWithoutCost;

  SalesInsights({
    required this.goal,
    required this.monthTotal,
    required this.monthCount,
    required this.avgTicket,
    required this.profit,
    required this.profitComplete,
    required this.lastMonthTotal,
    required this.lastMonthCount,
    required this.topProducts,
    required this.slowProduct,
    required this.weekday,
    required this.sellers,
    required this.productsCount,
    required this.salesAllTime,
    required this.productsWithoutCost,
  });

  factory SalesInsights.fromJson(Map<String, dynamic> json) {
    final month = json['month'] as Map<String, dynamic>;
    final lastMonth = json['lastMonth'] as Map<String, dynamic>;
    final counts = json['counts'] as Map<String, dynamic>;
    final slow = json['slowProduct'] as Map<String, dynamic>?;

    return SalesInsights(
      goal: json['goal'] == null ? null : parseNum(json['goal']).toDouble(),
      monthTotal: parseNum(month['total']).toDouble(),
      monthCount: parseNum(month['count']).toInt(),
      avgTicket: parseNum(month['avgTicket']).toDouble(),
      profit: parseNum(month['profit']).toDouble(),
      profitComplete: month['profitComplete'] as bool? ?? true,
      lastMonthTotal: parseNum(lastMonth['total']).toDouble(),
      lastMonthCount: parseNum(lastMonth['count']).toInt(),
      topProducts: (json['topProducts'] as List<dynamic>)
          .map((item) => ProductPerformance.fromJson(item as Map<String, dynamic>))
          .toList(),
      slowProduct: slow == null ? null : ProductPerformance.fromJson(slow),
      weekday: (json['weekday'] as List<dynamic>).map((value) => parseNum(value).toDouble()).toList(),
      sellers: (json['sellers'] as List<dynamic>)
          .map((item) => SellerPerformance.fromJson(item as Map<String, dynamic>))
          .toList(),
      productsCount: parseNum(counts['products']).toInt(),
      salesAllTime: parseNum(counts['salesAllTime']).toInt(),
      productsWithoutCost: parseNum(counts['productsWithoutCost']).toInt(),
    );
  }
}
