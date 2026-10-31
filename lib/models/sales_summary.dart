import '../core/utils/decimal.dart';

/// Resumen de ventas para el inicio: hoy vs. ayer y la semana (lunes a domingo) vs. la anterior.
class SalesSummary {
  final double todaySales;
  final double yesterdaySales;
  final int todayUnits;
  final int yesterdayUnits;
  final double thisWeekTotal;
  final double lastWeekTotal;
  final List<double> thisWeekDays;
  final List<double> lastWeekDays;

  /// Posición de hoy dentro de la semana (0 = lunes).
  final int todayIndex;

  SalesSummary({
    required this.todaySales,
    required this.yesterdaySales,
    required this.todayUnits,
    required this.yesterdayUnits,
    required this.thisWeekTotal,
    required this.lastWeekTotal,
    required this.thisWeekDays,
    required this.lastWeekDays,
    required this.todayIndex,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>;
    final yesterday = json['yesterday'] as Map<String, dynamic>;
    final thisWeek = json['thisWeek'] as Map<String, dynamic>;
    final lastWeek = json['lastWeek'] as Map<String, dynamic>;
    List<double> days(Map<String, dynamic> week) =>
        (week['days'] as List<dynamic>).map((value) => parseNum(value).toDouble()).toList();

    return SalesSummary(
      todaySales: parseNum(today['sales']).toDouble(),
      yesterdaySales: parseNum(yesterday['sales']).toDouble(),
      todayUnits: parseNum(today['units']).toInt(),
      yesterdayUnits: parseNum(yesterday['units']).toInt(),
      thisWeekTotal: parseNum(thisWeek['total']).toDouble(),
      lastWeekTotal: parseNum(lastWeek['total']).toDouble(),
      thisWeekDays: days(thisWeek),
      lastWeekDays: days(lastWeek),
      todayIndex: parseNum(json['todayIndex']).toInt(),
    );
  }
}
