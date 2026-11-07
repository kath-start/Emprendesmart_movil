import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/plans/plans_screen.dart';
import '../../models/entrepreneur.dart';
import '../utils/labels.dart';
import 'notification_service.dart';

/// Recordatorios en la bandeja del teléfono para pagar o renovar el plan de EmprendeSmart.
///
/// - Plan de pago con vencimiento: 3 días antes, 1 día antes, el día que vence y al vencer
///   (quedan 3 días de gracia antes de volver a Gratis; lo hace el backend).
/// - Plan Gratis: un recordatorio semanal (lunes 10:00) para empezar un plan.
///
/// Se reprograman cada vez que cambia el perfil (login, pago confirmado, etc.).
class PlanReminders {
  PlanReminders._();

  static const payload = 'plans';
  static const _channelId = 'plan_reminders';
  static const _channelName = 'Recordatorios de pago';
  static const _enabledKey = 'plan_reminders_enabled';
  static const _graceDays = 3;
  static const _reminderHour = 10;

  /// Ids fijos para poder cancelarlos y reprogramarlos.
  static const _ids = [9001, 9002, 9003, 9004, 9005];

  static const _storage = FlutterSecureStorage();

  static Future<bool> isEnabled() async => (await _storage.read(key: _enabledKey)) != 'false';

  static Future<void> setEnabled(bool enabled, Entrepreneur? entrepreneur) async {
    await _storage.write(key: _enabledKey, value: enabled.toString());
    await sync(entrepreneur);
  }

  /// Registra qué abrir al tocar un recordatorio: la pantalla de planes (de ahí, el QR de Yape).
  static void registerTapHandler() {
    NotificationService.registerTapHandler(
      payload,
      (navigator) => navigator.push(MaterialPageRoute(builder: (_) => const PlansScreen())),
    );
  }

  static Future<void> sync(Entrepreneur? entrepreneur) async {
    if (!NotificationService.isSupported) return;
    for (final id in _ids) {
      await NotificationService.cancel(id);
    }
    if (entrepreneur == null || !await isEnabled()) return;

    if (entrepreneur.isFreePlan) {
      await NotificationService.schedule(
        id: _ids.first,
        when: _nextWeekday(DateTime.monday),
        weekly: true,
        title: 'Haz crecer tu negocio 🚀',
        body: 'Empieza un plan de EmprendeSmart desde S/ 19.90 al mes y paga fácil con Yape.',
        channelId: _channelId,
        channelName: _channelName,
        payload: payload,
      );
      return;
    }

    final expires = entrepreneur.planExpiresAt?.toLocal();
    if (expires == null) return; // Plan sin vencimiento: nada que recordar.

    final day = DateUtils.dateOnly(expires);
    final graceEnd = day.add(const Duration(days: _graceDays));
    final reminders = <(DateTime, String, String)>[
      (
        _at(day.subtract(const Duration(days: 3))),
        'Tu plan vence en 3 días',
        'Renueva tu plan ${Labels.plan(entrepreneur.plan)} con Yape y sigue usando todas sus funciones.',
      ),
      (
        _at(day.subtract(const Duration(days: 1))),
        'Tu plan vence mañana',
        'Renueva hoy tu plan ${Labels.plan(entrepreneur.plan)}: escanea el QR de Yape desde la app.',
      ),
      (
        _at(day),
        'Tu plan vence hoy',
        'Paga tu plan ${Labels.plan(entrepreneur.plan)} con Yape para no perder tus beneficios.',
      ),
      (
        _at(day.add(const Duration(days: 1))),
        'Tu plan venció',
        'Tienes hasta el ${_date(graceEnd)} para renovar; después tu cuenta pasará al plan Gratis.',
      ),
    ];

    final now = DateTime.now();
    for (var i = 0; i < reminders.length; i++) {
      final (date, title, body) = reminders[i];
      if (!date.isAfter(now)) continue;
      await NotificationService.schedule(
        id: _ids[i + 1],
        when: date,
        title: title,
        body: body,
        channelId: _channelId,
        channelName: _channelName,
        payload: payload,
      );
    }
  }

  static DateTime _at(DateTime day) => DateTime(day.year, day.month, day.day, _reminderHour);

  static DateTime _nextWeekday(int weekday) {
    final now = DateTime.now();
    var date = _at(now);
    while (date.weekday != weekday || !date.isAfter(now)) {
      date = _at(date.add(const Duration(days: 1)));
    }
    return date;
  }

  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
