import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/task_provider.dart';
import '../theme/theme.dart';
import 'category_group.dart';

class TomorrowView extends ConsumerWidget {
  const TomorrowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    return ref.watch(tomorrowTasksProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (tasks) {
            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'Nothing for tomorrow',
                  style: TextStyle(color: kTextMuted),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: buildCategoryGroups(
                tasks: tasks,
                categories: categories,
                currentBucket: 'tomorrow',
              ),
            );
          },
        );
  }
}
