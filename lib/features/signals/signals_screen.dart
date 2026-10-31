import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/labels.dart';
import '../../models/alert.dart';
import '../../models/recommendation.dart';
import '../businesses/business_provider.dart';
import '../plans/plans_screen.dart';
import 'signal_service.dart';

const _green = Color(0xFF16A34A);
const _purple = Color(0xFF7C3AED);

Color _severityColor(String severity) => switch (severity) {
  'CRITICAL' => const Color(0xFFDC2626),
  'WARNING' => const Color(0xFFF59E0B),
  _ => AppTheme.primary,
};

IconData _severityIcon(String severity) => switch (severity) {
  'CRITICAL' => Icons.error_rounded,
  'WARNING' => Icons.warning_amber_rounded,
  _ => Icons.info_rounded,
};

Color _priorityColor(String priority) => switch (priority) {
  'HIGH' => const Color(0xFFDC2626),
  'MEDIUM' => const Color(0xFFF59E0B),
  _ => AppTheme.textSecondary,
};

String _priorityLabel(String priority) => switch (priority) {
  'HIGH' => 'Prioridad alta',
  'MEDIUM' => 'Prioridad media',
  _ => 'Prioridad baja',
};

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

/// Alertas del negocio (stock bajo, caídas de ingresos…) y recomendaciones para hacerlo crecer.
class SignalsScreen extends StatefulWidget {
  final String businessId;

