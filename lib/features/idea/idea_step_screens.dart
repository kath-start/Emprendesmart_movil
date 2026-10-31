import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../models/business.dart';
import '../../models/idea_plan.dart';
import '../businesses/business_provider.dart';

String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

double? _parseMoney(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

String _moneyText(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

/// Estructura común de los pasos: cabecera con ícono, contenido con scroll y botón "Guardar".
class _StepScaffold extends StatefulWidget {
  final Business business;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  /// Devuelve el plan actualizado con lo que se llenó en el paso, o `null` si falta algo.
  final IdeaPlan? Function() buildPlan;

  const _StepScaffold({
    required this.business,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
    required this.buildPlan,
  });

  @override
  State<_StepScaffold> createState() => _StepScaffoldState();
}

class _StepScaffoldState extends State<_StepScaffold> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final plan = widget.buildPlan();
    if (plan == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<BusinessProvider>().saveIdeaPlan(widget.business.id, plan);
      messenger.showSnackBar(const SnackBar(content: Text('¡Paso guardado!')));
      navigator.pop();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.business.isOwner;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(widget.icon, color: widget.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(widget.subtitle, style: const TextStyle(color: AppTheme.textSecondary, height: 1.35)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ...widget.children,
            if (!canEdit) ...[
              const SizedBox(height: 16),
              const Text(
                'Solo el dueño del negocio puede guardar cambios en el plan.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: (_saving || !canEdit) ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
    ),
  );
}

/// Recuadro con un consejo corto para quien no sabe qué escribir.
class _Tip extends StatelessWidget {
  final String text;

  const _Tip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF8E6), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_outlined, size: 20, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF7C4A03))),
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final bool required;

  const _MoneyField({required this.controller, required this.label, this.helper, this.onChanged, this.required = true});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 2, prefixText: 'S/ '),
      validator: (value) {
        if (!required && (value == null || value.trim().isEmpty)) return null;
        return _parseMoney(value ?? '') == null ? 'Ingresa un monto' : null;
      },
    );
  }
}

/// Tarjeta de resultados de las calculadoras.
class _ResultCard extends StatelessWidget {
  final List<(String, String)> rows;
  final String? highlightLabel;
  final String? highlightValue;
  final String? warning;

  const _ResultCard({required this.rows, this.highlightLabel, this.highlightValue, this.warning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0B2F7A), Color(0xFF1A6FF0)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (highlightLabel != null) ...[
            Text(highlightLabel!, style: const TextStyle(color: Color(0xFFC9D6F2), fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              highlightValue ?? '—',
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
          ],
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: const TextStyle(color: Color(0xFFE3EDFF), fontSize: 13)),
                  ),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (warning != null) ...[
            const SizedBox(height: 8),
            Text(warning!, style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12.5, height: 1.3)),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Paso 1: cliente ─────────────────────────

class CustomerStepScreen extends StatefulWidget {
  final Business business;

  const CustomerStepScreen({super.key, required this.business});

  @override
  State<CustomerStepScreen> createState() => _CustomerStepScreenState();
}

class _CustomerStepScreenState extends State<CustomerStepScreen> {
  late final _whoController = TextEditingController(text: widget.business.ideaPlan.customerWho);
  late final _problemController = TextEditingController(text: widget.business.ideaPlan.customerProblem);

  @override
  void dispose() {
    _whoController.dispose();
    _problemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null;
    return _StepScaffold(
      business: widget.business,
      title: 'Tu cliente ideal',
      subtitle: 'Saber a quién le vendes te ayuda a decidir qué ofrecer, a qué precio y por dónde vender.',
      icon: Icons.person_search_rounded,
      color: const Color(0xFF7C3AED),
      buildPlan: () => widget.business.ideaPlan.copyWith(
        customerWho: _whoController.text.trim(),
        customerProblem: _problemController.text.trim(),
      ),
      children: [
        const _Label('¿Quién te va a comprar?'),
        TextFormField(
          controller: _whoController,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej. Mamás que trabajan y no tienen tiempo de cocinar postres para cumpleaños',
          ),
          validator: required,
        ),
        const SizedBox(height: 8),
        const _Label('¿Qué necesidad o problema le resuelves?'),
        TextFormField(
          controller: _problemController,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej. Tener una torta bonita y rica a domicilio sin tener que prepararla',
          ),
          validator: required,
        ),
        const SizedBox(height: 8),
        const _Tip(
          'Mientras más específico, mejor. "Todo el mundo" no es un cliente: piensa en una persona real, '
          'dónde vive, qué hace y por qué te elegiría a ti.',
        ),
      ],
    );
  }
}

