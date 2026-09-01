import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'calendar_event.dart';
import 'calendar_repository.dart';

/// Civil Berlin wall times, carried in UTC DateTime values without conversion.
/// These are not UTC instants and must never be passed through toLocal().
Map<String, Object?> sharedEventData(CalendarEvent event) => {
  'title': event.title,
  'notes': event.notes,
  'year': event.start.year,
  'month': event.start.month,
  'day': event.start.day,
  'startMinute': event.start.hour * 60 + event.start.minute,
  'endMinute': event.end.hour * 60 + event.end.minute,
  'importance': event.importance.name,
  'reminderMinutesBefore': event.reminderMinutesBefore,
  if (event.isAllDay) 'allDay': true,
  if (event.recurrence != EventRecurrence.none)
    'recurrence': {
      'frequency': event.recurrence.name,
      if (event.recurrenceEnd != null) ...{
        'endYear': event.recurrenceEnd!.year,
        'endMonth': event.recurrenceEnd!.month,
        'endDay': event.recurrenceEnd!.day,
      },
    },
  'revision': event.revision + 1,
};

CalendarEvent sharedEvent(String id, Map<String, dynamic> data) {
  final y = data['year'] as int,
      m = data['month'] as int,
      d = data['day'] as int;
  final start = data['startMinute'] as int, end = data['endMinute'] as int;
  final importance = EventImportance.values.firstWhere(
    (value) => value.name == data['importance'],
    orElse: () => EventImportance.normal,
  );
  final reminder = data['reminderMinutesBefore'];
  final allDay = data['allDay'];
  final recurrenceData = data['recurrence'];
  var recurrence = EventRecurrence.none;
  DateTime? recurrenceEnd;
  final date = DateTime.utc(y, m, d);
  if (date.year != y ||
      date.month != m ||
      date.day != d ||
      y < 1900 ||
      y > 2100 ||
      start < 0 ||
      end >= 1440 ||
      end <= start ||
      (reminder != null &&
          (reminder is! int || ![0, 10, 30, 60, 1440].contains(reminder))) ||
      (allDay != null && allDay is! bool) ||
      (allDay == true && reminder != null) ||
      (data['revision'] as int) < 1) {
    throw const FormatException('Ungültiger gemeinsamer Termin.');
  }
  if (recurrenceData != null) {
    if (recurrenceData is! Map<String, dynamic>) {
      throw const FormatException('Ungültige Terminwiederholung.');
    }
    recurrence = EventRecurrence.values.firstWhere(
      (value) =>
          value != EventRecurrence.none &&
          value.name == recurrenceData['frequency'],
      orElse: () =>
          throw const FormatException('Ungültige Terminwiederholung.'),
    );
    final endValues = [
      recurrenceData['endYear'],
      recurrenceData['endMonth'],
      recurrenceData['endDay'],
    ];
    if (endValues.any((value) => value != null)) {
      if (endValues.any((value) => value is! int)) {
        throw const FormatException('Ungültiges Wiederholungsende.');
      }
      final endDate = DateTime.utc(
        endValues[0]! as int,
        endValues[1]! as int,
        endValues[2]! as int,
      );
      if (endDate.year != endValues[0] ||
          endDate.month != endValues[1] ||
          endDate.day != endValues[2] ||
          endDate.isBefore(date)) {
        throw const FormatException('Ungültiges Wiederholungsende.');
      }
      recurrenceEnd = endDate;
    }
  }
  return CalendarEvent(
    id: id,
    title: data['title'] as String,
    notes: data['notes'] as String,
    start: date.add(Duration(minutes: start)),
    end: date.add(Duration(minutes: end)),
    revision: data['revision'] as int,
    importance: importance,
    reminderMinutesBefore: reminder as int?,
    isAllDay: allDay == true,
    recurrence: recurrence,
    recurrenceEnd: recurrenceEnd,
  );
}

class FirestoreCalendarRepository extends CalendarRepository {
  FirestoreCalendarRepository({
    required this.db,
    required this.familyId,
    required this.familyName,
    required this.uid,
    required this.sessionValid,
  });

  final FirebaseFirestore db;
  final String familyId, familyName, uid;
  final bool Function(String uid) sessionValid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _activitySubscription;
  final _noticeController = StreamController<CalendarNotice>.broadcast();
  List<CalendarEvent> _events = [];
  DateTime _day = DateTime.now();
  int _generation = 0;
  bool _disposed = false, _loading = true, _saving = false;
  bool _activityReady = false;
  String? _error;
  @override
  bool get isShared => true;
  @override
  String get label => familyName;
  @override
  bool get isLoading => _loading;
  @override
  String? get syncError => _error;
  @override
  List<CalendarEvent> get allEvents =>
      sessionValid(uid) ? List.unmodifiable(_events) : const [];
  @override
  Stream<CalendarNotice> get notices => _noticeController.stream;
  CollectionReference<Map<String, dynamic>> get _collection =>
      db.collection('families/$familyId/events');

  void _requireSession() {
    if (_disposed || !sessionValid(uid)) {
      throw const CalendarFailure(
        'Die Sitzung hat sich geändert. Bitte öffne den gemeinsamen Kalender erneut.',
      );
    }
  }

