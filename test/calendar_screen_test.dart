import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/app.dart';
import 'package:moonkeep/features/calendar/calendar_event.dart';
import 'package:moonkeep/features/calendar/calendar_screen.dart';
import 'package:moonkeep/features/calendar/calendar_store.dart';

void main() {
  CalendarStore emptyStore() =>
      CalendarStore(read: () async => null, write: (_) async {});

  CalendarStore storeWithEvents(List<CalendarEvent> events) => CalendarStore(
    read: () async =>
        jsonEncode(events.map((event) => event.toJson()).toList()),
    write: (_) async {},
  );

  String dayId(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  CalendarEvent eventAt(
    String id,
    String title,
    DateTime day,
    int startHour,
    int endHour, {
    bool isAllDay = false,
    EventRecurrence recurrence = EventRecurrence.none,
    Iterable<String> assignedMemberIds = const [],
  }) => CalendarEvent(
    id: id,
    title: title,
    start: DateTime(day.year, day.month, day.day, startHour),
    end: DateTime(day.year, day.month, day.day, endHour),
    isAllDay: isAllDay,
    recurrence: recurrence,
    assignedMemberIds: assignedMemberIds,
  );

  testWidgets('creates, edits, cancels deletion and deletes an event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MoonkeepApp(store: emptyStore()));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Termine'), findsOneWidget);
    await tester.tap(find.text('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte einen Titel eingeben.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Picknick');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Picknick'), findsOneWidget);
    expect(find.text('Termin erstellt.'), findsOneWidget);

    await tester.ensureVisible(find.text('Picknick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picknick'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Picknick im Park',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Picknick im Park'), findsOneWidget);
    expect(find.text('Picknick'), findsNothing);
    expect(find.text('Termin gespeichert.'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Termin löschen'));
    await tester.tap(find.byTooltip('Termin löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.text('Picknick im Park'), findsOneWidget);
    await tester.tap(find.byTooltip('Termin löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Termine'), findsOneWidget);
    expect(find.text('Termin gelöscht.'), findsOneWidget);
  });

  testWidgets('aborting a new event leaves the store unchanged', (
    tester,
  ) async {
    final store = emptyStore();
    await tester.pumpWidget(MoonkeepApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Nicht speichern');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(store.eventsOn(DateTime.now()), isEmpty);
  });

  testWidgets('creates, edits, and deletes a complete recurring series', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = emptyStore();
    await tester.pumpWidget(MoonkeepApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Training');
    await tester.ensureVisible(find.text('Keine Wiederholung'));
    await tester.tap(find.text('Keine Wiederholung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wöchentlich').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(store.allEvents, hasLength(1));
    expect(store.allEvents.single.recurrence, EventRecurrence.weekly);
    expect(find.textContaining('Wöchentlich'), findsOneWidget);
    expect(find.text('Terminserie erstellt.'), findsOneWidget);

    await tester.tap(find.text('Training'));
    await tester.pumpAndSettle();
    expect(find.text('Serie bearbeiten'), findsOneWidget);
    expect(
      find.text('Änderungen gelten für die gesamte Terminserie.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Wöchentlich'));
    await tester.tap(find.text('Wöchentlich'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Täglich').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.allEvents.single.recurrence, EventRecurrence.daily);
    expect(find.text('Terminserie gespeichert.'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Termin löschen'));
    await tester.tap(find.byTooltip('Termin löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Terminserie löschen?'), findsOneWidget);
    expect(find.textContaining('alle Wiederholungen'), findsOneWidget);
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(store.allEvents, isEmpty);
    expect(find.text('Terminserie gelöscht.'), findsOneWidget);
  });

  testWidgets('creates and switches an all-day event without showing times', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = emptyStore();
    await tester.pumpWidget(MoonkeepApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Geburtstag');
    final allDaySwitch = find.widgetWithText(SwitchListTile, 'Ganztägig');
    expect(find.textContaining('Beginn:'), findsOneWidget);
    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(find.textContaining('Beginn:'), findsNothing);
    expect(find.textContaining('Ende:'), findsNothing);
    expect(find.text('Erinnerung'), findsNothing);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(store.allEvents.single.isAllDay, isTrue);
    expect(find.text('Termin erstellt.'), findsOneWidget);
    var tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Geburtstag'),
        matching: find.byType(ListTile),
      ),
    );
    expect((tile.subtitle! as Text).data, 'Ganztägig\nBetrifft: Alle');

    await tester.tap(find.text('Geburtstag'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(allDaySwitch).value, isTrue);
    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(find.textContaining('Beginn:'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(store.allEvents.single.isAllDay, isFalse);
    expect(find.text('Termin gespeichert.'), findsOneWidget);
    tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Geburtstag'),
        matching: find.byType(ListTile),
      ),
    );
    expect((tile.subtitle! as Text).data, isNot('Ganztägig'));

    await tester.tap(find.text('Geburtstag'));
    await tester.pumpAndSettle();
    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.allEvents.single.isAllDay, isTrue);
  });

  testWidgets('shows storage load failure without allowing new events', (
    tester,
  ) async {
    await tester.pumpWidget(
      MoonkeepApp(
        store: CalendarStore(read: () async => 'broken', write: (_) async {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Der gemeinsame Kalender konnte nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.text('Termin anlegen'), findsNothing);
  });

  testWidgets('shows save failure and keeps the editor open', (tester) async {
    await tester.pumpWidget(
      MoonkeepApp(
        store: CalendarStore(
          read: () async => null,
          write: (_) async => throw StateError('full'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Ausflug');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(
      find.text('Speichern fehlgeschlagen. Bitte erneut versuchen.'),
      findsNothing,
    );
    expect(
      find.text(
        'Termin konnte nicht gespeichert werden. Bitte erneut versuchen.',
      ),
      findsOneWidget,
    );
    expect(find.text('Neuer Termin'), findsOneWidget);
  });

  testWidgets('Today resets a browsed month even when today remains selected', (
    tester,
  ) async {
    await tester.pumpWidget(MoonkeepApp(store: emptyStore()));
    await tester.pumpAndSettle();
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    final today = DateTime.now();
    final previousMonth = DateTime(today.year, today.month - 1);
    final nextMonth = DateTime(today.year, today.month + 1);
    await tester.tap(find.byTooltip(localizations.previousMonthTooltip));
    await tester.pumpAndSettle();
    expect(
      find.text(localizations.formatMonthYear(previousMonth)),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(localizations.nextMonthTooltip));
    await tester.pumpAndSettle();
    expect(find.text(localizations.formatMonthYear(today)), findsOneWidget);
    await tester.tap(find.byTooltip(localizations.nextMonthTooltip));
    await tester.pumpAndSettle();
    expect(find.text(localizations.formatMonthYear(nextMonth)), findsOneWidget);
    await tester.tap(find.text('Heute'));
    await tester.pumpAndSettle();
    expect(find.text(localizations.formatMonthYear(today)), findsOneWidget);
    expect(find.text(localizations.formatMonthYear(nextMonth)), findsNothing);
  });

  testWidgets('month grid shows occurrences, all-day events and overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final events = [
      eventAt('all-day', 'Urlaub', today, 7, 8, isAllDay: true),
      eventAt(
        'recurring',
        'Training',
        today,
        8,
        9,
        recurrence: EventRecurrence.weekly,
      ),
      eventAt('third', 'Arzt', today, 9, 10),
      eventAt('fourth', 'Kita', today, 10, 11),
      eventAt('tomorrow', 'Einkaufen', tomorrow, 11, 12),
    ];
    await tester.pumpWidget(MoonkeepApp(store: storeWithEvents(events)));
    await tester.pumpAndSettle();

    expect(find.text('Monat'), findsOneWidget);
    expect(
      find.byKey(ValueKey('month-event-all-day-${dayId(today)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('month-event-recurring-${dayId(today)}')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('month-more-${dayId(today)}')), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('month-day-${dayId(tomorrow)}')));
    await tester.pumpAndSettle();
    expect(find.text('Einkaufen'), findsOneWidget);
    expect(
      find.text(
        MaterialLocalizations.of(tester.element(find.byType(Scaffold).first))
            .formatFullDate(tomorrow),
      ),
      findsOneWidget,
    );
  });

  testWidgets('week grid lists equal-height events chronologically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final tuesday = weekStart.add(const Duration(days: 1));
    final wednesday = weekStart.add(const Duration(days: 2));
    final thursday = weekStart.add(const Duration(days: 3));
    final events = [
      eventAt('timed', 'Besprechung', tuesday, 9, 11),
      eventAt('early', 'Frühdienst', tuesday, 2, 3),
      eventAt(
        'overlap',
        'Telefonat',
        tuesday,
        10,
        12,
        assignedMemberIds: const ['member-a'],
      ),
      eventAt('all-day', 'Geburtstag', wednesday, 9, 10, isAllDay: true),
      eventAt(
        'recurring',
        'Training',
        thursday.subtract(const Duration(days: 7)),
        18,
        19,
        recurrence: EventRecurrence.weekly,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          store: storeWithEvents(events),
          memberLabels: const {'member-a': 'member@example.test'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();

    for (var index = 0; index < 7; index++) {
      expect(
        find.byKey(
          ValueKey('week-day-${dayId(weekStart.add(Duration(days: index)))}'),
        ),
        findsOneWidget,
      );
    }
    final early = find.byKey(ValueKey('week-event-early-${dayId(tuesday)}'));
    final timed = find.byKey(ValueKey('week-event-timed-${dayId(tuesday)}'));
    final overlap = find.byKey(
      ValueKey('week-event-overlap-${dayId(tuesday)}'),
    );
    expect(tester.getTopLeft(early).dy, lessThan(tester.getTopLeft(timed).dy));
    expect(
      tester.getTopLeft(timed).dy,
      lessThan(tester.getTopLeft(overlap).dy),
    );
    expect(tester.getSize(early).height, tester.getSize(timed).height);
    expect(tester.getSize(timed).height, tester.getSize(overlap).height);
    expect(
      tester
          .getSize(find.byKey(ValueKey('week-timeline-${dayId(tuesday)}')))
          .height,
      greaterThanOrEqualTo(300),
    );
    expect(find.text('02:00 – 03:00\nFrühdienst'), findsOneWidget);
    expect(find.text('09:00 – 11:00\nBesprechung'), findsOneWidget);
    expect(find.text('06:00'), findsNothing);
    expect(find.text('22:00'), findsNothing);
    expect(
      find.byKey(ValueKey('week-all-day-all-day-${dayId(wednesday)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('week-event-recurring-${dayId(thursday)}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.fling(
      find.byKey(const ValueKey('week-swipe-area')),
      const Offset(0, -300),
      1000,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        ValueKey('week-day-${dayId(weekStart.add(const Duration(days: 7)))}'),
      ),
      findsOneWidget,
    );
    await tester.fling(
      find.byKey(const ValueKey('week-swipe-area')),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('week-day-${dayId(weekStart)}')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Nächste Woche'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        ValueKey('week-day-${dayId(weekStart.add(const Duration(days: 7)))}'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Vorherige Woche'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('week-day-${dayId(weekStart)}')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Nächste Woche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heute'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('week-day-${dayId(weekStart)}')),
      findsOneWidget,
    );
  });

  testWidgets('calendar and editor fit a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MoonkeepApp(store: emptyStore()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Monat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Termin anlegen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates and edits event member assignments', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = emptyStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          store: store,
          memberLabels: const {
            'member-a': 'marcel@example.com',
            'member-b': 'claire@example.com',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Planung');
    await tester.ensureVisible(find.text('Betrifft'));
    await tester.tap(find.text('Betrifft'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('assignment-all')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('assignment-member-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(store.allEvents.single.assignedMemberIds, {'member-a'});
    expect(find.textContaining('Betrifft: marcel@example.com'), findsOneWidget);

    await tester.tap(find.text('Planung'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Betrifft'));
    await tester.tap(find.text('Betrifft'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assignment-member-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(store.allEvents.single.assignedMemberIds, {'member-a', 'member-b'});
    expect(
      find.textContaining('Betrifft: claire@example.com, marcel@example.com'),
      findsOneWidget,
    );
  });

  testWidgets('shows a safe fallback for an unknown assigned member', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final event = CalendarEvent(
      id: 'historic',
      title: 'Historischer Termin',
      start: today.add(const Duration(hours: 9)),
      end: today.add(const Duration(hours: 10)),
      assignedMemberIds: const ['former-member'],
    );
    final store = CalendarStore(
      read: () async => jsonEncode([event.toJson()]),
      write: (_) async {},
    );
    await tester.pumpWidget(MaterialApp(home: CalendarScreen(store: store)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Betrifft: Ehemaliges Mitglied'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
