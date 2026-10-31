import 'package:flutter/material.dart';

/// Contenido de un avatar redondo: el logo del negocio si existe, si no el ícono de respaldo.
class BusinessLogo extends StatelessWidget {
  final String? logoUrl;
  final Widget fallback;

  const BusinessLogo({super.key, required this.logoUrl, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: ColoredBox(
        color: Colors.white,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
        ),
      ),
    );
  }
}
