import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/product.dart';
import '../scanner/barcode_scanner_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'product_provider.dart';
import 'widgets/product_widgets.dart';

enum _StockFilter { all, inStock, low, out }

const _filterLabels = {
  _StockFilter.all: 'Todos',
  _StockFilter.inStock: 'En stock',
  _StockFilter.low: 'Stock bajo',
  _StockFilter.out: 'Sin stock',
};

class ProductsScreen extends StatefulWidget {
  final String businessId;

  const ProductsScreen({super.key, required this.businessId});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _StockFilter _filter = _StockFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(widget.businessId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Escanea un empaque: abre el producto si ya existe, o propone crearlo con ese código.
  Future<void> _scanProduct() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final navigator = Navigator.of(context);
    final product = context.read<ProductProvider>().findByBarcode(code);
    if (product != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(businessId: widget.businessId, product: product),
        ),
      );
      return;
    }
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Producto no registrado'),
        content: Text('No tienes ningún producto con el código $code. ¿Quieres crearlo?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Crear producto')),
        ],
      ),
    );
    if (create != true || !mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(businessId: widget.businessId, initialSku: code),
      ),
    );
  }

  bool _matches(Product product) {
    final level = stockLevelOf(product);
    final passesFilter = switch (_filter) {
      _StockFilter.all => true,
      _StockFilter.inStock => level == StockLevel.inStock,
      // Incluye los agotados: también necesitan reposición.
      _StockFilter.low => level != StockLevel.inStock,
      _StockFilter.out => level == StockLevel.out,
    };
    if (!passesFilter) return false;
    if (_query.isEmpty) return true;
    final query = _query.toLowerCase();
    return product.name.toLowerCase().contains(query) ||
        (product.category?.toLowerCase().contains(query) ?? false) ||
        (product.sku?.contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.products;
    final visible = products.where(_matches).toList();
    final inStockCount = products.where((p) => stockLevelOf(p) == StockLevel.inStock).length;
    final lowCount = products.where((p) => stockLevelOf(p) != StockLevel.inStock).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => context.read<ProductProvider>().loadProducts(widget.businessId),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _Header(onScan: _scanProduct),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => _query = value.trim()),
                            decoration: InputDecoration(
                              hintText: 'Buscar producto...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(() {
                                        _searchController.clear();
                                        _query = '';
                                      }),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterButton(value: _filter, onChanged: (value) => setState(() => _filter = value)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.inventory_2_outlined,
                          color: AppTheme.primary,
                          label: 'Total',
                          value: products.length,
                          selected: _filter == _StockFilter.all,
                          onTap: () => setState(() => _filter = _StockFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF16A34A),
                          label: 'En stock',
                          value: inStockCount,
                          selected: _filter == _StockFilter.inStock,
                          onTap: () => setState(() => _filter = _StockFilter.inStock),
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: Icons.error_rounded,
                          color: const Color(0xFFEF4444),
                          label: 'Stock bajo',
                          value: lowCount,
                          selected: _filter == _StockFilter.low,
                          onTap: () => setState(() => _filter = _StockFilter.low),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (productProvider.isLoading && products.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (products.isEmpty)
                      const _EmptyMessage(
                        icon: Icons.inventory_2_outlined,
                        text: 'Aún no tienes productos.\nToca + para crear el primero o escanea un código de barras.',
                      )
                    else if (visible.isEmpty)
                      const _EmptyMessage(icon: Icons.search_off_rounded, text: 'Ningún producto coincide.')
                    else
                      for (final product in visible) _ProductCard(businessId: widget.businessId, product: product),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Nuevo producto',
          // Productos y Ventas conviven en pestañas; sin esto sus botones comparten animación y chocan.
          heroTag: null,
          shape: const CircleBorder(),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => ProductFormScreen(businessId: widget.businessId))),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onScan;

  const _Header({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return ClipPath(
      clipper: _CurvedBottomClipper(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A6FF0), Color(0xFF0D47C9)],
          ),
        ),
        padding: EdgeInsets.fromLTRB(canPop ? 4 : 16, MediaQuery.paddingOf(context).top + 12, 16, 34),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canPop)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 4, right: 12),
                child: Icon(Icons.inventory_2_outlined, color: Colors.white, size: 36),
              ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productos',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Administra tu inventario y mantén tu negocio siempre en control.',
                    style: TextStyle(color: Color(0xFFDCE8FF), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onScan,
                child: const Tooltip(
                  message: 'Escanear código de barras',
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurvedBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 20)
      ..quadraticBezierTo(size.width / 2, size.height + 4, size.width, size.height - 20)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FilterButton extends StatelessWidget {
  final _StockFilter value;
  final ValueChanged<_StockFilter> onChanged;

  const _FilterButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_StockFilter>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final entry in _filterLabels.entries) PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_outlined, color: AppTheme.primary, size: 22),
            const SizedBox(width: 6),
            Text(
              _filterLabels[value]!,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? color.withValues(alpha: 0.5) : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            // Número arriba y etiqueta abajo: así la etiqueta tiene todo el ancho y no se corta.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      '$value',
                      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String businessId;
  final Product product;

  const _ProductCard({required this.businessId, required this.product});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (product.category != null && product.category!.isNotEmpty) product.category!,
      if (product.unit != null && product.unit!.isNotEmpty) product.unit!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(businessId: businessId, product: product),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProductImage(url: product.imageUrl, size: 76),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      'S/ ${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StockBadge(level: stockLevelOf(product)),
                  const SizedBox(height: 8),
                  Text(
                    '${product.stock} en stock',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
