import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/calendar/calendar_screen.dart';
import 'features/calendar/calendar_store.dart';
import 'features/calendar/reminder_service.dart';
import 'features/account/auth_repository.dart';
import 'features/account/account_screen.dart';
import 'features/family/family_repository.dart';
import 'features/family/family_screen.dart';

class MoonkeepApp extends StatelessWidget {
  const MoonkeepApp({
    super.key,
    this.store,
    this.auth,
    this.family,
    this.accountSetupError,
    this.reminders,
    this.autoOpenCalendar = true,
  });

  final CalendarStore? store;
  final AuthRepository? auth;
  final FamilyRepository? family;
  final String? accountSetupError;
  final ReminderService? reminders;
  final bool autoOpenCalendar;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Moonkeep',
    debugShowCheckedModeBanner: false,
    locale: const Locale('de', 'DE'),
    supportedLocales: const [Locale('de', 'DE')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF65558F)),
      scaffoldBackgroundColor: const Color(0xFFF9F7FC),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
    home: store != null
        ? CalendarScreen(store: store, reminders: reminders)
        : FamilyScreen(
            auth: auth,
            repository: family,
            reminders: reminders,
            autoOpenCalendar: autoOpenCalendar,
          ),
    routes: {
      '/account': (context) =>
          AccountScreen(auth: auth, setupError: accountSetupError),
      '/family': (context) =>
          FamilyScreen(auth: auth, repository: family, reminders: reminders),
    },
  );
}
