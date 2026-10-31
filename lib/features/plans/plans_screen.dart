import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';
import 'plan_checkout_screen.dart';

class _Plan {
  final String code;
  final String name;
  final String tagline;
  final String price;
  final String period;
  final IconData icon;
  final Color color;
  final List<String> features;
  final String? promotions;
  final bool recommended;

  const _Plan({
    required this.code,
    required this.name,
    required this.tagline,
    required this.price,
    this.period = '/mes',
    required this.icon,
    required this.color,
    required this.features,
    this.promotions,
    this.recommended = false,
  });
}

/// Catálogo de planes. Los códigos coinciden con el enum `PlanType` del backend.
const _plans = [
  _Plan(
    code: 'FREE',
    name: 'Gratis',
    tagline: 'Para empezar y conocer EmprendeSmart.',
    price: 'S/ 0',
    period: '',
    icon: Icons.rocket_launch_outlined,
    color: Color(0xFF64748B),
    features: [
      'Crear tu cuenta de negocio',
      'Registrar productos',
      'Registrar ventas',
      'Ver ventas y métricas básicas',
      'Controlar tu inventario',
      'Alertas básicas de stock',
      'Asistente de IA: 5 consultas al día',
    ],
    promotions: '1 promoción gratuita al mes, visible dentro de EmprendeSmart',
  ),
  _Plan(
    code: 'EMPRENDE',
    name: 'Emprende',
    tagline: 'Para negocios que necesitan más capacidad.',
    price: 'S/ 19.90',
    icon: Icons.storefront_outlined,
    color: Color(0xFF10B981),
    features: [
      'Todo lo del plan Gratis',
      'Asistente de IA: 20 consultas al día',
      'Más productos',
      'Reportes',
      'Alertas',
    ],
    promotions: '3 promociones al mes con mayor visibilidad',
  ),
  _Plan(
    code: 'CRECIMIENTO',
    name: 'Crecimiento',
    tagline: 'Para negocios que quieren aprovechar la IA y el análisis.',
    price: 'S/ 39.90',
    icon: Icons.trending_up_rounded,
    color: AppTheme.primary,
    features: [
      'Todo lo del plan Emprende',
      'Asistente de IA sin límite y recomendaciones',
      'Simulaciones',
      'Reportes avanzados',
      'Alertas inteligentes',
    ],
    promotions: '10 promociones al mes con mayor alcance y sugerencias de qué productos promocionar',
    recommended: true,
  ),
  _Plan(
    code: 'PRO',
    name: 'Pro',
    tagline: 'Para negocios con mayor volumen y varios usuarios.',
    price: 'S/ 69.90',
    icon: Icons.workspace_premium_outlined,
    color: Color(0xFF7C3AED),
    features: [
      'Todas las funciones',
      'Análisis avanzado',
      'Tu equipo: hasta 5 personas (socio y cajero)',
      'Mayor capacidad',
    ],
  ),
];

/// Planes de EmprendeSmart y sus beneficios. Los planes de pago se cobran por Yape.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  void _choose(BuildContext context, _Plan plan) {
    if (plan.code == 'FREE') {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Plan Gratis'),
          content: const Text('Para volver al plan Gratis, escríbenos y te ayudamos con el cambio.'),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanCheckoutScreen(planCode: plan.code, planName: plan.name, color: plan.color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Se lee del perfil para que "Tu plan" cambie apenas se confirma un pago.
    final currentPlan = context.watch<AuthProvider>().entrepreneur?.plan;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final plan in _plans) ...[
                    _PlanCard(plan: plan, isCurrent: plan.code == currentPlan, onChoose: () => _choose(context, plan)),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedBottomClipper(),
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 8, 16, 36),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planes',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Elige el plan que mejor acompaña el crecimiento de tu negocio.',
                      style: TextStyle(color: Color(0xFFDCE8FF), height: 1.3),
                    ),
                  ],
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

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool isCurrent;
  final VoidCallback onChoose;

  const _PlanCard({required this.plan, required this.isCurrent, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final highlighted = isCurrent || plan.recommended;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlighted ? plan.color : AppTheme.border, width: highlighted ? 2 : 1),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: plan.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(plan.icon, color: plan.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
              if (isCurrent)
                _Tag(label: 'Tu plan', color: plan.color)
              else if (plan.recommended)
                _Tag(label: 'Recomendado', color: plan.color),
            ],
          ),
          const SizedBox(height: 10),
          Text(plan.tagline, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.3)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.price,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              if (plan.period.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 5),
                  child: Text(plan.period, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final feature in plan.features) _FeatureLine(text: feature, color: plan.color),
          if (plan.promotions != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: plan.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign_outlined, color: plan.color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(plan.promotions!, style: const TextStyle(color: AppTheme.textPrimary, height: 1.3)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (isCurrent)
            OutlinedButton(onPressed: null, child: const Text('Plan actual'))
          else
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: plan.color),
              onPressed: onChoose,
              child: Text('Elegir ${plan.name}'),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final String text;
  final Color color;

  const _FeatureLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
