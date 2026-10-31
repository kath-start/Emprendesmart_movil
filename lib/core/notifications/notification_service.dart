import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../theme/app_theme.dart';

/// Notificaciones del sistema (bandeja del teléfono). Solo Android e iOS; en el resto
/// de plataformas las llamadas no hacen nada.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _nextId = 0;

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      // Android 13+ pide permiso explícito para mostrar notificaciones.
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (error) {
      debugPrint('No se pudieron iniciar las notificaciones: $error');
    }
  }

  /// Muestra en la bandeja las alertas de stock bajo que devolvió una venta.
  static Future<void> showStockAlerts(List<String> messages) async {
    if (messages.isEmpty) return;
    await init();
    if (!_ready) return;

    final body = messages.join('\n');
    final title = messages.length == 1 ? 'Alerta de stock' : 'Alertas de stock (${messages.length})';
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'stock_alerts',
            'Alertas de stock',
            channelDescription: 'Avisos cuando a un producto le queda poco stock tras una venta',
            importance: Importance.high,
            priority: Priority.high,
            color: AppTheme.primary,
            // Texto expandible para que se lean todas las alertas completas.
            styleInformation: BigTextStyleInformation(body, contentTitle: title),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (error) {
      debugPrint('No se pudo mostrar la notificación: $error');
    }
  }
}
