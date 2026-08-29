import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_event.dart';
import 'calendar_repository.dart';

/// Device-local prototype storage. Never used as a shared family database.
class CalendarStore extends CalendarRepository {
  CalendarStore({required this.read, required this.write});

  factory CalendarStore.local() {
    final preferences = SharedPreferencesAsync();
    return CalendarStore(
      read: () => preferences.getString(storageKey),
      write: (value) => preferences.setString(storageKey, value),
    );
  }

  static const storageKey = 'moonkeep.events.v1';
  final Future<String?> Function() read;
  final Future<void> Function(String value) write;
  List<CalendarEvent> _events = [];
  bool _loaded = false;
  bool _saving = false;

  @override
  List<CalendarEvent> get allEvents => List.unmodifiable(_events);

  @override
  Future<void> load() async {
    _loaded = false;
    final raw = await read();
    final decoded = raw == null
        ? <dynamic>[]
        : jsonDecode(raw) as List<dynamic>;
    final events = decoded
        .map((value) => CalendarEvent.fromJson(value as Map<String, dynamic>))
        .toList();
    if (events.map((event) => event.id).toSet().length != events.length) {
      throw const FormatException('Doppelte Termin-IDs im lokalen Kalender.');
    }
    _events = events;
    _loaded = true;
    notifyListeners();
  }

  @override
  List<CalendarEvent> eventsOn(DateTime day) =>
      _events.where((event) => isSameDay(event.start, day)).toList()
        ..sort((a, b) {
          final byTime = a.start.compareTo(b.start);
          return byTime == 0 ? a.id.compareTo(b.id) : byTime;
        });

  @override
  Future<void> save(CalendarEvent event) => _persist([
    ..._events.where((existing) => existing.id != event.id),
    event,
  ]);

  @override
  Future<void> delete(String id, {int? expectedRevision}) =>
      _persist(_events.where((event) => event.id != id).toList());

  Future<void> _persist(List<CalendarEvent> events) async {
    if (!_loaded || _saving) {
      throw StateError('Kalender ist noch nicht bereit.');
    }
    _saving = true;
    try {
      await write(jsonEncode(events.map((event) => event.toJson()).toList()));
      _events = events;
      notifyListeners();
    } finally {
      _saving = false;
    }
  }
}
