import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/business.dart';
import '../assistant/assistant_screen.dart';
import '../businesses/business_provider.dart';
import '../products/product_provider.dart';
import 'idea_step_screens.dart';

/// Contenido del Inicio mientras el negocio está en etapa IDEA: en vez de ventas y gráficos,
/// un plan por pasos para lanzar el negocio, el asistente en modo idea y el paso a "Inicio".
class IdeaDashboard extends StatefulWidget {
  final Business business;
  final VoidCallback onOpenProducts;

  const IdeaDashboard({super.key, required this.business, required this.onOpenProducts});

  @override
  State<IdeaDashboard> createState() => _IdeaDashboardState();
}

class _IdeaDashboardState extends State<IdeaDashboard> {
  bool _changingStage = false;

  @override
  void initState() {
    super.initState();
    // El paso "primeros productos" se completa cuando el negocio ya tiene alguno.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProductProvider>().loadProducts(widget.business.id);
    });
  }

  Future<void> _open(Widget screen) =>
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _markFirstSale() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¡Felicidades! 🎉',
      message:
          'Tu negocio pasará a la etapa **Inicio**. Desde ahora verás tus ventas, ingresos y gráficos en el Inicio.',
      icon: Icons.celebration_rounded,
      destructive: false,
      confirmLabel: 'Sí, ya vendí',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _changingStage = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<BusinessProvider>().changeStage(widget.business.id, 'EARLY');
      messenger.showSnackBar(
        const SnackBar(content: Text('¡Bien hecho! Registra tus ventas desde "Registrar venta".')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _changingStage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final plan = business.ideaPlan;
    final hasProducts = context.watch<ProductProvider>().products.any((p) => p.businessId == business.id);

    final steps = [
      _Step(
        icon: Icons.person_search_rounded,
        color: const Color(0xFF7C3AED),
        title: 'Define a tu cliente',
        subtitle: 'A quién le vendes y qué problema le resuelves',
        done: plan.hasCustomer,
        onTap: () => _open(CustomerStepScreen(business: business)),
      ),
      _Step(
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF1A6FF0),
        title: 'Arma tus primeros productos',
        subtitle: 'Registra lo que vas a ofrecer, con foto y precio',
        done: hasProducts,
        onTap: widget.onOpenProducts,
      ),
      _Step(
        icon: Icons.sell_rounded,
        color: const Color(0xFF10B981),
        title: 'Calcula tu precio',
        subtitle: plan.suggestedPrice == null
            ? 'Costo + la ganancia que quieres = precio'
            : 'Precio sugerido: S/ ${plan.suggestedPrice!.toStringAsFixed(2)}',
        done: plan.hasPricing,
        onTap: () => _open(PricingStepScreen(business: business)),
      ),
      _Step(
        icon: Icons.savings_rounded,
        color: const Color(0xFFF59E0B),
        title: '¿Cuánto necesito para empezar?',
        subtitle: 'Tu inversión y cuánto vender para recuperarla',
        done: plan.hasInvestment,
        onTap: () => _open(InvestmentStepScreen(business: business)),
      ),
      _Step(
        icon: Icons.campaign_rounded,
        color: const Color(0xFFDB2777),
        title: 'Cómo vas a vender',
        subtitle: plan.hasChannels ? plan.channels.join(' · ') : 'WhatsApp, redes, ferias, tienda…',
        done: plan.hasChannels,
        onTap: () => _open(ChannelsStepScreen(business: business)),
      ),
    ];
    final completed = steps.where((step) => step.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressCard(completed: completed, total: steps.length),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Tu plan para lanzar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
        ),
        for (var i = 0; i < steps.length; i++) _StepTile(number: i + 1, step: steps[i]),
        const SizedBox(height: 6),
        _AssistantCard(onTap: () => _open(AssistantScreen(businessId: business.id, ideaMode: true))),
        if (business.isOwner) ...[
          const SizedBox(height: 16),
          _FirstSaleCard(loading: _changingStage, onTap: _markFirstSale),
        ],
      ],
    );
  }
}

class _Step {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  const _Step({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });
}

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressCard({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = completed / total;
    final message = switch (completed) {
      0 => 'Empieza por el primer paso: conocer a tu cliente.',
      _ when completed == total => '¡Plan completo! Ya estás listo para tu primera venta.',
      _ when progress >= 0.6 => '¡Vas muy bien! Te falta poco para lanzar.',
      _ => 'Buen comienzo. Sigue completando tu plan.',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2F7A), Color(0xFF1A6FF0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1A6FF0).withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                  ),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, color: Color(0xFFFDE68A), size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Tu idea en marcha',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed de $total pasos completados',
                  style: const TextStyle(color: Color(0xFFE3EDFF), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Color(0xFFE3EDFF), fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int number;
  final _Step step;

  const _StepTile({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: step.done ? const Color(0xFFA7F3D0) : AppTheme.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: step.onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(step.icon, color: step.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PASO $number',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: step.color,
                        ),
                      ),
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                step.done
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28)
                    : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBD5E1), size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AssistantCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8E6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFDE3A7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)]),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valida tu idea con IA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '"¿Es buena mi idea?", "Dame un plan para mi primer mes", nombres para tu negocio…',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF7C4A03), height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB45309)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstSaleCard extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _FirstSaleCard({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Ya empezaste a vender?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cuando hagas tu primera venta, pasa tu negocio a la etapa Inicio para ver tus ventas y gráficos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: loading ? null : onTap,
            icon: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.celebration_rounded),
            label: const Text('¡Ya hice mi primera venta!', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
