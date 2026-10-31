import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.init();
  runApp(const App());
}
