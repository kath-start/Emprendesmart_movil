import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/product.dart';
import '../../models/yape_payment.dart';
import '../products/product_provider.dart';
import '../products/widgets/product_widgets.dart';
import '../scanner/barcode_scanner_screen.dart';
import '../yape/yape_provider.dart';
import 'sale_provider.dart';

class NewSaleScreen extends StatefulWidget {
  final String businessId;

  /// Cobro de Yape al que se le asignan los productos; al registrar la venta queda conciliado.
  final YapePayment? yapePayment;

  const NewSaleScreen({super.key, required this.businessId, this.yapePayment});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final Map<String, int> _quantities = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  /// Cómo pagó el cliente. Un cobro de Yape/Plin ya trae su método.
  late String _paymentMethod = widget.yapePayment?.method ?? 'efectivo';

  /// Productos que suman exactamente el monto del Yape (se marcan solos al abrir).
  String? _suggestionLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final productProvider = context.read<ProductProvider>();
      if (productProvider.products.isEmpty) {
        await productProvider.loadProducts(widget.businessId);
      }
      if (mounted) _applyYapeSuggestion(productProvider.products);
    });
  }

  void _applyYapeSuggestion(List<Product> products) {
    final amount = widget.yapePayment?.amount;
    if (amount == null) return;
    final suggestion = suggestProductsForAmount(amount, products);
    if (suggestion == null) return;
    final byId = {for (final p in products) p.id: p};
    setState(() {
      _quantities
        ..clear()
        ..addAll(suggestion);
      _suggestionLabel = suggestion.entries.map((e) => '${byId[e.key]!.name} ×${e.value}').join(' + ');
    });
  }

  double _totalFor(List<Product> products) {
    var total = 0.0;
    for (final product in products) {
      final quantity = _quantities[product.id] ?? 0;
      total += product.price * quantity;
    }
    return total;
  }

  void _changeQuantity(Product product, int delta) {
    setState(() {
      final current = _quantities[product.id] ?? 0;
      final next = (current + delta).clamp(0, product.stock);
      _quantities[product.id] = next;
    });
  }

  /// Escanea un empaque y suma una unidad de ese producto a la venta.
  Future<void> _scanProduct() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final product = context.read<ProductProvider>().findByBarcode(code);
    if (product == null) {
      messenger.showSnackBar(SnackBar(content: Text('No hay ningún producto con el código $code.')));
      return;
    }
    final current = _quantities[product.id] ?? 0;
    if (current >= product.stock) {
      messenger.showSnackBar(SnackBar(content: Text('Sin stock suficiente de "${product.name}".')));
      return;
    }
    _changeQuantity(product, 1);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${product.name}: ${current + 1} en la venta'),
        duration: const Duration(seconds: 2),
        // Con un botón, Flutter deja el aviso fijo por defecto y tapa el escáner al reabrirlo.
        persist: false,
        action: SnackBarAction(label: 'Escanear otro', onPressed: _scanProduct),
      ),
    );
  }

  Future<void> _submit() async {
    final items = _quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'productId': entry.key, 'quantity': entry.value})
        .toList();
    if (items.isEmpty) return;

    final payment = widget.yapePayment;
    final total = _totalFor(context.read<ProductProvider>().products);
    if (payment?.amount != null && _cents(total) != _cents(payment!.amount!)) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'El total no coincide',
        message:
            'El ${payment.methodLabel} fue por ${formatMoney(payment.amount!)} y la venta suma ${formatMoney(total)}. '
            '¿Registrar la venta de todas formas?',
        icon: Icons.payments_outlined,
        destructive: false,
        confirmLabel: 'Registrar',
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final yapeProvider = context.read<YapeProvider>();
      final result = await context.read<SaleProvider>().createSale(
        widget.businessId,
        items: items,
        notes: payment?.saleNote,
        paymentMethod: _paymentMethod,
      );
      final alerts = result.alerts;
      if (payment != null) {
        await yapeProvider.markLinked(payment.id, saleId: result.sale.id, businessId: widget.businessId);
      }
      if (!mounted) return;
      await context.read<ProductProvider>().loadProducts(widget.businessId);
      if (!mounted) return;
      // La venta ya se registró: vaciamos el carrito para que detrás del aviso no queden
      // cantidades mayores al stock recién actualizado (p. ej. "51" con "8 disponibles").
      setState(_quantities.clear);

      if (alerts.isNotEmpty) {
        final messages = alerts.map((alert) => alert.message).toList();
        // Queda en la bandeja del teléfono aunque se cierre el aviso.
        NotificationService.showStockAlerts(messages);
        await showDialog<void>(
          context: context,
          barrierColor: AppTheme.navy.withValues(alpha: 0.35),
          builder: (_) => _StockAlertsDialog(messages: messages),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.products;
    final hasItems = _quantities.values.any((quantity) => quantity > 0);
    final units = _quantities.values.fold<int>(0, (sum, quantity) => sum + quantity);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            // Manchas decorativas del fondo, como en el resto de la app.
            const Positioned(top: -90, right: -100, child: _Blob(size: 260, alpha: 0.07)),
            const Positioned(bottom: 40, left: -150, child: _Blob(size: 300, alpha: 0.05)),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.yapePayment == null
                                    ? 'Nueva venta'
                                    : 'Asignar cobro ${widget.yapePayment!.methodLabel}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                widget.yapePayment == null
                                    ? 'Selecciona productos y registra tu venta'
                                    : '¿Qué productos te pagaron?',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Escanear código de barras',
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary, size: 32),
                          onPressed: _scanProduct,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: productProvider.isLoading && products.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            children: [
                              if (widget.yapePayment != null)
                                _YapeBanner(
                                  payment: widget.yapePayment!,
                                  total: _totalFor(products),
                                  suggestion: _suggestionLabel,
                                ),
                              for (final product in products)
                                _SaleProductCard(
                                  product: product,
                                  quantity: _quantities[product.id] ?? 0,
                                  onAdd: () => _changeQuantity(product, 1),
                                  onRemove: () => _changeQuantity(product, -1),
                                  onClear: () => setState(() => _quantities[product.id] = 0),
                                ),
                              // Con pocos productos, la pantalla recuerda cómo sumar más al catálogo.
                              if (products.length <= 2) _EmptyHint(hasProducts: products.isNotEmpty),
                            ],
                          ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (widget.yapePayment == null)
                    _PaymentMethodPicker(
                      selected: _paymentMethod,
                      onChanged: _isSubmitting ? null : (method) => setState(() => _paymentMethod = method),
                    ),
                  _TotalBar(
                    total: _totalFor(products),
                    units: units,
                    isSubmitting: _isSubmitting,
                    onSubmit: (hasItems && !_isSubmitting) ? _submit : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _cents(double value) => (value * 100).round();

/// Métodos de pago que puede elegir el emprendedor al registrar una venta.
const paymentMethods = <({String id, String label, IconData icon})>[
  (id: 'efectivo', label: 'Efectivo', icon: Icons.payments_outlined),
  (id: 'yape', label: 'Yape', icon: Icons.qr_code_2_rounded),
  (id: 'plin', label: 'Plin', icon: Icons.phone_android_rounded),
];

/// Fila "¿Cómo pagó?" con Efectivo / Yape / Plin.
class _PaymentMethodPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String>? onChanged;

  const _PaymentMethodPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              '¿Cómo pagó el cliente?',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Row(
            children: [
              for (final method in paymentMethods) ...[
                if (method != paymentMethods.first) const SizedBox(width: 8),
                Expanded(
                  child: _PaymentMethodChip(
                    label: method.label,
                    icon: method.icon,
                    selected: method.id == selected,
                    onTap: onChanged == null ? null : () => onChanged!(method.id),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _PaymentMethodChip({required this.label, required this.icon, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.textSecondary;
    return Material(
      color: selected ? AppTheme.primary.withValues(alpha: 0.10) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border, width: selected ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Busca productos con stock que sumen exactamente [amount]: un producto (1 o varias
/// unidades) o dos productos distintos. Devuelve `productId → cantidad`, o null si nada cuadra.
Map<String, int>? suggestProductsForAmount(double amount, List<Product> products) {
  final target = _cents(amount);
  if (target <= 0) return null;
  final available = products.where((p) => p.stock > 0 && _cents(p.price) > 0).toList();

  for (final p in available) {
    if (_cents(p.price) == target) return {p.id: 1};
  }
  for (final p in available) {
    final price = _cents(p.price);
    final units = target ~/ price;
    if (target % price == 0 && units <= p.stock && units <= 20) return {p.id: units};
  }
  for (var i = 0; i < available.length; i++) {
    for (var j = i + 1; j < available.length; j++) {
      if (_cents(available[i].price) + _cents(available[j].price) == target) {
        return {available[i].id: 1, available[j].id: 1};
      }
    }
  }
  return null;
}

/// Cabecera morada con el cobro de Yape y cuánto falta para que la venta cuadre.
class _YapeBanner extends StatelessWidget {
  static const yapePurple = Color(0xFF742284);
  static const plinTeal = Color(0xFF00A19B);

  final YapePayment payment;
  final double total;
  final String? suggestion;

  const _YapeBanner({required this.payment, required this.total, this.suggestion});

  @override
  Widget build(BuildContext context) {
    final amount = payment.amount;
    final brand = payment.isPlin ? plinTeal : yapePurple;
    final method = payment.methodLabel;
    final (IconData icon, Color color, String text) = switch (amount) {
      null => (Icons.info_outline_rounded, AppTheme.textSecondary, 'No se pudo leer el monto del $method.'),
      _ when total == 0 => (Icons.touch_app_outlined, AppTheme.textSecondary, 'Elige los productos que te pagaron.'),
      final a when _cents(total) == _cents(a) => (
        Icons.check_circle_rounded,
        const Color(0xFF16A34A),
        'El total coincide con el $method',
      ),
      final a when total < a => (
        Icons.error_outline_rounded,
        const Color(0xFFD97706),
        'Faltan ${formatMoney(a - total)} para cuadrar',
      ),
      final a => (
        Icons.error_outline_rounded,
        const Color(0xFFDC2626),
        'Supera al $method por ${formatMoney(total - a)}',
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brand.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  payment.isPlin ? 'P' : 'Y',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.displaySender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    Text('te pagó con $method', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Text(
                amount == null ? '—' : formatMoney(amount),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brand),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (suggestion != null) ...[
            const SizedBox(height: 6),
            Text(
              'Sugerido por el monto: $suggestion',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Aviso que aparece al registrar una venta que deja productos con poco stock.
class _StockAlertsDialog extends StatelessWidget {
  final List<String> messages;

  const _StockAlertsDialog({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(color: Color(0xFFE6EFFE), shape: BoxShape.circle),
                        child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 30),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Alertas de stock',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Varias alertas se desplazan dentro del aviso en vez de estirarlo fuera de la pantalla.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final message in messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          message,
                          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.45),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                // El tema pide ancho completo (Size.fromHeight); aquí el botón va a la derecha.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;

  const _Blob({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SaleProductCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onClear;

  const _SaleProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final inStock = product.stock > 0;
    final selected = quantity > 0;
    final name = product.name.isEmpty ? product.name : product.name[0].toUpperCase() + product.name.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppTheme.primary.withValues(alpha: 0.5) : Colors.transparent, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          ProductImage(url: product.imageUrl, size: 68, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'S/ ${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: inStock ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        inStock ? '${product.stock} ${product.stock == 1 ? 'disponible' : 'disponibles'}' : 'Sin stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF1F5FB), borderRadius: BorderRadius.circular(24)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundButton(icon: Icons.remove_rounded, onTap: quantity > 0 ? onRemove : null),
                SizedBox(
                  width: 26,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                _RoundButton(icon: Icons.add_rounded, onTap: quantity < product.stock ? onAdd : null),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: const Color(0xFFFDECEC),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Quitar de la venta',
              icon: const Icon(Icons.delete_outline_rounded),
              color: const Color(0xFFDC2626),
              disabledColor: const Color(0xFFDC2626).withValues(alpha: 0.35),
              onPressed: quantity > 0 ? onClear : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? const Color(0xFFDCE8FD) : const Color(0xFFE7ECF3),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppTheme.primary : AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final bool hasProducts;

  const _EmptyHint({required this.hasProducts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 12),
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(80),
                  ),
                ),
                Icon(Icons.shopping_cart_outlined, size: 92, color: AppTheme.primary.withValues(alpha: 0.85)),
                Positioned(
                  right: 44,
                  bottom: 22,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary,
                      child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasProducts ? '¿Vendes algo más?' : '¡Sé el primero en\nagregar productos!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasProducts
                ? 'Agrega más productos desde la pestaña Productos\ny aparecerán aquí para venderlos.'
                : 'Crea los productos de tu tienda en la pestaña\nProductos y agrégalos a la venta.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  final double total;
  final int units;
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  const _TotalBar({required this.total, required this.units, required this.isSubmitting, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: AppTheme.navy.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: const Color(0xFFE6EFFE), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    units == 0 ? 'Total' : 'Total ($units unid.)',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'S/ ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 44, color: AppTheme.border),
            const SizedBox(width: 12),
            FilledButton.icon(
              // El tema pide ancho completo (Size.fromHeight); dentro de un Row eso es infinito.
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: onSubmit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.point_of_sale_rounded),
              label: const Text('Registrar venta'),
            ),
          ],
        ),
      ),
    );
  }
}
