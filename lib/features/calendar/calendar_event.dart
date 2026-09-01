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

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required String title,
    required this.start,
    required this.end,
    String notes = '',
    this.revision = 0,
    this.importance = EventImportance.normal,
    this.reminderMinutesBefore,
    this.isAllDay = false,
    this.recurrence = EventRecurrence.none,
    this.recurrenceEnd,
  }) : title = title.trim(),
       notes = notes.trim() {
    if (id.isEmpty || this.title.isEmpty) {
      throw ArgumentError('ID und Titel dürfen nicht leer sein.');
    }
    if (!end.isAfter(start) || !isSameDay(start, end)) {
      throw ArgumentError(
        'Das Ende muss am selben Tag nach dem Beginn liegen.',
      );
    }
    if (isAllDay && reminderMinutesBefore != null) {
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
  }

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String notes;
  final int revision;
  final EventImportance importance;
  final int? reminderMinutesBefore;
  final bool isAllDay;
  final EventRecurrence recurrence;
  final DateTime? recurrenceEnd;

  bool occursOn(DateTime day) {
    final distance = _civilDay(day).difference(_civilDay(start)).inDays;
    if (distance < 0 ||
        (recurrenceEnd != null && _compareCivilDays(day, recurrenceEnd!) > 0)) {
      return false;
    }
    return switch (recurrence) {
      EventRecurrence.none => distance == 0,
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
    'reminderMinutesBefore': reminderMinutesBefore,
    'isAllDay': isAllDay,
    'recurrence': recurrence.name,
    'recurrenceEnd': recurrenceEnd?.toIso8601String(),
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
      reminderMinutesBefore: json['reminderMinutesBefore'] as int?,
      isAllDay: json['isAllDay'] as bool? ?? false,
      recurrence: recurrence,
      recurrenceEnd: recurrence == EventRecurrence.none || recurrenceEnd == null
          ? null
          : DateTime.parse(recurrenceEnd as String),
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _civilDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

int _compareCivilDays(DateTime a, DateTime b) =>
    _civilDay(a).compareTo(_civilDay(b));
