import 'package:flutter/material.dart' hide Step;

import '../models/step.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import '../theme/theme.dart';

void showStepsSheet(
  BuildContext context,
  Task task,
  FirestoreService service,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _StepsSheet(task: task, service: service),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _StepsSheet extends StatefulWidget {
  const _StepsSheet({required this.task, required this.service});

  final Task task;
  final FirestoreService service;

  @override
  State<_StepsSheet> createState() => _StepsSheetState();
}

class _StepsSheetState extends State<_StepsSheet> {
  late List<Step> _steps;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _steps = List<Step>.from(widget.task.steps);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() => widget.service.updateTask(
        widget.task.copyWith(steps: List<Step>.from(_steps)),
      );

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: kTextMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (_steps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Text(
                '${_steps.where((s) => s.isCompleted).length}'
                ' of ${_steps.length} steps done',
                style: const TextStyle(fontSize: 14, color: kTextMuted),
              ),
            ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Steps list
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final step in _steps)
                  Dismissible(
                    key: ValueKey(step.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      setState(() => _steps.removeWhere((s) => s.id == step.id));
                      _save();
                    },
                    background: Container(
                      color: Colors.red.shade400,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          final idx =
                              _steps.indexWhere((s) => s.id == step.id);
                          if (idx != -1) {
                            _steps[idx] =
                                step.copyWith(isCompleted: !step.isCompleted);
                          }
                        });
                        _save();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              step.isCompleted
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              size: 24,
                              color:
                                  step.isCompleted ? kPrimary : kTextMuted,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                step.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: step.isCompleted
                                      ? kTextMuted
                                      : kTextDark,
                                  decoration: step.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Add step input
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, keyboard > 0 ? keyboard + 8 : 16),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              style: const TextStyle(fontSize: 16, color: kTextDark),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Add a step...',
                hintStyle:
                    const TextStyle(fontSize: 16, color: kTextMuted),
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (text) {
                final trimmed = text.trim();
                if (trimmed.isEmpty) {
                  _focus.requestFocus();
                  return;
                }
                setState(() => _steps.add(Step.create(trimmed)));
                _ctrl.clear();
                _save();
                _focus.requestFocus();
              },
            ),
          ),
        ],
      ),
    );
  }
}
