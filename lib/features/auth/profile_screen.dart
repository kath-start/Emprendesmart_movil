import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/countries.dart';
import '../../core/utils/labels.dart';
import '../businesses/business_provider.dart';
import '../businesses/widgets/business_logo.dart';
import '../businesses/widgets/business_logo_picker.dart';
import '../plans/plans_screen.dart';
import 'auth_provider.dart';
import 'profile_edit_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openChangePasswordDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña actual'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                  validator: (value) => (value == null || value.length < 8) ? 'Mínimo 8 caracteres' : null,
                ),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña'),
                  validator: (value) => (value != newController.text) ? 'No coincide' : null,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMessage!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSubmitting = true;
                        errorMessage = null;
                      });
                      try {
                        await dialogContext.read<AuthProvider>().changePassword(
                          currentPassword: currentController.text,
                          newPassword: newController.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Contraseña actualizada correctamente')));
                        }
                      } on ApiException catch (error) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorMessage = error.message;
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Menú del engrane: accesos rápidos de la cuenta.
  Future<void> _openSettings(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      // El perfil vive dentro de la pestaña "Más": sin esto la hoja queda detrás de la barra inferior.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Ajustes de la cuenta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded, color: AppTheme.primary),
              title: const Text('Cambiar contraseña'),
              onTap: () => Navigator.of(sheetContext).pop('password'),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined, color: Color(0xFF7C3AED)),
              title: const Text('Ver planes'),
              onTap: () => Navigator.of(sheetContext).pop('plans'),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
              title: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFFDC2626))),
              onTap: () => Navigator.of(sheetContext).pop('logout'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;

    switch (action) {
      case 'password':
        await _openChangePasswordDialog(context);
      case 'plans':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen()));
      case 'logout':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text('¿Seguro que quieres salir de tu cuenta?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrepreneur = context.watch<AuthProvider>().entrepreneur;
    final business = context.watch<BusinessProvider>().currentBusiness;
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: entrepreneur == null
            ? const Center(child: CircularProgressIndicator())
            : CustomPaint(
                painter: _BackgroundWavePainter(),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Header(onSettings: () => _openSettings(context)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileSummary(
                            name: entrepreneur.fullName,
                            email: entrepreneur.email,
                            status: entrepreneur.status,
                            logoUrl: business?.logoUrl,
                            onChangePhoto: (business?.isOwner ?? false)
                                ? () => changeBusinessLogo(context, business!)
                                : null,
                          ),
                          const SizedBox(height: 22),
                          _InfoCard(
                            children: [
                              _InfoTile(
                                icon: Icons.person_outline_rounded,
                                color: const Color(0xFF1A6FF0),
                                label: 'Nombre',
                                onTap: () => open(EditNameScreen(entrepreneur: entrepreneur)),
                                value: entrepreneur.fullName,
                              ),
                              _InfoTile(
                                icon: Icons.mail_outline_rounded,
                                color: const Color(0xFF7C3AED),
                                label: 'Email',
                                onTap: () => open(ChangeEmailScreen(entrepreneur: entrepreneur)),
                                value: entrepreneur.email,
                              ),
                              // Los datos opcionales vacíos se muestran como "Agregar" para poder completarlos.
                              _InfoTile(
                                icon: Icons.phone_outlined,
                                color: const Color(0xFF0891B2),
                                label: 'Teléfono',
                                onTap: () => open(EditPhoneScreen(entrepreneur: entrepreneur)),
                                value: entrepreneur.phone ?? 'Agregar teléfono',
                                isEmpty: entrepreneur.phone == null,
                              ),
                              _InfoTile(
                                icon: Icons.location_on_outlined,
                                color: const Color(0xFFEC4899),
                                label: 'País',
                                onTap: () => open(EditCountryScreen(entrepreneur: entrepreneur)),
                                value: entrepreneur.country == null
                                    ? 'Agregar país'
                                    : [?countryFlag(entrepreneur.country), entrepreneur.country!].join('  '),
                                isEmpty: entrepreneur.country == null,
                              ),
                              _InfoTile(
                                icon: Icons.map_outlined,
                                color: const Color(0xFF16A34A),
                                label: 'Ciudad',
                                onTap: () => open(EditTextFieldScreen.city(entrepreneur)),
                                value: entrepreneur.city ?? 'Agregar ciudad',
                                isEmpty: entrepreneur.city == null,
                              ),
                              _InfoTile(
                                icon: Icons.work_outline_rounded,
                                color: const Color(0xFFF97316),
                                label: 'Plan',
                                onTap: () => open(const PlansScreen()),
                                value: entrepreneur.planExpiresAt == null
                                    ? Labels.plan(entrepreneur.plan)
                                    : '${Labels.plan(entrepreneur.plan)} · hasta ${_shortDate(entrepreneur.planExpiresAt!.toLocal())}',
                              ),
                              _InfoTile(
                                icon: Icons.bar_chart_rounded,
                                color: const Color(0xFF4F46E5),
                                label: 'Estado',
                                onTap: () => open(AccountStatusScreen(entrepreneur: entrepreneur)),
                                value: Labels.status(entrepreneur.status),
                                valueWidget: _StatusPill(status: entrepreneur.status, withCheck: true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _ChangePasswordButton(onPressed: () => _openChangePasswordDialog(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSettings;

  const _Header({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    Widget roundButton({required IconData icon, required String tooltip, required VoidCallback onPressed}) => Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        iconSize: 28,
        padding: const EdgeInsets.all(14),
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );

    return ClipPath(
      clipper: _CurvedBottomClipper(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A2A86), Color(0xFF1250D6), Color(0xFF2F7BFF)],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 48),
        child: Row(
          children: [
            roundButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Text(
                'Mi perfil',
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
              ),
            ),
            roundButton(icon: Icons.settings_rounded, tooltip: 'Ajustes', onPressed: onSettings),
          ],
        ),
      ),
    );
  }
}

/// Borde inferior en ola: baja a la izquierda y sube hacia la derecha.
class _CurvedBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..lineTo(0, h - 26)
      ..cubicTo(w * 0.22, h - 44, w * 0.42, h + 6, w * 0.7, h - 14)
      ..quadraticBezierTo(w * 0.88, h - 26, w, h - 48)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ProfileSummary extends StatelessWidget {
  final String name;
  final String email;
  final String status;
  final String? logoUrl;

  /// null: la persona no es dueña del negocio y no puede cambiar el logo.
  final VoidCallback? onChangePhoto;

  const _ProfileSummary({
    required this.name,
    required this.email,
    required this.status,
    this.logoUrl,
    this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 116,
          height: 116,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Anillo azul con brillo alrededor de la foto.
              Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9CC4FF), Color(0xFF3D8BFF)],
                  ),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 22, spreadRadius: 2),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3D8BFF), Color(0xFF0D47C9)],
                    ),
                  ),
                  child: BusinessLogo(
                    logoUrl: logoUrl,
                    fallback: const Icon(Icons.person_rounded, color: Colors.white, size: 60),
                  ),
                ),
              ),
              if (onChangePhoto != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Material(
                    color: AppTheme.primary,
                    shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onChangePhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: Color(0xFF3B5BA9)),
              ),
              const SizedBox(height: 12),
              _StatusPill(status: status),
            ],
          ),
        ),
      ],
    );
  }
}

