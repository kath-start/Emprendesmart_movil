import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../assistant/assistant_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/profile_screen.dart';
import '../businesses/business_provider.dart';
import '../businesses/businesses_screen.dart';
import '../businesses/create_business_screen.dart';
import '../businesses/widgets/business_logo.dart';
import '../signals/signals_screen.dart';
import '../team/team_screen.dart';
import '../yape/yape_payments_screen.dart';

/// Pestaña "Más": cuenta, negocio y accesos secundarios.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Cerrar sesión?',
      message: 'Tendrás que volver a ingresar tu correo y contraseña para entrar.',
      icon: Icons.logout_rounded,
      destructive: false,
      confirmLabel: 'Salir',
    );
    if (confirmed == true && context.mounted) context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final entrepreneur = context.watch<AuthProvider>().entrepreneur;
    final business = context.watch<BusinessProvider>().currentBusiness;
    // Las pantallas secundarias cubren la barra inferior; "Mi perfil" se abre dentro de la pestaña y la conserva.
    void push(Widget screen) =>
        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => screen));
    void openProfile() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 16, 16, 24),
          children: [
            const Text(
              'Más',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 2),
            const Text(
              'Gestiona tu cuenta, negocios y configuraciones de la app.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 18),
            if (entrepreneur != null)
              _ProfileCard(
                name: entrepreneur.fullName,
                email: entrepreneur.email,
                plan: Labels.plan(entrepreneur.plan),
                logoUrl: business?.logoUrl,
                onTap: openProfile,
              ),
            _SectionHeader(
              icon: Icons.work_rounded,
              title: 'Negocio',
              actionLabel: (business?.isOwner ?? false) ? 'Gestiona tu negocio' : null,
              onAction: (business?.isOwner ?? false)
                  ? () => push(CreateBusinessScreen(existingBusiness: business))
                  : null,
            ),
            _Section(
              children: [
                _Option(
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF1A6FF0),
                  title: 'Cambiar de negocio',
                  subtitle: business == null
                      ? 'Elige con qué negocio trabajar'
                      : business.isShared
                      ? '${business.name} · ${business.role.label}'
                      : business.name,
                  onTap: () => push(const BusinessesScreen()),
                ),
                if (business != null && !business.isIdea)
                  _Option(
                    icon: Icons.qr_code_2_rounded,
                    color: const Color(0xFF742284),
                    title: 'Cobros Yape y Plin',
                    subtitle: 'Lee tus Yapes y Plines y conviértelos en ventas',
                    onTap: () => push(YapePaymentsScreen(businessId: business.id)),
                  ),
                if (business != null && business.isOwner) ...[
                  _Option(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF7C3AED),
                    title: 'Editar negocio',
                    subtitle: 'Modifica la información de tu negocio',
                    onTap: () => push(CreateBusinessScreen(existingBusiness: business)),
                  ),
                  _Option(
                    icon: Icons.groups_rounded,
                    color: const Color(0xFF0EA5E9),
                    title: 'Mi equipo',
                    subtitle: 'Invita a tu socio o a tu cajero(a)',
                    onTap: () => push(TeamScreen(business: business)),
                  ),
                ],
                if (business != null && business.canSeeInsights) ...[
                  _Option(
                    icon: Icons.notifications_rounded,
                    color: const Color(0xFFEF4444),
                    title: 'Alertas y recomendaciones',
                    subtitle: 'Mantente al día con las notificaciones',
                    onTap: () => push(SignalsScreen(businessId: business.id)),
                  ),
                  _Option(
                    icon: Icons.smart_toy_rounded,
                    color: const Color(0xFFF59E0B),
                    title: 'Asistente de IA',
                    subtitle: 'Resuelve tus dudas con inteligencia artificial',
                    onTap: () => push(AssistantScreen(businessId: business.id)),
                  ),
                ],
              ],
            ),
            _SectionHeader(
              icon: Icons.person_rounded,
              title: 'Cuenta',
              actionLabel: 'Tu información personal',
              onAction: openProfile,
            ),
            _Section(
              children: [
                _Option(
                  icon: Icons.person_outline_rounded,
                  color: const Color(0xFF10B981),
                  title: 'Mi perfil',
                  subtitle: 'Datos de tu cuenta y contraseña',
                  onTap: openProfile,
                ),
                _Option(
                  icon: Icons.logout_rounded,
                  color: const Color(0xFF64748B),
                  title: 'Cerrar sesión',
                  subtitle: 'Sal de tu cuenta de forma segura',
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String plan;
  final String? logoUrl;
  final VoidCallback onTap;

  const _ProfileCard({required this.name, required this.email, required this.plan, this.logoUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9DCFB)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F9FF), Color(0xFFDCE9FD)],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3D8BFF), Color(0xFF1A5FD8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: BusinessLogo(
                    logoUrl: logoUrl,
                    fallback: const Icon(Icons.person_rounded, color: Colors.white, size: 42),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6E6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium_rounded, size: 16, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Plan $plan',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.icon, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.navy, size: 26),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const Spacer(),
          if (actionLabel != null)
            Flexible(
              flex: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          actionLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;

  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
