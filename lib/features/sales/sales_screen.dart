import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../auth/auth_provider.dart';
import '../auth/profile_screen.dart';
import '../businesses/business_provider.dart';
import '../products/product_provider.dart';
import '../products/widgets/product_widgets.dart';
import '../signals/signals_screen.dart';
import 'new_sale_screen.dart';
import 'sale_detail_screen.dart';
import 'sale_provider.dart';

enum _Period { today, yesterday, week, month, all }

const _periodLabels = {
  _Period.today: 'Hoy',
  _Period.yesterday: 'Ayer',
  _Period.week: 'Últimos 7 días',
  _Period.month: 'Este mes',
  _Period.all: 'Todas',
};

/// Rango [inicio, fin) de un período y del período anterior equivalente (para comparar).
({DateTime start, DateTime end, DateTime? prevStart, DateTime? prevEnd})? _rangeFor(_Period period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case _Period.today:
      final start = today;
      return (
        start: start,
        end: start.add(const Duration(days: 1)),
        prevStart: start.subtract(const Duration(days: 1)),
        prevEnd: start,
      );
    case _Period.yesterday:
      final start = today.subtract(const Duration(days: 1));
      return (start: start, end: today, prevStart: start.subtract(const Duration(days: 1)), prevEnd: start);
    case _Period.week:
      final start = today.subtract(const Duration(days: 6));
      return (
        start: start,
        end: today.add(const Duration(days: 1)),
        prevStart: start.subtract(const Duration(days: 7)),
        prevEnd: start,
      );
    case _Period.month:
      final start = DateTime(now.year, now.month);
      return (
        start: start,
        end: DateTime(now.year, now.month + 1),
        prevStart: DateTime(now.year, now.month - 1),
        prevEnd: start,
      );
    case _Period.all:
      return null;
  }
}

const _comparisonLabels = {
  _Period.today: 'vs. ayer',
  _Period.yesterday: 'vs. anteayer',
  _Period.week: 'vs. 7 días anteriores',
  _Period.month: 'vs. mes anterior',
};

String _two(int n) => n.toString().padLeft(2, '0');
String _formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';
int _unitsOf(Sale sale) => sale.items.fold(0, (sum, item) => sum + item.quantity);

class SalesScreen extends StatefulWidget {
  final String businessId;