/// Píldora verde (o roja) con el estado de la cuenta.
class _StatusPill extends StatelessWidget {
  final String status;
  final bool withCheck;

  const _StatusPill({required this.status, this.withCheck = false});

  @override
  Widget build(BuildContext context) {
    final active = status == 'ACTIVE';
    final color = active ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: (active ? const Color(0xFF22C55E) : color).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withCheck)
            Icon(active ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 20)
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 8),
          Text(
            Labels.status(status),
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Lista de datos: cada uno en su propia tarjeta blanca.
class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final child in children)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: AppTheme.navy.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  /// Reemplaza al texto del valor (p. ej. la píldora de "Estado").
  final Widget? valueWidget;

  /// El dato no está registrado: [value] es una invitación a agregarlo.
  final bool isEmpty;

  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    this.valueWidget,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF4A5B85))),
                  const SizedBox(height: 4),
                  valueWidget ??
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isEmpty ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                ],
              ),
            ),
            Icon(
              isEmpty ? Icons.add_rounded : Icons.chevron_right_rounded,
              color: isEmpty ? AppTheme.primary : AppTheme.textPrimary,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ChangePasswordButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFF1A6FF0), Color(0xFF0D5BE0)]),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: Colors.white, size: 26),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Cambiar contraseña',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ondas suaves al pie de la pantalla, como fondo decorativo.
class _BackgroundWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final back = Path()
      ..moveTo(0, size.height - 150)
      ..quadraticBezierTo(size.width * 0.35, size.height - 230, size.width * 0.65, size.height - 170)
      ..quadraticBezierTo(size.width * 0.85, size.height - 130, size.width, size.height - 210)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final front = Path()
      ..moveTo(0, size.height - 90)
      ..quadraticBezierTo(size.width * 0.3, size.height - 150, size.width * 0.6, size.height - 100)
      ..quadraticBezierTo(size.width * 0.85, size.height - 60, size.width, size.height - 120)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, Paint()..color = AppTheme.primary.withValues(alpha: 0.05));
    canvas.drawPath(front, Paint()..color = AppTheme.primary.withValues(alpha: 0.07));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _shortDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
