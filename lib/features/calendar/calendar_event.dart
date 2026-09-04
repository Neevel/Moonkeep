enum EventImportance {
  low('Weniger wichtig'),
  normal('Normal'),
  high('Wichtig');

  const EventImportance(this.label);
  final String label;
}

enum EventRecurrence {
  none('Keine Wiederholung'),
  daily('Täglich'),
  weekly('Wöchentlich'),
  biweekly('Alle 2 Wochen'),
  monthly('Monatlich'),
  yearly('Jährlich');

  const EventRecurrence(this.label);
  final String label;
}

enum ReminderOffset {
  none('Keine Erinnerung', null),
  atStart('Zur Startzeit', 0),
  legacyMinutes10('10 Minuten vorher', 10),
  minutes15('15 Minuten vorher', 15),
  minutes30('30 Minuten vorher', 30),
  hours1('1 Stunde vorher', 60),
  days1('1 Tag vorher', 1440);

  const ReminderOffset(this.label, this.minutesBefore);

  final String label;
  final int? minutesBefore;

  static const editorValues = [
    none,
    atStart,
    minutes15,
    minutes30,
    hours1,
    days1,
  ];

  static ReminderOffset fromMinutes(Object? value) {
    if (value == null) return none;
    return values.firstWhere(
      (offset) => offset.minutesBefore == value,
      orElse: () => throw const FormatException('Ungültige Erinnerung.'),
    );
  }
}

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required String title,
    required this.start,
    required this.end,
    String notes = '',
    this.revision = 0,
    this.importance = EventImportance.normal,
    this.reminderOffset = ReminderOffset.none,
    this.isAllDay = false,
    this.recurrence = EventRecurrence.none,
    this.recurrenceEnd,
    Iterable<String> assignedMemberIds = const [],
  }) : title = title.trim(),
       notes = notes.trim(),
       assignedMemberIds = Set.unmodifiable(assignedMemberIds) {
    if (id.isEmpty || this.title.isEmpty) {
      throw ArgumentError('ID und Titel dürfen nicht leer sein.');
    }
    if (!end.isAfter(start)) {
      throw ArgumentError('Das Ende muss nach dem Beginn liegen.');
    }
    if (isAllDay && reminderOffset != ReminderOffset.none) {
      throw ArgumentError(
        'Ganztägige Termine unterstützen derzeit keine Erinnerungen.',
      );
    }
    if (recurrence == EventRecurrence.none && recurrenceEnd != null) {
      throw ArgumentError(
        'Ein Enddatum ist nur für wiederkehrende Termine möglich.',
      );
    }
    if (recurrenceEnd != null && _compareCivilDays(recurrenceEnd!, start) < 0) {
      throw ArgumentError(
        'Das Wiederholungsende darf nicht vor dem Terminbeginn liegen.',
      );
    }
    if (recurrence != EventRecurrence.none && isMultiDay) {
      throw ArgumentError(
        'Mehrtagestermine können derzeit nicht wiederholt werden.',
      );
    }
    if (this.assignedMemberIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Mitglieds-IDs dürfen nicht leer sein.');
    }
    if (this.assignedMemberIds.length > 50) {
      throw ArgumentError('Zu viele Terminzuordnungen.');
    }
  }

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String notes;
  final int revision;
  final EventImportance importance;
  final ReminderOffset reminderOffset;
  final bool isAllDay;
  final EventRecurrence recurrence;
  final DateTime? recurrenceEnd;

  /// Empty means that the event applies to every calendar member.
  final Set<String> assignedMemberIds;

  bool get appliesToAllMembers => assignedMemberIds.isEmpty;
  bool get isMultiDay => !isSameDay(start, end);

  bool occursOn(DateTime day) {
    final distance = _civilDay(day).difference(_civilDay(start)).inDays;
    if (distance < 0 ||
        (recurrenceEnd != null && _compareCivilDays(day, recurrenceEnd!) > 0)) {
      return false;
    }
    return switch (recurrence) {
      EventRecurrence.none =>
        distance <= _civilDay(end).difference(_civilDay(start)).inDays,
      EventRecurrence.daily => true,
      EventRecurrence.weekly => distance % 7 == 0,
      EventRecurrence.biweekly => distance % 14 == 0,
      EventRecurrence.monthly => day.day == start.day,
      EventRecurrence.yearly =>
        day.month == start.month && day.day == start.day,
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'notes': notes,
    'importance': importance.name,
    'reminderMinutesBefore': reminderOffset.minutesBefore,
    'isAllDay': isAllDay,
    'recurrence': recurrence.name,
    'recurrenceEnd': recurrenceEnd?.toIso8601String(),
    if (assignedMemberIds.isNotEmpty)
      'assignedMemberIds': assignedMemberIds.toList(),
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final recurrence = EventRecurrence.values.firstWhere(
      (value) => value.name == json['recurrence'],
      orElse: () => EventRecurrence.none,
    );
    final recurrenceEnd = json['recurrenceEnd'];
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      notes: json['notes'] as String,
      importance: EventImportance.values.firstWhere(
        (value) => value.name == json['importance'],
        orElse: () => EventImportance.normal,
      ),
      reminderOffset: ReminderOffset.fromMinutes(json['reminderMinutesBefore']),
      isAllDay: json['isAllDay'] as bool? ?? false,
      recurrence: recurrence,
      recurrenceEnd: recurrence == EventRecurrence.none || recurrenceEnd == null
          ? null
          : DateTime.parse(recurrenceEnd as String),
      assignedMemberIds:
          (json['assignedMemberIds'] as List<dynamic>?)?.cast<String>() ??
          const [],
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _civilDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

int _compareCivilDays(DateTime a, DateTime b) =>
    _civilDay(a).compareTo(_civilDay(b));
