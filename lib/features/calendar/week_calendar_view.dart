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
    return GestureDetector(
      key: const ValueKey('week-swipe-area'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -250) {
          onNext();
        } else if (velocity > 250) {
          onPrevious();
        }
      },
      child: Padding(
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
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720
                    ? 4
                    : constraints.maxWidth >= 520
                    ? 3
                    : 2;
                const spacing = 6.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final day in days)
                      SizedBox(
                        width: width,
                        child: _WeekDayCard(
                          day: day,
                          selected: DateUtils.isSameDay(day, selectedDay),
                          events: _events(day),
                          onDaySelected: onDaySelected,
                          onEventSelected: onEventSelected,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<CalendarEvent> _events(DateTime day) =>
      eventsByDay[DateTime(day.year, day.month, day.day)] ?? const [];
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    required this.day,
    required this.selected,
    required this.events,
    required this.onDaySelected,
    required this.onEventSelected,
  });

  static const double _eventHeight = 38;

  final DateTime day;
  final bool selected;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDaySelected;
  final void Function(CalendarEvent event, DateTime day) onEventSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allDay = events.where((event) => event.isAllDay).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    final timed = events.where((event) => !event.isAllDay).toList()
      ..sort((a, b) {
        final start = a.start.compareTo(b.start);
        return start != 0 ? start : a.id.compareTo(b.id);
      });
    final today = DateUtils.isSameDay(day, DateTime.now());
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.42)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: today
              ? colors.primary.withValues(alpha: 0.7)
              : colors.outlineVariant,
          width: today ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('week-day-${_dayId(day)}'),
        onTap: () => onDaySelected(day),
        child: ConstrainedBox(
          key: ValueKey('week-day-card-${_dayId(day)}'),
          constraints: const BoxConstraints(minHeight: 150),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_weekday(day.weekday)} ${day.day}.${day.month}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: today ? colors.primary : null,
                        ),
                      ),
                    ),
                    Text(
                      '${events.length}',
                      style: TextStyle(fontSize: 11, color: colors.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (allDay.isNotEmpty) ...[
                  Text(
                    'Ganztägig',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  for (final event in allDay)
                    _event(
                      event,
                      label: '• ${event.title}',
                      key: 'week-all-day-${event.id}-${_dayId(day)}',
                    ),
                  if (timed.isNotEmpty) const SizedBox(height: 5),
                ],
                for (final event in timed)
                  _event(
                    event,
                    label:
                        '${_time(event.start)} – ${_time(event.end)}\n${event.title}',
                    key: 'week-event-${event.id}-${_dayId(day)}',
                  ),
                if (events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Text(
                      'Keine Termine',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: colors.outline),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _event(
    CalendarEvent event, {
    required String label,
    required String key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: SizedBox(
      key: ValueKey(key),
      height: _eventHeight,
      child: _CompactEvent(
        event: event,
        label: label,
        onTap: () => onEventSelected(event, day),
      ),
    ),
  );
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
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
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

String _weekday(int weekday) =>
    const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][weekday - 1];

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dayId(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
