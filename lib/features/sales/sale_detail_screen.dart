import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../products/product_provider.dart';
import '../products/widgets/product_widgets.dart';
import 'sale_provider.dart';

const _yapePurple = Color(0xFF742284);
const _plinTeal = Color(0xFF00A19B);
const _green = Color(0xFF16A34A);

const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _two(int n) => n.toString().padLeft(2, '0');
String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)} ${d.year}';
String _longDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]} de ${d.year}';

typedef _Payment = ({String? method, String? payer, bool fromWallet});

/// Método de pago de la venta. Si vino de un cobro leído del teléfono, la nota dice quién pagó
/// ("Cobro Yape · María López · S/ 40.00" o "Cobro Plin · …").
_Payment _paymentOf(Sale sale) {
  final notes = sale.notes;
  final match = notes == null ? null : RegExp(r'^Cobro (Yape|Plin)').firstMatch(notes);
  if (match == null) return (method: sale.paymentMethod, payer: null, fromWallet: false);
  final parts = notes!.split('·').map((p) => p.trim()).toList();
  final payer = parts.length > 1 && !parts[1].startsWith('S/') ? parts[1] : null;
  return (method: sale.paymentMethod ?? match.group(1)!.toLowerCase(), payer: payer, fromWallet: true);
}

String _methodLabel(String? method) => switch (method) {
  'efectivo' => 'Efectivo',
  'yape' => 'Yape',
  'plin' => 'Plin',
  'tarjeta' => 'Tarjeta',
  _ => 'No especificado',
};

IconData _methodIcon(String? method) => switch (method) {
  'yape' => Icons.qr_code_2_rounded,
  'plin' => Icons.phone_android_rounded,
  'tarjeta' => Icons.credit_card_rounded,
  _ => Icons.payments_outlined,
};

class SaleDetailScreen extends StatefulWidget {
  final String businessId;
  final String saleId;

  const SaleDetailScreen({super.key, required this.businessId, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late Future<Sale> _saleFuture;

  @override
  void initState() {
    super.initState();
    _load();
    // Fotos y costos de los productos (si se abre desde Yape aún pueden no estar cargados).
    final products = context.read<ProductProvider>();
    if (products.products.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => products.loadProducts(widget.businessId));
    }
  }

  void _load() {
    _saleFuture = context.read<SaleProvider>().getSaleById(widget.businessId, widget.saleId);
  }

  @override
  Widget build(BuildContext context) {
    final productsById = {for (final p in context.watch<ProductProvider>().products) p.id: p};

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de venta')),
      body: FutureBuilder<Sale>(
        future: _saleFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(onRetry: () => setState(_load));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final sale = snapshot.data!;
          final payment = _paymentOf(sale);
          final units = sale.items.fold<int>(0, (sum, item) => sum + item.quantity);

          // Ganancia estimada solo si todos los productos vendidos tienen costo registrado.
          double? cost = 0;
          for (final item in sale.items) {
            final unitCost = productsById[item.productId]?.cost;
            if (unitCost == null) {
              cost = null;
              break;
            }
            cost = cost! + unitCost * item.quantity;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _TotalCard(sale: sale, units: units, payment: payment),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Productos',
                trailing: '${sale.items.length} ${sale.items.length == 1 ? 'producto' : 'productos'}',
                child: Column(
                  children: [
                    for (var i = 0; i < sale.items.length; i++) ...[
                      if (i > 0) const Divider(height: 20, color: AppTheme.border),
                      _ItemRow(item: sale.items[i], product: productsById[sale.items[i].productId]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.receipt_long_outlined,
                title: 'Resumen',
                child: Column(
                  children: [
                    _SummaryRow(label: 'Unidades vendidas', value: '$units'),
                    if (cost != null) ...[
                      _SummaryRow(label: 'Costo de los productos', value: formatMoney(cost)),
                      _SummaryRow(
                        label: 'Ganancia estimada',
                        value: formatMoney(sale.total - cost),
                        valueColor: sale.total - cost >= 0 ? _green : const Color(0xFFDC2626),
                      ),
                    ],
                    const Divider(height: 24, color: AppTheme.border),
                    _SummaryRow(label: 'Total cobrado', value: formatMoney(sale.total), emphasized: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.info_outline_rounded,
                title: 'Detalles',
                child: Column(
                  children: [
                    if (sale.sellerName != null)
                      _InfoRow(icon: Icons.person_outline_rounded, label: 'Vendió', value: sale.sellerName!),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha',
                      value: '${_longDate(sale.soldAt.toLocal())}, ${_time(sale.soldAt.toLocal())}',
                    ),
                    _InfoRow(
                      icon: _methodIcon(payment.method),
                      label: 'Método de pago',
                      value: payment.payer == null
                          ? _methodLabel(payment.method)
                          : '${_methodLabel(payment.method)} · ${payment.payer}',
                    ),
                    if (!payment.fromWallet && sale.notes != null && sale.notes!.trim().isNotEmpty)
                      _InfoRow(icon: Icons.sticky_note_2_outlined, label: 'Nota', value: sale.notes!.trim()),
                    _InfoRow(
                      icon: Icons.tag_rounded,
                      label: 'Código de venta',
                      value: '#${sale.id.substring(0, 8).toUpperCase()}',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: sale.id));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Código de venta copiado')));
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final Sale sale;
  final int units;
  final _Payment payment;

  const _TotalCard({required this.sale, required this.units, required this.payment});

  @override
  Widget build(BuildContext context) {
    final soldAt = sale.soldAt.toLocal();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
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
            right: -50,
            top: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 16),
                          SizedBox(width: 5),
                          Text(
                            'Venta registrada',
                            style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_shortDate(soldAt)} · ${_time(soldAt)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Total cobrado', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(sale.total),
                    style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (payment.method != null)
                      _Chip(
                        background: switch (payment.method) {
                          'yape' => _yapePurple,
                          'plin' => _plinTeal,
                          _ => Colors.white.withValues(alpha: 0.14),
                        },
                        icon: _methodIcon(payment.method),
                        label: payment.payer == null
                            ? 'Pagó con ${_methodLabel(payment.method)}'
                            : '${_methodLabel(payment.method)} · ${payment.payer}',
                      ),
                    _Chip(
                      background: Colors.white.withValues(alpha: 0.14),
                      icon: Icons.inventory_2_outlined,
                      label: '$units ${units == 1 ? 'unidad' : 'unidades'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Color background;
  final IconData icon;
  final String label;

  const _Chip({required this.background, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final Widget child;

  const _SectionCard({required this.icon, required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              if (trailing != null)
                Text(trailing!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final SaleItem item;
  final Product? product;

  const _ItemRow({required this.item, this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProductImage(url: product?.imageUrl, size: 52, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName ?? product?.name ?? 'Producto',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.quantity} × ${formatMoney(item.unitPrice)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatMoney(item.subtotal),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  const _SummaryRow({required this.label, required this.value, this.valueColor, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: emphasized ? 16 : 14,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: emphasized ? 20 : 14.5,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: const Color(0xFFEAF1FD), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.copy_rounded, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar la venta',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Revisa tu conexión e inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
