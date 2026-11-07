import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../models/sales_insights.dart';

const _green = Color(0xFF10B981);
const _red = Color(0xFFEF4444);

/// Metas de la etapa Inicio. Al cumplirlas todas se ofrece pasar a Crecimiento.
class EarlyGoalsCard extends StatelessWidget {
  static const productsGoal = 5;
  static const salesGoal = 10;
  static const monthGoal = 500.0;

  final SalesInsights insights;
  final bool canAdvance;
  final VoidCallback onAdvance;
  final VoidCallback onOpenProducts;

  const EarlyGoalsCard({
    super.key,
    required this.insights,
    required this.canAdvance,
    required this.onAdvance,
    required this.onOpenProducts,
  });

  @override
  Widget build(BuildContext context) {
    final goals = [
      _Goal(
        icon: Icons.inventory_2_rounded,
        title: 'Registra $productsGoal productos',
        current: math.min(insights.productsCount, productsGoal).toDouble(),
        target: productsGoal.toDouble(),
        label: '${math.min(insights.productsCount, productsGoal)} de $productsGoal',
        onTap: onOpenProducts,
      ),
      _Goal(
        icon: Icons.point_of_sale_rounded,
        title: 'Haz tus primeras $salesGoal ventas',
        current: math.min(insights.salesAllTime, salesGoal).toDouble(),
        target: salesGoal.toDouble(),
        label: '${math.min(insights.salesAllTime, salesGoal)} de $salesGoal',
      ),
      _Goal(
        icon: Icons.request_quote_rounded,
        title: 'Registra el costo de tus productos',
        current: insights.productsCount == 0 ? 0 : (insights.productsCount - insights.productsWithoutCost).toDouble(),
        target: math.max(insights.productsCount, 1).toDouble(),
        label: insights.productsCount == 0
            ? 'Sin productos'
            : insights.productsWithoutCost == 0
            ? 'Todos listos'
            : 'Faltan ${insights.productsWithoutCost}',
        hint: 'Así podremos calcular tu ganancia',
        onTap: onOpenProducts,
      ),
      _Goal(
        icon: Icons.emoji_events_rounded,
        title: 'Vende ${formatMoney(monthGoal)} en un mes',
        current: math.min(insights.monthTotal, monthGoal),
        target: monthGoal,
        label: '${formatMoney(insights.monthTotal)} este mes',
      ),
    ];
    final done = goals.where((goal) => goal.done).length;
    final allDone = done == goals.length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icons.flag_rounded,
            color: const Color(0xFF1A6FF0),
            title: 'Tus primeras metas',
            trailing: Text(
              '$done/${goals.length}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cúmplelas para dejar tu negocio listo para crecer.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final goal in goals) _GoalRow(goal: goal),
          if (allDone && canAdvance) ...[
            const SizedBox(height: 8),
            _AdvanceButton(label: '¡Listo para crecer! Pasar a Crecimiento', onTap: onAdvance),
          ],
        ],
      ),
    );
  }
}

class _Goal {
  final IconData icon;
  final String title;
  final double current;
  final double target;
  final String label;
  final String? hint;
  final VoidCallback? onTap;

  const _Goal({
    required this.icon,
    required this.title,
    required this.current,
    required this.target,
    required this.label,
    this.hint,
    this.onTap,
  });

  bool get done => target > 0 && current >= target;
}

class _GoalRow extends StatelessWidget {
  final _Goal goal;

  const _GoalRow({required this.goal});

