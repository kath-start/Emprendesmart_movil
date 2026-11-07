import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../models/yape_payment.dart';
import '../sales/new_sale_screen.dart';
import '../sales/sale_detail_screen.dart';
import 'yape_provider.dart';

const _yapePurple = Color(0xFF742284);
const _plinTeal = Color(0xFF00A19B);

/// Cobros recibidos por Yape o Plin: los pendientes se convierten en venta eligiendo los productos.
class YapePaymentsScreen extends StatefulWidget {
  final String businessId;

  const YapePaymentsScreen({super.key, required this.businessId});

  @override
  State<YapePaymentsScreen> createState() => _YapePaymentsScreenState();
}

class _YapePaymentsScreenState extends State<YapePaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<YapeProvider>();
      provider.refreshPermission();
      provider.sync();
    });
  }

  void _assign(YapePayment payment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewSaleScreen(businessId: widget.businessId, yapePayment: payment),
      ),
    );
  }

  void _openSale(YapePayment payment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SaleDetailScreen(businessId: payment.businessId ?? widget.businessId, saleId: payment.saleId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YapeProvider>();
    final pending = provider.pending;
    final history = provider.history;

    return Scaffold(
      appBar: AppBar(title: const Text('Cobros Yape y Plin')),
      body: RefreshIndicator(
        onRefresh: provider.sync,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (!YapeProvider.isSupported)
              const _InfoCard(
                icon: Icons.phone_android_rounded,
                title: 'Disponible en Android',
                message: 'La lectura automática de Yape y Plin funciona en celulares Android.',
              )
            else if (!provider.isListenerEnabled)
              _EnableCard(onEnable: provider.openListenerSettings)
            else
              const _InfoCard(
                icon: Icons.notifications_active_outlined,
                title: 'Leyendo tus Yapes y Plines',
                message:
                    'Cada pago que recibas aparece aquí, aunque la app esté cerrada. '
                    'Asígnale los productos y quedará registrado como venta.',
              ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Por asignar', count: pending.length),
            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No tienes cobros pendientes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            for (final payment in pending)
              _PaymentCard(
                payment: payment,
                trailing: PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  onSelected: (_) => provider.ignore(payment.id),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'ignore', child: Text('No es una venta (ignorar)'))],
                ),
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _yapePurple,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _assign(payment),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Asignar productos'),
                ),
              ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionTitle(title: 'Historial', count: history.length),
              for (final payment in history)
                _PaymentCard(
                  payment: payment,
                  onTap: payment.saleId != null ? () => _openSale(payment) : null,
                  trailing: payment.status == YapePaymentStatus.ignored
                      ? TextButton(onPressed: () => provider.restore(payment.id), child: const Text('Restaurar'))
                      : const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnableCard extends StatelessWidget {
  final VoidCallback onEnable;

  const _EnableCard({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF8E2DA0), _yapePurple]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_off_outlined, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Activa la lectura de Yape y Plin',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Dale a EmprendeSmart acceso a las notificaciones para registrar cada Yape o Plin que recibas. '
            'Solo se leen los avisos de pagos recibidos (Yape y la app de tu banco para Plin).',
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _yapePurple,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onEnable,
            child: const Text('Activar en Ajustes', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Busca "EmprendeSmart · Cobros Yape" y actívalo.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoCard({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF4ECF6), borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _yapePurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _yapePurple, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: AppTheme.textPrimary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        '$title ($count)',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final YapePayment payment;
  final Widget? trailing;
  final Widget? action;
  final VoidCallback? onTap;

  const _PaymentCard({required this.payment, this.trailing, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (String statusText, Color statusColor) = switch (payment.status) {
      YapePaymentStatus.pending => ('Por asignar', const Color(0xFFD97706)),
      YapePaymentStatus.linked => ('Venta registrada', const Color(0xFF16A34A)),
      YapePaymentStatus.ignored => ('Ignorado', AppTheme.textSecondary),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: payment.isPlin ? _plinTeal : _yapePurple,
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${_timeAgo(payment.receivedAt)} · $statusText',
                          style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    payment.amount == null ? '—' : '+ ${formatMoney(payment.amount!)}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F9A72)),
                  ),
                  ?trailing,
                ],
              ),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'ayer';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