  const SignalsScreen({super.key, required this.businessId});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  late final SignalService _signalService = SignalService(context.read<ApiClient>());
  List<Alert>? _alerts;
  List<Recommendation>? _recommendations;
  String? _error;
  int _tab = 0;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        _signalService.listAlerts(widget.businessId),
        _signalService.listRecommendations(widget.businessId),
      ]);
      if (!mounted) return;
      setState(() {
        _alerts = results[0] as List<Alert>;
        _recommendations = results[1] as List<Recommendation>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _generateRecommendations() async {
    setState(() => _generating = true);
    try {
      final generated = await _signalService.generateRecommendations(widget.businessId);
      if (!mounted) return;
      // Las nuevas reemplazan a las de IA pendientes; recargamos para ver la lista completa.
      await _load();
      if (!mounted) return;
      setState(() => _tab = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            generated.isEmpty
                ? 'La IA no encontró recomendaciones nuevas por ahora.'
                : '${generated.length} recomendaciones nuevas para tu negocio',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showRecommendation(Recommendation recommendation) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RecommendationDetail(recommendation: recommendation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts;
    final recommendations = _recommendations;
    final openAlerts = alerts?.where((a) => a.status != 'RESOLVED').length ?? 0;
    final isOwner = context.watch<BusinessProvider>().currentBusiness?.isOwner ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(openAlerts: openAlerts, onBellTap: () => setState(() => _tab = 0)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _SegmentedTabs(
                  selected: _tab,
                  alertsCount: alerts?.length ?? 0,
                  recommendationsCount: recommendations?.length ?? 0,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
              ),
              Expanded(
                child: RefreshIndicator(onRefresh: _load, child: _buildBody(alerts, recommendations, isOwner)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<Alert>? alerts, List<Recommendation>? recommendations, bool isOwner) {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: _load,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }
    if (alerts == null || recommendations == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final children = <Widget>[];
    if (_tab == 0) {
      if (alerts.isEmpty) {
        children.add(
          const _EmptyState(
            icon: Icons.notifications_rounded,
            title: 'No tienes alertas por ahora',
            text: 'Cuando algo importante ocurra en tu negocio,\nte lo notificaremos aquí.',
          ),
        );
      } else {
        children.addAll(alerts.map((alert) => _AlertCard(alert: alert)));
      }
      children.add(
        _SectionHeader(
          title: 'Recomendaciones',
          onSeeAll: recommendations.isEmpty ? null : () => setState(() => _tab = 1),
        ),
      );
      if (recommendations.isEmpty) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aún no hay recomendaciones para tu negocio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        );
      } else {
        final first = recommendations.first;
        children.add(_RecommendationCard(recommendation: first, onOpen: () => _showRecommendation(first)));
      }
    } else {
      if (recommendations.isEmpty) {
        children.add(
          const _EmptyState(
            icon: Icons.lightbulb_rounded,
            title: 'Sin recomendaciones por ahora',
            text: 'Deja que la IA revise tus productos y ventas\npara darte ideas de cómo vender más.',
          ),
        );
        children.add(_GenerateButton(generating: _generating, onPressed: _generateRecommendations));
      } else {
        children.add(_GenerateButton(generating: _generating, onPressed: _generateRecommendations, compact: true));
        children.addAll(
          recommendations.map((r) => _RecommendationCard(recommendation: r, onOpen: () => _showRecommendation(r))),
        );
      }
    }
    if (isOwner) {
      children.add(
        _PlansBanner(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen()))),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: children);
  }
}

class _Header extends StatelessWidget {
  final int openAlerts;
  final VoidCallback onBellTap;

  const _Header({required this.openAlerts, required this.onBellTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alertas y recomendaciones',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Mantente al día con lo más importante para tu negocio',
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Alertas',
            onPressed: onBellTap,
            icon: Badge(
              isLabelVisible: openAlerts > 0,
              label: Text('$openAlerts'),
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(Icons.notifications_none_rounded, color: AppTheme.primary, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int selected;
  final int alertsCount;
  final int recommendationsCount;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({
    required this.selected,
    required this.alertsCount,
    required this.recommendationsCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE6EFFE), borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          _Segment(
            icon: Icons.notifications_rounded,
            label: 'Alertas',
            count: alertsCount,
            selected: selected == 0,
            onTap: () => onChanged(0),
          ),
          _Segment(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Recomendaciones',
            count: recommendationsCount,
            selected: selected == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppTheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.22) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyState({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        children: [
          SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                ),
                Icon(icon, size: 84, color: AppTheme.primary),
                Positioned(
                  right: 22,
                  bottom: 28,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF14B8A6),
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    final resolved = alert.status == 'RESOLVED';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(_severityIcon(alert.severity), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Labels.alertType(alert.type),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, height: 1.3),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (alert.triggeredAt != null) _formatDate(alert.triggeredAt!),
                    if (alert.status != null) Labels.alertStatus(alert.status!),
                  ].join(' · '),
                  style: TextStyle(color: resolved ? _green : AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primary, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Ver todas'), Icon(Icons.chevron_right_rounded)],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;
  final VoidCallback onOpen;

  const _RecommendationCard({required this.recommendation, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final fromAi = recommendation.source == 'AI';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.trending_up_rounded, color: _purple, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Tag(label: fromAi ? 'IA' : recommendation.category, color: _purple),
                          _Tag(
                            label: _priorityLabel(recommendation.priority),
                            color: _priorityColor(recommendation.priority),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recommendation.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6EFFE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Ver recomendación',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _RecommendationDetail extends StatelessWidget {
  final Recommendation recommendation;

  const _RecommendationDetail({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: [
                _Tag(label: recommendation.source == 'AI' ? 'IA' : 'Sugerencia', color: _purple),
                _Tag(label: recommendation.category, color: AppTheme.primary),
                _Tag(label: _priorityLabel(recommendation.priority), color: _priorityColor(recommendation.priority)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recommendation.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.description,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.45),
            ),
            const SizedBox(height: 14),
            Text(
              'Generada el ${_formatDate(recommendation.generatedAt)} · '
              '${Labels.recommendationStatus(recommendation.status)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlansBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PlansBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.campaign_rounded, color: _green, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Quieres más visibilidad?',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Con nuestros planes puedes publicar más promociones y llegar a más clientes.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            onPressed: onTap,
            child: const Text('Ver planes'),
          ),
        ],
      ),
    );
  }
}

/// Botón que pide a la IA recomendaciones basadas en el inventario y las ventas.
class _GenerateButton extends StatelessWidget {
  final bool generating;
  final VoidCallback onPressed;
  final bool compact;

  const _GenerateButton({required this.generating, required this.onPressed, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final label = generating
        ? 'Analizando tu negocio...'
        : compact
        ? 'Actualizar con IA'
        : 'Generar recomendaciones con IA';
    final icon = generating
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.auto_awesome_rounded);

    return Padding(
      padding: EdgeInsets.only(top: compact ? 0 : 16, bottom: 16),
      child: Align(
        alignment: compact ? Alignment.centerRight : Alignment.center,
        child: FilledButton.icon(
          // El tema pide ancho completo (Size.fromHeight); aquí el botón se ajusta a su texto.
          style: FilledButton.styleFrom(
            minimumSize: Size(0, compact ? 42 : 52),
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: generating ? null : onPressed,
          icon: icon,
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
