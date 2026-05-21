import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/task_provider.dart';
import '../theme/theme.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/category_group.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'GOALS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: kGoalsColor,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ref.watch(goalsTasksProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tasks) {
              if (tasks.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_outlined, size: 48, color: kTextMuted),
                      SizedBox(height: 12),
                      Text(
                        'No pressure. Just direction.',
                        style: TextStyle(color: kTextMuted, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: buildCategoryGroups(
                  tasks: tasks,
                  categories: categories,
                  currentBucket: 'goals',
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTaskSheet(context, ref, isGoal: true),
        backgroundColor: kGoalsColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