  const SalesScreen({super.key, required this.businessId});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  _Period _period = _Period.today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SaleProvider>().loadSales(widget.businessId);
      // Los nombres y fotos de los productos vendidos salen del catálogo.
      final productProvider = context.read<ProductProvider>();
      if (productProvider.products.isEmpty) productProvider.loadProducts(widget.businessId);
    });
  }

  Future<void> _refresh() => Future.wait([
    context.read<SaleProvider>().loadSales(widget.businessId),
    context.read<ProductProvider>().loadProducts(widget.businessId),
  ]);

  Future<void> _newSale() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewSaleScreen(businessId: widget.businessId)));
    if (mounted) context.read<SaleProvider>().loadSales(widget.businessId);
  }

  @override
  Widget build(BuildContext context) {
    final saleProvider = context.watch<SaleProvider>();
    final productsById = {for (final p in context.watch<ProductProvider>().products) p.id: p};
    final allSales = saleProvider.sales;

    final range = _rangeFor(_period);
    bool inRange(Sale sale, DateTime start, DateTime end) {
      final soldAt = sale.soldAt.toLocal();
      return !soldAt.isBefore(start) && soldAt.isBefore(end);
    }

    final sales = range == null ? allSales : allSales.where((s) => inRange(s, range.start, range.end)).toList();
    final total = sales.fold<double>(0, (sum, s) => sum + s.total);
    double? change;
    if (range != null && range.prevStart != null) {
      final previous = allSales
          .where((s) => inRange(s, range.prevStart!, range.prevEnd!))
          .fold<double>(0, (sum, s) => sum + s.total);
      if (previous > 0) change = (total - previous) / previous * 100;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 96),
            children: [
              _Header(businessId: widget.businessId),
              const SizedBox(height: 18),
              _TotalCard(
                label: _period == _Period.all ? 'Total de ventas' : 'Ventas · ${_periodLabels[_period]}',
                total: total,
                change: change,
                comparisonLabel: _comparisonLabels[_period],
                hasPrevious: range != null,
              ),
              const SizedBox(height: 12),
              _SummaryRow(units: sales.fold(0, (sum, s) => sum + _unitsOf(s)), salesCount: sales.length),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Historial de ventas',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ),
                  _PeriodButton(value: _period, onChanged: (value) => setState(() => _period = value)),
                ],
              ),
              const SizedBox(height: 10),
              if (saleProvider.isLoading && allSales.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (sales.isEmpty)
                _EmptySales(
                  message: allSales.isEmpty
                      ? 'Aún no registras ventas.\nToca + para registrar la primera.'
                      : 'No hay ventas en este período.',
                )
              else
                for (final sale in sales)
                  _SaleCard(sale: sale, businessId: widget.businessId, productsById: productsById),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Nueva venta',
          // Productos y Ventas conviven en pestañas; sin esto sus botones comparten animación y chocan.
          heroTag: null,
          shape: const CircleBorder(),
          onPressed: _newSale,
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String businessId;

  const _Header({required this.businessId});

  @override
  Widget build(BuildContext context) {
    final entrepreneur = context.watch<AuthProvider>().entrepreneur;
    final initials = entrepreneur == null
        ? '?'
        : '${entrepreneur.firstName.isNotEmpty ? entrepreneur.firstName[0] : ''}'
                  '${entrepreneur.lastName.isNotEmpty ? entrepreneur.lastName[0] : ''}'
              .toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF1A6FF0), Color(0xFF0D47C9)]),
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ventas',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              Text(
                'Gestiona tus ventas de manera fácil y rápida.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
        if (context.watch<BusinessProvider>().currentBusiness?.canSeeInsights ?? false) ...[
          IconButton(
            tooltip: 'Alertas',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.border),
            ),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SignalsScreen(businessId: businessId))),
            icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 6),
        ],
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.navy,
            child: Text(
              initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double total;
  final double? change;
  final String? comparisonLabel;
  final bool hasPrevious;

  const _TotalCard({
    required this.label,
    required this.total,
    required this.change,
    required this.comparisonLabel,
    required this.hasPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final up = (change ?? 0) >= 0;
    final changeColor = up ? const Color(0xFF4ADE80) : const Color(0xFFFF8A8A);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2463), Color(0xFF0D47C9)],
        ),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          const Positioned(
            right: 18,
            top: 18,
            child: Icon(Icons.bar_chart_rounded, color: Color(0xFF7DB4FF), size: 34),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(color: Color(0xFFDCE8FF), fontSize: 14)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _money(total),
                          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (hasPrevious) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (change != null) ...[
                              Icon(
                                up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                color: changeColor,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${up ? '+' : ''}${change!.toStringAsFixed(0)}%',
                                style: TextStyle(color: changeColor, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                change == null ? 'Sin ventas para comparar $comparisonLabel' : comparisonLabel ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFFB9CCF0), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int units;
  final int salesCount;

  const _SummaryRow({required this.units, required this.salesCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.inventory_2_outlined,
                  value: '$units',
                  label: units == 1 ? 'unidad vendida' : 'unidades vendidas',
                ),
              ),
              const VerticalDivider(width: 20, color: AppTheme.border),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.receipt_long_outlined,
                  value: '$salesCount',
                  label: salesCount == 1 ? 'venta' : 'ventas',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final _Period value;
  final ValueChanged<_Period> onChanged;

  const _PeriodButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Period>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final entry in _periodLabels.entries) PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              _periodLabels[value]!,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;
  final String businessId;
  final Map<String, Product> productsById;

  const _SaleCard({required this.sale, required this.businessId, required this.productsById});

  @override
  Widget build(BuildContext context) {
    final units = _unitsOf(sale);
    final firstProduct = sale.items.isEmpty ? null : productsById[sale.items.first.productId];
    final otherCount = sale.items.length - 1;
    final title = firstProduct == null
        ? '$units producto${units == 1 ? '' : 's'}'
        : otherCount > 0
        ? '${firstProduct.name} y $otherCount más'
        : firstProduct.name;
    final soldAt = sale.soldAt.toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SaleDetailScreen(businessId: businessId, saleId: sale.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              firstProduct?.imageUrl != null
                  ? ProductImage(url: firstProduct!.imageUrl, size: 56)
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: Color(0xFFEAF2FF), shape: BoxShape.circle),
                      child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${_formatDate(soldAt)} · ${_formatTime(soldAt)} · $units unid.',
                        if (sale.sellerName != null) 'Vendió: ${sale.sellerName}',
                      ].join('\n'),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _money(sale.total),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySales extends StatelessWidget {
  final String message;

  const _EmptySales({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
