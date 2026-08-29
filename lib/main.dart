import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app.dart';
import 'features/account/auth_repository.dart';
import 'features/account/firebase_auth_repository.dart';
import 'firebase_configuration.dart';
import 'features/family/family_repository.dart';
import 'features/family/firestore_family_repository.dart';
import 'features/calendar/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthRepository? auth;
  FamilyRepository? family;
  String? accountSetupError;
  ReminderService? reminders;
  try {
    reminders = await LocalReminderService.initialize();
  } catch (_) {
    // The calendar remains usable if the operating system notification service
    // is unavailable on this platform.
  }
  try {
    final options = const FirebaseConfiguration.fromEnvironment().options;
    if (options != null) {
      final app = await Firebase.initializeApp(options: options)
          .timeout(const Duration(seconds: 15));
      final firebaseAuth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      firestore.settings = const Settings(persistenceEnabled: false);
      auth = FirebaseAuthRepository(firebaseAuth);
      family = FirestoreFamilyRepository(firestore, firebaseAuth);
    }
  } catch (_) {
    // Do not expose configuration, tokens or SDK exception details in the UI.
    accountSetupError =
        'Die Kontoverbindung konnte nicht gestartet werden. '
        'Bitte prüfe die Firebase-Einrichtung und starte die App erneut.';
  }
  runApp(
    MoonkeepApp(
      auth: auth,
      family: family,
      accountSetupError: accountSetupError,
      reminders: reminders,
    ),
  );
}
