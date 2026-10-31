import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/labels.dart';
import '../../models/business.dart';
import '../businesses/business_provider.dart';
import '../businesses/widgets/business_logo.dart';
import '../plans/plans_screen.dart';
import 'auth_provider.dart';

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

  /// La foto del perfil es el logo del negocio actual; solo el dueño puede cambiarla.
  Future<void> _changeLogo(BuildContext context, Business business) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      // El perfil vive dentro de la pestaña "Más": sin esto la hoja queda detrás de la barra inferior.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Logo de ${business.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
            if (business.logoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                title: const Text('Quitar logo', style: TextStyle(color: Color(0xFFDC2626))),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    final provider = context.read<BusinessProvider>();
    final messenger = ScaffoldMessenger.of(context);
    void show(String message) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    try {
      if (action == 'remove') {
        await provider.removeLogo(business.id);
        show('Se quitó el logo');
        return;
      }
      final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final XFile? file;
      try {
        file = await ImagePicker().pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      } catch (_) {
        show(source == ImageSource.camera ? 'No se pudo abrir la cámara.' : 'No se pudo abrir la galería.');
        return;
      }
      if (file == null) return;
      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      show('Subiendo logo…');
      await provider.uploadLogo(business.id, await file.readAsBytes(), contentType: contentType);
      show('Logo de ${business.name} actualizado');
    } on ApiException catch (e) {
      show(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrepreneur = context.watch<AuthProvider>().entrepreneur;
    final business = context.watch<BusinessProvider>().currentBusiness;
    // Editar datos y foto aún no existe en la API: se avisa en vez de dejar botones que no responden.
    void comingSoon(String message) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

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
                            onChangePhoto: (business?.isOwner ?? false) ? () => _changeLogo(context, business!) : null,
                          ),
                          const SizedBox(height: 24),
                          _InfoCard(
                            children: [
                              _InfoTile(
                                icon: Icons.person_outline_rounded,
                                color: AppTheme.primary,
                                label: 'Nombre',
                                onTap: () => comingSoon('Pronto podrás editar este dato'),
                                value: entrepreneur.fullName,
                              ),
                              _InfoTile(
                                icon: Icons.mail_outline_rounded,
                                color: const Color(0xFF7C3AED),
                                label: 'Email',
                                onTap: () => comingSoon('Pronto podrás editar este dato'),
                                value: entrepreneur.email,
                              ),
                              if (entrepreneur.phone != null)
                                _InfoTile(
                                  icon: Icons.phone_outlined,
                                  color: const Color(0xFF0EA5E9),
                                  label: 'Teléfono',
                                  onTap: () => comingSoon('Pronto podrás editar este dato'),
                                  value: entrepreneur.phone!,
                                ),
                              if (entrepreneur.country != null)
                                _InfoTile(
                                  icon: Icons.public_rounded,
                                  color: const Color(0xFF14B8A6),
                                  label: 'País',
                                  onTap: () => comingSoon('Pronto podrás editar este dato'),
                                  value: entrepreneur.country!,
                                ),
                              if (entrepreneur.city != null)
                                _InfoTile(
                                  icon: Icons.location_on_outlined,
                                  color: const Color(0xFFEC4899),
                                  label: 'Ciudad',
                                  onTap: () => comingSoon('Pronto podrás editar este dato'),
                                  value: entrepreneur.city!,
                                ),
                              _InfoTile(
                                icon: Icons.credit_card_rounded,
                                color: const Color(0xFF10B981),
                                label: 'Plan',
                                onTap: () =>
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen())),
                                value: Labels.plan(entrepreneur.plan),
                              ),
                              _InfoTile(
                                icon: Icons.verified_user_outlined,
                                color: const Color(0xFFF59E0B),
                                label: 'Estado',
                                onTap: () =>
                                    comingSoon('Tu cuenta está ${Labels.status(entrepreneur.status).toLowerCase()}'),
                                value: Labels.status(entrepreneur.status),
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
            const Expanded(
              child: Text(
                'Mi perfil',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            Material(
              color: Colors.white.withValues(alpha: 0.16),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Ajustes',
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                onPressed: onSettings,
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
    final isActive = status == 'ACTIVE';
    final statusColor = isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary.withValues(alpha: 0.08)),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3D8BFF), Color(0xFF0D47C9)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: BusinessLogo(
                  logoUrl: logoUrl,
                  fallback: const Icon(Icons.person_rounded, color: Colors.white, size: 52),
                ),
              ),
            ),
            if (onChangePhoto != null)
              Positioned(
                right: 2,
                bottom: 2,
                child: Material(
                  color: AppTheme.primary,
                  shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onChangePhoto,
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
          ],
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      Labels.status(status),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppTheme.navy.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFE6ECF5)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
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
