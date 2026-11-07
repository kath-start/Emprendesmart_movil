import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/yape_payment.dart';

/// Cobros de Yape leídos de las notificaciones del teléfono (solo Android).
///
/// El lector nativo (`YapeNotificationListener.kt`) guarda cada pago en una cola aunque la
/// app esté cerrada; aquí se pasan a la lista local y el emprendedor les asigna productos.
class YapeProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _channel = MethodChannel('emprende_smart/yape');
  static const _events = EventChannel('emprende_smart/yape_events');
  static const _storageKey = 'yape_payments';
  static const _maxStored = 300;

  final FlutterSecureStorage _storage;
  StreamSubscription<dynamic>? _eventsSubscription;
  bool _started = false;
  Future<void>? _syncing;

  YapeProvider({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  List<YapePayment> payments = [];

  /// Si el usuario dio a la app el "Acceso a notificaciones" de Android.
  bool isListenerEnabled = false;

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  List<YapePayment> get pending => payments.where((p) => p.isPending).toList();

  List<YapePayment> get history => payments.where((p) => !p.isPending).toList();

  int get pendingCount => payments.where((p) => p.isPending).length;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _load();
    if (!isSupported) return;
    WidgetsBinding.instance.addObserver(this);
    _eventsSubscription = _events.receiveBroadcastStream().listen((_) => sync(), onError: (_) {});
    await refreshPermission();
    await sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes (o de Yape) se revisa el permiso y los pagos que llegaron mientras tanto.
    if (state == AppLifecycleState.resumed) {
      refreshPermission();
      sync();
    }
  }

  Future<void> refreshPermission() async {
    if (!isSupported) return;
    try {
      final enabled = await _channel.invokeMethod<bool>('isEnabled') ?? false;
      if (enabled != isListenerEnabled) {
        isListenerEnabled = enabled;
        notifyListeners();
      }
    } on PlatformException catch (error) {
      debugPrint('No se pudo revisar el acceso a notificaciones: $error');
    }
  }

  Future<void> openListenerSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openSettings');
  }

  /// Trae los pagos que leyó Android y los borra de su cola una vez guardados aquí.
  Future<void> sync() => _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<void> _sync() async {
    if (!isSupported) return;
    try {
      final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>('pending') ?? [];
      if (raw.isEmpty) return;

      final known = payments.map((p) => p.id).toSet();
      final incoming = <YapePayment>[];
      for (final item in raw) {
        final id = item['id'] as String;
        if (known.contains(id)) continue;
        incoming.add(
          YapePayment.fromNotification(
            id: id,
            title: item['title'] as String? ?? '',
            text: item['text'] as String? ?? '',
            postedAt: DateTime.fromMillisecondsSinceEpoch((item['postedAt'] as num).toInt()),
            source: item['source'] as String? ?? 'yape',
          ),
        );
      }
      if (incoming.isNotEmpty) {
        _setPayments([...incoming, ...payments]);
        await _save();
      }
      // Solo se borra de la cola nativa lo que ya quedó guardado.
      await _channel.invokeMethod<void>('ack', {'ids': raw.map((item) => item['id'] as String).toList()});
    } on PlatformException catch (error) {
      debugPrint('No se pudieron leer los pagos de Yape: $error');
    }
  }

  Future<void> markLinked(String paymentId, {required String saleId, required String businessId}) =>
      _update(paymentId, (p) => p.copyWith(status: YapePaymentStatus.linked, saleId: saleId, businessId: businessId));

  Future<void> ignore(String paymentId) => _update(paymentId, (p) => p.copyWith(status: YapePaymentStatus.ignored));

  Future<void> restore(String paymentId) => _update(paymentId, (p) => p.copyWith(status: YapePaymentStatus.pending));

  Future<void> _update(String id, YapePayment Function(YapePayment) change) async {
    _setPayments([for (final p in payments) p.id == id ? change(p) : p]);
    await _save();
  }

  void _setPayments(List<YapePayment> list) {
    list.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    payments = list.length > _maxStored ? list.sublist(0, _maxStored) : list;
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null) return;
      final items = jsonDecode(raw) as List<dynamic>;
      _setPayments(items.map((item) => YapePayment.fromJson(item as Map<String, dynamic>)).toList());
    } catch (error) {
      debugPrint('No se pudieron cargar los cobros de Yape: $error');
    }
  }

  Future<void> _save() => _storage.write(key: _storageKey, value: jsonEncode(payments.map((p) => p.toJson()).toList()));

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    if (_started && isSupported) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
