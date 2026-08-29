import 'dart:async';

import 'package:flutter/material.dart';

import 'calendar_event.dart';
import 'calendar_repository.dart';
import 'event_editor.dart';
import 'reminder_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.store,
    this.disposeStore = false,
    this.reminders,
  });

  final CalendarRepository? store;
  final bool disposeStore;
  final ReminderService? reminders;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarRepository? _store;
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  DateTime _visibleMonth = DateUtils.dateOnly(DateTime.now());
  String? _error;
  bool _busy = false;
  int _calendarRevision = 0;
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$verb: ${notice.title}')));
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
        builder: (context) =>
            EventEditor(store: _store!, day: _day, event: event),
      ),
    );
    if (saved != null && mounted) {
      setState(() {
        _day = DateUtils.dateOnly(saved.start);
        _visibleMonth = DateTime(_day.year, _day.month);
      });
      _store?.selectDay(_day);
      final reminders = widget.reminders;
      if (reminders != null) {
        if (saved.reminderMinutesBefore != null) {
          final allowed = await reminders.requestPermission();
          if (!allowed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Termin gespeichert. Benachrichtigungen sind auf diesem Gerät nicht erlaubt.',
                ),
              ),
            );
          }
        }
        await reminders.schedule(saved, shared: _store!.isShared);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              event == null ? 'Termin wurde erstellt.' : 'Termin gespeichert.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termin löschen?'),
        content: Text(
          _store!.isShared
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Termin wurde gelöscht.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is CalendarFailure
                  ? error.message
                  : 'Löschen fehlgeschlagen. Bitte erneut versuchen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          TextButton(
            onPressed: () => setState(() {
              _day = DateUtils.dateOnly(DateTime.now());
              _visibleMonth = DateTime(_day.year, _day.month);
              _calendarRevision++;
              _store?.selectDay(_day);
            }),
            child: const Text('Heute'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: _store == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy || _store!.isLoading || _store!.syncError != null
                  ? null
                  : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Termin anlegen'),
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      Text(
                        'Mehr Zeit füreinander.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Euer gemeinsamer Alltag beginnt mit einem guten Überblick.',
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.group_outlined, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: const Text(
                                'Gemeinsamer Kalender · Alle Mitglieder können Termine bearbeiten. Uhrzeiten: Europe/Berlin, auch auf Reisen. Nur online verfügbar.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final calendar = Card(
                            child: _MonthCalendar(
                              key: ValueKey(_calendarRevision),
                              selectedDay: _day,
                              visibleMonth: _visibleMonth,
                              eventsOn: _store!.eventsOn,
                              onMonthChanged: (month) =>
                                  setState(() => _visibleMonth = month),
                              onDaySelected: (day) {
                                setState(() {
                                  _day = day;
                                  _visibleMonth = DateTime(day.year, day.month);
                                });
                                _store?.selectDay(day);
                              },
                            ),
                          );
                          final agenda = _agenda(context);
                          if (constraints.maxWidth >= 720) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: calendar),
                                const SizedBox(width: 24),
                                Expanded(child: agenda),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              calendar,
                              const SizedBox(height: 24),
                              agenda,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

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
              leading: Icon(
                event.importance == EventImportance.high
                    ? Icons.priority_high
                    : event.importance == EventImportance.low
                    ? Icons.low_priority
                    : Icons.event_outlined,
                color: _importanceColor(context, event.importance),
              ),
              subtitle: Text(
                '${TimeOfDay.fromDateTime(event.start).format(context)} – '
                '${TimeOfDay.fromDateTime(event.end).format(context)}'
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

  Color _importanceColor(BuildContext context, EventImportance importance) =>
      switch (importance) {
        EventImportance.high => Theme.of(context).colorScheme.error,
        EventImportance.normal => Theme.of(context).colorScheme.primary,
        EventImportance.low => Theme.of(context).colorScheme.outline,
      };
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    super.key,
    required this.selectedDay,
    required this.visibleMonth,
    required this.eventsOn,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final DateTime selectedDay;
  final DateTime visibleMonth;
  final List<CalendarEvent> Function(DateTime day) eventsOn;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: localizations.previousMonthTooltip,
                onPressed: () => onMonthChanged(
                  DateTime(visibleMonth.year, visibleMonth.month - 1),
                ),
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
                onPressed: () => onMonthChanged(
                  DateTime(visibleMonth.year, visibleMonth.month + 1),
                ),
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
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          for (var week = 0; week < 6; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: _dayCell(
                      context,
                      gridStart.add(Duration(days: week * 7 + weekday)),
                      colors,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime day, ColorScheme colors) {
    final events = eventsOn(day);
    final selected = DateUtils.isSameDay(day, selectedDay);
    final inMonth = day.month == visibleMonth.month;
    final importance =
        events.any((event) => event.importance == EventImportance.high)
        ? EventImportance.high
        : events.any((event) => event.importance == EventImportance.normal)
        ? EventImportance.normal
        : EventImportance.low;
    final markerColor = switch (importance) {
      EventImportance.high => colors.error,
      EventImportance.normal => colors.primary,
      EventImportance.low => colors.outline,
    };
    return Semantics(
      label:
          '${MaterialLocalizations.of(context).formatFullDate(day)}${events.isEmpty ? '' : ', ${events.length} Termine'}',
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => onDaySelected(DateUtils.dateOnly(day)),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 44,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : null,
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: inMonth ? null : colors.outline.withValues(alpha: 0.6),
                  fontWeight: selected ? FontWeight.bold : null,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 6,
                height: 6,
                child: events.isEmpty
                    ? null
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
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
