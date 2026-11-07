import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../theme/app_theme.dart';

/// Notificaciones del sistema (bandeja del teléfono). Solo Android e iOS; en el resto
/// de plataformas las llamadas no hacen nada.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _nextId = 0;

  /// Navigator de la app, para abrir una pantalla al tocar una notificación.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Qué hacer al tocar una notificación con cierto `payload` (lo registra quien la programa).
  static final Map<String, void Function(NavigatorState navigator)> _tapHandlers = {};

  /// Payload de la notificación que abrió la app estando cerrada; se atiende al llegar al inicio.
  static String? _launchPayload;

  static bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!isSupported || _ready) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) => _handleTap(response.payload),
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) _launchPayload = launch!.notificationResponse?.payload;
      // Android 13+ pide permiso explícito para mostrar notificaciones.
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (error) {
      debugPrint('No se pudieron iniciar las notificaciones: $error');
    }
  }

  static void registerTapHandler(String payload, void Function(NavigatorState navigator) handler) =>
      _tapHandlers[payload] = handler;

  /// Llamar cuando la app ya muestra el inicio: abre lo que pedía la notificación que la lanzó.
  static void handleLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    if (payload != null) _handleTap(payload);
  }

  static void _handleTap(String? payload) {
    final handler = _tapHandlers[payload];
    final navigator = navigatorKey.currentState;
    if (handler == null) return;
    if (navigator == null) {
      _launchPayload = payload;
      return;
    }
    handler(navigator);
  }

  /// Programa una notificación para [when] (hora local). Si [weekly], se repite cada semana.
  static Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
    bool weekly = false,
  }) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: payload,
        // Se programa en UTC con el instante exacto: no depende de la zona configurada.
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: weekly ? DateTimeComponents.dayOfWeekAndTime : null,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
            color: AppTheme.primary,
            styleInformation: BigTextStyleInformation(body, contentTitle: title),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (error) {
      debugPrint('No se pudo programar la notificación: $error');
    }
  }

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (error) {
      debugPrint('No se pudo cancelar la notificación: $error');
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
