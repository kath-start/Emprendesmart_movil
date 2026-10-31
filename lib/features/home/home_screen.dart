import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../models/business.dart';
import '../../models/sales_insights.dart';
import '../../models/sales_summary.dart';
import '../assistant/assistant_screen.dart';
import '../auth/auth_provider.dart';
import '../businesses/business_provider.dart';
import '../businesses/businesses_screen.dart';
import '../businesses/widgets/business_logo.dart';
import '../products/products_screen.dart';
import '../sales/new_sale_screen.dart';
import '../sales/sale_service.dart';
import '../sales/sales_screen.dart';
import '../signals/signal_service.dart';
import '../signals/signals_screen.dart';
import '../idea/idea_dashboard.dart';
import 'more_screen.dart';
import 'widgets/sales_overview.dart';
import 'widgets/stage_panels.dart';

const _tabHome = 0;
const _tabProducts = 1;
const _tabSales = 2;
const _tabMore = 3;

/// Pantalla principal con barra de navegación inferior: Inicio, Productos, Ventas y Más.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = _tabHome;
  // Las pestañas se construyen la primera vez que se visitan, para no cargar todo al abrir la app.
  final Set<int> _visitedTabs = {_tabHome};
  // "Más" tiene su propio Navigator para que "Mi perfil" se abra sin ocultar la barra inferior.
  final _moreNavigatorKey = GlobalKey<NavigatorState>();

  void _goTo(int tab) {
    if (tab == _tabMore && _tab == _tabMore) {
      _moreNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    setState(() {
      _tab = tab;
      _visitedTabs.add(tab);
    });
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    if (business == null) {
      return const Scaffold(body: Center(child: Text('No se encontró un negocio activo.')));
    }

    // Quien atiende la caja solo usa Ventas y Más; el resto ve todas las pestañas.
    final tabs = business.canSeeDashboard
        ? const [_tabHome, _tabProducts, _tabSales, _tabMore]
        : const [_tabSales, _tabMore];
    final tab = tabs.contains(_tab) ? _tab : _tabSales;
    _visitedTabs.add(tab);

    Widget lazyTab(int index, Widget Function() builder) =>
        _visitedTabs.contains(index) && tabs.contains(index) ? builder() : const SizedBox.shrink();

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          lazyTab(
            _tabHome,
            () => _Dashboard(key: ValueKey('home-${business.id}'), business: business, onOpenTab: _goTo),
          ),
          lazyTab(
            _tabProducts,
            () => ProductsScreen(key: ValueKey('products-${business.id}'), businessId: business.id),
          ),
          lazyTab(_tabSales, () => SalesScreen(key: ValueKey('sales-${business.id}'), businessId: business.id)),
          lazyTab(
            _tabMore,
            () => NavigatorPopHandler<Object?>(
              enabled: tab == _tabMore,
              onPopWithResult: (_) => _moreNavigatorKey.currentState?.maybePop(),
              child: Navigator(
                key: _moreNavigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const MoreScreen()),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(tabs: tabs, currentIndex: tab, onTap: _goTo),
    );
  }
}

class _Dashboard extends StatefulWidget {
  final Business business;
  final ValueChanged<int> onOpenTab;

  const _Dashboard({super.key, required this.business, required this.onOpenTab});

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  bool _hasOpenAlerts = false;
  SalesSummary? _summary;
  bool _summaryFailed = false;
  SalesInsights? _insights;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al pasar de "Idea" a "Inicio" aparecen el resumen y los indicadores, que aún no se habían cargado.
    if (oldWidget.business.isIdea && !widget.business.isIdea) {
      _loadSummary();
      _loadInsights();
    }
  }

  Future<void> _refresh() => Future.wait([
    _loadAlerts(),
    if (!widget.business.isIdea) ...[_loadSummary(), _loadInsights()],
  ]);

  Future<void> _loadInsights() async {
    try {
      final insights = await SaleService(context.read<ApiClient>()).insights(widget.business.id);
      if (mounted) setState(() => _insights = insights);
    } catch (_) {
      // Los paneles por etapa son complementarios: si fallan, el inicio sigue mostrando lo demás.
    }
  }

  Future<void> _saveGoal(double? goal) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<BusinessProvider>().setSalesGoal(widget.business.id, goal);
      await _loadInsights();
      messenger.showSnackBar(SnackBar(content: Text(goal == null ? 'Meta eliminada' : '¡Meta guardada!')));
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _advanceTo(String stage) async {
    final label = Labels.businessStage(stage);
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Pasar a $label?',
      message: 'Tu inicio se adaptará a la etapa **$label**. Puedes cambiarla cuando quieras desde "Editar negocio".',
      icon: Icons.rocket_launch_rounded,
      destructive: false,
      confirmLabel: 'Sí, avanzar',
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<BusinessProvider>().changeStage(widget.business.id, stage);
      messenger.showSnackBar(SnackBar(content: Text('¡Felicidades! Tu negocio ahora está en $label 🎉')));
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Paneles propios de cada etapa (después del resumen de ventas de hoy).
  List<Widget> _stagePanels(Business business) {
    final insights = _insights;
    if (insights == null) return const [];
    final owner = business.isOwner;
    void openProducts() => widget.onOpenTab(_tabProducts);

    return switch (business.stage) {
      'EARLY' => [
        EarlyGoalsCard(
          insights: insights,
          canAdvance: owner,
          onAdvance: () => _advanceTo('GROWTH'),
          onOpenProducts: openProducts,
        ),
      ],
      'GROWTH' => [
        SalesGoalCard(insights: insights, canEdit: owner, onSave: _saveGoal),
        MonthComparisonCard(insights: insights),
        TopProductsCard(insights: insights),
      ],
      _ => [
        MonthSummaryCard(insights: insights),
        SalesGoalCard(insights: insights, canEdit: owner, onSave: _saveGoal),
        TopProductsCard(insights: insights),
        if (insights.sellers.length >= 2) SellersCard(insights: insights),
      ],
    };
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryFailed = false);
    try {
      final summary = await SaleService(context.read<ApiClient>()).summary(widget.business.id);
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(() => _summaryFailed = true);
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await SignalService(context.read<ApiClient>()).listAlerts(widget.business.id);
      if (!mounted) return;
      setState(() => _hasOpenAlerts = alerts.any((alert) => alert.status == null || alert.status == 'OPEN'));
    } catch (_) {
      // El punto rojo es solo un aviso; si falla la carga, simplemente no se muestra.
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final firstName = context.watch<AuthProvider>().entrepreneur?.firstName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              hasAlerts: _hasOpenAlerts,
              onAlerts: () => _push(SignalsScreen(businessId: business.id)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Greeting(
                    firstName: firstName,
                    business: business,
                    onBusinessTap: () => _push(const BusinessesScreen()),
                  ),
                  const SizedBox(height: 16),
                  // Un negocio que todavía es idea no vende: ve su plan de lanzamiento en vez de ventas.
                  if (business.isIdea)
                    IdeaDashboard(business: business, onOpenProducts: () => widget.onOpenTab(_tabProducts))
                  else ...[
                    SalesStatsCard(summary: _summary),
                    ..._stagePanels(business),
                    WeeklySalesChart(summary: _summary, failed: _summaryFailed, onRetry: _loadSummary),
                    if (business.stage == 'GROWTH' && business.isOwner && _insights != null)
                      NextStageCard(
                        title: '¿Tu negocio ya es estable?',
                        message:
                            'Si ya tienes clientes fijos y ventas constantes, pasa a Consolidado '
                            'para ver ganancias, ticket promedio y ventas por vendedor.',
                        buttonLabel: 'Pasar a Consolidado',
                        onTap: () => _advanceTo('ESTABLISHED'),
                      ),
                    _ActionCard(
                      icon: Icons.inventory_2_outlined,
                      colors: const [Color(0xFF3D8BFF), Color(0xFF1A6FF0)],
                      title: 'Ver productos',
                      subtitle: 'Consulta, edita y gestiona todos tus productos.',
                      onTap: () => widget.onOpenTab(_tabProducts),
                    ),
                    _ActionCard(
                      icon: Icons.point_of_sale_rounded,
                      colors: const [Color(0xFF34D399), Color(0xFF10B981)],
                      title: 'Registrar venta',
                      subtitle: 'Realiza ventas de forma rápida y sencilla.',
                      onTap: () => _push(NewSaleScreen(businessId: business.id)),
                    ),
                    _ActionCard(
                      icon: Icons.bar_chart_rounded,
                      colors: const [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                      title: 'Historial de ventas',
                      subtitle: 'Revisa tus ventas, ingresos y rendimiento.',
                      onTap: () => widget.onOpenTab(_tabSales),
                    ),
                    _ActionCard(
                      icon: Icons.notifications_rounded,
                      colors: const [Color(0xFFFF8A8A), Color(0xFFEF4444)],
                      title: 'Alertas y recomendaciones',
                      subtitle: 'Recibe alertas de stock y sugerencias de la IA para mejorar.',
                      onTap: () => _push(SignalsScreen(businessId: business.id)),
                    ),
                    _ActionCard(
                      icon: Icons.smart_toy_rounded,
                      colors: const [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                      title: 'Asistente de IA',
                      subtitle: 'Pregúntale a la IA, analiza tus datos y toma mejores decisiones.',
                      onTap: () => _push(AssistantScreen(businessId: business.id)),
                    ),
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
  final bool hasAlerts;
  final VoidCallback onAlerts;

  const _Header({required this.hasAlerts, required this.onAlerts});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedBottomClipper(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1F4D), Color(0xFF0B2F7A), Color(0xFF123C96)],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 8, 34),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset('assets/images/logo_icon_dark.png', width: 54, height: 54),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Se achica si no cabe (teléfonos con letra grande) en vez de partirse en dos líneas.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        children: [
                          TextSpan(
                            text: 'Emprende',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Smart',
                            style: TextStyle(color: AppTheme.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text('Tu negocio, en tus manos', style: TextStyle(color: Color(0xFFC9D6F2), fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Alertas',
              onPressed: onAlerts,
              icon: Badge(
                isLabelVisible: hasAlerts,
                smallSize: 10,
                backgroundColor: const Color(0xFFFF4D4F),
                child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
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
      ..lineTo(0, size.height - 22)
      ..quadraticBezierTo(size.width / 2, size.height + 6, size.width, size.height - 22)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Greeting extends StatelessWidget {
  final String? firstName;
  final Business business;
  final VoidCallback onBusinessTap;

  const _Greeting({required this.firstName, required this.business, required this.onBusinessTap});

  @override
  Widget build(BuildContext context) {
    final category = business.category;
    final businessDetail = [
      if (category.isNotEmpty) category[0].toUpperCase() + category.substring(1),
      Labels.businessStage(business.stage),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(color: Color(0xFFDDE8FB), shape: BoxShape.circle),
              child: BusinessLogo(
                logoUrl: business.logoUrl,
                fallback: const Icon(Icons.person_rounded, size: 36, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName == null ? '¡Hola!' : '¡Hola, $firstName!',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    business.isIdea
                        ? 'Sigue estos pasos para convertir tu idea en un negocio.'
                        : 'Aquí tienes un resumen de tu negocio de hoy y esta semana.',
                    style: const TextStyle(color: AppTheme.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onBusinessTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.storefront_outlined, color: AppTheme.textPrimary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          business.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        Text(businessDetail, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const Text('Cambiar', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1F4D).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                    ),
                    child: Icon(icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, height: 1.3)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final List<int> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomBar({required this.tabs, required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Inicio'),
    (icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded, label: 'Productos'),
    (icon: Icons.bar_chart_rounded, activeIcon: Icons.bar_chart_rounded, label: 'Ventas'),
    (icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Más'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1F4D).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final i in tabs)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(i),
                  child: _BottomBarItem(
                    icon: currentIndex == i ? _items[i].activeIcon : _items[i].icon,
                    label: _items[i].label,
                    selected: currentIndex == i,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _BottomBarItem({required this.icon, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.textSecondary;
    // La pestaña activa lleva una "píldora" azul claro de fondo.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE6EFFE) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? 28 : 0,
            height: 3,
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2)),
          ),
        ],
      ),
    );
  }
}
