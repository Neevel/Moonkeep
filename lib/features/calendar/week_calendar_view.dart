import 'package:flutter/material.dart';

import 'calendar_event.dart';
import 'member_color_resolver.dart';

class WeekCalendarView extends StatelessWidget {
  const WeekCalendarView({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.eventsByDay,
    required this.memberLabels,
    required this.onPrevious,
    required this.onNext,
    required this.onDaySelected,
    required this.onEventSelected,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> eventsByDay;
  final Map<String, String> memberLabels;
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
            for (final day in days)
              _WeekDaySection(
                day: day,
                selected: DateUtils.isSameDay(day, selectedDay),
                events: _events(day),
                memberLabels: memberLabels,
                onDaySelected: onDaySelected,
                onEventSelected: onEventSelected,
              ),
          ],
        ),
      ),
    );
  }

  List<CalendarEvent> _events(DateTime day) =>
      eventsByDay[DateTime(day.year, day.month, day.day)] ?? const [];
}

class _WeekDaySection extends StatelessWidget {
  const _WeekDaySection({
    required this.day,
    required this.selected,
    required this.events,
    required this.memberLabels,
    required this.onDaySelected,
    required this.onEventSelected,
  });

  static const double _dayLabelWidth = 64;

  final DateTime day;
  final bool selected;
  final List<CalendarEvent> events;
  final Map<String, String> memberLabels;
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
    return AnimatedContainer(
      key: ValueKey('week-day-card-${_dayId(day)}'),
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.34)
            : colors.surface,
        border: Border(
          left: BorderSide(
            color: today ? colors.primary : Colors.transparent,
            width: 3,
          ),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('week-day-${_dayId(day)}'),
          onTap: () => onDaySelected(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _dayLabelWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${_weekday(day.weekday)} ${day.day}.${day.month}.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: today ? colors.primary : null,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: events.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Keine Termine',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.outline,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final event in allDay)
                              _event(
                                event,
                                timeLabel: 'Ganztägig',
                                memberLabels: memberLabels,
                                key: 'week-all-day-${event.id}-${_dayId(day)}',
                              ),
                            for (final event in timed)
                              _event(
                                event,
                                timeLabel: _timeLabel(event, day),
                                memberLabels: memberLabels,
                                key: 'week-event-${event.id}-${_dayId(day)}',
                              ),
                          ],
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
    required String timeLabel,
    required Map<String, String> memberLabels,
    required String key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: _CompactEvent(
      key: ValueKey(key),
      event: event,
      timeLabel: timeLabel,
      memberLabels: memberLabels,
      onTap: () => onEventSelected(event, day),
    ),
  );

  String _timeLabel(CalendarEvent event, DateTime day) {
    if (!event.isMultiDay || isSameDay(day, event.start)) {
      return _time(event.start);
    }
    if (isSameDay(day, event.end)) return 'bis ${_time(event.end)}';
    return 'läuft';
  }
}

class _CompactEvent extends StatelessWidget {
  const _CompactEvent({
    super.key,
    required this.event,
    required this.timeLabel,
    required this.memberLabels,
    required this.onTap,
  });

  final CalendarEvent event;
  final String timeLabel;
  final Map<String, String> memberLabels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (event.importance) {
      EventImportance.high => colors.error,
      EventImportance.normal => colors.primary,
      EventImportance.low => colors.outline,
    };
    final audience = MemberColorResolver.forEvent(event, memberLabels);
    return Material(
      color: audience.background,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  timeLabel,
                  maxLines: 1,
                  style: TextStyle(
                    color: audience.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (audience.kind == CalendarAudienceKind.multiple)
                Padding(
                  key: ValueKey('week-multiple-${event.id}'),
                  padding: const EdgeInsets.only(right: 5),
                  child: _ColorDots(colors: audience.indicatorColors),
                ),
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: audience.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
    ],
  );
}

String _weekday(int weekday) =>
    const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'][weekday - 1];

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dayId(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
