import 'dart:math';

import 'package:flutter/foundation.dart';

import 'calendar_event.dart';

class CalendarFailure implements Exception {
  const CalendarFailure(this.message);
  final String message;
}

enum CalendarNoticeKind { created, deleted }

class CalendarNotice {
  const CalendarNotice({required this.kind, required this.title});
  final CalendarNoticeKind kind;
  final String title;
}

/// Shared and local calendars have separate storage and never migrate implicitly.
abstract class CalendarRepository extends ChangeNotifier {
  bool get isShared => false;
  bool get isLoading => false;
  String? get syncError => null;
  String get label => 'Moonkeep';
  List<CalendarEvent> get allEvents => const [];
  Stream<CalendarNotice> get notices => const Stream.empty();
  Future<void> load();
  void selectDay(DateTime day) {}
  List<CalendarEvent> eventsOn(DateTime day);
  Future<void> save(CalendarEvent event);
  Future<void> delete(String id, {int? expectedRevision});
  String newId() => secureCode();
}

String secureCode() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
