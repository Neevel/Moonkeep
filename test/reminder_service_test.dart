import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/features/calendar/calendar_event.dart';
import 'package:moonkeep/features/calendar/reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);

  CalendarEvent event(
    ReminderOffset offset, {
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    EventRecurrence recurrence = EventRecurrence.none,
  }) {
    final actualStart = start ?? DateTime.utc(2026, 9, 10, 18);
    return CalendarEvent(
      id: offset.name,
      title: 'Termin',
      start: actualStart,
      end: end ?? actualStart.add(const Duration(hours: 1)),
      isAllDay: allDay,
      recurrence: recurrence,
      reminderOffset: offset,
    );
  }

  test('calculates every selectable offset from the Berlin event start', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final expected = <ReminderOffset, tz.TZDateTime>{
      ReminderOffset.atStart: tz.TZDateTime(berlin, 2026, 9, 10, 18),
      ReminderOffset.minutes15: tz.TZDateTime(berlin, 2026, 9, 10, 17, 45),
      ReminderOffset.minutes30: tz.TZDateTime(berlin, 2026, 9, 10, 17, 30),
      ReminderOffset.hours1: tz.TZDateTime(berlin, 2026, 9, 10, 17),
      ReminderOffset.days1: tz.TZDateTime(berlin, 2026, 9, 9, 18),
    };
    expect(reminderDateTime(event(ReminderOffset.none), shared: true), isNull);
    for (final entry in expected.entries) {
      expect(reminderDateTime(event(entry.key), shared: true), entry.value);
    }
  });

  test('handles day month year and daylight-saving boundaries', () {
    final berlin = tz.getLocation('Europe/Berlin');
    CalendarEvent at(DateTime start, ReminderOffset offset) =>
        event(offset, start: start, end: start.add(const Duration(hours: 1)));

    expect(
      reminderDateTime(
        at(DateTime.utc(2026, 1, 1, 0, 10), ReminderOffset.minutes15),
        shared: true,
      ),
      tz.TZDateTime(berlin, 2025, 12, 31, 23, 55),
    );
    final dst = reminderDateTime(
      at(DateTime.utc(2026, 3, 29, 18), ReminderOffset.days1),
      shared: true,
    )!;
    expect((dst.year, dst.month, dst.day, dst.hour), (2026, 3, 28, 18));
  });

  test('past reminders are skipped without changing the event', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final appointment = event(ReminderOffset.minutes30);
    expect(
      schedulableReminderDateTime(
        appointment,
        shared: true,
        now: tz.TZDateTime(berlin, 2026, 9, 10, 17, 20),
      ),
      tz.TZDateTime(berlin, 2026, 9, 10, 17, 30),
    );
    expect(
      schedulableReminderDateTime(
        appointment,
        shared: true,
        now: tz.TZDateTime(berlin, 2026, 9, 10, 17, 50),
      ),
      isNull,
    );
    expect(appointment.reminderOffset, ReminderOffset.minutes30);
  });

  test('multi-day uses only its start and all-day schedules nothing', () {
    final start = DateTime.utc(2026, 9, 4, 18);
    final end = DateTime.utc(2026, 9, 6, 12);
    final timed = event(ReminderOffset.days1, start: start, end: end);
    expect(
      reminderDateTime(timed, shared: true),
      tz.TZDateTime(tz.getLocation('Europe/Berlin'), 2026, 9, 3, 18),
    );
    expect(
      reminderDateTime(
        event(ReminderOffset.none, start: start, end: end, allDay: true),
        shared: true,
      ),
      isNull,
    );
  });

  test('recurrence keeps the existing original-start scheduling behavior', () {
    final recurring = event(
      ReminderOffset.minutes15,
      recurrence: EventRecurrence.weekly,
    );
    expect(
      reminderDateTime(recurring, shared: true),
      tz.TZDateTime(tz.getLocation('Europe/Berlin'), 2026, 9, 10, 17, 45),
    );
  });

  testWidgets('local scheduling cancels before create edit and delete', (
    tester,
  ) async {
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final service = await LocalReminderService.initialize();
    calls.clear();

    await service.schedule(event(ReminderOffset.none), shared: true);
    expect(calls.map((call) => call.method), ['cancel']);

    calls.clear();
    final futureStart = DateTime.utc(2099, 9, 10, 18);
    await service.schedule(
      event(ReminderOffset.minutes15, start: futureStart),
      shared: true,
    );
    expect(calls.map((call) => call.method), ['cancel', 'zonedSchedule']);

    await service.schedule(
      event(ReminderOffset.hours1, start: futureStart),
      shared: true,
    );
    expect(calls.map((call) => call.method), [
      'cancel',
      'zonedSchedule',
      'cancel',
      'zonedSchedule',
    ]);

    calls.clear();
    await service.schedule(
      event(ReminderOffset.minutes30, start: DateTime.utc(2020, 1, 1, 18)),
      shared: true,
    );
    expect(calls.map((call) => call.method), ['cancel']);

    calls.clear();
    await service.cancel(ReminderOffset.minutes15.name);
    expect(calls.map((call) => call.method), ['cancel']);
  });
}
