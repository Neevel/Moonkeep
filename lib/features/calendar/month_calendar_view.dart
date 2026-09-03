import 'package:flutter/material.dart';

import 'calendar_event.dart';

class MonthCalendarView extends StatelessWidget {
  const MonthCalendarView({
    super.key,
    required this.visibleMonth,
    required this.selectedDay,
    required this.eventsByDay,
    required this.onPrevious,
    required this.onNext,
    required this.onDaySelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> eventsByDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    return GestureDetector(
      key: const ValueKey('month-swipe-area'),
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
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: localizations.previousMonthTooltip,
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    localizations.formatMonthYear(visibleMonth),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: localizations.nextMonthTooltip,
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final label in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            for (var week = 0; week < 6; week++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    Expanded(
                      child: _MonthDayCell(
                        day: gridStart.add(Duration(days: week * 7 + weekday)),
                        visibleMonth: visibleMonth,
                        selectedDay: selectedDay,
                        events:
                            eventsByDay[_dateKey(
                              gridStart.add(Duration(days: week * 7 + weekday)),
                            )] ??
                            const [],
                        onSelected: onDaySelected,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.visibleMonth,
    required this.selectedDay,
    required this.events,
    required this.onSelected,
  });

  final DateTime day;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = DateUtils.isSameDay(day, selectedDay);
    final today = DateUtils.isSameDay(day, DateTime.now());
    final inMonth =
        day.month == visibleMonth.month && day.year == visibleMonth.year;
    final visibleEvents = events.take(2).toList();
    return Semantics(
      label:
          '${MaterialLocalizations.of(context).formatFullDate(day)}${events.isEmpty ? '' : ', ${events.length} Termine'}',
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('month-day-${_dayId(day)}'),
        onTap: () => onSelected(DateUtils.dateOnly(day)),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 74,
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : null,
            borderRadius: BorderRadius.circular(10),
            border: today
                ? Border.all(color: colors.primary.withValues(alpha: 0.65))
                : Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.45),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${day.day}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1,
                  fontSize: 12,
                  color: inMonth
                      ? colors.onSurface
                      : colors.outline.withValues(alpha: 0.6),
                  fontWeight: selected || today ? FontWeight.bold : null,
                ),
              ),
              const SizedBox(height: 4),
              for (var index = 0; index < visibleEvents.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Container(
                    key: ValueKey(
                      'month-event-${visibleEvents[index].id}-${_dayId(day)}',
                    ),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _eventColor(
                        colors,
                        visibleEvents[index],
                      ).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '• ${visibleEvents[index].title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1,
                        color: _eventColor(colors, visibleEvents[index]),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (events.length > visibleEvents.length)
                Text(
                  '+${events.length - visibleEvents.length}',
                  key: ValueKey('month-more-${_dayId(day)}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _eventColor(ColorScheme colors, CalendarEvent event) =>
    switch (event.importance) {
      EventImportance.high => colors.error,
      EventImportance.normal => colors.primary,
      EventImportance.low => colors.outline,
    };

DateTime _dateKey(DateTime day) => DateTime(day.year, day.month, day.day);

String _dayId(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
