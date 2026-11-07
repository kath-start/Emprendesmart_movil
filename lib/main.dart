import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/plan_reminders.dart';
import 'features/auth/firebase_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseSignIn.init();
  PlanReminders.registerTapHandler();
  NotificationService.init();
  runApp(const App());
}
