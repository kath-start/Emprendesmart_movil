import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/labels.dart';
import '../auth/auth_provider.dart';
import 'plan_checkout_screen.dart';
import 'plans_screen.dart';

/// Aviso en Inicio cuando el plan está por vencer (5 días o menos) o ya venció.
/// Lleva directo al pago con el QR de Yape para renovar.
class PlanExpiryBanner extends StatelessWidget {
  static const _warnDays = 5;
  static const _graceDays = 3;

  const PlanExpiryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final entrepreneur = context.watch<AuthProvider>().entrepreneur;
    final daysLeft = entrepreneur?.planDaysLeft;
    if (entrepreneur == null || entrepreneur.isFreePlan || daysLeft == null || daysLeft > _warnDays) {
      return const SizedBox.shrink();
    }

    final planName = Labels.plan(entrepreneur.plan);
    final expired = daysLeft < 0;
    final color = expired || daysLeft <= 1 ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final title = switch (daysLeft) {
      < 0 => 'Tu plan $planName venció',
      0 => 'Tu plan $planName vence hoy',
      1 => 'Tu plan $planName vence mañana',
      _ => 'Tu plan $planName vence en $daysLeft días',
    };
    final graceLeft = _graceDays + daysLeft;
    final message = expired
        ? 'Renuévalo ${graceLeft <= 0 ? 'hoy' : 'en los próximos $graceLeft ${graceLeft == 1 ? 'día' : 'días'}'} o tu cuenta pasará al plan Gratis.'
        : 'Renuévalo con Yape para seguir usando todas sus funciones.';

    void renew() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PlanCheckoutScreen(planCode: entrepreneur.plan, planName: planName, color: planColor(entrepreneur.plan)),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppTheme.textPrimary, height: 1.35)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: renew,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Renovar con Yape'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen())),
                child: const Text('Ver planes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
