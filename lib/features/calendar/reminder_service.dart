import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';

tz.TZDateTime? reminderDateTime(CalendarEvent event, {required bool shared}) {
  if (event.isAllDay || event.reminderOffset == ReminderOffset.none) {
    return null;
  }
  final start = shared
      ? tz.TZDateTime(
          tz.getLocation('Europe/Berlin'),
          event.start.year,
          event.start.month,
          event.start.day,
          event.start.hour,
          event.start.minute,
        )
      : tz.TZDateTime.from(event.start.toUtc(), tz.UTC);
  if (event.reminderOffset == ReminderOffset.days1) {
    return tz.TZDateTime(
      start.location,
      start.year,
      start.month,
      start.day - 1,
      start.hour,
      start.minute,
    );
  }
  return start.subtract(Duration(minutes: event.reminderOffset.minutesBefore!));
}

tz.TZDateTime? schedulableReminderDateTime(
  CalendarEvent event, {
  required bool shared,
  tz.TZDateTime? now,
}) {
  final scheduled = reminderDateTime(event, shared: shared);
  if (scheduled == null) return null;
  final current = now ?? tz.TZDateTime.now(scheduled.location);
  return scheduled.isAfter(current) ? scheduled : null;
}

abstract interface class ReminderService {
  Future<bool> requestPermission();
  Future<void> schedule(CalendarEvent event, {required bool shared});
  Future<void> cancel(String eventId);
}

class LocalReminderService implements ReminderService {
  LocalReminderService._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'moonkeep_reminders',
      'Terminerinnerungen',
      channelDescription: 'Erinnerungen an bevorstehende Moonkeep-Termine',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<LocalReminderService> initialize() async {
    tz_data.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return LocalReminderService._(plugin);
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidGranted ?? iosGranted ?? true;
  }

  @override
  Future<void> schedule(CalendarEvent event, {required bool shared}) async {
    await cancel(event.id);
    final scheduled = schedulableReminderDateTime(event, shared: shared);
    if (scheduled == null) return;
    await _plugin.zonedSchedule(
      id: _notificationId(event.id),
      title: event.reminderOffset == ReminderOffset.atStart
          ? 'Termin beginnt jetzt'
          : 'Termin steht bevor',
      body: event.title,
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: event.id,
    );
  }

  @override
  Future<void> cancel(String eventId) =>
      _plugin.cancel(id: _notificationId(eventId));

  int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
