import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';

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
    if (event.isAllDay) return;
    final minutes = event.reminderMinutesBefore;
    if (minutes == null) return;
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
    final scheduled = start.subtract(Duration(minutes: minutes));
    if (!scheduled.isAfter(tz.TZDateTime.now(scheduled.location))) return;
    await _plugin.zonedSchedule(
      id: _notificationId(event.id),
      title: minutes == 0 ? 'Termin beginnt jetzt' : 'Termin steht bevor',
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
