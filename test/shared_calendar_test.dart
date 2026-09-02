import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/features/calendar/calendar_event.dart';
import 'package:moonkeep/features/calendar/firestore_calendar_repository.dart';

void main() {
  test('shared event round-trips Berlin civil time and revision', () {
    final original = CalendarEvent(
      id: 'one',
      title: '  Ausflug  ',
      notes: ' Treffpunkt ',
      start: DateTime.utc(2028, 2, 29, 9, 15),
      end: DateTime.utc(2028, 2, 29, 10, 45),
      revision: 4,
      recurrence: EventRecurrence.yearly,
      recurrenceEnd: DateTime.utc(2032, 2, 29),
      assignedMemberIds: const ['member-a', 'member-b'],
    );
    final data = sharedEventData(original);
    expect(data['revision'], 5);
    final restored = sharedEvent('one', {...data, 'revision': 5});
    expect(restored.start, DateTime.utc(2028, 2, 29, 9, 15));
    expect(restored.end, DateTime.utc(2028, 2, 29, 10, 45));
    expect(restored.title, 'Ausflug');
    expect(restored.notes, 'Treffpunkt');
    expect(restored.revision, 5);
    expect(restored.recurrence, EventRecurrence.yearly);
    expect(restored.recurrenceEnd, DateTime.utc(2032, 2, 29));
    expect(restored.isAllDay, isFalse);
    expect(restored.assignedMemberIds, {'member-a', 'member-b'});
  });

  test('shared all-day event round-trips without a reminder', () {
    final original = CalendarEvent(
      id: 'birthday',
      title: 'Geburtstag',
      start: DateTime.utc(2028, 2, 29, 9),
      end: DateTime.utc(2028, 2, 29, 10),
      isAllDay: true,
      recurrence: EventRecurrence.yearly,
    );
    final data = sharedEventData(original);
    expect(data['allDay'], isTrue);
    expect(data['reminderMinutesBefore'], isNull);
    expect(sharedEvent('birthday', {...data, 'revision': 1}).isAllDay, isTrue);
  });

  test('shared event parser rejects impossible dates and intervals', () {
    final valid = {
      'title': 'Test',
      'notes': '',
      'year': 2026,
      'month': 8,
      'day': 29,
      'startMinute': 540,
      'endMinute': 600,
      'revision': 1,
    };
    expect(
      () => sharedEvent('one', {...valid, 'month': 2, 'day': 30}),
      throwsFormatException,
    );
    expect(
      () => sharedEvent('one', {...valid, 'endMinute': 540}),
      throwsFormatException,
    );
    expect(
      () => sharedEvent('one', {...valid, 'revision': 0}),
      throwsFormatException,
    );
    expect(sharedEvent('one', valid).recurrence, EventRecurrence.none);
    expect(sharedEvent('one', valid).isAllDay, isFalse);
    expect(sharedEvent('one', valid).appliesToAllMembers, isTrue);
    expect(
      () => sharedEvent('one', {...valid, 'allDay': 'yes'}),
      throwsFormatException,
    );
    expect(
      () => sharedEvent('one', {
        ...valid,
        'allDay': true,
        'reminderMinutesBefore': 30,
      }),
      throwsFormatException,
    );
    expect(
      () => sharedEvent('one', {
        ...valid,
        'recurrence': {'frequency': 'sometimes'},
      }),
      throwsFormatException,
    );
    expect(
      () => sharedEvent('one', {...valid, 'assignedMemberIds': 'member-a'}),
      throwsFormatException,
    );
  });
}
