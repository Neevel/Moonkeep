import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_event.dart';

const recurringReminderPlanningDays = 30;
const iosPendingNotificationLimit = 64;
const _payloadPrefix = 'moonkeep:event:';

class PlannedReminder {
  const PlannedReminder({
    required this.occurrenceStart,
    required this.scheduledDate,
  });

  final tz.TZDateTime occurrenceStart;
  final tz.TZDateTime scheduledDate;
}

tz.Location _eventLocation(bool shared) =>
    shared ? tz.getLocation('Europe/Berlin') : tz.UTC;

tz.TZDateTime _eventStart(CalendarEvent event, tz.Location location) =>
    tz.TZDateTime(
      location,
      event.start.year,
      event.start.month,
      event.start.day,
      event.start.hour,
      event.start.minute,
    );

tz.TZDateTime _reminderForStart(tz.TZDateTime start, ReminderOffset offset) {
  if (offset == ReminderOffset.days1) {
    // Civil subtraction keeps the local wall time stable across DST changes.
    return tz.TZDateTime(
      start.location,
      start.year,
      start.month,
      start.day - 1,
      start.hour,
      start.minute,
    );
  }
  return start.subtract(Duration(minutes: offset.minutesBefore!));
}

tz.TZDateTime? reminderDateTime(CalendarEvent event, {required bool shared}) {
  if (event.isAllDay || event.reminderOffset == ReminderOffset.none) {
    return null;
  }
  return _reminderForStart(
    _eventStart(event, _eventLocation(shared)),
    event.reminderOffset,
  );
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

/// Plans reminders whose notification time is in the next 30 calendar days.
///
/// Occurrences are inspected up to one day beyond that window so a one-day
/// offset can still produce a reminder inside it. CalendarEvent.occursOn is the
/// single recurrence rule source used by both the calendar and notifications.
List<PlannedReminder> plannedReminders(
  CalendarEvent event, {
  required bool shared,
  tz.TZDateTime? now,
}) {
  if (event.isAllDay || event.reminderOffset == ReminderOffset.none) {
    return const [];
  }
  final location = _eventLocation(shared);
  final current = now ?? tz.TZDateTime.now(location);
  if (event.recurrence == EventRecurrence.none) {
    final scheduled = schedulableReminderDateTime(
      event,
      shared: shared,
      now: current,
    );
    return scheduled == null
        ? const []
        : [
            PlannedReminder(
              occurrenceStart: _eventStart(event, location),
              scheduledDate: scheduled,
            ),
          ];
  }

  final windowEnd = tz.TZDateTime(
    location,
    current.year,
    current.month,
    current.day + recurringReminderPlanningDays,
    current.hour,
    current.minute,
    current.second,
    current.millisecond,
    current.microsecond,
  );
  final extraOccurrenceDays =
      (event.reminderOffset.minutesBefore! / Duration.minutesPerDay).ceil();
  final lastOccurrenceDay = tz.TZDateTime(
    location,
    windowEnd.year,
    windowEnd.month,
    windowEnd.day + extraOccurrenceDays,
  );
  var day = tz.TZDateTime(location, current.year, current.month, current.day);
  final result = <PlannedReminder>[];
  while (!day.isAfter(lastOccurrenceDay)) {
    final civilDay = DateTime.utc(day.year, day.month, day.day);
    if (event.occursOn(civilDay)) {
      final occurrenceStart = tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
        event.start.hour,
        event.start.minute,
      );
      final scheduled = _reminderForStart(
        occurrenceStart,
        event.reminderOffset,
      );
      if (scheduled.isAfter(current) && !scheduled.isAfter(windowEnd)) {
        result.add(
          PlannedReminder(
            occurrenceStart: occurrenceStart,
            scheduledDate: scheduled,
          ),
        );
      }
    }
    day = tz.TZDateTime(location, day.year, day.month, day.day + 1);
  }
  return result;
}

