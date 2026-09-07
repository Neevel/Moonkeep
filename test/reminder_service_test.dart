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
    String id = 'event-1',
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    EventRecurrence recurrence = EventRecurrence.none,
    DateTime? recurrenceEnd,
  }) {
    final actualStart = start ?? DateTime.utc(2026, 9, 10, 18);
    return CalendarEvent(
      id: id,
      title: 'Termin',
      start: actualStart,
      end: end ?? actualStart.add(const Duration(hours: 1)),
      isAllDay: allDay,
      recurrence: recurrence,
      recurrenceEnd: recurrenceEnd,
      reminderOffset: offset,
    );
  }

  List<tz.TZDateTime> dates(CalendarEvent value, tz.TZDateTime now) =>
      plannedReminders(
        value,
        shared: true,
        now: now,
      ).map((reminder) => reminder.scheduledDate).toList();

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

  test('single event stays unrestricted by recurring planning horizon', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final result = dates(
      event(ReminderOffset.minutes15, start: DateTime.utc(2027, 1, 1, 18)),
      tz.TZDateTime(berlin, 2026, 9, 1),
    );
    expect(result, [tz.TZDateTime(berlin, 2027, 1, 1, 17, 45)]);
  });

  test('daily recurrence plans every future reminder in the horizon', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final result = dates(
      event(
        ReminderOffset.atStart,
        start: DateTime.utc(2026, 8, 30, 18),
        recurrence: EventRecurrence.daily,
      ),
      tz.TZDateTime(berlin, 2026, 9, 1, 17),
    );
    expect(result, hasLength(30));
    expect(result.first, tz.TZDateTime(berlin, 2026, 9, 1, 18));
    expect(result.last, tz.TZDateTime(berlin, 2026, 9, 30, 18));
  });

  test('weekly and biweekly recurrences retain their weekday spacing', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final now = tz.TZDateTime(berlin, 2026, 9, 1);
    final weekly = dates(
      event(
        ReminderOffset.minutes15,
        start: DateTime.utc(2026, 8, 31, 18),
        recurrence: EventRecurrence.weekly,
      ),
      now,
    );
    final biweekly = dates(
      event(
        ReminderOffset.hours1,
        start: DateTime.utc(2026, 8, 31, 18),
        recurrence: EventRecurrence.biweekly,
      ),
      now,
    );
    expect(weekly.map((date) => date.day), [7, 14, 21, 28]);
    expect(weekly.every((date) => date.weekday == DateTime.monday), isTrue);
    expect(biweekly.map((date) => date.day), [14, 28]);
  });

  test('monthly recurrence skips a month without the original day', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final result = dates(
      event(
        ReminderOffset.atStart,
        start: DateTime.utc(2026, 1, 31, 18),
        recurrence: EventRecurrence.monthly,
      ),
      tz.TZDateTime(berlin, 2026, 1, 30),
    );
    expect(result, [tz.TZDateTime(berlin, 2026, 1, 31, 18)]);
  });

  test('yearly recurrence plans the matching month and day', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final result = dates(
      event(
        ReminderOffset.minutes15,
        start: DateTime.utc(2024, 9, 10, 18),
        recurrence: EventRecurrence.yearly,
      ),
      tz.TZDateTime(berlin, 2026, 9, 1),
    );
    expect(result, [tz.TZDateTime(berlin, 2026, 9, 10, 17, 45)]);
  });

  test('end date is inclusive and excludes later occurrences', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final result = dates(
      event(
        ReminderOffset.atStart,
        start: DateTime.utc(2026, 9, 1, 18),
        recurrence: EventRecurrence.daily,
        recurrenceEnd: DateTime.utc(2026, 9, 3),
      ),
      tz.TZDateTime(berlin, 2026, 9, 1, 19),
    );
    expect(result, [
      tz.TZDateTime(berlin, 2026, 9, 2, 18),
      tz.TZDateTime(berlin, 2026, 9, 3, 18),
    ]);
  });

  test('past reminders are skipped and later replan rolls horizon forward', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final recurring = event(
      ReminderOffset.minutes15,
      start: DateTime.utc(2026, 8, 1, 18),
      recurrence: EventRecurrence.daily,
    );
    final first = dates(recurring, tz.TZDateTime(berlin, 2026, 9, 1, 18));
    final later = dates(recurring, tz.TZDateTime(berlin, 2026, 9, 2, 18));
    expect(first.first, tz.TZDateTime(berlin, 2026, 9, 2, 17, 45));
    expect(later.first, tz.TZDateTime(berlin, 2026, 9, 3, 17, 45));
    expect(later.last, tz.TZDateTime(berlin, 2026, 10, 2, 17, 45));
  });

  test('one-day offset includes occurrence just beyond occurrence window', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final result = dates(
      event(
        ReminderOffset.days1,
        start: DateTime.utc(2026, 9, 1, 18),
        recurrence: EventRecurrence.daily,
      ),
      tz.TZDateTime(berlin, 2026, 9, 1, 20),
    );
    expect(result.last, tz.TZDateTime(berlin, 2026, 10, 1, 18));
  });

  test('weekly Berlin occurrence keeps wall time across DST change', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final reminders = plannedReminders(
      event(
        ReminderOffset.hours1,
        start: DateTime.utc(2026, 3, 22, 10),
        recurrence: EventRecurrence.weekly,
      ),
      shared: true,
      now: tz.TZDateTime(berlin, 2026, 3, 21),
    );
    expect(reminders.take(2).map((item) => item.occurrenceStart.hour), [
      10,
      10,
    ]);
    expect(reminders.take(2).map((item) => item.scheduledDate.hour), [9, 9]);
    expect(reminders[0].occurrenceStart.timeZoneOffset.inHours, 1);
    expect(reminders[1].occurrenceStart.timeZoneOffset.inHours, 2);
  });

  test('all-day events schedule nothing', () {
    final berlin = tz.getLocation('Europe/Berlin');
    expect(
      dates(
        event(
          ReminderOffset.none,
          allDay: true,
          recurrence: EventRecurrence.daily,
        ),
        tz.TZDateTime(berlin, 2026, 9, 1),
      ),
      isEmpty,
    );
  });

  test('timed multi-day event schedules only its actual start', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final result = dates(
      event(
        ReminderOffset.days1,
        start: DateTime.utc(2026, 9, 10, 18),
        end: DateTime.utc(2026, 9, 12, 12),
      ),
      tz.TZDateTime(berlin, 2026, 9, 1),
    );
    expect(result, [tz.TZDateTime(berlin, 2026, 9, 9, 18)]);
  });

  test(
    'occurrence notification IDs are stable and distinguish occurrences',
    () {
      final berlin = tz.getLocation('Europe/Berlin');
      final first = tz.TZDateTime(berlin, 2026, 9, 1, 18);
      final second = tz.TZDateTime(berlin, 2026, 9, 2, 18);
      expect(
        reminderNotificationId('series', first),
        reminderNotificationId('series', first),
      );
      expect(
        reminderNotificationId('series', first),
        isNot(reminderNotificationId('series', second)),
      );
      expect(
        reminderNotificationId('series', first),
        isNot(reminderNotificationId('other-series', first)),
      );
    },
  );

  group('local scheduling', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    late List<Map<String, Object?>> pending;
    late List<MethodCall> calls;
    late LocalReminderService service;
    late tz.Location berlin;

    setUp(() async {
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      pending = [];
      calls = [];
      berlin = tz.getLocation('Europe/Berlin');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'pendingNotificationRequests') {
              return pending.map((item) => Map.of(item)).toList();
            }
            final arguments = call.arguments as Map<dynamic, dynamic>;
            if (call.method == 'cancel') {
              pending.removeWhere((item) => item['id'] == arguments['id']);
            } else if (call.method == 'zonedSchedule') {
              pending.removeWhere((item) => item['id'] == arguments['id']);
              pending.add({
                'id': arguments['id'] as int,
                'title': arguments['title'] as String?,
                'body': arguments['body'] as String?,
                'payload': arguments['payload'] as String?,
                'scheduledDateTimeISO8601':
                    arguments['scheduledDateTimeISO8601'] as String,
              });
            }
            return true;
          });
      service = await LocalReminderService.initialize(
        now: (_) => tz.TZDateTime(berlin, 2026, 9, 7),
        platform: TargetPlatform.android,
      );
      calls.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('create schedules one notification per recurring occurrence', () async {
      await service
          .reconcile([
            event(
              ReminderOffset.atStart,
              recurrence: EventRecurrence.weekly,
              start: DateTime.utc(2026, 9, 8, 18),
            ),
          ], shared: true)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => fail(
              'Scheduling did not finish: ${calls.map((call) => call.method).toList()}',
            ),
          );
      expect(pending, hasLength(5));
      expect(pending.map((item) => item['id']).toSet(), hasLength(5));
      expect(
        pending.every((item) => item['payload'] == 'moonkeep:event:event-1'),
        isTrue,
      );
    });

    test(
      'edit removes old occurrences and reminder removal clears all',
      () async {
        await service.reconcile([
          event(
            ReminderOffset.atStart,
            recurrence: EventRecurrence.daily,
            start: DateTime.utc(2026, 9, 8, 18),
          ),
        ], shared: true);
        expect(pending, hasLength(29));

        await service.reconcile([
          event(
            ReminderOffset.hours1,
            recurrence: EventRecurrence.weekly,
            recurrenceEnd: DateTime.utc(2026, 9, 15),
            start: DateTime.utc(2026, 9, 8, 20),
          ),
        ], shared: true);
        expect(pending, hasLength(2));

        await service.reconcile([
          event(
            ReminderOffset.none,
            recurrence: EventRecurrence.weekly,
            start: DateTime.utc(2026, 9, 8, 20),
          ),
        ], shared: true);
        expect(pending, isEmpty);
      },
    );

    test('timed to all-day and delete remove every series reminder', () async {
      await service.reconcile([
        event(
          ReminderOffset.minutes15,
          recurrence: EventRecurrence.daily,
          start: DateTime.utc(2026, 9, 8, 18),
        ),
      ], shared: true);
      expect(pending, isNotEmpty);
      await service.reconcile([
        event(
          ReminderOffset.none,
          allDay: true,
          recurrence: EventRecurrence.daily,
          start: DateTime.utc(2026, 9, 8),
        ),
      ], shared: true);
      expect(pending, isEmpty);

      await service.reconcile([
        event(
          ReminderOffset.minutes15,
          recurrence: EventRecurrence.weekly,
          start: DateTime.utc(2026, 9, 8, 18),
        ),
      ], shared: true);
      await service.cancel('event-1');
      expect(pending, isEmpty);
    });

    test(
      'iOS keeps the globally earliest 64 reminders across series',
      () async {
        service = await LocalReminderService.initialize(
          now: (_) => tz.TZDateTime(berlin, 2026, 9, 7),
          platform: TargetPlatform.iOS,
        );
        pending.add({
          'id': 987654,
          'title': 'Alt',
          'body': 'Alt',
          'payload': 'moonkeep:event:deleted',
          'scheduledDateTimeISO8601': '2026-09-08T00:00:00.000+0200',
        });
        final events = [
          event(
            ReminderOffset.atStart,
            id: 'morning',
            recurrence: EventRecurrence.daily,
            start: DateTime.utc(2026, 9, 8, 8),
          ),
          event(
            ReminderOffset.atStart,
            id: 'noon',
            recurrence: EventRecurrence.daily,
            start: DateTime.utc(2026, 9, 8, 12),
          ),
          event(
            ReminderOffset.atStart,
            id: 'evening',
            recurrence: EventRecurrence.daily,
            start: DateTime.utc(2026, 9, 8, 18),
          ),
        ];
        final allCandidates = [
          for (final value in events)
            ...plannedReminders(
              value,
              shared: true,
              now: tz.TZDateTime(berlin, 2026, 9, 7),
            ).map((planned) => planned.scheduledDate.toIso8601String()),
        ]..sort();

        await service.reconcile(events, shared: true);

        final scheduled =
            pending
                .map((item) => item['scheduledDateTimeISO8601']! as String)
                .toList()
              ..sort();
        expect(pending, hasLength(iosPendingNotificationLimit));
        expect(scheduled, allCandidates.take(iosPendingNotificationLimit));
        expect(
          pending.any((item) => item['payload'] == 'moonkeep:event:deleted'),
          isFalse,
        );
        expect(
          pending.map((item) => item['payload']).toSet(),
          containsAll([
            'moonkeep:event:morning',
            'moonkeep:event:noon',
            'moonkeep:event:evening',
          ]),
        );
      },
    );

    test('Android keeps more than 64 reminders in the horizon', () async {
      final events = [
        for (var index = 0; index < 3; index++)
          event(
            ReminderOffset.atStart,
            id: 'daily-$index',
            recurrence: EventRecurrence.daily,
            start: DateTime.utc(2026, 9, 8, 8 + index),
          ),
      ];

      await service.reconcile(events, shared: true);

      expect(pending.length, greaterThan(iosPendingNotificationLimit));
    });

    test('reconcile removes deleted events and stays idempotent', () async {
      final first = event(
        ReminderOffset.atStart,
        id: 'first',
        recurrence: EventRecurrence.weekly,
        start: DateTime.utc(2026, 9, 8, 18),
      );
      final second = event(
        ReminderOffset.atStart,
        id: 'second',
        start: DateTime.utc(2026, 9, 10, 18),
      );
      await service.reconcile([first, second], shared: true);
      expect(
        pending.map((item) => item['payload']),
        contains('moonkeep:event:second'),
      );

      await service.reconcile([first], shared: true);
      final firstOnlyIds = pending.map((item) => item['id']).toSet();
      expect(
        pending.every((item) => item['payload'] == 'moonkeep:event:first'),
        isTrue,
      );
      await service.reconcile([first], shared: true);
      expect(pending.map((item) => item['id']).toSet(), firstOnlyIds);
      expect(pending, hasLength(firstOnlyIds.length));
    });

    test('reconcile removes legacy pending reminder payloads', () async {
      pending.add({
        'id': 123,
        'title': 'Alt',
        'body': 'Gelöscht',
        'payload': 'deleted-event',
      });
      await service.reconcile(const [], shared: true);
      expect(pending, isEmpty);
    });
  });
}