// ───────────────────────── Paso 3: precio ─────────────────────────

class PricingStepScreen extends StatefulWidget {
  final Business business;

  const PricingStepScreen({super.key, required this.business});

  @override
  State<PricingStepScreen> createState() => _PricingStepScreenState();
}

class _PricingStepScreenState extends State<PricingStepScreen> {
  static const _quickMargins = [30.0, 50.0, 80.0, 100.0];

  late final _costController = TextEditingController(text: _moneyText(widget.business.ideaPlan.unitCost));
  late double _margin = widget.business.ideaPlan.marginPercent ?? 50;

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = _parseMoney(_costController.text);
    final price = cost == null ? null : cost * (1 + _margin / 100);
    final profit = price == null ? null : price - cost!;

    return _StepScaffold(
      business: widget.business,
      title: 'Calcula tu precio',
      subtitle: 'Parte de lo que te cuesta hacer o comprar un producto y súmale la ganancia que quieres.',
      icon: Icons.sell_rounded,
      color: const Color(0xFF10B981),
      buildPlan: () => widget.business.ideaPlan.copyWith(unitCost: cost, marginPercent: _margin),
      children: [
        _MoneyField(
          controller: _costController,
          label: 'Costo por unidad',
          helper: 'Materiales, empaque y todo lo que gastas en hacer 1 unidad',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: _Label('Ganancia que quieres')),
            Text(
              '${_margin.round()}%',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
          ],
        ),
        Slider(
          value: _margin.clamp(0, 200),
          max: 200,
          divisions: 40,
          label: '${_margin.round()}%',
          onChanged: (value) => setState(() => _margin = value),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final margin in _quickMargins)
              ChoiceChip(
                label: Text('${margin.round()}%'),
                selected: _margin == margin,
                onSelected: (_) => setState(() => _margin = margin),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _ResultCard(
          highlightLabel: 'Precio sugerido',
          highlightValue: price == null ? null : _money(price),
          rows: [
            ('Costo', cost == null ? '—' : _money(cost)),
            ('Ganancia por unidad', profit == null ? '—' : _money(profit)),
            // Margen sobre el precio de venta: lo que queda de cada sol que cobras.
            if (price != null && price > 0) ('De cada S/ 1 que cobras, ganas', _money(profit! / price)),
          ],
        ),
        const SizedBox(height: 14),
        const _Tip(
          'Compara con lo que cobra tu competencia. Si tu precio sale mucho más alto, busca bajar costos '
          'o destaca algo que te haga diferente (calidad, delivery, presentación).',
        ),
      ],
    );
  }
}

// ───────────────────────── Paso 4: inversión ─────────────────────────

class InvestmentStepScreen extends StatefulWidget {
  final Business business;

  const InvestmentStepScreen({super.key, required this.business});

  @override
  State<InvestmentStepScreen> createState() => _InvestmentStepScreenState();
}

class _InvestmentStepScreenState extends State<InvestmentStepScreen> {
  late final IdeaPlan _plan = widget.business.ideaPlan;
  late final _initialController = TextEditingController(text: _moneyText(_plan.initialInvestment));
  late final _fixedController = TextEditingController(text: _moneyText(_plan.monthlyFixed));
  // Si ya calculó su precio en el paso anterior, se usa como punto de partida.
  late final _priceController = TextEditingController(
    text: _moneyText(_plan.investmentUnitPrice ?? _plan.suggestedPrice),
  );
  late final _costController = TextEditingController(text: _moneyText(_plan.investmentUnitCost ?? _plan.unitCost));

