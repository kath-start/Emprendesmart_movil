import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/business.dart';
import '../business_provider.dart';

/// Cambia, agrega o quita el logo de un negocio (cámara o galería). Solo para el dueño.
Future<void> changeBusinessLogo(BuildContext context, Business business) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    // Algunas pantallas viven dentro de la pestaña "Más": sin esto la hoja queda detrás de la barra inferior.
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
