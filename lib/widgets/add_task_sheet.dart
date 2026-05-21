import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/theme.dart';

/// Opens the quick-add sheet. Pass [initialBucket] to pre-select Today/Tomorrow.
/// Pass [isGoal] to create a goal (hides bucket toggle, sets bucket: 'goals').
void showAddTaskSheet(
  BuildContext context,
  WidgetRef ref, {
  String initialBucket = 'today',
  bool isGoal = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddTaskSheet(
      initialBucket: isGoal ? 'goals' : initialBucket,
      isGoal: isGoal,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet({
    required this.initialBucket,
    this.isGoal = false,
  });

  final String initialBucket;
  final bool isGoal;

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  late final TextEditingController _titleCtrl;
  late String _bucket;
  String? _categoryId;
  DateTime? _deadline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _bucket = widget.initialBucket;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final task = Task(
      id: Task.newId(),
      userId: uid,
      title: title,
      bucket: _bucket,
      categoryId: _categoryId ?? (categories.isNotEmpty ? categories.first.id : 'life'),
      isGoal: widget.isGoal,
      deadline: _deadline,
      createdAt: DateTime.now(),
    );

    await ref.read(firestoreServiceProvider).addTask(task);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task added')));
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Today';
    if (date == tomorrow) return 'Tomorrow';
    return '${d.day} ${_months[d.month - 1]}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    // Auto-select first category if none selected yet
    if (_categoryId == null && categories.isNotEmpty) {
      Future.microtask(() => setState(() => _categoryId = categories.first.id));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, keyboard + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: label + bucket toggle ──────────────────────────
          Row(
            children: [
              Text(
                widget.isGoal ? 'Add goal' : 'Add task',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              const Spacer(),
              if (!widget.isGoal)
                _BucketToggle(
                  selected: _bucket,
                  onSelect: (b) => setState(() => _bucket = b),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Title input ────────────────────────────────────────────────
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 16, color: kTextDark),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'What needs doing?',
              hintStyle: const TextStyle(color: kTextMuted),
              filled: true,
              fillColor: const Color(0xFFF2F2F7),
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
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // ── Category chips ─────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: categories.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final selected = cat.id == _categoryId;
                      final color = cat.color;
                      return GestureDetector(
                        onTap: () => setState(() => _categoryId = cat.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.12)
                                : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? color : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? color : kTextMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          // ── Deadline (optional) ────────────────────────────────────────
          if (_deadline == null)
            TextButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.calendar_today_outlined,
                  size: 16, color: kPrimary),
              label: const Text(
                'Set deadline',
                style: TextStyle(color: kPrimary, fontSize: 14),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDate(_deadline!),
                    style: const TextStyle(
                        fontSize: 13, color: kPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _deadline = null),
                  child: const Icon(Icons.close, size: 16, color: kTextMuted),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // ── Save ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bucket toggle ──────────────────────────────────────────────────────────────

class _BucketToggle extends StatelessWidget {
  const _BucketToggle({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8EE),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(label: 'Today', value: 'today', selected: selected,
              onSelect: onSelect),
          _Pill(label: 'Tmrw', value: 'tomorrow', selected: selected,
              onSelect: onSelect),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final accent = value == 'today' ? kTodayColor : kTomorrowColor;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? accent : kTextMuted,
          ),
        ),
      ),
    );
  }
}