  @override
  Future<void> load() {
    _watchActivity();
    return _watch(_day);
  }

  @override
  void selectDay(DateTime day) {
    _day = day;
  }

  void _watchActivity() {
    unawaited(_activitySubscription?.cancel());
    _activityReady = false;
    _activitySubscription = db
        .collection('families/$familyId/activity')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          if (_disposed ||
              snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites) {
            return;
          }
          if (!_activityReady) {
            _activityReady = true;
            return;
          }
          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final data = change.doc.data();
            if (data == null || data['actorId'] == uid) continue;
            final action = data['action'];
            if (action == 'created' || action == 'deleted') {
              _noticeController.add(
                CalendarNotice(
                  kind: action == 'created'
                      ? CalendarNoticeKind.created
                      : CalendarNoticeKind.deleted,
                  title: data['title'] as String,
                ),
              );
            }
          }
        });
  }

  Future<void> _watch(DateTime day) async {
    if (_disposed) return;
    final generation = ++_generation;
    _day = day;
    _events = [];
    _loading = true;
    _error = null;
    notifyListeners();
    await _subscription?.cancel();
    if (_disposed || generation != _generation) return;
    final ready = Completer<void>();
    void finish() {
      if (!ready.isCompleted) ready.complete();
    }

    void fail(Object error) {
      if (_disposed || generation != _generation) return;
      _events = [];
      _loading = false;
      _error = _errorMessage(error);
      notifyListeners();
      finish();
    }

    try {
      _requireSession();
      _subscription = _collection
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
            if (_disposed || generation != _generation) return;
            try {
              _requireSession();
              if (snapshot.metadata.isFromCache) {
                _events = [];
                _error = 'Warte auf Serververbindung. Gemeinsame Termine sind nur online verfügbar.';
                notifyListeners();
                return;
              }
              if (snapshot.metadata.hasPendingWrites) return;
              _events = snapshot.docs
                  .map((doc) => sharedEvent(doc.id, doc.data()))
                  .toList();
              _loading = false;
              _error = null;
              notifyListeners();
              finish();
            } catch (error) {
              fail(error);
            }
          }, onError: fail);
      await ready.future.timeout(const Duration(seconds: 15));
    } catch (error) {
      fail(error);
    }
  }

  @override
  List<CalendarEvent> eventsOn(DateTime day) {
    if (!sessionValid(uid)) return [];
    return _events.where((e) => e.occursOn(day)).toList()..sort(
      (a, b) => a.start.compareTo(b.start) != 0
          ? a.start.compareTo(b.start)
          : a.id.compareTo(b.id),
    );
  }

  Future<void> _write(Future<void> Function() operation) async {
    _requireSession();
    if (_saving) {
      throw const CalendarFailure('Eine Änderung wird bereits gespeichert.');
    }
    _saving = true;
    try {
      await operation();
      _requireSession();
    } catch (error) {
      throw CalendarFailure(_errorMessage(error));
    } finally {
      _saving = false;
    }
  }

  @override
  Future<void> save(CalendarEvent event) => _write(
    () => db.runTransaction((tx) async {
      _requireSession();
      final ref = _collection.doc(event.id);
      final old = await tx.get(ref);
      if ((old.exists ? old.data()!['revision'] : 0) != event.revision) {
        throw const CalendarFailure(
          'Dieser Termin wurde inzwischen geändert oder gelöscht. Bitte gehe zurück und öffne den aktuellen Termin erneut.',
        );
      }
      tx.set(ref, {
        ...sharedEventData(event),
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!old.exists) {
        tx.set(db.collection('families/$familyId/activity').doc(), {
          'action': 'created',
          'eventId': event.id,
          'title': event.title,
          'actorId': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }),
  );

  @override
  Future<void> delete(String id, {int? expectedRevision}) => _write(
    () => db.runTransaction((tx) async {
      _requireSession();
      final ref = _collection.doc(id);
      final old = await tx.get(ref);
      if (!old.exists || old.data()!['revision'] != expectedRevision) {
        throw const CalendarFailure(
          'Dieser Termin wurde inzwischen geändert oder gelöscht. Bitte prüfe den aktuellen Stand.',
        );
      }
      tx.delete(ref);
      tx.set(db.collection('families/$familyId/activity').doc(), {
        'action': 'deleted',
        'eventId': id,
        'title': old.data()!['title'],
        'actorId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }),
  );

  String _errorMessage(Object error) {
    if (error is CalendarFailure) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Kein Zugriff auf diesen Kalender. Bitte Konto und Freigabe prüfen.';
    }
    if (error is FormatException) {
      return 'Ein gemeinsamer Termin enthält ungültige Daten. Bitte die Daten prüfen.';
    }
    return 'Keine bestätigte Serververbindung. Bitte erneut versuchen. Der Serverstand wird beim Aktualisieren neu geladen.';
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    unawaited(_activitySubscription?.cancel());
    unawaited(_noticeController.close());
    _events = [];
    super.dispose();
  }
}
