import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/task_service.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _indigo     = Color(0xFF3D5AFE);
const _textDark   = Color(0xFF1A1A2E);
const _textMuted  = Color(0xFF888888);
const _surface    = Color(0xFFF8F9FF);
const _nowColor   = Color(0xFFE53935);
const _soonColor  = Color(0xFFFB8C00);
const _laterColor = Color(0xFF43A047);

// ── Bucket metadata ───────────────────────────────────────────────────────────
const _bucketLabels = ['NOW', 'SOON', 'LATER'];
const _bucketKeys   = ['now', 'soon', 'later'];

Color _interpolateColor(double page) {
  final p = page.clamp(0.0, 2.0);
  if (p <= 1) return Color.lerp(_nowColor,  _soonColor,  p)!;
  return       Color.lerp(_soonColor, _laterColor, p - 1)!;
}

// ── Date helpers ─────────────────────────────────────────────────────────────
Future<DateTime?> _pickDate(BuildContext context) => showDatePicker(
  context: context,
  initialDate: DateTime.now(),
  firstDate: DateTime.now(),
  lastDate: DateTime.now().add(const Duration(days: 365)),
);

String _formatDeadline(DateTime deadline) {
  final today    = DateTime.now();
  final todayD   = DateTime(today.year, today.month, today.day);
  final tomorrow = todayD.add(const Duration(days: 1));
  final d        = DateTime(deadline.year, deadline.month, deadline.day);
  if (d == todayD)   return 'Today';
  if (d == tomorrow) return 'Tomorrow';
  return DateFormat('dd MMM').format(deadline);
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Add-task bottom sheet ──────────────────────────────────────────────────
  void _showAddTaskSheet(BuildContext context) {
    final bucket          = _bucketKeys[_currentPage];
    final titleController = TextEditingController();
    final bucketLabel     =
        _bucketLabels[_currentPage][0] +
        _bucketLabels[_currentPage].substring(1).toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        DateTime? selectedDeadline;
        return StatefulBuilder(
          builder: (_, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24, 24, 24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add to $bucketLabel',
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: const TextStyle(color: _textDark),
                    decoration: InputDecoration(
                      hintText: 'Task title',
                      hintStyle: const TextStyle(color: _textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
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
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _saveTask(
                      context: context,
                      sheetContext: sheetContext,
                      titleController: titleController,
                      bucket: bucket,
                      deadline: selectedDeadline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (selectedDeadline == null)
                    TextButton(
                      onPressed: () async {
                        final picked = await _pickDate(sheetContext);
                        if (picked != null) {
                          setSheetState(() => selectedDeadline = picked);
                        }
                      },
                      child: const Text(
                        'Set deadline',
                        style: TextStyle(color: _indigo),
                      ),
                    )
                  else
                    Row(children: [
                      Text(
                        _formatDeadline(selectedDeadline!),
                        style: const TextStyle(color: _indigo, fontSize: 13),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: _textMuted),
                        onPressed: () =>
                            setSheetState(() => selectedDeadline = null),
                      ),
                    ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _saveTask(
                        context: context,
                        sheetContext: sheetContext,
                        titleController: titleController,
                        bucket: bucket,
                        deadline: selectedDeadline,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveTask({
    required BuildContext context,
    required BuildContext sheetContext,
    required TextEditingController titleController,
    required String bucket,
    DateTime? deadline,
  }) async {
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      bucket: bucket,
      deadline: deadline,
      createdAt: DateTime.now(),
    );

    await ref.read(taskServiceProvider).addTask(task);
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task added')));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final taskService = ref.read(taskServiceProvider);

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (_, _) {
                  final page = _pageController.hasClients
                      ? (_pageController.page ?? _currentPage.toDouble())
                      : _currentPage.toDouble();
                  final color = _interpolateColor(page);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bucketLabels[_currentPage],
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(
                        height: 20,
                        child: _currentPage == 0
                            ? Text(
                                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                                style: const TextStyle(
                                  fontSize: 14, color: _textMuted,
                                ),
                              )
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── PageView ───────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _BucketPage(bucket: 'now',   taskService: taskService),
                  _BucketPage(bucket: 'soon',  taskService: taskService),
                  _BucketPage(bucket: 'later', taskService: taskService),
                ],
              ),
            ),

            // ── Bottom bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (v < -200 && _currentPage < 2) _goToPage(_currentPage + 1);
                        if (v > 200  && _currentPage > 0) _goToPage(_currentPage - 1);
                      },
                      child: SizedBox(
                        height: 24,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              height: 10,
                              width: double.infinity,
                              child: ColoredBox(
                                color: const Color(0xFFE0E0E0),
                                child: AnimatedBuilder(
                                  animation: _pageController,
                                  builder: (_, _) {
                                    final page = _pageController.hasClients
                                        ? (_pageController.page ??
                                            _currentPage.toDouble())
                                        : _currentPage.toDouble();
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: (page + 1) / 3,
                                        child: ColoredBox(
                                          color: _interpolateColor(page),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: () => _showAddTaskSheet(context),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BucketPage — shared task list for all three buckets
// ─────────────────────────────────────────────────────────────────────────────
class _BucketPage extends ConsumerWidget {
  const _BucketPage({required this.bucket, required this.taskService});

  final String      bucket;
  final TaskService taskService;

  String? get _nextBucket => switch (bucket) {
    'now'  => 'soon',
    'soon' => 'later',
    _      => null,
  };

  String? get _prevBucket => switch (bucket) {
    'later' => 'soon',
    'soon'  => 'now',
    _       => null,
  };

  ReorderableListView _buildList(List<Task> tasks) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      buildDefaultDragHandles: false,
      itemCount: tasks.length,
      itemBuilder: (_, index) => _TaskItem(
        key: ValueKey(tasks[index].id),
        task: tasks[index],
        taskService: taskService,
        nextBucket: _nextBucket,
        prevBucket: _prevBucket,
        index: index,
      ),
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final reordered = List<Task>.from(tasks);
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        for (var i = 0; i < reordered.length; i++) {
          taskService.updateTask(reordered[i].copyWith(manualOrder: i));
        }
      },
    );
  }

  Widget _buildSoonPreview(List<Task> soonTasks) {
    final preview  = soonTasks.take(3).toList();
    final overflow = soonTasks.length - preview.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // "SOON" header + faint rule
          Row(
            children: const [
              Text(
                'SOON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _soonColor,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Preview cards
          for (final task in preview) _buildPreviewCard(task),
          // Overflow indicator
          if (overflow > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'and $overflow more →',
                style: const TextStyle(fontSize: 12, color: _textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(Task task) {
    final deadline = task.deadline;
    final isOverdue = deadline != null && deadline.isBefore(DateTime.now());

    return Opacity(
      opacity: 0.8,
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _indigo,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _textDark,
                      ),
                    ),
                    if (deadline != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDeadline(deadline),
                        style: TextStyle(
                          fontSize: 11,
                          color: isOverdue ? Colors.red : _textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = switch (bucket) {
      'now'  => ref.watch(nowTasksProvider),
      'soon' => ref.watch(soonTasksProvider),
      _      => ref.watch(laterTasksProvider),
    };

    // Watched unconditionally but only used on the Now page.
    final soonTasks = bucket == 'now'
        ? (ref.watch(soonTasksProvider).valueOrNull ?? <Task>[])
        : <Task>[];

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        // Soon / Later pages — no preview needed.
        if (bucket != 'now') {
          if (tasks.isEmpty) {
            return const Center(
              child: Text('No tasks', style: TextStyle(color: _textMuted)),
            );
          }
          return _buildList(tasks);
        }

        // Now page — Column: scrollable list + fixed soon preview.
        return Column(
          children: [
            if (tasks.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    soonTasks.isEmpty ? 'No tasks' : 'Nothing due now',
                    style: const TextStyle(color: _textMuted),
                  ),
                ),
              )
            else
              Expanded(child: _buildList(tasks)),
            if (soonTasks.isNotEmpty) _buildSoonPreview(soonTasks),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TaskItem — card with chevrons, checkmark, drag handle; tap opens steps sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TaskItem extends StatefulWidget {
  const _TaskItem({
    super.key,
    required this.task,
    required this.taskService,
    required this.nextBucket,
    required this.prevBucket,
    required this.index,
  });

  final Task        task;
  final TaskService taskService;
  final String?     nextBucket;
  final String?     prevBucket;
  final int         index;

  @override
  State<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<_TaskItem> {
  late final TextEditingController _stepController;
  late final FocusNode             _stepFocusNode;

  @override
  void initState() {
    super.initState();
    _stepController = TextEditingController();
    _stepFocusNode  = FocusNode();
  }

  @override
  void dispose() {
    _stepController.dispose();
    _stepFocusNode.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _onDelete() {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    final task = widget.task;
    widget.taskService.deleteTask(task.id);
    messenger.showSnackBar(SnackBar(
      content: const Text('Deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => widget.taskService.addTask(task),
      ),
    ));
  }

  Future<void> _onComplete() async {
    HapticFeedback.lightImpact();
    await widget.taskService.updateTask(widget.task.copyWith(isComplete: true));
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) await widget.taskService.deleteTask(widget.task.id);
  }

  void _moveTask(String bucket) {
    HapticFeedback.lightImpact();
    widget.taskService.moveTask(widget.task.id, bucket);
    final label = bucket[0].toUpperCase() + bucket.substring(1);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Moved to $label')));
  }

  // ── Steps sheet ───────────────────────────────────────────────────────────
  void _showStepsSheet() {
    // Snapshot at open time; sheet manages its own local lists for
    // instant UI feedback without waiting for Firestore round-trips.
    var localSteps     = List<String>.from(widget.task.steps);
    var localCompleted = List<String>.from(widget.task.completedSteps);
    _stepController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (_, setSheetState) {
            final keyboard = MediaQuery.of(sheetContext).viewInsets.bottom;

            // Persists both lists to Firestore atomically.
            void save() => widget.taskService.updateTask(
                  widget.task.copyWith(
                    steps: List.from(localSteps),
                    completedSteps: List.from(localCompleted),
                  ),
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
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
                            color: _textDark,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _textMuted),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),

                // ── Progress ─────────────────────────────────────────────────
                if (localSteps.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                    child: Text(
                      '${localCompleted.length} of ${localSteps.length} steps done',
                      style: const TextStyle(fontSize: 14, color: _textMuted),
                    ),
                  ),

                const SizedBox(height: 12),
                const Divider(height: 1),

                // ── Steps list ───────────────────────────────────────────────
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      for (final step in localSteps)
                        Dismissible(
                          key: ValueKey(step),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            setSheetState(() {
                              localSteps.remove(step);
                              localCompleted.remove(step);
                            });
                            save();
                          },
                          background: Container(
                            color: Colors.red.shade400,
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                if (localCompleted.contains(step)) {
                                  localCompleted.remove(step);
                                } else {
                                  localCompleted.add(step);
                                }
                              });
                              save();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    localCompleted.contains(step)
                                        ? Icons.circle
                                        : Icons.circle_outlined,
                                    size: 24,
                                    color: localCompleted.contains(step)
                                        ? _indigo
                                        : _textMuted,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      step,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: localCompleted.contains(step)
                                            ? _textMuted
                                            : _textDark,
                                        decoration:
                                            localCompleted.contains(step)
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

                // ── Add step ─────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16, 12, 16, keyboard > 0 ? keyboard + 8 : 16,
                  ),
                  child: TextField(
                    controller: _stepController,
                    focusNode: _stepFocusNode,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16, color: _textDark),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Add a step...',
                      hintStyle:
                          const TextStyle(fontSize: 16, color: _textMuted),
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
                        _stepFocusNode.requestFocus();
                        return;
                      }
                      setSheetState(() => localSteps.add(trimmed));
                      _stepController.clear();
                      // Only steps changed — no need to touch completedSteps.
                      widget.taskService.updateTask(
                        widget.task.copyWith(steps: List.from(localSteps)),
                      );
                      _stepFocusNode.requestFocus();
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Long-press snooze sheet ────────────────────────────────────────────────
  void _onLongPress() {
    HapticFeedback.lightImpact();
    _showSnoozeSheet();
  }

  void _showSnoozeSheet() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Tomorrow'),
              onTap: () => _defer(
                sheetContext, today.add(const Duration(days: 1)),
                'Snoozed until tomorrow',
              ),
            ),
            ListTile(
              title: const Text('In 2 days'),
              onTap: () => _defer(
                sheetContext, today.add(const Duration(days: 2)),
                'Snoozed for 2 days',
              ),
            ),
            ListTile(
              title: const Text('Next week'),
              onTap: () => _defer(
                sheetContext, today.add(const Duration(days: 7)),
                'Snoozed until next week',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: _indigo),
              title: const Text('Set deadline'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final date = await _pickDate(context);
                if (date == null || !mounted) return;
                await widget.taskService
                    .updateTask(widget.task.copyWith(deadline: date));
              },
            ),
            if (widget.task.deadline != null)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: _textMuted),
                title: const Text('Remove deadline'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  await widget.taskService.removeDeadline(widget.task.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _defer(
    BuildContext sheetContext,
    DateTime newDueDate,
    String message,
  ) async {
    await widget.taskService.deferTask(widget.task.id, newDueDate);
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final task       = widget.task;
    final isComplete = task.isComplete;
    final deadline   = task.deadline;
    final isOverdue  = deadline != null && deadline.isBefore(DateTime.now());
    final doneCount  = task.completedSteps.length;
    final stepCount  = task.steps.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Dismissible(
        key: ValueKey(task.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _onDelete(),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Opacity(
          opacity: isComplete ? 0.4 : 1.0,
          child: Card(
            child: InkWell(
              onTap: _showStepsSheet,
              onLongPress: _onLongPress,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left chevron — move to prevBucket
                  if (widget.prevBucket != null)
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: _textMuted),
                      onPressed: () => _moveTask(widget.prevBucket!),
                    )
                  else
                    const SizedBox(width: 48),

                  // Task content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _textDark,
                            decoration: isComplete
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        if (deadline != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatDeadline(deadline),
                            style: TextStyle(
                              fontSize: 12,
                              color: isOverdue ? Colors.red : _textMuted,
                            ),
                          ),
                        ],
                        if (stepCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$doneCount/$stepCount steps',
                            style: const TextStyle(
                                fontSize: 11, color: _textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Right chevron — move to nextBucket
                  if (widget.nextBucket != null)
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: _textMuted),
                      onPressed: () => _moveTask(widget.nextBucket!),
                    ),

                  // Checkmark — complete
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline,
                        color: _textMuted),
                    onPressed: _onComplete,
                  ),

                  // Drag handle
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.drag_handle, color: _textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