int reminderNotificationId(String eventId, tz.TZDateTime occurrenceStart) {
  final value =
      '$eventId|${occurrenceStart.year}-${occurrenceStart.month}-${occurrenceStart.day}'
      'T${occurrenceStart.hour}:${occurrenceStart.minute}';
  return _stableNotificationId(value);
}

int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

abstract interface class ReminderService {
  Future<bool> requestPermission();
  Future<void> cancel(String eventId);
  Future<void> reconcile(
    Iterable<CalendarEvent> events, {
    required bool shared,
  });
}

class LocalReminderService implements ReminderService {
  LocalReminderService._(this._plugin, this._now, this._platform);

  final FlutterLocalNotificationsPlugin _plugin;
  final tz.TZDateTime Function(tz.Location location) _now;
  final TargetPlatform _platform;
  Future<void> _pendingOperation = Future.value();
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'moonkeep_reminders',
      'Terminerinnerungen',
      channelDescription: 'Erinnerungen an bevorstehende Moonkeep-Termine',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<LocalReminderService> initialize({
    tz.TZDateTime Function(tz.Location location)? now,
    TargetPlatform? platform,
  }) async {
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
    return LocalReminderService._(
      plugin,
      now ?? (location) => tz.TZDateTime.now(location),
      platform ?? defaultTargetPlatform,
    );
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

  Future<void> _serialized(Future<void> Function() operation) {
    final result = _pendingOperation.then((_) => operation());
    _pendingOperation = result.catchError((_) {});
    return result;
  }

  @override
  Future<void> cancel(String eventId) =>
      _serialized(() => _cancelEvent(eventId));

  @override
  Future<void> reconcile(
    Iterable<CalendarEvent> events, {
    required bool shared,
  }) => _serialized(() async {
    final location = _eventLocation(shared);
    final current = _now(location);
    final desired = <(CalendarEvent, PlannedReminder)>[];
    for (final event in events) {
      for (final planned in plannedReminders(
        event,
        shared: shared,
        now: current,
      )) {
        desired.add((event, planned));
      }
    }
    desired.sort((left, right) {
      final byDate = left.$2.scheduledDate.compareTo(right.$2.scheduledDate);
      if (byDate != 0) return byDate;
      final byEvent = left.$1.id.compareTo(right.$1.id);
      if (byEvent != 0) return byEvent;
      return left.$2.occurrenceStart.compareTo(right.$2.occurrenceStart);
    });
    if (_platform == TargetPlatform.iOS &&
        desired.length > iosPendingNotificationLimit) {
      desired.removeRange(iosPendingNotificationLimit, desired.length);
    }
    final desiredIds = desired
        .map(
          (item) => reminderNotificationId(item.$1.id, item.$2.occurrenceStart),
        )
        .toSet();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final currentPayload =
          request.payload?.startsWith(_payloadPrefix) == true;
      if (!currentPayload || !desiredIds.contains(request.id)) {
        // Non-namespaced payloads are reminders from Moonkeep's legacy ID
        // strategy; this app has no other local-notification feature.
        await _plugin.cancel(id: request.id);
      }
    }
    for (final item in desired) {
      await _schedulePlanned(item.$1, item.$2);
    }
  });

  Future<void> _cancelEvent(String eventId) async {
    final payload = '$_payloadPrefix$eventId';
    final pending = await _plugin.pendingNotificationRequests();
    final ids = pending
        .where(
          (request) => request.payload == payload || request.payload == eventId,
        )
        .map((request) => request.id)
        .toSet();
    // Clean up the one-ID strategy used before occurrence reminders.
    ids.add(_stableNotificationId(eventId));
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> _schedulePlanned(CalendarEvent event, PlannedReminder planned) =>
      _plugin.zonedSchedule(
        id: reminderNotificationId(event.id, planned.occurrenceStart),
        title: event.reminderOffset == ReminderOffset.atStart
            ? 'Termin beginnt jetzt'
            : 'Termin steht bevor',
        body: event.title,
        scheduledDate: planned.scheduledDate,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_payloadPrefix${event.id}',
      );
}
