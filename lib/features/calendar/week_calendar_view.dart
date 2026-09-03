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
  static const double _eventHeight = 38;

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
    final allDayCount = days
        .map((day) => _allDayEvents(day).length)
        .fold<int>(0, math.max);
    final timedCount = days
        .map((day) => _timedEvents(day).length)
        .fold<int>(0, math.max);
    final allDayHeight = _rowHeight(allDayCount, emptyHeight: 0);
    final timedHeight = _rowHeight(timedCount, emptyHeight: 64);

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
              width: 7 * _dayWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headers(context, days),
                  if (allDayCount > 0) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 4, 4, 3),
                      child: Text(
                        'Ganztägig',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _eventRow(context, days, allDayHeight, allDay: true),
                    const SizedBox(height: 6),
                  ],
                  _eventRow(context, days, timedHeight, allDay: false),
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

  Widget _eventRow(
    BuildContext context,
    List<DateTime> days,
    double height, {
    required bool allDay,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final day in days)
        GestureDetector(
          onTap: () => onDaySelected(day),
          child: Container(
            key: ValueKey(
              '${allDay ? 'week-all-day-column' : 'week-timeline'}-${_dayId(day)}',
            ),
            width: _dayWidth,
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: DateUtils.isSameDay(day, selectedDay)
                  ? Theme.of(context).colorScheme.primaryContainer
                        .withValues(alpha: 0.22)
                  : null,
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
                for (final event
                    in allDay ? _allDayEvents(day) : _timedEvents(day))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SizedBox(
                      key: ValueKey(
                        '${allDay ? 'week-all-day' : 'week-event'}-${event.id}-${_dayId(day)}',
                      ),
                      height: _eventHeight,
                      child: _CompactEvent(
                        event: event,
                        label: allDay
                            ? '• ${event.title}'
                            : '${_time(event.start)} ${event.title}',
                        onTap: () => onEventSelected(event, day),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );

  List<CalendarEvent> _allDayEvents(DateTime day) {
    final events = _events(day).where((event) => event.isAllDay).toList();
    events.sort((a, b) => a.title.compareTo(b.title));
    return events;
  }

  List<CalendarEvent> _timedEvents(DateTime day) {
    final events = _events(day).where((event) => !event.isAllDay).toList();
    events.sort((a, b) {
      final start = a.start.compareTo(b.start);
      return start != 0 ? start : a.id.compareTo(b.id);
    });
    return events;
  }

  List<CalendarEvent> _events(DateTime day) =>
      eventsByDay[DateTime(day.year, day.month, day.day)] ?? const [];

  double _rowHeight(int count, {required double emptyHeight}) => count == 0
      ? emptyHeight
      : math.max(emptyHeight, 7 + count * (_eventHeight + 4));
}

class _CompactEvent extends StatelessWidget {
  const _CompactEvent({
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
          child: Align(
            alignment: Alignment.centerLeft,
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
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dayId(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