  @override
  void dispose() {
    _initialController.dispose();
    _fixedController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _parseMoney(_initialController.text);
    final fixed = _parseMoney(_fixedController.text) ?? 0;
    final price = _parseMoney(_priceController.text);
    final cost = _parseMoney(_costController.text);
    final gain = (price != null && cost != null) ? price - cost : null;
    final validGain = gain != null && gain > 0;

    final unitsToRecover = (validGain && initial != null) ? (initial / gain).ceil() : null;
    final unitsPerMonth = validGain ? (fixed / gain).ceil() : null;
    void refresh(String _) => setState(() {});

    return _StepScaffold(
      business: widget.business,
      title: '¿Cuánto necesito?',
      subtitle: 'Calcula cuánto dinero necesitas para empezar y cuántas unidades debes vender para recuperarlo.',
      icon: Icons.savings_rounded,
      color: const Color(0xFFF59E0B),
      buildPlan: () => _plan.copyWith(
        initialInvestment: initial,
        monthlyFixed: fixed,
        investmentUnitPrice: price,
        investmentUnitCost: cost,
      ),
      children: [
        _MoneyField(
          controller: _initialController,
          label: 'Inversión inicial',
          helper: 'Equipos, primer stock, permisos, publicidad inicial…',
          onChanged: refresh,
        ),
        const SizedBox(height: 14),
        _MoneyField(
          controller: _fixedController,
          label: 'Gastos fijos al mes (opcional)',
          helper: 'Alquiler, internet, luz, pasajes… lo que pagas vendas o no',
          required: false,
          onChanged: refresh,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MoneyField(controller: _priceController, label: 'Precio de venta', onChanged: refresh),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MoneyField(controller: _costController, label: 'Costo por unidad', onChanged: refresh),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ResultCard(
          highlightLabel: 'Unidades para recuperar tu inversión',
          highlightValue: unitsToRecover == null ? null : '$unitsToRecover unidades',
          rows: [
            ('Ganancia por unidad', gain == null ? '—' : _money(gain)),
            if (fixed > 0)
              ('Ventas al mes para cubrir gastos fijos', unitsPerMonth == null ? '—' : '$unitsPerMonth unidades'),
            if (unitsToRecover != null && fixed > 0 && unitsPerMonth != null)
              (
                'Si vendes ${unitsPerMonth * 2} al mes, recuperas en',
                _monthsToRecover(initial!, fixed, gain!, unitsPerMonth * 2),
              ),
          ],
          warning: gain != null && !validGain
              ? 'Tu precio es igual o menor a tu costo: estarías perdiendo dinero en cada venta.'
              : null,
        ),
        const SizedBox(height: 14),
        const _Tip(
          'Empieza pequeño: prueba con poco stock y vende a conocidos antes de invertir todo. '
          'Así validas la idea arriesgando menos.',
        ),
      ],
    );
  }

  static String _monthsToRecover(double initial, double fixed, double gain, int unitsPerMonth) {
    final monthlyProfit = unitsPerMonth * gain - fixed;
    if (monthlyProfit <= 0) return '—';
    final months = (initial / monthlyProfit).ceil();
    return months == 1 ? '1 mes' : '$months meses';
  }
}

// ───────────────────────── Paso 5: canales de venta ─────────────────────────

class ChannelsStepScreen extends StatefulWidget {
  final Business business;

  const ChannelsStepScreen({super.key, required this.business});

  @override
  State<ChannelsStepScreen> createState() => _ChannelsStepScreenState();
}

class _ChannelsStepScreenState extends State<ChannelsStepScreen> {
  static const _options = [
    ('WhatsApp', Icons.chat_rounded),
    ('Instagram', Icons.camera_alt_rounded),
    ('Facebook', Icons.thumb_up_alt_rounded),
    ('TikTok', Icons.music_note_rounded),
    ('Feria o mercado', Icons.storefront_rounded),
    ('Tienda física', Icons.store_mall_directory_rounded),
    ('Delivery', Icons.delivery_dining_rounded),
    ('Página web', Icons.language_rounded),
    ('Boca a boca', Icons.record_voice_over_rounded),
  ];

  late final Set<String> _selected = {...widget.business.ideaPlan.channels};
  late final _noteController = TextEditingController(text: widget.business.ideaPlan.channelsNote);
  bool _showError = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      business: widget.business,
      title: 'Cómo vas a vender',
      subtitle: 'Elige por dónde vas a llegar a tus clientes. Puedes marcar varios.',
      icon: Icons.campaign_rounded,
      color: const Color(0xFFDB2777),
      buildPlan: () {
        if (_selected.isEmpty) {
          setState(() => _showError = true);
          return null;
        }
        return widget.business.ideaPlan.copyWith(
          channels: _selected.toList(),
          channelsNote: _noteController.text.trim(),
        );
      },
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, icon) in _options)
              FilterChip(
                avatar: Icon(icon, size: 18),
                label: Text(name),
                selected: _selected.contains(name),
                onSelected: (value) => setState(() {
                  value ? _selected.add(name) : _selected.remove(name);
                  _showError = false;
                }),
              ),
          ],
        ),
        if (_showError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Elige al menos un canal',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 20),
        const _Label('¿Algún detalle? (opcional)'),
        TextFormField(
          controller: _noteController,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej. Publicar 3 veces por semana y hacer delivery los fines de semana',
          ),
        ),
        const SizedBox(height: 8),
        const _Tip(
          'No necesitas estar en todos lados. Empieza por 1 o 2 canales donde ya están tus clientes '
          'y hazlo bien antes de sumar más.',
        ),
      ],
    );
  }
}
