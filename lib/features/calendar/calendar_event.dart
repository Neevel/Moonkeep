enum EventImportance {
  low('Weniger wichtig'),
  normal('Normal'),
  high('Wichtig');

  const EventImportance(this.label);
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
  }

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String notes;
  final int revision;
  final EventImportance importance;
  final int? reminderMinutesBefore;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'notes': notes,
    'importance': importance.name,
    'reminderMinutesBefore': reminderMinutesBefore,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
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
  );
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
