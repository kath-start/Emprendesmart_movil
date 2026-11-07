import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Estructura común de login y registro: cabecera azul con la marca e ilustración,
/// tarjeta clara con borde ondulado y pie con ola y lema.
class AuthLayout extends StatelessWidget {
  final Widget child;
  final bool showBack;

  const AuthLayout({super.key, required this.child, this.showBack = false});

  static const _cardColor = Color(0xFFF6F8FD);

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
              const Positioned(top: -60, right: -80, child: _Bubble(size: 240, opacity: 0.06)),
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                        child: Column(
                          children: [
                            SizedBox(
                              height: showBack ? 40 : 12,
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
                            const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  BrandHeader(),
                                  Expanded(child: SizedBox(height: 140, child: _HeaderIllustration())),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      // Padding (no ConstrainedBox) para que la altura intrínseca se calcule con el ancho real.
                      padding: EdgeInsets.symmetric(
                        horizontal: ((MediaQuery.sizeOf(context).width - 480) / 2).clamp(0.0, double.infinity),
                      ),
                      child: Builder(
                        builder: (context) => ClipPath(
                          clipper: _WavyTopClipper(),
                          child: Container(
                            color: _cardColor,
                            child: Column(
                              children: [
                                Padding(padding: const EdgeInsets.fromLTRB(26, 40, 26, 8), child: child),
                                const Spacer(),
                                const _Footer(),
                              ],
                            ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: const Color(0xFF3FB5FF).withValues(alpha: 0.55), blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Image.asset('assets/images/logo_icon.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.5),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 18, height: 2, color: AppTheme.accent),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Tu negocio, en tus manos',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Container(width: 18, height: 2, color: AppTheme.accent),
          ],
        ),
      ],
    );
  }
}

/// Campo de texto de las pantallas de acceso: relleno claro y el ícono dentro de un círculo.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: color, width: width),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7A93), fontSize: 16),
        filled: true,
        fillColor: const Color(0xFFEEF3FB),
        contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 12),
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: Color(0xFFE1EAF8), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF0D2A6B), size: 24),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 66, minHeight: 42),
        suffixIcon: suffix,
        enabledBorder: border(const Color(0xFFD5DEEC)),
        focusedBorder: border(AppTheme.primary, 1.6),
        errorBorder: border(Theme.of(context).colorScheme.error),
        focusedErrorBorder: border(Theme.of(context).colorScheme.error, 1.6),
      ),
    );
  }
}

/// Botón principal con degradado y forma de píldora.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E9BFF), Color(0xFF0B5CE8), Color(0xFF0A3FC4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A6FF0).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 56,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 14),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón blanco con sombra suave para accesos alternativos (Google).
class AuthSecondaryButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  const AuthSecondaryButton({super.key, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFDCE3EE)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0D47C9).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'o',
            style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }
}

/// "G" multicolor aproximada al logo de Google, sin depender de un asset externo.
class GoogleMark extends StatelessWidget {
  final double size;

  const GoogleMark({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const SweepGradient(
        colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFFEA4335)],
        stops: [0.0, 0.3, 0.55, 0.8, 1.0],
      ).createShader(bounds),
      child: Text(
        'G',
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: Colors.white),
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

/// Borde superior ondulado de la tarjeta (baja a la izquierda, sube a la derecha).
class _WavyTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    return Path()
      ..moveTo(0, 40)
      ..cubicTo(w * 0.25, -4, w * 0.55, 30, w * 0.78, 18)
      ..cubicTo(w * 0.9, 12, w * 0.97, 6, w, 0)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Pie con olas azules, ícono de crecimiento y lema.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _FooterWavesPainter())),
          const Positioned(
            left: 28,
            bottom: 22,
            right: 16,
            child: Row(
              children: [
                Icon(Icons.insights_rounded, color: Colors.white, size: 36),
                SizedBox(width: 24),
                Flexible(
                  child: Text(
                    'Crece. Gestiona. Emprende.',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic),
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

class _FooterWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final back = Path()
      ..moveTo(0, h * 0.18)
      ..cubicTo(w * 0.3, h * 0.0, w * 0.6, h * 0.5, w, h * 0.12)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = AppTheme.accent.withValues(alpha: 0.35));

    final front = Path()
      ..moveTo(0, h * 0.3)
      ..cubicTo(w * 0.35, h * 0.12, w * 0.65, h * 0.62, w, h * 0.25)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0B3FC0), Color(0xFF1A6FF0), Color(0xFF2E8CFF)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Laptop con gráfico ascendente y cohete, dibujada a mano (sin assets).
class _HeaderIllustration extends StatelessWidget {
  const _HeaderIllustration();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _LaptopPainter())),
            Positioned(
              right: w * 0.04,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF3FB5FF).withValues(alpha: 0.45), blurRadius: 24)],
                ),
                child: ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.white, Color(0xFFBFDFFF), Color(0xFFFF9A3C)],
                    stops: [0.0, 0.55, 0.85],
                  ).createShader(b),
                  child: const Icon(Icons.rocket_launch_rounded, size: 64, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LaptopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Pantalla
    final screen = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.78, h * 0.44),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A7BFF), Color(0xFF0C3FB8)],
        ).createShader(screen.outerRect),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF7CC4FF).withValues(alpha: 0.7),
    );

    final r = screen.outerRect;
    final light = Paint()..color = const Color(0xFF8FD0FF).withValues(alpha: 0.75);

    // Líneas de texto
    for (var i = 0; i < 3; i++) {
      final lw = i == 0 ? 0.32 : 0.24;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + r.width * 0.08, r.top + r.height * (0.14 + i * 0.13), r.width * lw, 5),
          const Radius.circular(3),
        ),
        light,
      );
    }
    canvas.drawCircle(Offset(r.left + r.width * 0.12, r.top + r.height * 0.78), 6, light);

    // Barras
    final bars = [0.25, 0.4, 0.58, 0.75];
    for (var i = 0; i < bars.length; i++) {
      final bh = r.height * bars[i];
      final left = r.left + r.width * (0.5 + i * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, r.bottom - r.height * 0.1 - bh, r.width * 0.08, bh),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF6CC3FF),
      );
    }

    // Flecha ascendente
    final arrow = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final start = Offset(r.left + r.width * 0.3, r.top + r.height * 0.72);
    final end = Offset(r.left + r.width * 0.86, r.top + r.height * 0.2);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(r.left + r.width * 0.6, r.top + r.height * 0.6, end.dx, end.dy),
      arrow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(end.dx - 12, end.dy + 1)
        ..lineTo(end.dx, end.dy)
        ..lineTo(end.dx - 2, end.dy + 12),
      arrow,
    );

    // Base
    final base = Path()
      ..moveTo(w * 0.04, h * 0.84)
      ..lineTo(w * 0.88, h * 0.84)
      ..lineTo(w * 0.94, h * 0.9)
      ..lineTo(w * 0.12, h * 0.9)
      ..close();
    canvas.drawPath(base, Paint()..color = const Color(0xFF4A9BFF).withValues(alpha: 0.85));

    // Destellos
    final spark = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.32, h * 0.14), Offset(w * 0.37, h * 0.24), spark);
    canvas.drawLine(Offset(w * 0.2, h * 0.24), Offset(w * 0.28, h * 0.28), spark);
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
