import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/inventory_movement.dart';
import '../../models/product.dart';
import '../businesses/business_provider.dart';
import 'product_form_screen.dart';
import 'product_provider.dart';
import 'widgets/product_widgets.dart';

/// RESTOCK/RETURN llegan como magnitud positiva (siempre suman), SALE como
/// magnitud positiva que resta, y ADJUSTMENT ya viene con el signo real.
int _movementDelta(InventoryMovement movement) {
  switch (movement.type) {
    case 'SALE':
      return -movement.quantity.abs();
    case 'ADJUSTMENT':
      return movement.quantity;
    default:
      return movement.quantity.abs();
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

class ProductDetailScreen extends StatefulWidget {
  final String businessId;
  final Product product;

  const ProductDetailScreen({super.key, required this.businessId, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  List<InventoryMovement>? _movements;
  bool _showAllMovements = false;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    final movements = await context.read<ProductProvider>().listMovements(widget.businessId, widget.product.id);
    if (mounted) setState(() => _movements = movements);
  }

  Future<void> _editProduct(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(businessId: widget.businessId, product: product),
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar producto?',
      message: 'Vas a eliminar **${product.name}** de tu catálogo.',
      warning: 'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ProductProvider>().deleteProduct(widget.businessId, product.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  /// Entrada: reposición o devolución (suman). Salida: ajuste negativo (merma, uso interno, pérdida...).
  Future<void> _openMovementSheet(Product product, {required bool isEntry}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MovementSheet(businessId: widget.businessId, product: product, isEntry: isEntry),
    );
    if (saved == true) {
      await _loadMovements();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(isEntry ? 'Entrada registrada' : 'Salida registrada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final product = products.firstWhere((p) => p.id == widget.product.id, orElse: () => widget.product);
    final business = context.watch<BusinessProvider>().currentBusiness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de producto'),
        actions: [
          if (business?.canManageProducts ?? false)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar producto',
              onPressed: () => _editProduct(product),
            ),
          // Solo el dueño puede eliminar productos.
          if (business?.canDeleteProducts ?? false)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar producto',
              onPressed: () => _confirmDelete(product),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMovements,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _HeroCard(product: product),
            const SizedBox(height: 14),
            _InfoCard(product: product),
            const SizedBox(height: 14),
            _MovementsCard(
              movements: _movements,
              showAll: _showAllMovements,
              onToggleAll: () => setState(() => _showAllMovements = !_showAllMovements),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.3),
                  ),
                  onPressed: () => _openMovementSheet(product, isEntry: true),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Registrar entrada'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: product.stock > 0 ? () => _openMovementSheet(product, isEntry: false) : null,
                  icon: const Icon(Icons.outbox_outlined),
                  label: const Text('Registrar salida'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Product product;

  const _HeroCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final category = product.category;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEAF2FF), Color(0xFFD6E6FF)],
                    ),
                  ),
                  child: ProductImage(url: product.imageUrl, size: 128, radius: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.15,
                        ),
                      ),
                      if (product.description != null && product.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary, height: 1.3),
                        ),
                      ],
                      const SizedBox(height: 10),
                      StockBadge(level: stockLevelOf(product)),
                      if (category != null && category.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.category_outlined, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  category,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatTile(
                  icon: Icons.sell_outlined,
                  color: AppTheme.primary,
                  label: 'Precio',
                  value: _money(product.price),
                ),
                const SizedBox(width: 10),
                _StatTile(
                  icon: Icons.savings_outlined,
                  color: const Color(0xFF8B5CF6),
                  label: 'Costo',
                  value: product.cost == null ? '—' : _money(product.cost!),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatTile(
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF16A34A),
                  label: 'Stock actual',
                  value: '${product.stock}',
                ),
                const SizedBox(width: 10),
                _StatTile(
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFF59E0B),
                  label: 'Alerta de stock bajo',
                  value: '${product.lowStockThreshold}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
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

class _InfoCard extends StatelessWidget {
  final Product product;

  const _InfoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final margin = product.cost == null ? null : product.price - product.cost!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardTitle(icon: Icons.description_outlined, title: 'Información del producto'),
            const Divider(height: 20),
            _InfoRow(icon: Icons.category_outlined, label: 'Categoría', value: product.category ?? '—'),
            _InfoRow(icon: Icons.straighten_rounded, label: 'Unidad', value: product.unit ?? '—'),
            if (margin != null)
              _InfoRow(
                icon: Icons.trending_up_rounded,
                label: 'Ganancia por unidad',
                value: _money(margin),
                valueColor: margin >= 0 ? const Color(0xFF16A34A) : Theme.of(context).colorScheme.error,
              ),
            _InfoRow(icon: Icons.toggle_on_outlined, label: 'Estado', value: Labels.status(product.status)),
            _InfoRow(
              icon: Icons.qr_code_2_rounded,
              label: 'Código de barras',
              value: product.sku ?? '—',
              trailing: product.sku == null
                  ? null
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Copiar código',
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: product.sku!));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado')));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.navy),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: trailing == null ? 8 : 0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: valueColor ?? AppTheme.textPrimary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _MovementsCard extends StatelessWidget {
  final List<InventoryMovement>? movements;
  final bool showAll;
  final VoidCallback onToggleAll;

  const _MovementsCard({required this.movements, required this.showAll, required this.onToggleAll});

  static const _previewCount = 5;

  @override
  Widget build(BuildContext context) {
    final items = movements;
    final visible = items == null ? const <InventoryMovement>[] : (showAll ? items : items.take(_previewCount));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.bar_chart_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Movimientos de inventario',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Historial de entradas y salidas de este producto.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (items == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Sin movimientos todavía.', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else ...[
              for (final movement in visible) _MovementTile(movement: movement),
              if (items.length > _previewCount)
                TextButton(onPressed: onToggleAll, child: Text(showAll ? 'Ver menos' : 'Ver todos (${items.length})')),
            ],
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final InventoryMovement movement;

  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final delta = _movementDelta(movement);
    final isIn = delta >= 0;
    final color = isIn ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
    final details = [
      if (movement.note != null && movement.note!.isNotEmpty) movement.note!,
      _formatDate(movement.occurredAt),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(isIn ? Icons.south_west_rounded : Icons.north_east_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Labels.movementType(movement.type),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            isIn ? '+$delta' : '$delta',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _MovementSheet extends StatefulWidget {
  final String businessId;
  final Product product;
  final bool isEntry;

  const _MovementSheet({required this.businessId, required this.product, required this.isEntry});

  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  String _entryType = 'RESTOCK';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final quantity = int.parse(_quantityController.text);
    final note = _noteController.text.trim();
    try {
      await context.read<ProductProvider>().createMovement(
        widget.businessId,
        widget.product.id,
        type: widget.isEntry ? _entryType : 'ADJUSTMENT',
        quantity: widget.isEntry ? quantity : -quantity,
        note: note.isEmpty ? null : note,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEntry = widget.isEntry;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEntry ? 'Registrar entrada' : 'Registrar salida',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              isEntry
                  ? 'Suma unidades al stock de "${widget.product.name}".'
                  : 'Resta unidades del stock (merma, pérdida, uso interno). Las ventas se registran en "Registrar venta".',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            if (isEntry) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'RESTOCK', label: Text('Reposición'), icon: Icon(Icons.local_shipping_outlined)),
                  ButtonSegment(value: 'RETURN', label: Text('Devolución'), icon: Icon(Icons.undo_rounded)),
                ],
                selected: {_entryType},
                onSelectionChanged: (value) => setState(() => _entryType = value.first),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _quantityController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Cantidad',
                prefixIcon: Icon(isEntry ? Icons.add_rounded : Icons.remove_rounded),
                helperText: isEntry ? null : 'Stock disponible: ${widget.product.stock}',
              ),
              validator: (value) {
                final quantity = int.tryParse(value ?? '');
                if (quantity == null || quantity <= 0) return 'Ingresa una cantidad mayor a 0';
                if (!isEntry && quantity > widget.product.stock) return 'No puede superar el stock actual';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: isEntry ? 'Nota (opcional)' : 'Motivo (opcional)',
                counterText: '',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEntry ? 'Guardar entrada' : 'Guardar salida'),
            ),
          ],
        ),
      ),
    );
  }
}
