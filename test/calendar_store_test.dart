import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/features/calendar/calendar_event.dart';
import 'package:moonkeep/features/calendar/calendar_store.dart';

void main() {
  final day = DateTime(2026, 8, 28);
  CalendarEvent event(
    String id, {
    int hour = 9,
    String title = 'Familienzeit',
  }) => CalendarEvent(
    id: id,
    title: title,
    start: DateTime(2026, 8, 28, hour),
    end: DateTime(2026, 8, 28, hour + 1),
  );

  test('validates title and same-day time interval', () {
    expect(() => event('1', title: '  '), throwsArgumentError);
    expect(
      () => CalendarEvent(id: '1', title: 'Test', start: day, end: day),
      throwsArgumentError,
    );
    expect(
      () => CalendarEvent(
        id: '1',
        title: 'Test',
        start: day,
        end: day.add(const Duration(days: 1)),
      ),
      throwsArgumentError,
    );
    expect(event('1', title: '  Ausflug  ').title, 'Ausflug');
  });

  test('round-trips a complete event', () {
    final original = CalendarEvent(
      id: '1',
      title: 'Ausflug',
      start: DateTime(2026, 8, 28, 9),
      end: DateTime(2026, 8, 28, 10),
      notes: 'Picknick mitbringen',
      importance: EventImportance.high,
      reminderMinutesBefore: 30,
    );
    final restored = CalendarEvent.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), original.toJson());
    expect(restored.importance, EventImportance.high);
    expect(restored.reminderMinutesBefore, 30);
  });

  test('old one-time events remain compatible without recurrence fields', () {
    final restored = CalendarEvent.fromJson({
      'id': 'old',
      'title': 'Altbestand',
      'start': '2026-08-28T09:00:00.000',
      'end': '2026-08-28T10:00:00.000',
      'notes': '',
      'importance': 'normal',
      'reminderMinutesBefore': null,
    });
    expect(restored.recurrence, EventRecurrence.none);
    expect(restored.isAllDay, isFalse);
    expect(restored.occursOn(DateTime(2026, 8, 28)), isTrue);
    expect(restored.occursOn(DateTime(2026, 8, 29)), isFalse);
  });

  test('all-day events round-trip and work with recurrence', () {
    final original = CalendarEvent(
      id: 'birthday',
      title: 'Geburtstag',
      start: DateTime(2026, 9, 1, 9),
      end: DateTime(2026, 9, 1, 10),
      isAllDay: true,
      recurrence: EventRecurrence.yearly,
      recurrenceEnd: DateTime(2030, 9, 1),
    );
    final restored = CalendarEvent.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.isAllDay, isTrue);
    expect(restored.occursOn(DateTime(2029, 9, 1)), isTrue);
    expect(restored.occursOn(DateTime(2029, 9, 2)), isFalse);
    expect(
      () => CalendarEvent(
        id: 'invalid',
        title: 'Ungültig',
        start: DateTime(2026, 9, 1, 9),
        end: DateTime(2026, 9, 1, 10),
        isAllDay: true,
        reminderMinutesBefore: 30,
      ),
      throwsArgumentError,
    );
  });

  test(
    'calculates supported recurrences without materializing occurrences',
    () {
      CalendarEvent recurring(EventRecurrence recurrence, {DateTime? end}) =>
          CalendarEvent(
            id: recurrence.name,
            title: recurrence.label,
            start: DateTime(2026, 1, 1, 9),
            end: DateTime(2026, 1, 1, 10),
            recurrence: recurrence,
            recurrenceEnd: end,
          );

      expect(
        recurring(EventRecurrence.daily).occursOn(DateTime(2026, 1, 2)),
        isTrue,
      );
      expect(
        recurring(EventRecurrence.weekly).occursOn(DateTime(2026, 1, 8)),
        isTrue,
      );
      expect(
        recurring(EventRecurrence.weekly).occursOn(DateTime(2026, 1, 9)),
        isFalse,
      );
      expect(
        recurring(EventRecurrence.biweekly).occursOn(DateTime(2026, 1, 15)),
        isTrue,
      );
      expect(
        recurring(EventRecurrence.biweekly).occursOn(DateTime(2026, 1, 8)),
        isFalse,
      );
      expect(
        recurring(EventRecurrence.monthly).occursOn(DateTime(2026, 2, 1)),
        isTrue,
      );
      expect(
        recurring(EventRecurrence.yearly).occursOn(DateTime(2027, 1, 1)),
        isTrue,
      );

      final limited = recurring(
        EventRecurrence.daily,
        end: DateTime(2026, 1, 3),
      );
      expect(limited.occursOn(DateTime(2026, 1, 3)), isTrue);
      expect(limited.occursOn(DateTime(2026, 1, 4)), isFalse);
    },
  );

  test('monthly recurrence on day 31 skips months without that day', () {
    final event = CalendarEvent(
      id: 'month-end',
      title: 'Monatsende',
      start: DateTime(2026, 1, 31, 9),
      end: DateTime(2026, 1, 31, 10),
      recurrence: EventRecurrence.monthly,
    );
    expect(event.occursOn(DateTime(2026, 2, 28)), isFalse);
    expect(event.occursOn(DateTime(2026, 3, 31)), isTrue);
  });

  test('persists creates, edits and deletes across store instances', () async {
    String? disk;
    CalendarStore newStore() => CalendarStore(
      read: () async => disk,
      write: (value) async => disk = value,
    );
    final store = newStore();
    await store.load();
    await store.save(event('late', hour: 15));
    await store.save(event('early'));
    expect(store.eventsOn(day).map((item) => item.id), ['early', 'late']);
    expect(store.eventsOn(DateTime(2026, 8, 29)), isEmpty);

    await store.save(event('early', title: 'Geändert'));
    final restored = newStore();
    await restored.load();
    expect(restored.eventsOn(day).first.title, 'Geändert');
    expect(restored.eventsOn(day), hasLength(2));
    await restored.delete('early');
    final afterDelete = newStore();
    await afterDelete.load();
    expect(afterDelete.eventsOn(day).single.id, 'late');
  });

  test(
    'failed writes preserve previous in-memory state and allow retry',
    () async {
      var fail = false;
      final store = CalendarStore(
        read: () async => null,
        write: (_) async {
          if (fail) throw StateError('disk full');
        },
      );
      await store.load();
      await store.save(event('1'));
      fail = true;
      await expectLater(
        store.save(event('1', title: 'Changed')),
        throwsStateError,
      );
      await expectLater(store.delete('1'), throwsStateError);
      expect(store.eventsOn(day).single.title, 'Familienzeit');
      fail = false;
      await store.delete('1');
      expect(store.eventsOn(day), isEmpty);
    },
  );

  test('corrupt data is not overwritten by later writes', () async {
    var writes = 0;
    final store = CalendarStore(
      read: () async => 'broken json',
      write: (_) async => writes++,
    );
    await expectLater(store.load(), throwsFormatException);
    await expectLater(store.save(event('1')), throwsStateError);
    expect(writes, 0);
  });

  test('duplicate IDs fail to load', () async {
    final store = CalendarStore(
      read: () async => jsonEncode([event('1').toJson(), event('1').toJson()]),
      write: (_) async {},
    );
    await expectLater(store.load(), throwsFormatException);
  });

  test(
    'overlapping writes are rejected rather than losing an update',
    () async {
      final gate = Completer<void>();
      final store = CalendarStore(
        read: () async => null,
        write: (_) => gate.future,
      );
      await store.load();
      final first = store.save(event('1'));
      await expectLater(store.save(event('2')), throwsStateError);
      gate.complete();
      await first;
      expect(store.eventsOn(day).single.id, '1');
    },
  );
}
