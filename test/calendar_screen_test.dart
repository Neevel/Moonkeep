import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/app.dart';
import 'package:moonkeep/features/calendar/calendar_event.dart';
import 'package:moonkeep/features/calendar/calendar_screen.dart';
import 'package:moonkeep/features/calendar/calendar_store.dart';
import 'package:moonkeep/features/calendar/event_editor.dart';
import 'package:moonkeep/features/calendar/member_color_resolver.dart';

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

  Finder agendaTile(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ListTile));

  CalendarEvent eventAt(
    String id,
    String title,
    DateTime day,
    int startHour,
    int endHour, {
    bool isAllDay = false,
    EventRecurrence recurrence = EventRecurrence.none,
    EventImportance importance = EventImportance.normal,
    Iterable<String> assignedMemberIds = const [],
    DateTime? endDay,
  }) => CalendarEvent(
    id: id,
    title: title,
    start: DateTime(day.year, day.month, day.day, startHour),
    end: DateTime(
      (endDay ?? day).year,
      (endDay ?? day).month,
      (endDay ?? day).day,
      endHour,
    ),
    isAllDay: isAllDay,
    recurrence: recurrence,
    importance: importance,
    assignedMemberIds: assignedMemberIds,
  );

  test(
    'member colors are deterministic and audience variants stay distinct',
    () {
      final memberA = MemberColorResolver.forMemberId('member-a');
      final memberAAgain = MemberColorResolver.forMemberId('member-a');
      final memberB = MemberColorResolver.forMemberId('member-b');
      expect(memberA.background, memberAAgain.background);
      expect(memberA.foreground, memberAAgain.foreground);
      expect(memberA.background, isNot(memberB.background));

      final day = DateTime(2026, 9, 4);
      final all = MemberColorResolver.forEvent(
        eventAt('all', 'Alle', day, 8, 9),
        const {'member-a': 'a@example.test'},
      );
      final single = MemberColorResolver.forEvent(
        eventAt(
          'single',
          'Person',
          day,
          8,
          9,
          assignedMemberIds: const ['member-a'],
        ),
        const {'member-a': 'a@example.test'},
      );
      final multiple = MemberColorResolver.forEvent(
        eventAt(
          'multiple',
          'Mehrere',
          day,
          8,
          9,
          assignedMemberIds: const ['member-a', 'member-b'],
        ),
        const {'member-a': 'a@example.test', 'member-b': 'b@example.test'},
      );
      final unknown = MemberColorResolver.forEvent(
        eventAt(
          'unknown',
          'Ehemalig',
          day,
          8,
          9,
          assignedMemberIds: const ['former-member'],
        ),
        const {},
      );
      expect(all, same(MemberColorResolver.all));
      expect(all.background, isNot(single.background));
      expect(multiple.kind, CalendarAudienceKind.multiple);
      expect(multiple.indicatorColors, hasLength(2));
      expect(unknown, same(MemberColorResolver.unknown));
      final renamed = MemberColorResolver.forEvent(
        eventAt(
          'renamed',
          'Person',
          day,
          8,
          9,
          assignedMemberIds: const ['member-a'],
        ),
        const {'member-a': 'Neuer Name'},
      );
      expect(renamed.background, single.background);
    },
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
    await tester.tap(find.byTooltip('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte einen Titel eingeben.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Picknick');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(agendaTile('Picknick'), findsOneWidget);
    expect(find.text('Termin erstellt.'), findsOneWidget);

    await tester.ensureVisible(agendaTile('Picknick'));
    await tester.pumpAndSettle();
    await tester.tap(agendaTile('Picknick'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Picknick im Park',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(agendaTile('Picknick im Park'), findsOneWidget);
    expect(agendaTile('Picknick'), findsNothing);
    expect(find.text('Termin gespeichert.'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Termin löschen'));
    await tester.tap(find.byTooltip('Termin löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(agendaTile('Picknick im Park'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Termin anlegen'));
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

    await tester.tap(find.byTooltip('Termin anlegen'));
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

    await tester.tap(agendaTile('Training'));
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

    await tester.tap(find.byTooltip('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Geburtstag');
    final allDaySwitch = find.widgetWithText(SwitchListTile, 'Ganztägig');
    expect(find.byKey(const ValueKey('event-start-time')), findsOneWidget);
    expect(find.byKey(const ValueKey('event-end-time')), findsOneWidget);
    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-start-time')), findsNothing);
    expect(find.byKey(const ValueKey('event-end-time')), findsNothing);
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

    await tester.tap(agendaTile('Geburtstag'));
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

    await tester.tap(agendaTile('Geburtstag'));
    await tester.pumpAndSettle();
    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.allEvents.single.isAllDay, isTrue);
  });

  testWidgets('selects a reminder and clears it when switching to all-day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = emptyStore();
    await tester.pumpWidget(MoonkeepApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Termin anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Erinnerungstest');
    final reminderDropdown = find.byType(
      DropdownButtonFormField<ReminderOffset>,
    );
    await tester.ensureVisible(reminderDropdown);
    expect(
      tester
          .widget<DropdownButtonFormField<ReminderOffset>>(reminderDropdown)
          .initialValue,
      ReminderOffset.none,
    );
    await tester.tap(reminderDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 Minuten vorher').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.allEvents.single.reminderOffset, ReminderOffset.minutes15);
    expect(
      find.textContaining('Erinnerung: 15 Minuten vorher'),
      findsOneWidget,
    );

    await tester.tap(agendaTile('Erinnerungstest'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Ganztägig'));
    await tester.pumpAndSettle();
    expect(reminderDropdown, findsNothing);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.allEvents.single.reminderOffset, ReminderOffset.none);

    await tester.tap(agendaTile('Erinnerungstest'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Ganztägig'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<ReminderOffset>>(reminderDropdown)
          .initialValue,
      ReminderOffset.none,
    );
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
    expect(find.byKey(const ValueKey('calendar-add-event')), findsNothing);
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
    await tester.tap(find.byTooltip('Termin anlegen'));
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

  testWidgets(
    'month navigation slides by swipe and buttons and returns today',
    (tester) async {
      await tester.pumpWidget(MoonkeepApp(store: emptyStore()));
      await tester.pumpAndSettle();
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      final today = DateTime.now();
      final previousMonth = DateTime(today.year, today.month - 1);
      final nextMonth = DateTime(today.year, today.month + 1);
      await tester.fling(
        find.byKey(const ValueKey('month-swipe-area')),
        const Offset(-300, 0),
        1000,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(localizations.formatMonthYear(today)), findsOneWidget);
      expect(
        find.text(localizations.formatMonthYear(nextMonth)),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byKey(const ValueKey('month-swipe-area')),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
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
      expect(
        find.text(localizations.formatMonthYear(nextMonth)),
        findsOneWidget,
      );
      await tester.tap(find.text('Heute'));
      await tester.pumpAndSettle();
      expect(find.text(localizations.formatMonthYear(today)), findsOneWidget);
      expect(find.text(localizations.formatMonthYear(nextMonth)), findsNothing);
    },
  );

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
        assignedMemberIds: const ['member-a'],
      ),
      eventAt('third', 'Arzt', today, 9, 10),
      eventAt('fourth', 'Kita', today, 10, 11),
      eventAt('tomorrow', 'Einkaufen', tomorrow, 11, 12),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          store: storeWithEvents(events),
          memberLabels: const {
            'member-a': 'marcel@example.test',
            'member-b': 'claire@example.test',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monat'), findsOneWidget);
    expect(
      find.byKey(ValueKey('month-event-all-day-${dayId(today)}')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey('month-event-all-day-${dayId(today)}')),
        matching: find.text('Urlaub'),
      ),
      findsOneWidget,
    );
    expect(find.text('• Urlaub'), findsNothing);
    final allDayDecoration =
        tester
                .widget<Container>(
                  find.byKey(ValueKey('month-event-all-day-${dayId(today)}')),
                )
                .decoration
            as BoxDecoration;
    final memberDecoration =
        tester
                .widget<Container>(
                  find.byKey(ValueKey('month-event-recurring-${dayId(today)}')),
                )
                .decoration
            as BoxDecoration;
    expect(allDayDecoration.color, MemberColorResolver.all.background);
    expect(
      memberDecoration.color,
      MemberColorResolver.forMemberId('member-a').background,
    );
    expect(
      find.byKey(ValueKey('month-event-recurring-${dayId(today)}')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('month-more-${dayId(today)}')), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('month-day-${dayId(tomorrow)}')));
    await tester.pumpAndSettle();
    expect(agendaTile('Einkaufen'), findsOneWidget);
    expect(
      find.text(
        MaterialLocalizations.of(tester.element(find.byType(Scaffold).first))
            .formatFullDate(tomorrow),
      ),
      findsOneWidget,
    );
  });

  testWidgets('week overview stays compact and lists events chronologically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final tuesday = weekStart.add(const Duration(days: 1));
    final wednesday = weekStart.add(const Duration(days: 2));
    final thursday = weekStart.add(const Duration(days: 3));
    final events = [
      eventAt(
        'all-day-tuesday',
        'Geburtstag',
        tuesday,
        9,
        10,
        isAllDay: true,
        assignedMemberIds: const ['member-a'],
      ),
      eventAt('timed', 'Besprechung', tuesday, 9, 11),
      eventAt(
        'early',
        'Frühdienst',
        tuesday,
        2,
        3,
        assignedMemberIds: const ['member-b'],
      ),
      eventAt(
        'overlap',
        'Telefonat',
        tuesday,
        10,
        12,
        importance: EventImportance.high,
        assignedMemberIds: const ['member-a', 'member-b'],
      ),
      eventAt('all-day', 'Urlaub', wednesday, 9, 10, isAllDay: true),
      eventAt(
        'recurring',
        'Training',
        thursday.subtract(const Duration(days: 7)),
        18,
        19,
        recurrence: EventRecurrence.weekly,
        assignedMemberIds: const ['member-a'],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          store: storeWithEvents(events),
          memberLabels: const {
            'member-a': 'marcel@example.test',
            'member-b': 'claire@example.test',
          },
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
    for (var index = 0; index < 6; index++) {
      final current = find.byKey(
        ValueKey('week-day-${dayId(weekStart.add(Duration(days: index)))}'),
      );
      final next = find.byKey(
        ValueKey('week-day-${dayId(weekStart.add(Duration(days: index + 1)))}'),
      );
      expect(
        tester.getTopLeft(current).dy,
        lessThan(tester.getTopLeft(next).dy),
      );
    }
    final early = find.byKey(ValueKey('week-event-early-${dayId(tuesday)}'));
    final timed = find.byKey(ValueKey('week-event-timed-${dayId(tuesday)}'));
    final overlap = find.byKey(
      ValueKey('week-event-overlap-${dayId(tuesday)}'),
    );
    final allDay = find.byKey(
      ValueKey('week-all-day-all-day-tuesday-${dayId(tuesday)}'),
    );
    expect(tester.getTopLeft(allDay).dy, lessThan(tester.getTopLeft(early).dy));
    expect(tester.getTopLeft(early).dy, lessThan(tester.getTopLeft(timed).dy));
    expect(
      tester.getTopLeft(timed).dy,
      lessThan(tester.getTopLeft(overlap).dy),
    );
    expect(tester.getSize(early).height, tester.getSize(timed).height);
    expect(tester.getSize(timed).height, tester.getSize(overlap).height);
    expect(
      tester.getSize(find.byKey(const ValueKey('week-swipe-area'))).height,
      lessThan(600),
    );
    final emptyDayHeight = tester
        .getSize(find.byKey(ValueKey('week-day-card-${dayId(weekStart)}')))
        .height;
    final busyDayHeight = tester
        .getSize(find.byKey(ValueKey('week-day-card-${dayId(tuesday)}')))
        .height;
    expect(emptyDayHeight, lessThan(busyDayHeight));
    expect(find.text('Keine Termine'), findsWidgets);
    expect(find.text('Ganztägig'), findsWidgets);
    expect(find.text('02:00'), findsOneWidget);
    expect(find.text('Frühdienst'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Besprechung'), findsOneWidget);
    Material eventMaterial(Finder eventFinder) => tester.widget<Material>(
      find.descendant(of: eventFinder, matching: find.byType(Material)).first,
    );
    expect(
      eventMaterial(allDay).color,
      MemberColorResolver.forMemberId('member-a').background,
    );
    expect(
      eventMaterial(early).color,
      MemberColorResolver.forMemberId('member-b').background,
    );
    expect(find.byKey(const ValueKey('week-multiple-overlap')), findsOneWidget);
    final multipleAudience = MemberColorResolver.forEvent(
      events.firstWhere((event) => event.id == 'overlap'),
      const {
        'member-a': 'marcel@example.test',
        'member-b': 'claire@example.test',
      },
    );
    expect(eventMaterial(overlap).color, multipleAudience.background);
    expect(
      eventMaterial(overlap).color,
      isNot(MemberColorResolver.forMemberId('member-a').background),
    );
    final recurring = find.byKey(
      ValueKey('week-event-recurring-${dayId(thursday)}'),
    );
    expect(
      eventMaterial(recurring).color,
      MemberColorResolver.forMemberId('member-a').background,
    );
    final importanceDecoration =
        tester
                .widget<Container>(
                  find
                      .descendant(of: overlap, matching: find.byType(Container))
                      .first,
                )
                .decoration
            as BoxDecoration;
    final importanceBorder = importanceDecoration.border! as Border;
    expect(
      importanceBorder.left.color,
      Theme.of(tester.element(overlap)).colorScheme.error,
    );
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
    await tester.tap(timed);
    await tester.pumpAndSettle();
    expect(find.text('Termin bearbeiten'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('week-swipe-area')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(ValueKey('week-day-${dayId(weekStart)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey('week-day-${dayId(weekStart.add(const Duration(days: 7)))}'),
      ),
      findsOneWidget,
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
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('week-day-${dayId(weekStart)}')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Nächste Woche'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(ValueKey('week-day-${dayId(weekStart)}')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey('week-day-${dayId(weekStart.add(const Duration(days: 7)))}'),
      ),
      findsOneWidget,
    );
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

  testWidgets(
    'multi-day events appear on every day with range labels and member filters',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateUtils.dateOnly(DateTime.now());
      final start = today.subtract(Duration(days: today.weekday - 1));
      final middle = start.add(const Duration(days: 1));
      final end = start.add(const Duration(days: 2));
      final events = [
        eventAt(
          'trip',
          'Reise',
          start,
          18,
          12,
          endDay: end,
          assignedMemberIds: const ['member-a'],
        ),
        eventAt('holiday', 'Urlaub', start, 9, 10, endDay: end, isAllDay: true),
        eventAt('middle-a', 'Mitte A', middle, 8, 9),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarScreen(
            store: storeWithEvents(events),
            memberLabels: const {'member-a': 'Marcel', 'member-b': 'Sandra'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final day in [start, middle, end]) {
        expect(
          find.byKey(ValueKey('month-event-trip-${dayId(day)}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('month-event-holiday-${dayId(day)}')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(
          ValueKey(
            'month-event-trip-${dayId(start.subtract(const Duration(days: 1)))}',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('month-more-${dayId(middle)}')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ValueKey('month-day-${dayId(middle)}')));
      await tester.pumpAndSettle();
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      expect(
        find.textContaining(
          '${localizations.formatShortDate(start)} – ${localizations.formatShortDate(end)}',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('member-filter-member-b')));
      await tester.pumpAndSettle();
      expect(agendaTile('Reise'), findsNothing);
      expect(agendaTile('Urlaub'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('member-filter-member-a')));
      await tester.pumpAndSettle();
      expect(agendaTile('Reise'), findsOneWidget);
      expect(agendaTile('Urlaub'), findsOneWidget);

      await tester.tap(find.text('Woche'));
      await tester.pumpAndSettle();
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('läuft'), findsOneWidget);
      expect(find.text('bis 12:00'), findsOneWidget);
      for (final day in [start, middle, end]) {
        expect(
          find.byKey(ValueKey('week-all-day-holiday-${dayId(day)}')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('calendar and editor fit a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MoonkeepApp(store: emptyStore()));
    await tester.pumpAndSettle();
    expect(find.text('Mehr Zeit füreinander.'), findsNothing);
    expect(
      find.text('Euer gemeinsamer Alltag beginnt mit einem guten Überblick.'),
      findsNothing,
    );
    expect(find.textContaining('Alle Mitglieder können Termine'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Woche'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Monat'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Termin anlegen'), findsOneWidget);
    await tester.tap(find.byTooltip('Termin anlegen'));
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
          memberLabels: const {'member-a': 'Marcel', 'member-b': 'Sandra'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Termin anlegen'));
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
    expect(find.textContaining('Betrifft: Marcel'), findsOneWidget);
    expect(find.byKey(const ValueKey('member-color-legend')), findsOneWidget);
    expect(find.text('Marcel'), findsOneWidget);
    expect(find.text('Sandra'), findsOneWidget);
    final agendaAudience = find.descendant(
      of: find.byKey(ValueKey('agenda-audience-${store.allEvents.single.id}')),
      matching: find.byType(Container),
    );
    final agendaDecoration =
        tester.widget<Container>(agendaAudience.first).decoration
            as BoxDecoration;
    expect(
      agendaDecoration.color,
      MemberColorResolver.forMemberId('member-a').background,
    );

    await tester.tap(agendaTile('Planung'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Betrifft'));
    await tester.tap(find.text('Betrifft'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assignment-member-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(store.allEvents.single.assignedMemberIds, {'member-a', 'member-b'});
    expect(find.textContaining('Betrifft: Marcel, Sandra'), findsOneWidget);
  });

  testWidgets('editor creates shortens and removes a multi-day range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = emptyStore();
    await store.load();
    final start = DateTime(2026, 9, 10);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(key: ValueKey('editor-host'))),
      ),
    );

    Future<void> openEditor([CalendarEvent? event]) async {
      unawaited(
        Navigator.of(tester.element(find.byKey(const ValueKey('editor-host'))))
            .push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    EventEditor(store: store, day: start, event: event),
              ),
            ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> chooseEndDay(int day) async {
      final okLabel = MaterialLocalizations.of(
        tester.element(find.byType(Scaffold)),
      ).okButtonLabel;
      await tester.tap(find.byKey(const ValueKey('event-end-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$day').last);
      await tester.tap(find.text(okLabel));
      await tester.pumpAndSettle();
    }

    await openEditor();
    await tester.enterText(find.byType(TextFormField).first, 'Reise');
    await chooseEndDay(12);
    expect(
      tester
          .widget<DropdownButtonFormField<EventRecurrence>>(
            find.byType(DropdownButtonFormField<EventRecurrence>),
          )
          .onChanged,
      isNull,
    );
    expect(
      find.text('Mehrtagestermine können derzeit nicht wiederholt werden.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.allEvents.single.end.day, 12);

    await openEditor(store.allEvents.single);
    await chooseEndDay(11);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.allEvents.single.end.day, 11);

    await openEditor(store.allEvents.single);
    await chooseEndDay(10);
    expect(
      tester
          .widget<DropdownButtonFormField<EventRecurrence>>(
            find.byType(DropdownButtonFormField<EventRecurrence>),
          )
          .onChanged,
      isNotNull,
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.allEvents.single.isMultiDay, isFalse);

    final recurring = CalendarEvent(
      id: 'series',
      title: 'Serie',
      start: DateTime(2026, 9, 10, 9),
      end: DateTime(2026, 9, 10, 10),
      recurrence: EventRecurrence.weekly,
    );
    await openEditor(recurring);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('event-end-date')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'member chips filter month week agenda and preselect new assignments',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final store = storeWithEvents([
        eventAt('all', 'Für alle', today, 8, 9),
        eventAt(
          'a',
          'Nur Marcel',
          today,
          9,
          10,
          assignedMemberIds: const ['member-a'],
        ),
        eventAt(
          'b',
          'Nur Sandra',
          today,
          10,
          11,
          importance: EventImportance.high,
          assignedMemberIds: const ['member-b'],
        ),
        eventAt(
          'ab',
          'Marcel und Sandra',
          today,
          11,
          12,
          isAllDay: true,
          assignedMemberIds: const ['member-a', 'member-b'],
        ),
        eventAt(
          'tomorrow-b',
          'Morgen nur Sandra',
          tomorrow,
          9,
          10,
          recurrence: EventRecurrence.daily,
          assignedMemberIds: const ['member-b'],
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarScreen(
            store: store,
            memberLabels: const {'member-a': 'Marcel', 'member-b': 'Sandra'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(agendaTile('Für alle'), findsOneWidget);
      expect(agendaTile('Nur Marcel'), findsOneWidget);
      expect(agendaTile('Nur Sandra'), findsOneWidget);
      expect(agendaTile('Marcel und Sandra'), findsOneWidget);
      expect(
        find.byKey(ValueKey('month-more-${dayId(today)}')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('month-more-${dayId(today)}')))
            .data,
        '+2',
      );

      await tester.tap(find.byKey(const ValueKey('member-filter-member-a')));
      await tester.pumpAndSettle();
      expect(agendaTile('Für alle'), findsOneWidget);
      expect(agendaTile('Nur Marcel'), findsOneWidget);
      expect(agendaTile('Marcel und Sandra'), findsOneWidget);
      expect(agendaTile('Nur Sandra'), findsNothing);
      expect(
        find.byKey(ValueKey('month-event-b-${dayId(today)}')),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('month-more-${dayId(today)}')))
            .data,
        '+1',
      );

      await tester.tap(agendaTile('Marcel und Sandra'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Betrifft'));
      await tester.tap(find.text('Betrifft'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('assignment-member-a')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('assignment-member-b')),
            )
            .value,
        isTrue,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Woche'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('week-event-a-${dayId(today)}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('week-event-b-${dayId(today)}')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('week-day-card-${dayId(tomorrow)}')),
          matching: find.text('Keine Termine'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Termin anlegen'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Betrifft'));
      await tester.tap(find.text('Betrifft'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('assignment-member-a')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('assignment-all')),
            )
            .value,
        isFalse,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('member-filter-member-b')));
      await tester.pumpAndSettle();
      expect(agendaTile('Nur Marcel'), findsNothing);
      expect(agendaTile('Nur Sandra'), findsOneWidget);
      expect(agendaTile('Marcel und Sandra'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('member-filter-all')));
      await tester.pumpAndSettle();
      expect(agendaTile('Nur Marcel'), findsOneWidget);
      expect(agendaTile('Nur Sandra'), findsOneWidget);
    },
  );

  testWidgets('member filter survives renaming and resets when member leaves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final store = storeWithEvents([
      eventAt(
        'a',
        'Termin A',
        today,
        9,
        10,
        assignedMemberIds: const ['member-a'],
      ),
      eventAt(
        'b',
        'Termin B',
        today,
        10,
        11,
        assignedMemberIds: const ['member-b'],
      ),
    ]);

    Widget calendar(Map<String, String> labels) => MaterialApp(
      home: CalendarScreen(
        key: const ValueKey('calendar'),
        store: store,
        memberLabels: labels,
      ),
    );

    await tester.pumpWidget(
      calendar(const {'member-a': 'Marcel', 'member-b': 'Sandra'}),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-filter-member-a')));
    await tester.pumpAndSettle();
    expect(agendaTile('Termin A'), findsOneWidget);
    expect(agendaTile('Termin B'), findsNothing);

    await tester.pumpWidget(
      calendar(const {'member-a': 'Papa', 'member-b': 'Sandra'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Papa'), findsOneWidget);
    expect(agendaTile('Termin A'), findsOneWidget);
    expect(agendaTile('Termin B'), findsNothing);

    await tester.pumpWidget(calendar(const {'member-b': 'Sandra'}));
    await tester.pumpAndSettle();
    expect(agendaTile('Termin A'), findsOneWidget);
    expect(agendaTile('Termin B'), findsOneWidget);
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
    final unknownAudience = find.descendant(
      of: find.byKey(const ValueKey('agenda-audience-historic')),
      matching: find.byType(Container),
    );
    final unknownDecoration =
        tester.widget<Container>(unknownAudience.first).decoration
            as BoxDecoration;
    expect(unknownDecoration.color, MemberColorResolver.unknown.background);
    expect(tester.takeException(), isNull);
  });
}
