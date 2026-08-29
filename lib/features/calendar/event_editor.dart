import 'package:flutter/material.dart';

import 'calendar_event.dart';
import 'calendar_repository.dart';

class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    required this.store,
    required this.day,
    this.event,
  });

  final CalendarRepository store;
  final DateTime day;
  final CalendarEvent? event;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late EventImportance _importance;
  late int? _reminderMinutesBefore;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _notes = TextEditingController(text: event?.notes ?? '');
    _day = event?.start ?? widget.day;
    _start = event == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(event.start);
    _end = event == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay.fromDateTime(event.end);
    _importance = event?.importance ?? EventImportance.normal;
    _reminderMinutesBefore = event?.reminderMinutesBefore;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay time) => widget.store.isShared
      ? DateTime.utc(_day.year, _day.month, _day.day, time.hour, time.minute)
      : DateTime(_day.year, _day.month, _day.day, time.hour, time.minute);

  Future<void> _chooseDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day != null && mounted) setState(() => _day = day);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_at(_end).isAfter(_at(_start))) {
      setState(() => _error = 'Das Ende muss nach dem Beginn liegen.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final event = CalendarEvent(
        id: widget.event?.id ?? widget.store.newId(),
        title: _title.text,
        start: _at(_start),
        end: _at(_end),
        notes: _notes.text,
        revision: widget.event?.revision ?? 0,
        importance: _importance,
        reminderMinutesBefore: _reminderMinutesBefore,
      );
      await widget.store.save(event);
      if (mounted) Navigator.of(context).pop(event);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is CalendarFailure
              ? error.message
              : 'Speichern fehlgeschlagen. Bitte erneut versuchen.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null ? 'Neuer Termin' : 'Termin bearbeiten',
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
                  onPressed: _busy ? null : _chooseDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    MaterialLocalizations.of(context).formatFullDate(_day),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _busy ? null : () => _chooseTime(true),
                      child: Text('Beginn: ${_start.format(context)}'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _chooseTime(false),
                      child: Text('Ende: ${_end.format(context)}'),
                    ),
                  ],
                ),
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
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: _reminderMinutesBefore,
                  decoration: const InputDecoration(
                    labelText: 'Erinnerung',
                    prefixIcon: Icon(Icons.notifications_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Keine')),
                    DropdownMenuItem(value: 0, child: Text('Zum Terminbeginn')),
                    DropdownMenuItem(
                      value: 10,
                      child: Text('10 Minuten vorher'),
                    ),
                    DropdownMenuItem(
                      value: 30,
                      child: Text('30 Minuten vorher'),
                    ),
                    DropdownMenuItem(value: 60, child: Text('1 Stunde vorher')),
                    DropdownMenuItem(value: 1440, child: Text('1 Tag vorher')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _reminderMinutesBefore = value),
                ),
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
