import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';
import 'payment_service.dart';

/// Pago de un plan por Yape: QR del negocio, monto exacto y el aviso "Ya pagué".
/// Luego espera a que el backend confirme el pago con la notificación de Yape.
class PlanCheckoutScreen extends StatefulWidget {
  final String planCode;
  final String planName;
  final Color color;

  const PlanCheckoutScreen({super.key, required this.planCode, required this.planName, required this.color});

  @override
  State<PlanCheckoutScreen> createState() => _PlanCheckoutScreenState();
}

class _PlanCheckoutScreenState extends State<PlanCheckoutScreen> {
  static const _pollInterval = Duration(seconds: 5);

  late final PaymentService _service = PaymentService(context.read<ApiClient>());
  final _formKey = GlobalKey<FormState>();
  final _payerController = TextEditingController();

  YapeSettings? _settings;
  PlanPayment? _payment;
  String? _loadError;
  bool _isSubmitting = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _payerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final results = await Future.wait([_service.getSettings(), _service.listMine()]);
      final settings = results[0] as YapeSettings;
      final payments = results[1] as List<PlanPayment>;
      // Si ya avisó que pagó este plan, se retoma la espera en vez de pedirle pagar otra vez.
      final pending = payments.where((p) => p.isPending && p.plan == widget.planCode).firstOrNull;
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _payment = pending;
      });
      if (pending != null) _startPolling();
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    }
  }

  double get _amount => _settings?.prices[widget.planCode] ?? 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final payment = await _service.create(plan: widget.planCode, payerName: _payerController.text.trim());
      if (!mounted) return;
      setState(() => _payment = payment);
      if (payment.isConfirmed) {
        await _onConfirmed();
      } else {
        _startPolling();
      }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final current = _payment;
    if (current == null) return;
    try {
      final payments = await _service.listMine();
      final updated = payments.where((p) => p.id == current.id).firstOrNull;
      if (!mounted || updated == null || updated.isPending) return;
      _pollTimer?.cancel();
      setState(() => _payment = updated);
      if (updated.isConfirmed) await _onConfirmed();
    } on ApiException {
      // Sin conexión por un momento: se vuelve a intentar en el siguiente ciclo.
    }
  }

  Future<void> _onConfirmed() async {
    _pollTimer?.cancel();
    try {
      await context.read<AuthProvider>().refreshProfile();
    } on ApiException {
      // El plan ya quedó activo en el servidor; el perfil se actualizará al volver a abrir la app.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(title: 'Plan ${widget.planName}'),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        color: AppTheme.textSecondary,
        title: 'No se pudo cargar el pago',
        text: _loadError!,
        action: FilledButton(onPressed: _load, child: const Text('Reintentar')),
      );
    }
    final settings = _settings;
    if (settings == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final payment = _payment;
    if (payment != null) {
      if (payment.isConfirmed) {
        return _Message(
          icon: Icons.verified_rounded,
          color: const Color(0xFF16A34A),
          title: '¡Pago confirmado!',
          text: 'Tu plan ${widget.planName} ya está activo. Gracias por confiar en EmprendeSmart.',
          action: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Listo')),
        );
      }
      if (payment.status == 'REJECTED') {
        return _Message(
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFDC2626),
          title: 'No pudimos confirmar tu pago',
          text: payment.rejectedReason ?? 'Revisa que el monto y el nombre sean correctos e inténtalo de nuevo.',
          action: FilledButton(
            onPressed: () => setState(() => _payment = null),
            child: const Text('Intentar de nuevo'),
          ),
        );
      }
      return _Message(
        icon: Icons.hourglass_top_rounded,
        color: widget.color,
        title: 'Verificando tu pago…',
        text:
            'Estamos esperando la confirmación de Yape por S/ ${payment.amount.toStringAsFixed(2)} '
            'a nombre de ${payment.payerName}. Suele tardar menos de un minuto. '
            'Puedes salir de esta pantalla: tu plan se activará apenas se confirme.',
        showProgress: true,
      );
    }

    if (settings.qrUrl == null) {
      return const _Message(
        icon: Icons.qr_code_2_rounded,
        color: AppTheme.textSecondary,
        title: 'Pago por Yape no disponible',
        text: 'Todavía no está configurado el QR de pago. Inténtalo más tarde.',
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QrCard(settings: settings, amount: _amount, color: widget.color),
          const SizedBox(height: 20),
          const _Step(number: 1, text: 'Abre Yape y escanea el QR (o yapea al número).'),
          _Step(number: 2, text: 'Paga exactamente S/ ${_amount.toStringAsFixed(2)}.'),
          const _Step(number: 3, text: 'Escribe tu nombre tal como aparece en tu Yape y toca "Ya pagué".'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _payerController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre en tu Yape',
              hintText: 'Ej. María López',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) =>
                (value == null || value.trim().length < 2) ? 'Escribe el nombre que aparece en tu Yape' : null,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: widget.color),
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Ya pagué'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedBottomClipper(),
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        padding: EdgeInsets.fromLTRB(4, MediaQuery.paddingOf(context).top + 8, 16, 32),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
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

class _QrCard extends StatelessWidget {
  final YapeSettings settings;
  final double amount;
  final Color color;

  const _QrCard({required this.settings, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          const Text('Total a pagar', style: TextStyle(color: AppTheme.textSecondary)),
          Text(
            'S/ ${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              settings.qrUrl!,
              width: 230,
              height: 230,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(width: 230, height: 230, child: Center(child: CircularProgressIndicator())),
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 230,
                height: 230,
                child: Center(child: Text('No se pudo cargar el QR', textAlign: TextAlign.center)),
              ),
            ),
          ),
          if (settings.holderName != null || settings.phone != null) ...[
            const SizedBox(height: 14),
            if (settings.holderName != null)
              Text(
                settings.holderName!,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 16),
              ),
            if (settings.phone != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Yape: ${settings.phone}', style: const TextStyle(color: AppTheme.textSecondary)),
                  IconButton(
                    tooltip: 'Copiar número',
                    icon: Icon(Icons.copy_rounded, size: 18, color: color),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: settings.phone!.replaceAll(' ', '')));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Número copiado')));
                    },
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primary,
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final Widget? action;
  final bool showProgress;

  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.action,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
            margin: const EdgeInsets.symmetric(horizontal: 120),
            child: Icon(icon, color: color, size: 52),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.4),
          ),
          if (showProgress) ...[const SizedBox(height: 24), const Center(child: CircularProgressIndicator())],
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}
