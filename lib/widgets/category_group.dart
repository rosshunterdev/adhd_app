import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/task.dart';
import 'task_tile.dart';

class CategoryGroup extends StatelessWidget {
  const CategoryGroup({
    super.key,
    required this.category,
    required this.tasks,
    required this.currentBucket,
  });

  final Category? category;
  final List<Task> tasks;
  final String currentBucket;

  @override
  Widget build(BuildContext context) {
    final color = category?.color ?? const Color(0xFF888888);
    final name = (category?.name ?? 'Uncategorised').toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: color.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${tasks.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),

        // Task tiles
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final task in tasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TaskTile(
                    key: ValueKey(task.id),
                    task: task,
                    currentBucket: currentBucket,
                    category: category,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

List<Widget> buildCategoryGroups({
  required List<Task> tasks,
  required List<Category> categories,
  required String currentBucket,
}) {
  final grouped = <String, List<Task>>{};
  for (final task in tasks) {
    grouped.putIfAbsent(task.categoryId, () => []).add(task);
  }

  final result = <Widget>[];

  // Named category groups in order
  for (final cat in categories) {
    final catTasks = grouped[cat.id];
    if (catTasks != null && catTasks.isNotEmpty) {
      result.add(CategoryGroup(
        category: cat,
        tasks: catTasks,
        currentBucket: currentBucket,
      ));
    }
  }

  // Uncategorised group last
  final knownIds = categories.map((c) => c.id).toSet();
  final uncategorised = tasks
      .where((t) => !knownIds.contains(t.categoryId))
      .toList();
  if (uncategorised.isNotEmpty) {
    result.add(CategoryGroup(
      category: null,
      tasks: uncategorised,
      currentBucket: currentBucket,
    ));
  }

  return result;
}
