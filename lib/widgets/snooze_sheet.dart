import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/firestore_service.dart';
import '../theme/theme.dart';

Future<void> showSnoozeSheet(
  BuildContext context,
  Task task,
  FirestoreService service,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ScheduleSheet(task: task, service: service, scaffoldCtx: context),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({
    required this.task,
    required this.service,
    required this.scaffoldCtx,
  });

  final Task task;
  final FirestoreService service;
  final BuildContext scaffoldCtx;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  TimeOfDay? _time;
  int? _durationMinutes;

  static const _timePicks = [
    ('Morning', TimeOfDay(hour: 9, minute: 0)),
    ('Noon', TimeOfDay(hour: 12, minute: 0)),
    ('Afternoon', TimeOfDay(hour: 14, minute: 0)),
    ('Evening', TimeOfDay(hour: 19, minute: 0)),
  ];

  static const _durations = [30, 60, 90, 120];

  static String _durLabel(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }

  static String _timeLabel(TimeOfDay t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  void initState() {
    super.initState();
    final st = widget.task.scheduledTime;
    if (st != null) {
      _time = TimeOfDay(hour: st.hour, minute: st.minute);
    }
    _durationMinutes = widget.task.durationMinutes;
  }

  Future<void> _defer(DateTime newDueDate, String message) async {
    await widget.service.deferTask(widget.task.id, newDueDate);
    if (mounted) Navigator.of(context).pop();
    if (widget.scaffoldCtx.mounted) {
      ScaffoldMessenger.of(widget.scaffoldCtx)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _saveTimeBlock() async {
    final t = _time;
    if (t == null) return;
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    await widget.service.updateTask(
      widget.task.copyWith(scheduledTime: base, durationMinutes: _durationMinutes),
    );
    if (mounted) Navigator.of(context).pop();
    if (widget.scaffoldCtx.mounted) {
      ScaffoldMessenger.of(widget.scaffoldCtx)
          .showSnackBar(const SnackBar(content: Text('Time block set')));
    }
  }

  Future<void> _removeDeadline() async {
    await widget.service.removeDeadline(widget.task.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clearTimeBlock() async {
    await widget.service.clearTimeBlock(widget.task.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDeadline() async {
    final ctx = widget.scaffoldCtx;
    Navigator.of(context).pop();
    final date = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    await widget.service.updateTask(widget.task.copyWith(deadline: date));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hasTimeBlock = widget.task.scheduledTime != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Snooze section ─────────────────────────────────────────────
            const Text(
              'SNOOZE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kTextMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            _SnoozeRow(
              label: 'Tomorrow',
              onTap: () => _defer(today.add(const Duration(days: 1)),
                  'Snoozed until tomorrow'),
            ),
            _SnoozeRow(
              label: 'In 2 days',
              onTap: () => _defer(today.add(const Duration(days: 2)),
                  'Snoozed for 2 days'),
            ),
            _SnoozeRow(
              label: 'Next week',
              onTap: () => _defer(today.add(const Duration(days: 7)),
                  'Snoozed until next week'),
            ),
            _SnoozeRow(
              icon: Icons.calendar_today_outlined,
              label: 'Set deadline',
              onTap: _pickDeadline,
            ),
            if (widget.task.deadline != null)
              _SnoozeRow(
                icon: Icons.cancel_outlined,
                iconColor: kTextMuted,
                label: 'Remove deadline',
                onTap: _removeDeadline,
              ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Block time section ──────────────────────────────────────────
            const Text(
              'BLOCK TIME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kTextMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),

            if (hasTimeBlock && _time == null)
              // Show existing block with clear option
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: kPrimary),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimeBlock(
                        widget.task.scheduledTime!, widget.task.durationMinutes),
                    style: const TextStyle(
                        color: kPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearTimeBlock,
                    child: const Text('Clear',
                        style: TextStyle(color: kTextMuted)),
                  ),
                ],
              )
            else ...[
              // Time quick-picks
              Wrap(
                spacing: 8,
                children: _timePicks.map((pick) {
                  final (label, tod) = pick;
                  final selected = _time?.hour == tod.hour &&
                      _time?.minute == tod.minute;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _time = selected ? null : tod),
                    selectedColor: kPrimary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: selected ? kPrimary : kTextMuted,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: selected ? kPrimary : Colors.transparent,
                    ),
                    backgroundColor: const Color(0xFFF2F2F7),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Duration chips
              Wrap(
                spacing: 8,
                children: _durations.map((d) {
                  final selected = _durationMinutes == d;
                  return ChoiceChip(
                    label: Text(_durLabel(d)),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _durationMinutes = selected ? null : d),
                    selectedColor: kPrimary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: selected ? kPrimary : kTextMuted,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: selected ? kPrimary : Colors.transparent,
                    ),
                    backgroundColor: const Color(0xFFF2F2F7),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_time != null)
                    Text(
                      '${_timeLabel(_time!)}${_durationMinutes != null ? ' · ${_durLabel(_durationMinutes!)}' : ''}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: kPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  if (hasTimeBlock)
                    TextButton(
                      onPressed: _clearTimeBlock,
                      child: const Text('Clear',
                          style: TextStyle(color: kTextMuted)),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _time != null ? _saveTimeBlock : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      disabledBackgroundColor: const Color(0xFFE0E0E0),
                    ),
                    child: const Text('Set block'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SnoozeRow extends StatelessWidget {
  const _SnoozeRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor = kPrimary,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: kTextDark),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

String _formatTimeBlock(DateTime time, int? duration) {
  final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
  final m = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  final timeStr = '$h:$m $period';
  if (duration == null) return timeStr;
  final d = duration < 60 ? '${duration}m' : '${duration ~/ 60}h${duration % 60 > 0 ? ' ${duration % 60}m' : ''}';
  return '$timeStr · $d';
}
