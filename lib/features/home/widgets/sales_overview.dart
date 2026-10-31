import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/sales_summary.dart';

String _money(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return 'S/ $whole.${parts[1]}';
}

/// Montos cortos para ejes y etiquetas del gráfico: 450, 1.2k, 15k.
String _shortMoney(double value) {
  if (value >= 1000) {
    final thousands = value / 1000;
    return 'S/ ${thousands >= 10 ? thousands.round() : thousands.toStringAsFixed(1).replaceAll('.0', '')}k';
  }
  return 'S/ ${value.round()}';
}

/// Tarjeta con tres indicadores: ventas de hoy, ingresos de la semana y productos vendidos hoy.
class SalesStatsCard extends StatelessWidget {
  final SalesSummary? summary;

  const SalesStatsCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final data = summary;
    return _SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stat(
              icon: Icons.attach_money_rounded,
              iconColor: const Color(0xFF10B981),
              iconBackground: const Color(0xFFD1FAE5),
              label: 'Ventas hoy',
              value: data == null ? null : _money(data.todaySales),
              current: data?.todaySales,
              previous: data?.yesterdaySales,
              comparedTo: 'vs. ayer',
            ),
            const _Divider(),
            _Stat(
              icon: Icons.trending_up_rounded,
              iconColor: AppTheme.primary,
              iconBackground: const Color(0xFFDDE8FB),
              label: 'Ingresos semana',
              value: data == null ? null : _money(data.thisWeekTotal),
              current: data?.thisWeekTotal,
              previous: data?.lastWeekTotal,
              comparedTo: 'vs. sem. pasada',
            ),
            const _Divider(),
            _Stat(
              icon: Icons.inventory_2_rounded,
              iconColor: const Color(0xFF7C3AED),
              iconBackground: const Color(0xFFEDE4FF),
              label: 'Vendidos hoy',
              value: data?.todayUnits.toString(),
              current: data?.todayUnits.toDouble(),
              previous: data?.yesterdayUnits.toDouble(),
              comparedTo: 'vs. ayer',
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const VerticalDivider(width: 1, thickness: 1, indent: 8, endIndent: 8, color: AppTheme.border);
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String? value;
  final double? current;
  final double? previous;
  final String comparedTo;

  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.current,
    required this.previous,
    required this.comparedTo,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 2),
            // Los montos grandes se achican para no partirse en dos líneas.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: value == null
                  ? Container(
                      width: 70,
                      height: 22,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEFF3F9), borderRadius: BorderRadius.circular(6)),
                    )
                  : Text(
                      value!,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
            ),
            const SizedBox(height: 4),
            if (current != null && previous != null)
              _Trend(current: current!, previous: previous!, comparedTo: comparedTo),
          ],
        ),
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  final double current;
  final double previous;
  final String comparedTo;

  const _Trend({required this.current, required this.previous, required this.comparedTo});

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    IconData? icon;
    if (previous == 0) {
      // Sin base para comparar no hay porcentaje: se muestra un texto neutro.
      text = current == 0 ? 'Sin ventas' : 'Nuevo';
      color = current == 0 ? AppTheme.textSecondary : const Color(0xFF10B981);
      if (current > 0) icon = Icons.arrow_upward_rounded;
    } else {
      final change = (current - previous) / previous * 100;
      final up = change >= 0;
      text = '${up ? '+' : ''}${change.round()}%';
      color = up ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      icon = up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 13, color: color),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 3),
          Text(comparedTo, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

/// Gráfico de barras con el total vendido por día (lunes a domingo).
class WeeklySalesChart extends StatefulWidget {
  final SalesSummary? summary;
  final bool failed;
  final VoidCallback onRetry;

  const WeeklySalesChart({super.key, required this.summary, required this.failed, required this.onRetry});

  @override
  State<WeeklySalesChart> createState() => _WeeklySalesChartState();
}

class _WeeklySalesChartState extends State<WeeklySalesChart> {
  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _chartHeight = 170.0;

  bool _showLastWeek = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.summary;

    return _SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: AppTheme.primary, size: 26),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Ventas de la semana',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
              PopupMenuButton<bool>(
                initialValue: _showLastWeek,
                onSelected: (value) => setState(() => _showLastWeek = value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('Esta semana')),
                  PopupMenuItem(value: true, child: Text('Semana pasada')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        _showLastWeek ? 'Semana pasada' : 'Esta semana',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (data == null)
            SizedBox(
              height: _chartHeight + 24,
              child: Center(
                child: widget.failed
                    ? TextButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('No se pudo cargar. Reintentar'),
                      )
                    : const CircularProgressIndicator(),
              ),
            )
          else
            _buildChart(data),
        ],
      ),
    );
  }

  Widget _buildChart(SalesSummary data) {
    final values = _showLastWeek ? data.lastWeekDays : data.thisWeekDays;
    final highlight = _showLastWeek ? -1 : data.todayIndex;
    final maxValue = _niceMax(values.fold<double>(0, math.max));
    final ticks = [for (var i = 4; i >= 0; i--) maxValue * i / 4];
    final total = values.fold<double>(0, (sum, value) => sum + value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Eje Y con cinco marcas (0 a máximo).
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final tick in ticks)
                      SizedBox(
                        height: 14,
                        child: Text(
                          _shortMoney(tick),
                          style: const TextStyle(fontSize: 10, height: 1.4, color: AppTheme.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  children: [
                    // Líneas guía horizontales alineadas con las marcas del eje.
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Misma altura que las etiquetas del eje para que cada línea quede a su centro.
                          for (var i = 0; i < ticks.length; i++)
                            SizedBox(
                              height: 14,
                              child: Center(
                                child: Container(
                                  height: 1,
                                  color: i == ticks.length - 1 ? AppTheme.border : const Color(0xFFEEF2F8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      bottom: 7,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < values.length; i++)
                            Expanded(
                              child: _Bar(
                                value: values[i],
                                fraction: maxValue == 0 ? 0 : values[i] / maxValue,
                                highlighted: i == highlight,
                                isFuture: highlight >= 0 && i > highlight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 50),
            for (var i = 0; i < _dayLabels.length; i++)
              Expanded(
                child: Text(
                  _dayLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: i == highlight ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight: i == highlight ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF4F7FC), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Text(
                _showLastWeek ? 'Total semana pasada' : 'Total esta semana',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              Text(
                _money(total),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Redondea el máximo hacia arriba a un valor "bonito" divisible entre 4 (p. ej. 610 → 800).
  static double _niceMax(double value) {
    if (value <= 0) return 100;
    final rawStep = value / 4;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    for (final factor in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      final step = factor * magnitude;
      if (step >= rawStep) return step * 4;
    }
    return 10 * magnitude * 4;
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double fraction;
  final bool highlighted;
  final bool isFuture;

  const _Bar({required this.value, required this.fraction, required this.highlighted, required this.isFuture});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // La barra llena ocupa exactamente de la línea del 0 a la del máximo (7 px arriba del borde).
        final maxBarHeight = constraints.maxHeight - 7;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) {
            // Los días sin ventas muestran una base mínima para que se note la columna.
            final barHeight = math.max(animated * maxBarHeight, 3.0);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: barHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: value == 0
                        ? null
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: highlighted
                                ? const [Color(0xFF0D47C9), Color(0xFF1A6FF0)]
                                : const [Color(0xFF3D8BFF), Color(0xFF6BA6FF)],
                          ),
                    color: value == 0 ? (isFuture ? const Color(0xFFF1F4F9) : const Color(0xFFE3EAF5)) : null,
                  ),
                ),
                if (value > 0)
                  Positioned(
                    bottom: barHeight + 2,
                    left: 0,
                    right: 0,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _shortMoney(value),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: highlighted ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _SectionCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0A1F4D).withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
