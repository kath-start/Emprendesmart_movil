import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Estructura común de login y registro: cabecera azul con la marca y tarjeta blanca con el formulario.
class AuthLayout extends StatelessWidget {
  final Widget child;
  final bool showBack;

  const AuthLayout({super.key, required this.child, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D47C9),
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
          child: Stack(
            children: [
              const Positioned(top: -60, right: -80, child: _Bubble(size: 240, opacity: 0.08)),
              const Positioned(top: 150, left: -90, child: _Bubble(size: 200, opacity: 0.06)),
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 40,
                              child: showBack
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: IconButton(
                                        color: Colors.white,
                                        icon: const Icon(Icons.arrow_back_rounded),
                                        onPressed: () => Navigator.of(context).maybePop(),
                                      ),
                                    )
                                  : null,
                            ),
                            const BrandHeader(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 8), child: child),
                              const Spacer(),
                              const SizedBox(height: 72, width: double.infinity, child: _Waves()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo + nombre + lema, en blanco sobre la cabecera azul.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: const Color(0xFF3FB5FF).withValues(alpha: 0.45), blurRadius: 28, spreadRadius: 2),
            ],
          ),
          child: Image.asset('assets/images/logo_icon.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 14),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
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
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 22, height: 2, color: AppTheme.accent),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Tu negocio, en tus manos',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Container(width: 22, height: 2, color: AppTheme.accent),
          ],
        ),
      ],
    );
  }
}

/// Separador "o" entre el botón principal y los accesos alternativos.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('o', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}

/// "G" multicolor aproximada al logo de Google, sin depender de un asset externo.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const SweepGradient(
        colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFFEA4335)],
        stops: [0.0, 0.3, 0.55, 0.8, 1.0],
      ).createShader(bounds),
      child: const Text(
        'G',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final double opacity;

  const _Bubble({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _Waves extends StatelessWidget {
  const _Waves();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _WavesPainter());
}

class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final back = Path()
      ..moveTo(0, h * 0.45)
      ..cubicTo(w * 0.3, h * 0.05, w * 0.6, h * 0.85, w, h * 0.25)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = AppTheme.accent.withValues(alpha: 0.25));

    final front = Path()
      ..moveTo(0, h * 0.7)
      ..cubicTo(w * 0.35, h * 0.35, w * 0.65, h * 1.05, w, h * 0.55)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1A6FF0), Color(0xFF3FB5FF)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mensaje de error del backend, destacado dentro del formulario.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: error)),
          ),
        ],
      ),
    );
  }
}
