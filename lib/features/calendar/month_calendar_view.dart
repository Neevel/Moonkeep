import 'package:flutter/material.dart';

import 'calendar_event.dart';
import 'member_color_resolver.dart';

class MonthCalendarView extends StatelessWidget {
  const MonthCalendarView({
    super.key,
    required this.visibleMonth,
    required this.selectedDay,
    required this.eventsByDay,
    required this.memberLabels,
    required this.onPrevious,
    required this.onNext,
    required this.onDaySelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> eventsByDay;
  final Map<String, String> memberLabels;
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
                      padding: EdgeInsets.symmetric(vertical: 4),
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
                        memberLabels: memberLabels,
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
    required this.memberLabels,
    required this.onSelected,
  });

  final DateTime day;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final List<CalendarEvent> events;
  final Map<String, String> memberLabels;
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
          height: 68,
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.fromLTRB(2, 3, 2, 1),
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
              const SizedBox(height: 3),
              for (var index = 0; index < visibleEvents.length; index++)
                _MonthEventChip(
                  event: visibleEvents[index],
                  day: day,
                  memberLabels: memberLabels,
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

class _MonthEventChip extends StatelessWidget {
  const _MonthEventChip({
    required this.event,
    required this.day,
    required this.memberLabels,
  });

  final CalendarEvent event;
  final DateTime day;
  final Map<String, String> memberLabels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final audience = MemberColorResolver.forEvent(event, memberLabels);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        key: ValueKey('month-event-${event.id}-${_dayId(day)}'),
        height: 15,
        padding: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: audience.background,
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(color: _importanceColor(colors, event), width: 2),
          ),
        ),
        child: Row(
          children: [
            if (audience.kind == CalendarAudienceKind.multiple)
              Padding(
                padding: const EdgeInsets.only(left: 2, right: 2),
                child: _ColorDots(colors: audience.indicatorColors),
              )
            else
              const SizedBox(width: 2),
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  color: audience.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDots extends StatelessWidget {
  const _ColorDots({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final color in colors.take(3))
        Container(
          width: 3,
          height: 3,
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
    ],
  );
}

Color _importanceColor(ColorScheme colors, CalendarEvent event) =>
    switch (event.importance) {
      EventImportance.high => colors.error,
      EventImportance.normal => colors.primary,
      EventImportance.low => colors.outline,
    };

DateTime _dateKey(DateTime day) => DateTime(day.year, day.month, day.day);

String _dayId(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
