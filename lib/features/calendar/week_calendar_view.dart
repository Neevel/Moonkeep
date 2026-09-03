import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'calendar_event.dart';

class WeekCalendarView extends StatelessWidget {
  const WeekCalendarView({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.eventsByDay,
    required this.onPrevious,
    required this.onNext,
    required this.onDaySelected,
    required this.onEventSelected,
  });

  static const double _dayWidth = 116;
  static const double _timeWidth = 48;
  static const double _hourHeight = 52;

  final DateTime weekStart;
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> eventsByDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDaySelected;
  final void Function(CalendarEvent event, DateTime day) onEventSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final days = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    final timedEvents = [
      for (final day in days) ..._events(day).where((event) => !event.isAllDay),
    ];
    final startHour = timedEvents.isEmpty
        ? 6
        : math.min(
            6,
            timedEvents.map((event) => event.start.hour).reduce(math.min),
          );
    final endHour = timedEvents.isEmpty
        ? 22
        : math.max(
            22,
            timedEvents
                .map(
                  (event) => math.min(
                    24,
                    event.end.hour + (event.end.minute == 0 ? 0 : 1),
                  ),
                )
                .reduce(math.max),
          );
    final allDayCount = days
        .map((day) => _events(day).where((event) => event.isAllDay).length)
        .fold<int>(0, math.max);
    final allDayHeight = allDayCount == 0
        ? 0.0
        : math.max(48.0, 8 + allDayCount * 34.0);
    final timelineHeight = (endHour - startHour) * _hourHeight;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Vorherige Woche',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${localizations.formatShortDate(weekStart)} – ${localizations.formatShortDate(weekEnd)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Nächste Woche',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _timeWidth + 7 * _dayWidth,
              child: Column(
                children: [
                  _headers(context, days),
                  if (allDayCount > 0) _allDayRow(context, days, allDayHeight),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _timeAxis(context, startHour, endHour, timelineHeight),
                      for (final day in days)
                        _dayTimeline(context, day, startHour, timelineHeight),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headers(BuildContext context, List<DateTime> days) => Row(
    children: [
      const SizedBox(width: _timeWidth),
      for (final day in days)
        SizedBox(
          width: _dayWidth,
          child: InkWell(
            key: ValueKey('week-day-${_dayId(day)}'),
            onTap: () => onDaySelected(day),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: DateUtils.isSameDay(day, selectedDay)
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    const [
                      'Mo',
                      'Di',
                      'Mi',
                      'Do',
                      'Fr',
                      'Sa',
                      'So',
                    ][day.weekday - 1],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('${day.day}.${day.month}.'),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _allDayRow(
    BuildContext context,
    List<DateTime> days,
    double height,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: _timeWidth,
        height: height,
        child: const Padding(
          padding: EdgeInsets.only(top: 8, right: 4),
          child: Text(
            'Ganz-\ntägig',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 9),
          ),
        ),
      ),
      for (final day in days)
        Container(
          width: _dayWidth,
          height: height,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Column(
            children: [
              for (final event in _events(day).where((event) => event.isAllDay))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _CompactEvent(
                    key: ValueKey('week-all-day-${event.id}-${_dayId(day)}'),
                    event: event,
                    label: '• ${event.title}',
                    onTap: () => onEventSelected(event, day),
                  ),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _timeAxis(
    BuildContext context,
    int startHour,
    int endHour,
    double height,
  ) => SizedBox(
    width: _timeWidth,
    height: height,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        for (var hour = startHour; hour <= endHour; hour++)
          Positioned(
            top: (hour - startHour) * _hourHeight - 6,
            right: 5,
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _dayTimeline(
    BuildContext context,
    DateTime day,
    int startHour,
    double height,
  ) {
    final colors = Theme.of(context).colorScheme;
    final events = _events(day).where((event) => !event.isAllDay).toList();
    final layout = _layoutEvents(events);
    return GestureDetector(
      onTap: () => onDaySelected(day),
      child: Container(
        key: ValueKey('week-timeline-${_dayId(day)}'),
        width: _dayWidth,
        height: height,
        decoration: BoxDecoration(
          color: DateUtils.isSameDay(day, selectedDay)
              ? colors.primaryContainer.withValues(alpha: 0.22)
              : null,
          border: Border(left: BorderSide(color: colors.outlineVariant)),
        ),
        child: Stack(
          children: [
            for (var hour = 0; hour <= height / _hourHeight; hour++)
              Positioned(
                top: hour * _hourHeight,
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
            for (final positioned in layout)
              Positioned(
                key: ValueKey(
                  'week-event-${positioned.event.id}-${_dayId(day)}',
                ),
                top: _top(positioned.event, startHour),
                left: 2 + positioned.lane * positioned.laneWidth,
                width: math.max(2, positioned.laneWidth - 3),
                height: _height(positioned.event),
                child: _CompactEvent(
                  event: positioned.event,
                  label:
                      '${_time(positioned.event.start)} ${positioned.event.title}',
                  onTap: () => onEventSelected(positioned.event, day),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_EventLayout> _layoutEvents(List<CalendarEvent> events) {
    events.sort((a, b) {
      final start = _minute(a.start).compareTo(_minute(b.start));
      return start != 0 ? start : a.id.compareTo(b.id);
    });
    final laneEnds = <int>[];
    final assigned = <(CalendarEvent, int)>[];
    for (final event in events) {
      final start = _minute(event.start);
      final visualEnd = math.max(_minute(event.end), start + 30);
      var lane = laneEnds.indexWhere((end) => end <= start);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(visualEnd);
      } else {
        laneEnds[lane] = visualEnd;
      }
      assigned.add((event, lane));
    }
    final laneWidth = (_dayWidth - 4) / math.max(1, laneEnds.length);
    return [
      for (final item in assigned)
        _EventLayout(event: item.$1, lane: item.$2, laneWidth: laneWidth),
    ];
  }

  List<CalendarEvent> _events(DateTime day) =>
      eventsByDay[DateTime(day.year, day.month, day.day)] ?? const [];

  double _top(CalendarEvent event, int startHour) =>
      (_minute(event.start) - startHour * 60) * (_hourHeight / 60);

  double _height(CalendarEvent event) => math.max(
    30,
    (_minute(event.end) - _minute(event.start)) * (_hourHeight / 60) - 2,
  );
}

class _CompactEvent extends StatelessWidget {
  const _CompactEvent({
    super.key,
    required this.event,
    required this.label,
    required this.onTap,
  });

  final CalendarEvent event;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (event.importance) {
      EventImportance.high => colors.error,
      EventImportance.normal => colors.primary,
      EventImportance.low => colors.outline,
    };
    return Material(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventLayout {
  const _EventLayout({
    required this.event,
    required this.lane,
    required this.laneWidth,
  });

  final CalendarEvent event;
  final int lane;
  final double laneWidth;
}

int _minute(DateTime value) => value.hour * 60 + value.minute;

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dayId(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
