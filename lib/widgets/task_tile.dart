import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../theme/theme.dart';
import 'snooze_sheet.dart';
import 'steps_sheet.dart';

// Dot renders status; tap toggles yetToStart ↔ inProgress.
Widget _statusDot(TaskStatus status, Color catColor) {
  final (color, filled) = switch (status) {
    TaskStatus.inProgress => (catColor, true),
    TaskStatus.completed  => (catColor.withValues(alpha: 0.4), true),
    TaskStatus.moved      => (kTextMuted, false),
    _                     => (catColor, false), // yetToStart
  };
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: filled ? color : null,
      border: filled ? null : Border.all(color: color, width: 2),
      shape: BoxShape.circle,
    ),
  );
}

String _formatTimeBlock(DateTime time, int? duration) {
  final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
  final m = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  final timeStr = '$h:$m $period';
  if (duration == null) return timeStr;
  final d = duration < 60
      ? '${duration}m'
      : '${duration ~/ 60}h${duration % 60 > 0 ? ' ${duration % 60}m' : ''}';
  return '$timeStr · $d';
}

String _formatDeadline(DateTime deadline) {
  final today = DateTime.now();
  final todayD = DateTime(today.year, today.month, today.day);
  final tomorrow = todayD.add(const Duration(days: 1));
  final d = DateTime(deadline.year, deadline.month, deadline.day);
  if (d == todayD) return 'Today';
  if (d == tomorrow) return 'Tomorrow';
  return DateFormat('dd MMM').format(deadline);
}

class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.currentBucket,
    this.category,
  });

  final Task task;
  final String currentBucket;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(firestoreServiceProvider);
    final deadline = task.deadline;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isOverdue = deadline != null && deadline.isBefore(today);
    final isComplete = task.status == TaskStatus.completed;
    final stepCount = task.steps.length;
    final doneCount = task.completedStepCount;
    final catColor = category?.color ?? const Color(0xFF888888);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        final snapshot = task;
        service.deleteTask(snapshot.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => service.addTask(snapshot),
          ),
        ));
      },
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
        opacity: switch (task.status) {
          TaskStatus.completed => 0.45,
          TaskStatus.moved     => 0.78,
          _                   => 1.0,
        },
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showStepsSheet(context, task, service),
            onLongPress: () {
              HapticFeedback.lightImpact();
              showSnoozeSheet(context, task, service);
            },
            child: IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isOverdue)
                  Container(width: 4, color: Colors.red.shade400),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        isOverdue ? 10 : 14, 12, 4, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                  // Status dot — tap to toggle yetToStart ↔ inProgress
                  GestureDetector(
                    onTap: () {
                      if (task.status == TaskStatus.completed ||
                          task.status == TaskStatus.moved) { return; }
                      final next = task.status == TaskStatus.inProgress
                          ? TaskStatus.yetToStart
                          : TaskStatus.inProgress;
                      service.updateTask(task.copyWith(status: next));
                    },
                    child: _statusDot(task.status, catColor),
                  ),
                  const SizedBox(width: 12),

                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: task.status == TaskStatus.inProgress
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: kTextDark,
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
                              color: isOverdue ? Colors.red : kTextMuted,
                            ),
                          ),
                        ],
                        if (stepCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$doneCount/$stepCount steps',
                            style:
                                const TextStyle(fontSize: 11, color: kTextMuted),
                          ),
                        ],
                        if (task.scheduledTime != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatTimeBlock(
                                task.scheduledTime!, task.durationMinutes),
                            style: const TextStyle(
                              fontSize: 11,
                              color: kPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (task.status == TaskStatus.moved) ...[
                          const SizedBox(height: 2),
                          const Text(
                            '↑ carried forward',
                            style: TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Move to other bucket (not shown for goals)
                  if (currentBucket != 'goals')
                    IconButton(
                      icon: Icon(
                        currentBucket == 'today'
                            ? Icons.arrow_forward
                            : Icons.arrow_back,
                        size: 18,
                        color: kTextMuted,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final dest =
                            currentBucket == 'today' ? 'tomorrow' : 'today';
                        service.moveTask(task.id, dest);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Moved to ${dest == 'today' ? 'Today' : 'Tomorrow'}'),
                        ));
                      },
                      tooltip: currentBucket == 'today'
                          ? 'Move to Tomorrow'
                          : 'Move to Today',
                    ),

                  // Complete
                  IconButton(
                    icon: Icon(
                      isComplete
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: isComplete ? kPrimary : kTextMuted,
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await service.updateTask(
                          task.copyWith(status: TaskStatus.completed));
                      await Future<void>.delayed(
                          const Duration(milliseconds: 1200));
                      await service.deleteTask(task.id);
                    },
                  ),
                      ],
                    ),
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
