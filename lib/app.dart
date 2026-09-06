import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/calendar/calendar_screen.dart';
import 'features/calendar/calendar_store.dart';
import 'features/calendar/reminder_service.dart';
import 'features/account/auth_repository.dart';
import 'features/account/account_screen.dart';
import 'features/family/family_repository.dart';
import 'features/family/family_screen.dart';
import 'features/settings/settings_screen.dart';
import 'theme/moonkeep_theme.dart';
import 'theme/moonkeep_theme_controller.dart';

class MoonkeepApp extends StatefulWidget {
  const MoonkeepApp({
    super.key,
    this.store,
    this.auth,
    this.family,
    this.accountSetupError,
    this.reminders,
    this.autoOpenCalendar = true,
    this.themeController,
  });

  final CalendarStore? store;
  final AuthRepository? auth;
  final FamilyRepository? family;
  final String? accountSetupError;
  final ReminderService? reminders;
  final bool autoOpenCalendar;
  final MoonkeepThemeController? themeController;

  @override
  State<MoonkeepApp> createState() => _MoonkeepAppState();
}

class _MoonkeepAppState extends State<MoonkeepApp> {
  late final MoonkeepThemeController _themeController =
      widget.themeController ?? MoonkeepThemeController();
  late final bool _ownsThemeController = widget.themeController == null;

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_themeChanged);
  }

  void _themeChanged() => setState(() {});

  @override
  void dispose() {
    _themeController.removeListener(_themeChanged);
    if (_ownsThemeController) _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Moonkeep',
    debugShowCheckedModeBanner: false,
    locale: const Locale('de', 'DE'),
    supportedLocales: const [Locale('de', 'DE')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: MoonkeepThemes.themeFor(_themeController.themeId),
    builder: (context, child) => MoonkeepThemeScope(
      controller: _themeController,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    ),
    home: widget.store != null
        ? CalendarScreen(store: widget.store, reminders: widget.reminders)
        : FamilyScreen(
            auth: widget.auth,
            repository: widget.family,
            reminders: widget.reminders,
            autoOpenCalendar: widget.autoOpenCalendar,
          ),
    routes: {
      '/account': (context) => AccountScreen(
        auth: widget.auth,
        syncDisplayName: widget.family?.updateOwnDisplayName,
        accountDeletionPlan: widget.family?.accountDeletionPlan,
        cleanupForAccountDeletion: widget.family?.cleanupForAccountDeletion,
        setupError: widget.accountSetupError,
      ),
      '/family': (context) => FamilyScreen(
        auth: widget.auth,
        repository: widget.family,
        reminders: widget.reminders,
        initialSection:
            ModalRoute.of(context)?.settings.arguments as FamilySection?,
      ),
    },
  );
}
