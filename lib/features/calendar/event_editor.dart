import 'package:flutter/material.dart';

import 'calendar_event.dart';
import 'calendar_repository.dart';

class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    required this.store,
    required this.day,
    this.event,
    this.memberLabels = const {},
    this.initialAssignedMemberIds = const {},
  });

  final CalendarRepository store;
  final DateTime day;
  final CalendarEvent? event;
  final Map<String, String> memberLabels;
  final Set<String> initialAssignedMemberIds;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _day;
  late DateTime _endDay;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late EventImportance _importance;
  late ReminderOffset _reminderOffset;
  late bool _isAllDay;
  late EventRecurrence _recurrence;
  late DateTime? _recurrenceEnd;
  late Set<String> _assignedMemberIds;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _notes = TextEditingController(text: event?.notes ?? '');
    _day = event?.start ?? widget.day;
    _endDay = event?.end ?? _day;
    _start = event == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(event.start);
    _end = event == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay.fromDateTime(event.end);
    _importance = event?.importance ?? EventImportance.normal;
    _reminderOffset = event?.reminderOffset ?? ReminderOffset.none;
    _isAllDay = event?.isAllDay ?? false;
    _recurrence = event?.recurrence ?? EventRecurrence.none;
    _recurrenceEnd = event?.recurrenceEnd;
    _assignedMemberIds = {
      ...(event?.assignedMemberIds ?? widget.initialAssignedMemberIds),
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay time) => _atDay(_day, time);

  DateTime _atDay(DateTime day, TimeOfDay time) => widget.store.isShared
      ? DateTime.utc(day.year, day.month, day.day, time.hour, time.minute)
      : DateTime(day.year, day.month, day.day, time.hour, time.minute);

  bool get _isMultiDay => !isSameDay(_day, _endDay);

  Future<void> _chooseStartDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day != null && mounted) {
      setState(() {
        final wasSingleDay = !_isMultiDay;
        _day = day;
        if (_recurrence != EventRecurrence.none ||
            wasSingleDay ||
            _isBefore(_endDay, _day)) {
          _endDay = _day;
        }
      });
    }
  }

  Future<void> _chooseEndDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _isBefore(_endDay, _day) ? _day : _endDay,
      firstDate: DateTime(_day.year, _day.month, _day.day),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day != null && mounted) {
      setState(() {
        _endDay = day;
        if (_isMultiDay) {
          _recurrence = EventRecurrence.none;
          _recurrenceEnd = null;
        }
      });
    }
  }

  Future<void> _chooseTime(bool start) async {
    final time = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (time == null || !mounted) return;
    setState(() {
      if (start) {
        _start = time;
      } else {
        _end = time;
      }
    });
  }

  Future<void> _chooseRecurrenceEnd() async {
    final initial = _recurrenceEnd == null || _isBefore(_recurrenceEnd!, _day)
        ? _day
        : _recurrenceEnd!;
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(_day.year, _day.month, _day.day),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day == null || !mounted) return;
    setState(
      () => _recurrenceEnd = widget.store.isShared
          ? DateTime.utc(day.year, day.month, day.day)
          : DateTime(day.year, day.month, day.day),
    );
  }

  bool _isBefore(DateTime a, DateTime b) => DateTime.utc(
    a.year,
    a.month,
    a.day,
  ).isBefore(DateTime.utc(b.year, b.month, b.day));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isBefore(_endDay, _day)) {
      setState(
        () => _error = 'Das Enddatum darf nicht vor dem Startdatum liegen.',
      );
      return;
    }
    if (!_isAllDay &&
        isSameDay(_day, _endDay) &&
        !_atDay(_endDay, _end).isAfter(_at(_start))) {
      setState(() => _error = 'Das Ende muss nach dem Beginn liegen.');
      return;
    }
    if (_recurrence != EventRecurrence.none &&
        _recurrenceEnd != null &&
        _isBefore(_recurrenceEnd!, _day)) {
      setState(
        () =>
            _error = 'Das Wiederholungsende darf nicht vor dem Termin liegen.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var start = _at(_start);
      var end = _atDay(_endDay, _end);
      if (_isAllDay && !end.isAfter(start)) {
        start = _at(const TimeOfDay(hour: 9, minute: 0));
        end = _atDay(_endDay, const TimeOfDay(hour: 10, minute: 0));
      }
      final event = CalendarEvent(
        id: widget.event?.id ?? widget.store.newId(),
        title: _title.text,
        start: start,
        end: end,
        notes: _notes.text,
        revision: widget.event?.revision ?? 0,
        importance: _importance,
        reminderOffset: _isAllDay ? ReminderOffset.none : _reminderOffset,
        isAllDay: _isAllDay,
        recurrence: _recurrence,
        recurrenceEnd: _recurrence == EventRecurrence.none
            ? null
            : _recurrenceEnd,
        assignedMemberIds: _assignedMemberIds,
      );
      await widget.store.save(event);
      if (mounted) Navigator.of(context).pop(event);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is CalendarFailure ? error.message : 'Termin konnte nicht gespeichert werden. Bitte erneut versuchen.';
        });
      }
    }
  }

  String _assignmentLabel() {
    if (_assignedMemberIds.isEmpty) return 'Alle';
    final labels =
        _assignedMemberIds
            .map((id) => widget.memberLabels[id] ?? 'Ehemaliges Mitglied')
            .toList()
          ..sort();
    return labels.join(', ');
  }

  Widget _assignmentEditor() {
    final members = widget.memberLabels.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final unknownIds = _assignedMemberIds
        .where((id) => !widget.memberLabels.containsKey(id))
        .toList();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      leading: const Icon(Icons.group_outlined),
      title: const Text('Betrifft'),
      subtitle: Text(_assignmentLabel()),
      children: [
        CheckboxListTile(
          key: const ValueKey('assignment-all'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Alle'),
          value: _assignedMemberIds.isEmpty,
          onChanged: _busy
              ? null
              : (_) => setState(() => _assignedMemberIds.clear()),
        ),
        for (final member in members)
          CheckboxListTile(
            key: ValueKey('assignment-${member.key}'),
            contentPadding: EdgeInsets.zero,
            title: Text(member.value),
            value: _assignedMemberIds.contains(member.key),
            onChanged: _busy
                ? null
                : (selected) => setState(() {
                    if (selected == true) {
                      _assignedMemberIds.add(member.key);
                    } else {
                      _assignedMemberIds.remove(member.key);
                    }
                  }),
          ),
        for (final id in unknownIds)
          CheckboxListTile(
            key: ValueKey('assignment-unknown-$id'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Ehemaliges Mitglied'),
            value: true,
            onChanged: null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null
              ? 'Neuer Termin'
              : widget.event!.recurrence == EventRecurrence.none
              ? 'Termin bearbeiten'
              : 'Serie bearbeiten',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              children: [
                if (widget.store.isShared)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Gemeinsamer Kalender · Uhrzeiten in Europe/Berlin. Änderungen werden für alle Mitglieder gespeichert.',
                    ),
                  ),
                if (widget.event?.recurrence != null &&
                    widget.event!.recurrence != EventRecurrence.none)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Änderungen gelten für die gesamte Terminserie.',
                    ),
                  ),
                TextFormField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Titel'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte einen Titel eingeben.'
                      : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('event-start-date'),
                  onPressed: _busy ? null : _chooseStartDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    'Start: ${MaterialLocalizations.of(context).formatFullDate(_day)}',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('event-end-date'),
                  onPressed: _busy || _recurrence != EventRecurrence.none
                      ? null
                      : _chooseEndDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    'Ende: ${MaterialLocalizations.of(context).formatFullDate(_endDay)}',
                  ),
                ),
                if (_recurrence != EventRecurrence.none)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Wiederkehrende Termine sind derzeit auf einen Tag begrenzt.',
                    ),
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ganztägig'),
                  value: _isAllDay,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _isAllDay = value;
                          if (value) _reminderOffset = ReminderOffset.none;
                        }),
                ),
                if (!_isAllDay)
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        key: const ValueKey('event-start-time'),
                        onPressed: _busy ? null : () => _chooseTime(true),
                        child: Text('Beginn: ${_start.format(context)}'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('event-end-time'),
                        onPressed: _busy ? null : () => _chooseTime(false),
                        child: Text('Ende: ${_end.format(context)}'),
                      ),
                    ],
                  ),
                if (widget.memberLabels.isNotEmpty ||
                    _assignedMemberIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _assignmentEditor(),
                ],
                const SizedBox(height: 24),
                DropdownButtonFormField<EventImportance>(
                  isExpanded: true,
                  initialValue: _importance,
                  decoration: const InputDecoration(
                    labelText: 'Wichtigkeit',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: [
                    for (final importance in EventImportance.values)
                      DropdownMenuItem(
                        value: importance,
                        child: Text(importance.label),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(
                          () => _importance = value ?? EventImportance.normal,
                        ),
                ),
                const SizedBox(height: 16),
                if (!_isAllDay)
                  DropdownButtonFormField<ReminderOffset>(
                    isExpanded: true,
                    initialValue: _reminderOffset,
                    decoration: const InputDecoration(
                      labelText: 'Erinnerung',
                      prefixIcon: Icon(Icons.notifications_outlined),
                    ),
                    items: [
                      for (final offset in {
                        ...ReminderOffset.editorValues,
                        if (_reminderOffset == ReminderOffset.legacyMinutes10)
                          ReminderOffset.legacyMinutes10,
                      })
                        DropdownMenuItem(
                          value: offset,
                          child: Text(offset.label),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(
                            () =>
                                _reminderOffset = value ?? ReminderOffset.none,
                          ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Wiederholen',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<EventRecurrence>(
                  isExpanded: true,
                  initialValue: _recurrence,
                  decoration: const InputDecoration(
                    labelText: 'Wiederholung',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: [
                    for (final recurrence in EventRecurrence.values)
                      DropdownMenuItem(
                        value: recurrence,
                        child: Text(recurrence.label),
                      ),
                  ],
                  onChanged: _busy || _isMultiDay
                      ? null
                      : (value) => setState(() {
                          _recurrence = value ?? EventRecurrence.none;
                          if (_recurrence != EventRecurrence.none) {
                            _endDay = _day;
                          }
                          if (_recurrence == EventRecurrence.none) {
                            _recurrenceEnd = null;
                          }
                        }),
                ),
                if (_isMultiDay)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Mehrtagestermine können derzeit nicht wiederholt werden.',
                    ),
                  ),
                if (_recurrence != EventRecurrence.none) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _chooseRecurrenceEnd,
                    icon: const Icon(Icons.event_busy_outlined),
                    label: Text(
                      _recurrenceEnd == null
                          ? 'Kein Enddatum'
                          : 'Endet am ${MaterialLocalizations.of(context).formatFullDate(_recurrenceEnd!)}',
                    ),
                  ),
                  if (_recurrenceEnd != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _recurrenceEnd = null),
                      child: const Text('Enddatum entfernen'),
                    ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _notes,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Notizen (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_busy ? 'Wird gespeichert …' : 'Speichern'),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      ),
    ),
  );
}
