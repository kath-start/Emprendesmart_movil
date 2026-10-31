import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale.dart';
import 'sale_provider.dart';

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
    _saleFuture = context.read<SaleProvider>().getSaleById(widget.businessId, widget.saleId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de venta')),
      body: FutureBuilder<Sale>(
        future: _saleFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('No se pudo cargar la venta: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final sale = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Total: S/ ${sale.total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
              if (sale.sellerName != null) ...[
                const SizedBox(height: 4),
                Text('Vendió: ${sale.sellerName}', style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (sale.notes != null && sale.notes!.isNotEmpty) ...[const SizedBox(height: 8), Text(sale.notes!)],
              const SizedBox(height: 16),
              const Divider(),
              ...sale.items.map(
                (item) => ListTile(
                  title: Text(item.productName ?? 'Producto'),
                  subtitle: Text('${item.quantity} x S/ ${item.unitPrice.toStringAsFixed(2)}'),
                  trailing: Text('S/ ${item.subtotal.toStringAsFixed(2)}'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
