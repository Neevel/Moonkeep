import 'dart:async';

import 'package:flutter/material.dart';

import 'calendar_event.dart';
import 'calendar_repository.dart';
import 'event_editor.dart';
import 'member_color_resolver.dart';
import 'month_calendar_view.dart';
import 'reminder_service.dart';
import 'week_calendar_view.dart';

enum _CalendarViewMode { month, week }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.store,
    this.disposeStore = false,
    this.reminders,
    this.memberLabels = const {},
  });

  final CalendarRepository? store;
  final bool disposeStore;
  final ReminderService? reminders;
  final Map<String, String> memberLabels;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarRepository? _store;
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  DateTime _visibleMonth = DateUtils.dateOnly(DateTime.now());
  DateTime _visibleWeekStart = _startOfWeek(DateTime.now());
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  int _navigationDirection = 1;
  String? _error;
  bool _busy = false;
  StreamSubscription<CalendarNotice>? _noticeSubscription;
  final Map<String, int> _scheduledRevisions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    CalendarRepository? store;
    try {
      store = _store ?? widget.store;
      if (store == null) {
        throw const CalendarFailure('Kein gemeinsamer Kalender ausgewählt.');
      }
      store.removeListener(_refresh);
      await store.load();
      if (!mounted) {
        if (widget.store == null || widget.disposeStore) store.dispose();
        return;
      }
      store.addListener(_refresh);
      await _noticeSubscription?.cancel();
      _noticeSubscription = store.notices.listen(_showFamilyNotice);
      setState(() => _store = store);
      _syncReminders();
    } catch (_) {
      if (widget.store == null) store?.dispose();
      if (mounted) {
        setState(
          () => _error = 'Der gemeinsame Kalender konnte nicht geladen werden.',
        );
      }
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
      _syncReminders();
    }
  }

  void _showFamilyNotice(CalendarNotice notice) {
    if (!mounted) return;
    final verb = notice.kind == CalendarNoticeKind.created
        ? 'Neuer Familientermin'
        : 'Familientermin gelöscht';
    _showMessage('$verb: ${notice.title}');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectDay(DateTime day, {int? navigationDirection}) {
    final selected = DateUtils.dateOnly(day);
    setState(() {
      if (navigationDirection != null) {
        _navigationDirection = navigationDirection;
      }
      _day = selected;
      _visibleMonth = DateTime(selected.year, selected.month);
      _visibleWeekStart = _startOfWeek(selected);
    });
    _store?.selectDay(selected);
  }

  void _goToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    final targetPeriod = _viewMode == _CalendarViewMode.month
        ? today.year * 12 + today.month
        : _startOfWeek(today).millisecondsSinceEpoch;
    final currentPeriod = _viewMode == _CalendarViewMode.month
        ? _visibleMonth.year * 12 + _visibleMonth.month
        : _visibleWeekStart.millisecondsSinceEpoch;
    _selectDay(
      today,
      navigationDirection: targetPeriod >= currentPeriod ? 1 : -1,
    );
  }

  void _changeMonth(int offset) {
    final month = DateTime(_visibleMonth.year, _visibleMonth.month + offset);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final selectedDay = _day.day > lastDay ? lastDay : _day.day;
    _selectDay(
      DateTime(month.year, month.month, selectedDay),
      navigationDirection: offset,
    );
  }

  void _changeWeek(int offset) {
    _selectDay(
      _day.add(Duration(days: offset * 7)),
      navigationDirection: offset,
    );
  }

  void _syncReminders() {
    final store = _store;
    final reminders = widget.reminders;
    if (store == null || reminders == null) return;
    final ids = store.allEvents.map((event) => event.id).toSet();
    for (final removed
        in _scheduledRevisions.keys.where((id) => !ids.contains(id)).toList()) {
      _scheduledRevisions.remove(removed);
      unawaited(reminders.cancel(removed));
    }
    for (final event in store.allEvents) {
      if (_scheduledRevisions[event.id] == event.revision) continue;
      _scheduledRevisions[event.id] = event.revision;
      unawaited(reminders.schedule(event, shared: store.isShared));
    }
  }

  @override
  void dispose() {
    unawaited(_noticeSubscription?.cancel());
    _store?.removeListener(_refresh);
    if (widget.store == null || widget.disposeStore) {
      (widget.store ?? _store)?.dispose();
    }
    super.dispose();
  }

  Future<void> _edit([CalendarEvent? event]) async {
    final saved = await Navigator.of(context).push<CalendarEvent>(
      MaterialPageRoute(
        builder: (context) => EventEditor(
          store: _store!,
          day: _day,
          event: event,
          memberLabels: widget.memberLabels,
        ),
      ),
    );
    if (saved != null && mounted) {
      final isSeries =
          (event != null && event.recurrence != EventRecurrence.none) ||
          saved.recurrence != EventRecurrence.none;
      final success = isSeries
          ? event == null
                ? 'Terminserie erstellt.'
                : 'Terminserie gespeichert.'
          : event == null
          ? 'Termin erstellt.'
          : 'Termin gespeichert.';
      var feedback = success;
      setState(() {
        _day = DateUtils.dateOnly(saved.start);
        _visibleMonth = DateTime(_day.year, _day.month);
        _visibleWeekStart = _startOfWeek(_day);
      });
      _store?.selectDay(_day);
      final reminders = widget.reminders;
      if (reminders != null) {
        if (saved.reminderMinutesBefore != null) {
          final allowed = await reminders.requestPermission();
          if (!allowed && mounted) {
            feedback =
                '$success Erinnerungen sind auf diesem Gerät nicht erlaubt.';
          }
        }
        await reminders.schedule(saved, shared: _store!.isShared);
      }
      if (mounted) _showMessage(feedback);
    }
  }

  Future<void> _delete(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          event.recurrence == EventRecurrence.none
              ? 'Termin löschen?'
              : 'Terminserie löschen?',
        ),
        content: Text(
          event.recurrence != EventRecurrence.none
              ? '„${event.title}“ und alle Wiederholungen werden für alle Mitglieder gelöscht.'
              : _store!.isShared
              ? '„${event.title}“ wird für alle Familienmitglieder gelöscht.'
              : '„${event.title}“ wird von diesem Gerät gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _store!.delete(event.id, expectedRevision: event.revision);
      await widget.reminders?.cancel(event.id);
      if (mounted) {
        _showMessage(
          event.recurrence == EventRecurrence.none
              ? 'Termin gelöscht.'
              : 'Terminserie gelöscht.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is CalendarFailure
              ? error.message
              : 'Termin konnte nicht gelöscht werden. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.nightlight_round),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.store?.label ?? 'Moonkeep',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kalender verwalten',
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pushNamed('/family'),
            icon: const Icon(Icons.group_outlined),
          ),
          IconButton(
            tooltip: 'Mein Konto',
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pushNamed('/account'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          TextButton(onPressed: _goToday, child: const Text('Heute')),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: _store == null
          ? null
          : FloatingActionButton(
              key: const ValueKey('calendar-add-event'),
              tooltip: 'Termin anlegen',
              onPressed: _busy || _store!.isLoading || _store!.syncError != null
                  ? null
                  : () => _edit(),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ),
              )
            : _store == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: SegmentedButton<_CalendarViewMode>(
                          segments: const [
                            ButtonSegment(
                              value: _CalendarViewMode.month,
                              label: Text('Monat'),
                              icon: Icon(Icons.calendar_view_month_outlined),
                            ),
                            ButtonSegment(
                              value: _CalendarViewMode.week,
                              label: Text('Woche'),
                              icon: Icon(Icons.calendar_view_week_outlined),
                            ),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _navigationDirection = 1;
                              _viewMode = selection.single;
                              _visibleMonth = DateTime(_day.year, _day.month);
                              _visibleWeekStart = _startOfWeek(_day);
                            });
                          },
                        ),
                      ),
                      if (widget.memberLabels.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _memberLegend(),
                      ],
                      const SizedBox(height: 8),
                      _calendarAndAgenda(context),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _calendarAndAgenda(BuildContext context) {
    final Widget calendar;
    final String periodKey;
    if (_viewMode == _CalendarViewMode.month) {
      final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
      final gridStart = first.subtract(Duration(days: first.weekday - 1));
      calendar = MonthCalendarView(
        visibleMonth: _visibleMonth,
        selectedDay: _day,
        eventsByDay: _eventsByDay(gridStart, 42),
        memberLabels: widget.memberLabels,
        onPrevious: () => _changeMonth(-1),
        onNext: () => _changeMonth(1),
        onDaySelected: (day) {
          final current = _visibleMonth.year * 12 + _visibleMonth.month;
          final target = day.year * 12 + day.month;
          _selectDay(day, navigationDirection: target >= current ? 1 : -1);
        },
      );
      periodKey = 'month-${_visibleMonth.year}-${_visibleMonth.month}';
    } else {
      calendar = WeekCalendarView(
        weekStart: _visibleWeekStart,
        selectedDay: _day,
        eventsByDay: _eventsByDay(_visibleWeekStart, 7),
        memberLabels: widget.memberLabels,
        onPrevious: () => _changeWeek(-1),
        onNext: () => _changeWeek(1),
        onDaySelected: _selectDay,
        onEventSelected: (event, day) {
          _selectDay(day);
          _edit(event);
        },
      );
      periodKey =
          'week-${_visibleWeekStart.year}-${_visibleWeekStart.month}-${_visibleWeekStart.day}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(periodKey);
              final direction = _navigationDirection.toDouble();
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(incoming ? direction : -direction, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            child: KeyedSubtree(key: ValueKey(periodKey), child: calendar),
          ),
        ),
        const SizedBox(height: 20),
        _agenda(context),
      ],
    );
  }

  Map<DateTime, List<CalendarEvent>> _eventsByDay(DateTime start, int days) => {
    for (var index = 0; index < days; index++)
      _dateKey(start.add(Duration(days: index))): _store!.eventsOn(
        start.add(Duration(days: index)),
      ),
  };

  Widget _agenda(BuildContext context) {
    final events = _store!.eventsOn(_day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_store!.isLoading) const LinearProgressIndicator(),
        if (_store!.syncError != null) ...[
          Text(
            _store!.syncError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: () => _store!.selectDay(_day),
            child: const Text('Verbindung erneut prüfen'),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            MaterialLocalizations.of(context).formatFullDate(_day),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (events.isEmpty && !_store!.isLoading && _store!.syncError == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.wb_sunny_outlined, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Noch keine Termine',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Platz für das, was euch wichtig ist.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        for (final event in events)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              title: Text(event.title),
              leading: _AgendaAudienceMarker(
                key: ValueKey('agenda-audience-${event.id}'),
                audience: MemberColorResolver.forEvent(
                  event,
                  widget.memberLabels,
                ),
                importanceColor: _importanceColor(context, event.importance),
                icon: event.importance == EventImportance.high
                    ? Icons.priority_high
                    : event.importance == EventImportance.low
                    ? Icons.low_priority
                    : Icons.event_outlined,
              ),
              subtitle: Text(
                '${event.isAllDay ? 'Ganztägig' : '${TimeOfDay.fromDateTime(event.start).format(context)} – ${TimeOfDay.fromDateTime(event.end).format(context)}'}'
                '\nBetrifft: ${_assignmentLabel(event)}'
                '${event.recurrence == EventRecurrence.none ? '' : '\n${event.recurrence.label}${event.recurrenceEnd == null ? '' : ' bis ${MaterialLocalizations.of(context).formatShortDate(event.recurrenceEnd!)}'}'}'
                '${event.notes.isEmpty ? '' : '\n${event.notes}'}',
              ),
              onTap: _busy ? null : () => _edit(event),
              trailing: IconButton(
                tooltip: 'Termin löschen',
                onPressed: _busy ? null : () => _delete(event),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
      ],
    );
  }

  String _assignmentLabel(CalendarEvent event) {
    if (event.appliesToAllMembers) return 'Alle';
    final labels =
        event.assignedMemberIds
            .map((id) => widget.memberLabels[id] ?? 'Ehemaliges Mitglied')
            .toList()
          ..sort();
    return labels.join(', ');
  }

  Widget _memberLegend() {
    final entries = widget.memberLabels.entries.toList()
      ..sort(
        (a, b) =>
            _shortMemberLabel(a.value).compareTo(_shortMemberLabel(b.value)),
      );
    return SizedBox(
      height: 28,
      child: ListView(
        key: const ValueKey('member-color-legend'),
        scrollDirection: Axis.horizontal,
        children: [
          const _LegendItem(label: 'Alle', audience: MemberColorResolver.all),
          for (final entry in entries)
            _LegendItem(
              label: _shortMemberLabel(entry.value),
              audience: MemberColorResolver.forMemberId(entry.key),
            ),
        ],
      ),
    );
  }

  Color _importanceColor(BuildContext context, EventImportance importance) =>
      switch (importance) {
        EventImportance.high => Theme.of(context).colorScheme.error,
        EventImportance.normal => Theme.of(context).colorScheme.primary,
        EventImportance.low => Theme.of(context).colorScheme.outline,
      };
}

class _AgendaAudienceMarker extends StatelessWidget {
  const _AgendaAudienceMarker({
    super.key,
    required this.audience,
    required this.importanceColor,
    required this.icon,
  });

  final CalendarAudienceStyle audience;
  final Color importanceColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: audience.background,
      shape: BoxShape.circle,
      border: Border.all(color: importanceColor, width: 2),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: importanceColor, size: 21),
        if (audience.kind == CalendarAudienceKind.multiple)
          Positioned(
            bottom: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in audience.indicatorColors.take(3))
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.audience});

  final String label;
  final CalendarAudienceStyle audience;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Farbe für $label',
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: audience.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: audience.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: audience.foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

String _shortMemberLabel(String label) {
  final at = label.indexOf('@');
  return at > 0 ? label.substring(0, at) : label;
}

DateTime _startOfWeek(DateTime day) {
  final date = DateUtils.dateOnly(day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

DateTime _dateKey(DateTime day) => DateTime(day.year, day.month, day.day);