  @override
  Widget build(BuildContext context) {
    final color = goal.done ? _green : AppTheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: goal.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(goal.done ? Icons.check_rounded : goal.icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            decoration: goal.done ? TextDecoration.lineThrough : null,
                            decorationColor: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        goal.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ProgressBar(value: goal.target == 0 ? 0 : goal.current / goal.target, color: color),
                  if (goal.hint != null && !goal.done) ...[
                    const SizedBox(height: 4),
                    Text(goal.hint!, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
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

/// Meta de ventas del mes (Crecimiento y Consolidado): avance, días que quedan y cuánto vender por día.
class SalesGoalCard extends StatelessWidget {
  final SalesInsights insights;
  final bool canEdit;
  final ValueChanged<double?> onSave;

  const SalesGoalCard({super.key, required this.insights, required this.canEdit, required this.onSave});

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: insights.goal == null ? '' : insights.goal!.toStringAsFixed(0));
    final result = await showDialog<Object?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Meta de ventas del mes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El mes pasado vendiste ${formatMoney(insights.lastMonthTotal)}. '
              'Una buena meta es un poco más que eso.',
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Meta', prefixText: 'S/ '),
            ),
          ],
        ),
        actions: [
          if (insights.goal != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Quitar meta', style: TextStyle(color: _red)),
            ),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(double.tryParse(controller.text.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // Sin dispose(): el diálogo aún usa el controller durante su animación de cierre (se libera solo).
    if (result == false) {
      onSave(null);
    } else if (result is double && result > 0) {
      onSave(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = insights.goal;
    if (goal == null) {
      return _Card(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.track_changes_rounded, color: Color(0xFFF59E0B), size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ponte una meta este mes',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Te mostraremos cuánto te falta y cuánto vender por día.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (canEdit)
              // El tema da a los botones ancho completo; dentro de una fila necesita un ancho propio.
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => _edit(context),
                child: const Text('Definir'),
              ),
          ],
        ),
      );
    }

    final progress = goal == 0 ? 0.0 : insights.monthTotal / goal;
    final remaining = math.max(goal - insights.monthTotal, 0.0);
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;
    final reached = remaining == 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: Icons.track_changes_rounded,
            color: const Color(0xFFF59E0B),
            title: 'Meta del mes',
            trailing: canEdit
                ? IconButton(
                    tooltip: 'Cambiar meta',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(insights.monthTotal),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 3),
                child: Text('de ${formatMoney(goal)}', style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: reached ? _green : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(value: progress, color: reached ? _green : const Color(0xFFF59E0B), height: 10),
          const SizedBox(height: 10),
          Text(
            reached
                ? '🎉 ¡Cumpliste tu meta del mes! Puedes subirla para seguir creciendo.'
                : 'Te faltan ${formatMoney(remaining)} en $daysLeft ${daysLeft == 1 ? 'día' : 'días'}: '
                      'unos ${formatMoney(remaining / daysLeft)} por día.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Este mes vs. el mes pasado: ingresos y número de ventas.
class MonthComparisonCard extends StatelessWidget {
  final SalesInsights insights;

  const MonthComparisonCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.compare_arrows_rounded,
            color: Color(0xFF7C3AED),
            title: 'Este mes vs. el pasado',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompareColumn(
                  label: 'Ingresos',
                  value: formatMoney(insights.monthTotal),
                  previous: formatMoney(insights.lastMonthTotal),
                  current: insights.monthTotal,
                  before: insights.lastMonthTotal,
                ),
              ),
              Container(width: 1, height: 64, color: AppTheme.border),
              Expanded(
                child: _CompareColumn(
                  label: 'Ventas',
                  value: '${insights.monthCount}',
                  previous: '${insights.lastMonthCount}',
                  current: insights.monthCount.toDouble(),
                  before: insights.lastMonthCount.toDouble(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareColumn extends StatelessWidget {
  final String label;
  final String value;
  final String previous;
  final double current;
  final double before;

  const _CompareColumn({
    required this.label,
    required this.value,
    required this.previous,
    required this.current,
    required this.before,
  });

  @override
  Widget build(BuildContext context) {
    final Widget change;
    if (before == 0) {
      change = Text(
        current == 0 ? 'Sin datos' : 'Nuevo este mes',
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      );
    } else {
      final percent = (current - before) / before * 100;
      final up = percent >= 0;
      change = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: up ? _green : _red),
          Text(
            '${up ? '+' : ''}${percent.round()}%',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: up ? _green : _red),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
          ),
          Text('Mes pasado: $previous', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          change,
        ],
      ),
    );
  }
}

/// Productos más vendidos del mes y, si hay, el que menos se mueve.
class TopProductsCard extends StatelessWidget {
  final SalesInsights insights;

  const TopProductsCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final slow = insights.slowProduct;
    final showSlow = slow != null && !insights.topProducts.any((p) => p.id == slow.id && p.units > 0);
    const medals = [Color(0xFFF59E0B), Color(0xFF94A3B8), Color(0xFFB45309)];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.star_rounded, color: Color(0xFFF59E0B), title: 'Tus productos estrella'),
          const SizedBox(height: 8),
          if (insights.topProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Aún no hay ventas este mes.', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          for (var i = 0; i < insights.topProducts.length; i++)
            _ProductRow(
              product: insights.topProducts[i],
              badge: CircleAvatar(
                radius: 13,
                backgroundColor: medals[i].withValues(alpha: 0.15),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: medals[i]),
                ),
              ),
            ),
          if (showSlow) ...[
            const Divider(height: 20, color: AppTheme.border),
            _ProductRow(
              product: slow,
              badge: const CircleAvatar(
                radius: 13,
                backgroundColor: Color(0xFFFEE2E2),
                child: Icon(Icons.trending_down_rounded, size: 16, color: _red),
              ),
              caption: 'El que menos se mueve: prueba una promoción o combo',
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ProductPerformance product;
  final Widget badge;
  final String? caption;

  const _ProductRow({required this.product, required this.badge, this.caption});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          badge,
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40,
              height: 40,
              child: product.imageUrl == null
                  ? const ColoredBox(
                      color: Color(0xFFEFF3F9),
                      child: Icon(Icons.inventory_2_outlined, color: AppTheme.textSecondary, size: 20),
                    )
                  : Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFEFF3F9)),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                Text(
                  caption ?? '${product.units} ${product.units == 1 ? 'unidad vendida' : 'unidades vendidas'}',
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            caption == null ? formatMoney(product.revenue) : '${product.units} u.',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Resumen del mes para Consolidado: ingresos, ticket promedio, ganancia y mejor día.
class MonthSummaryCard extends StatelessWidget {
  static const _days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _dayNames = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

  final SalesInsights insights;

  const MonthSummaryCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final maxDay = insights.weekday.fold<double>(0, math.max);
    final bestDay = maxDay == 0 ? -1 : insights.weekday.indexOf(maxDay);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.insights_rounded, color: Color(0xFF0D9488), title: 'Resumen del mes'),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(label: 'Ingresos', value: formatMoney(insights.monthTotal)),
              _Metric(label: 'Ticket promedio', value: formatMoney(insights.avgTicket)),
              _Metric(
                label: insights.profitComplete ? 'Ganancia' : 'Ganancia*',
                value: formatMoney(insights.profit),
                color: insights.profit >= 0 ? _green : _red,
              ),
            ],
          ),
          if (!insights.profitComplete)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '* Parcial: algunos productos vendidos no tienen costo registrado.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            bestDay < 0 ? 'Ventas por día de la semana' : 'Tu mejor día es el ${_dayNames[bestDay]}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: math.max(maxDay == 0 ? 0 : insights.weekday[i] / maxDay * 48, 3),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: i == bestDay ? const Color(0xFF0D9488) : const Color(0xFF99E0D6),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _days[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == bestDay ? FontWeight.w800 : FontWeight.w500,
                            color: i == bestDay ? const Color(0xFF0D9488) : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Metric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color ?? AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ventas del mes por vendedor (útil cuando hay equipo).
class SellersCard extends StatelessWidget {
  final SalesInsights insights;

  const SellersCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final best = insights.sellers.isEmpty ? 1.0 : insights.sellers.first.total;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.groups_rounded, color: Color(0xFF4F46E5), title: 'Ventas por vendedor'),
          const SizedBox(height: 8),
          for (final seller in insights.sellers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          seller.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ),
                      Text(
                        '${formatMoney(seller.total)} · ${seller.count} ${seller.count == 1 ? 'venta' : 'ventas'}',
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ProgressBar(value: best == 0 ? 0 : seller.total / best, color: const Color(0xFF4F46E5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Invitación a pasar a la siguiente etapa (solo la ve el dueño).
class NextStageCard extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  const NextStageCard({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 12),
          _AdvanceButton(label: buttonLabel, onTap: onTap),
        ],
      ),
    );
  }
}

class _AdvanceButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdvanceButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: _green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.rocket_launch_rounded),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const _ProgressBar({required this.value, required this.color, this.height = 7});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: color.withValues(alpha: 0.12),
          color: color,
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget? trailing;

  const _CardTitle({required this.icon, required this.color, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0A1F4D).withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
