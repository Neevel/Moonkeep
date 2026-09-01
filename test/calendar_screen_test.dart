import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/app.dart';
import 'package:moonkeep/features/calendar/calendar_event.dart';
import 'package:moonkeep/features/calendar/calendar_store.dart';

void main() {
  CalendarStore emptyStore() =>
      CalendarStore(read: () async => null, write: (_) async {});

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

    await tester.ensureVisible(find.byTooltip('Termin löschen'));
    await tester.tap(find.byTooltip('Termin löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Terminserie löschen?'), findsOneWidget);
    expect(find.textContaining('alle Wiederholungen'), findsOneWidget);
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(store.allEvents, isEmpty);
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
    final nextMonth = DateTime(today.year, today.month + 1);
    await tester.tap(find.byTooltip(localizations.nextMonthTooltip));
    await tester.pumpAndSettle();
    expect(find.text(localizations.formatMonthYear(nextMonth)), findsOneWidget);
    await tester.tap(find.text('Heute'));
    await tester.pumpAndSettle();
    expect(find.text(localizations.formatMonthYear(today)), findsOneWidget);
    expect(find.text(localizations.formatMonthYear(nextMonth)), findsNothing);
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
    await tester.tap(find.text('Termin anlegen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
