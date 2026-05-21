# User-Defined Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded `TaskCategory` enum with Firestore-backed user-editable categories, including a full management screen.

**Architecture:** A flat `categories` Firestore collection (same pattern as `tasks`) replaces the enum. Tasks store `categoryId: String` instead of `category: TaskCategory`. Default categories are seeded on first launch using the old enum names as IDs, giving zero-downtime migration for existing tasks.

**Tech Stack:** Flutter, Dart 3, Cloud Firestore, Riverpod 2, flutter_local_notifications (unchanged)

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Rewrite | `lib/models/category.dart` | `Category` class (id, userId, name, colorHex, order) + color getter |
| Modify | `lib/models/task.dart` | `categoryId: String` replaces `category: TaskCategory` |
| Modify | `lib/services/firestore_service.dart` | `categoriesStream`, `addCategory`, `updateCategory`, `deleteCategory`, `reorderCategories` |
| Create | `lib/services/category_service.dart` | `seedIfNeeded(uid)` — seeds 8 defaults if user has no categories |
| Modify | `lib/providers/task_provider.dart` | Add `categoriesProvider` StreamProvider |
| Modify | `lib/main.dart` | Call `CategoryService().seedIfNeeded(uid)` after auth |
| Modify | `lib/widgets/category_group.dart` | Accept `Category?` (null = uncategorised); add `buildCategoryGroups()` helper |
| Modify | `lib/widgets/task_tile.dart` | Accept `Category?` param; derive colour from it |
| Modify | `lib/widgets/today_view.dart` | Watch categoriesProvider; use `buildCategoryGroups()` |
| Modify | `lib/widgets/tomorrow_view.dart` | Same as TodayView |
| Modify | `lib/screens/goals_screen.dart` | Same as TodayView |
| Modify | `lib/widgets/add_task_sheet.dart` | `ConsumerStatefulWidget`; chips from `categoriesProvider` |
| Create | `lib/screens/categories_screen.dart` | ReorderableListView of categories; add/rename/recolour/delete |
| Modify | `lib/screens/home_screen.dart` | `tune` icon in header → `CategoriesScreen` |
| Modify | `lib/theme/theme.dart` | Remove `kCategoryColors` map and `categoryColor()` helper |
| Firebase Console | Firestore rules | Add `categories/{categoryId}` rule |

---

## Task 1: Rewrite Category model

**Files:**
- Rewrite: `lib/models/category.dart`

- [ ] **Step 1: Replace the file contents**

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String userId;
  final String name;
  final String colorHex; // e.g. "#5B8FBF"
  final int order;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorHex,
    required this.order,
  });

  Color get color =>
      Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

  static String newId() => const Uuid().v4();

  Category copyWith({
    String? name,
    String? colorHex,
    int? order,
  }) =>
      Category(
        id: id,
        userId: userId,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
        order: order ?? this.order,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'colorHex': colorHex,
        'order': order,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        colorHex: map['colorHex'] as String,
        order: map['order'] as int? ?? 0,
      );
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: errors about `TaskCategory` usages elsewhere — that's fine, subsequent tasks fix them.

---

## Task 2: Update Task model

**Files:**
- Modify: `lib/models/task.dart`

- [ ] **Step 1: Remove `TaskCategory` import and field; add `categoryId`**

Replace the import line:
```dart
import 'category.dart';
```
with nothing — `category.dart` no longer exports `TaskCategory`.

Remove from the class fields:
```dart
final TaskCategory category;
```

Add in its place:
```dart
final String categoryId;
```

- [ ] **Step 2: Update constructor**

Remove:
```dart
this.category = TaskCategory.life,
```
Add:
```dart
this.categoryId = 'life',
```

- [ ] **Step 3: Update `copyWith`**

Remove parameter:
```dart
TaskCategory? category,
```
Add:
```dart
String? categoryId,
```

Remove from return:
```dart
category: category ?? this.category,
```
Add:
```dart
categoryId: categoryId ?? this.categoryId,
```

- [ ] **Step 4: Update `toMap`**

Remove:
```dart
'category': category.name,
```
Add:
```dart
'categoryId': categoryId,
```

- [ ] **Step 5: Update `fromMap`**

Remove:
```dart
category: TaskCategoryX.fromString(map['category'] as String? ?? 'life'),
```
Add (falls back to old `category` field for existing tasks — zero-downtime migration):
```dart
categoryId: map['categoryId'] as String? ?? map['category'] as String? ?? 'life',
```

- [ ] **Step 6: Remove the `TaskCategory` enum and extension from `task.dart`**

Delete these lines entirely (the enum and extension were defined in `category.dart` — confirm they're not duplicated in `task.dart`; if they were moved there, delete them now).

- [ ] **Step 7: Verify**

Run: `flutter analyze`
Expected: errors in widgets that reference `task.category` or `TaskCategory` — fixed in later tasks.

---

## Task 3: Update FirestoreService

**Files:**
- Modify: `lib/services/firestore_service.dart`

- [ ] **Step 1: Add categories collection reference**

Add after the existing `_col` field:
```dart
final CollectionReference _cats =
    FirebaseFirestore.instance.collection('categories');
```

- [ ] **Step 2: Add `categoriesStream`**

Add after `goalsStream`:
```dart
Stream<List<Category>> get categoriesStream => _cats
    .where('userId', isEqualTo: uid)
    .orderBy('order')
    .snapshots()
    .map((snap) => snap.docs
        .map((d) => Category.fromMap(d.data() as Map<String, dynamic>))
        .toList());
```

- [ ] **Step 3: Add category CRUD methods**

Add at the bottom of the class (before the closing `}`):
```dart
Future<void> addCategory(Category category) async {
  await _cats.doc(category.id).set(category.toMap());
}

Future<void> updateCategory(Category category) async {
  await _cats.doc(category.id).update(category.toMap());
}

Future<void> deleteCategory(String id) async {
  await _cats.doc(id).delete();
}

Future<void> reorderCategories(
    List<Category> current, int oldIndex, int newIndex) async {
  final reordered = [...current];
  final item = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, item);

  final batch = FirebaseFirestore.instance.batch();
  for (var i = 0; i < reordered.length; i++) {
    batch.update(_cats.doc(reordered[i].id), {'order': i});
  }
  await batch.commit();
}
```

- [ ] **Step 4: Add `Category` import at the top of the file**

```dart
import '../models/category.dart';
```

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: errors elsewhere about missing categoryId — fixed in later tasks.

---

## Task 4: Add CategoryService (seeding)

**Files:**
- Create: `lib/services/category_service.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';

class CategoryService {
  final _cats = FirebaseFirestore.instance.collection('categories');

  static const _defaults = [
    (id: 'webDev',  name: 'Web Dev', colorHex: '#5B8FBF', order: 0),
    (id: 'appDev',  name: 'App Dev', colorHex: '#9060BF', order: 1),
    (id: 'study',   name: 'Study',   colorHex: '#C49A45', order: 2),
    (id: 'work',    name: 'Work',    colorHex: '#BF6060', order: 3),
    (id: 'admin',   name: 'Admin',   colorHex: '#7A8A96', order: 4),
    (id: 'life',    name: 'Life',    colorHex: '#5B9E6E', order: 5),
    (id: 'music',   name: 'Music',   colorHex: '#BF7EA0', order: 6),
    (id: 'goals',   name: 'Goals',   colorHex: '#5BA8A0', order: 7),
  ];

  Future<void> seedIfNeeded(String uid) async {
    final snap =
        await _cats.where('userId', isEqualTo: uid).limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in _defaults) {
      final cat = Category(
        id: d.id,
        userId: uid,
        name: d.name,
        colorHex: d.colorHex,
        order: d.order,
      );
      batch.set(_cats.doc(cat.id), cat.toMap());
    }
    await batch.commit();
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: no new errors from this file.

---

## Task 5: Update providers

**Files:**
- Modify: `lib/providers/task_provider.dart`

- [ ] **Step 1: Add `Category` import**

```dart
import '../models/category.dart';
```

- [ ] **Step 2: Add `categoriesProvider`**

Add after `goalsTasksProvider`:
```dart
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(firestoreServiceProvider).categoriesStream;
});
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: no new errors.

---

## Task 6: Update main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import**

```dart
import 'services/category_service.dart';
```

- [ ] **Step 2: Call seeding after auth**

The current sequence in `main()`:
```dart
final uid = await AuthService().signInAnonymously();
await CarryForwardService().runIfNeeded(uid);
```

Change to:
```dart
final uid = await AuthService().signInAnonymously();
await CategoryService().seedIfNeeded(uid);
await CarryForwardService().runIfNeeded(uid);
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: no new errors.

---

## Task 7: Update CategoryGroup widget

**Files:**
- Modify: `lib/widgets/category_group.dart`

- [ ] **Step 1: Read the current file to understand its full contents before editing**

Read `lib/widgets/category_group.dart`.

- [ ] **Step 2: Replace the full file**

The widget now takes `Category?` instead of `TaskCategory`. A `buildCategoryGroups()` helper is added at the bottom. Replace the entire file:

```dart
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../theme/theme.dart';
import 'task_tile.dart';

class CategoryGroup extends StatelessWidget {
  const CategoryGroup({
    super.key,
    required this.category,
    required this.tasks,
    required this.currentBucket,
  });

  /// null means "Uncategorised" (tasks whose category was deleted).
  final Category? category;
  final List<Task> tasks;
  final String currentBucket;

  @override
  Widget build(BuildContext context) {
    final color = category?.color ?? kTextMuted;
    final name = category?.name ?? 'Uncategorised';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
              const SizedBox(width: 8),
              Text(
                '${tasks.length}',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ),
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TaskTile(
              task: task,
              category: category,
              currentBucket: currentBucket,
            ),
          ),
      ],
    );
  }
}

/// Groups [tasks] by categoryId and returns CategoryGroup widgets.
/// Categories with no matching tasks are omitted.
/// Tasks with unknown categoryIds appear in a grey "Uncategorised" group last.
List<Widget> buildCategoryGroups({
  required List<Task> tasks,
  required List<Category> categories,
  required String currentBucket,
}) {
  final grouped = <String, List<Task>>{};
  for (final task in tasks) {
    grouped.putIfAbsent(task.categoryId, () => []).add(task);
  }

  final widgets = <Widget>[];
  final knownIds = categories.map((c) => c.id).toSet();

  // Known categories in order
  final sorted = [...categories]..sort((a, b) => a.order.compareTo(b.order));
  for (final cat in sorted) {
    if (grouped.containsKey(cat.id)) {
      widgets.add(CategoryGroup(
        key: ValueKey(cat.id),
        category: cat,
        tasks: grouped[cat.id]!,
        currentBucket: currentBucket,
      ));
    }
  }

  // Uncategorised (deleted category)
  final uncategorised =
      tasks.where((t) => !knownIds.contains(t.categoryId)).toList();
  if (uncategorised.isNotEmpty) {
    widgets.add(CategoryGroup(
      key: const ValueKey('uncategorised'),
      category: null,
      tasks: uncategorised,
      currentBucket: currentBucket,
    ));
  }

  return widgets;
}
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: errors in task_tile.dart about missing `category` param — fixed next.

---

## Task 8: Update TaskTile

**Files:**
- Modify: `lib/widgets/task_tile.dart`

- [ ] **Step 1: Add `Category` import**

```dart
import '../models/category.dart';
```

- [ ] **Step 2: Add `category` parameter to `TaskTile`**

Change the constructor from:
```dart
const TaskTile({
  super.key,
  required this.task,
  required this.currentBucket,
});

final Task task;
final String currentBucket;
```
To:
```dart
const TaskTile({
  super.key,
  required this.task,
  required this.category,
  required this.currentBucket,
});

final Task task;
final Category? category;
final String currentBucket;
```

- [ ] **Step 3: Replace `categoryColor(task.category)` with `category?.color`**

Find:
```dart
final catColor = categoryColor(task.category);
```
Replace with:
```dart
final catColor = category?.color ?? kTextMuted;
```

- [ ] **Step 4: Remove unused import of `category.dart` (the old enum version)**

The old import was `import '../models/category.dart';` — it stays but now imports the new `Category` class. No change needed here; the import is already correct.

- [ ] **Step 5: Verify**

Run: `flutter analyze`
Expected: errors in the views about `_groupByCategory` using old enum — fixed next.

---

## Task 9: Update TodayView, TomorrowView, GoalsScreen

**Files:**
- Modify: `lib/widgets/today_view.dart`
- Modify: `lib/widgets/tomorrow_view.dart`
- Modify: `lib/screens/goals_screen.dart`

- [ ] **Step 1: Replace `lib/widgets/today_view.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/task_provider.dart';
import '../theme/theme.dart';
import 'category_group.dart';

class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(todayTasksProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (tasks) {
            final categories =
                ref.watch(categoriesProvider).valueOrNull ?? [];

            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'Nothing for today',
                  style: TextStyle(color: kTextMuted),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: buildCategoryGroups(
                tasks: tasks,
                categories: categories,
                currentBucket: 'today',
              ),
            );
          },
        );
  }
}
```

- [ ] **Step 2: Replace `lib/widgets/tomorrow_view.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/task_provider.dart';
import '../theme/theme.dart';
import 'category_group.dart';

class TomorrowView extends ConsumerWidget {
  const TomorrowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(tomorrowTasksProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (tasks) {
            final categories =
                ref.watch(categoriesProvider).valueOrNull ?? [];

            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'Nothing for tomorrow',
                  style: TextStyle(color: kTextMuted),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
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
```

- [ ] **Step 3: Update `lib/screens/goals_screen.dart`**

Replace the `_groupByCategory` method and the `ListView` children section.

Remove the `_groupByCategory` method entirely.

Replace:
```dart
import '../models/category.dart';
import '../models/task.dart';
```
with:
```dart
import '../models/category.dart';
```
(Task import is no longer needed directly.)

Add to imports:
```dart
import '../widgets/category_group.dart';
```

Replace the `data:` branch:
```dart
data: (tasks) {
  if (tasks.isEmpty) {
    return const Center( ... );
  }

  final grouped = _groupByCategory(tasks);

  return ListView(
    padding: const EdgeInsets.only(bottom: 96),
    children: [
      for (final cat in TaskCategory.values)
        if (grouped.containsKey(cat))
          CategoryGroup(
            key: ValueKey(cat),
            category: grouped[cat]!,  // wrong type
            tasks: grouped[cat]!,
            currentBucket: 'goals',
          ),
    ],
  );
},
```
With:
```dart
data: (tasks) {
  final categories =
      ref.watch(categoriesProvider).valueOrNull ?? [];

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
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: errors in add_task_sheet.dart about TaskCategory — fixed next.

---

## Task 10: Update AddTaskSheet

**Files:**
- Modify: `lib/widgets/add_task_sheet.dart`

- [ ] **Step 1: Change `_AddTaskSheet` from `StatefulWidget` to `ConsumerStatefulWidget`**

Change:
```dart
class _AddTaskSheet extends StatefulWidget {
```
to:
```dart
class _AddTaskSheet extends ConsumerStatefulWidget {
```

Change:
```dart
class _AddTaskSheetState extends State<_AddTaskSheet> {
```
to:
```dart
class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
```

- [ ] **Step 2: Replace `TaskCategory _category` state with `String _categoryId`**

Remove:
```dart
TaskCategory _category = TaskCategory.life;
```
Add:
```dart
String _categoryId = 'life';
```

- [ ] **Step 3: Update `_save()` to use `_categoryId`**

Change:
```dart
category: _category,
```
to:
```dart
categoryId: _categoryId,
```

- [ ] **Step 4: Replace category chips in `build()`**

Remove the old `SizedBox` + `ListView.separated` chips block that iterates `TaskCategory.values`.

Replace with:
```dart
Builder(builder: (context) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
  return SizedBox(
    height: 36,
    child: ListView.separated(
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
  );
}),
```

- [ ] **Step 5: Remove old `TaskCategory` import**

Remove:
```dart
import '../models/category.dart';
```
Add back as:
```dart
import '../models/category.dart';
```
(The file is the same path but now imports `Category` not `TaskCategory` — confirm the import stays, it's needed for `categoriesProvider` via the provider import chain. Actually the import is via `task_provider.dart`. Add if missing.)

Also ensure this import exists:
```dart
import '../providers/task_provider.dart';
```

- [ ] **Step 6: Verify**

Run: `flutter analyze`
Expected: no new errors.

---

## Task 11: Build CategoriesScreen

**Files:**
- Create: `lib/screens/categories_screen.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../providers/task_provider.dart';
import '../services/firestore_service.dart';
import '../theme/theme.dart';

// 12-colour matte palette
const _palette = [
  '#BF6060', '#BF7EA0', '#9060BF', '#6068BF',
  '#5B8FBF', '#5BA8A0', '#5B9E6E', '#8BA85B',
  '#C49A45', '#C4784A', '#8C6B52', '#7A8A96',
];

Color _hexColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', '0xFF')));

String _nextColor(List<Category> existing) {
  final used = existing.map((c) => c.colorHex).toSet();
  return _palette.firstWhere(
    (c) => !used.contains(c),
    orElse: () => _palette[existing.length % _palette.length],
  );
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final service = ref.read(firestoreServiceProvider);

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
          'CATEGORIES',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: kTextDark,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: kPrimary),
            tooltip: 'Add category',
            onPressed: () =>
                _showAddSheet(context, categories, service),
          ),
        ],
      ),
      body: categories.isEmpty
          ? const Center(
              child: Text('No categories yet',
                  style: TextStyle(color: kTextMuted)))
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: categories.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                service.reorderCategories(categories, oldIndex, newIndex);
              },
              itemBuilder: (context, i) {
                final cat = categories[i];
                return _CategoryRow(
                  key: ValueKey(cat.id),
                  category: cat,
                  index: i,
                  service: service,
                );
              },
            ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    List<Category> existing,
    FirestoreService service,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddCategorySheet(
        existingCount: existing.length,
        defaultColorHex: _nextColor(existing),
        service: service,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required super.key,
    required this.category,
    required this.index,
    required this.service,
  });

  final Category category;
  final int index;
  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: GestureDetector(
        onTap: () => _showColorPicker(context),
        child: CircleAvatar(
          backgroundColor: category.color,
          radius: 18,
        ),
      ),
      title: GestureDetector(
        onTap: () => _showRenameDialog(context),
        child: Text(
          category.name,
          style: const TextStyle(
              fontSize: 15,
              color: kTextDark,
              fontWeight: FontWeight.w500),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: kTextMuted),
            onPressed: () => service.deleteCategory(category.id),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: kTextMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: category.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              const InputDecoration(hintText: 'Category name'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName != null && newName.isNotEmpty) {
      await service.updateCategory(category.copyWith(name: newName));
    }
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose colour',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _palette.map((hex) {
                final color = _hexColor(hex);
                final isSelected = hex == category.colorHex;
                return GestureDetector(
                  onTap: () {
                    service.updateCategory(
                        category.copyWith(colorHex: hex));
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 22)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet({
    required this.existingCount,
    required this.defaultColorHex,
    required this.service,
  });

  final int existingCount;
  final String defaultColorHex;
  final FirestoreService service;

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  late final TextEditingController _ctrl;
  late String _colorHex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _colorHex = widget.defaultColorHex;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);

    final cat = Category(
      id: Category.newId(),
      userId: widget.service.uid,
      name: name,
      colorHex: _colorHex,
      order: widget.existingCount,
    );
    await widget.service.addCategory(cat);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, keyboard + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New category',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextDark)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'Category name',
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
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _palette.map((hex) {
              final color = _hexColor(hex);
              final isSelected = hex == _colorHex;
              return GestureDetector(
                onTap: () => setState(() => _colorHex = hex),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 6,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
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
                  : const Text('Add',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: no errors from this file.

---

## Task 12: Update HomeScreen

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Add import**

```dart
import 'categories_screen.dart';
```

- [ ] **Step 2: Add `tune` icon to the header row**

The header row already has a goals flag icon button. Add a second icon button for categories. Find the section that contains the goals flag `IconButton` and add a new one before it:

```dart
// Categories nav
IconButton(
  icon: const Icon(Icons.tune, color: kTextMuted),
  tooltip: 'Categories',
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const CategoriesScreen(),
    ),
  ),
),
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: no new errors.

---

## Task 13: Clean up theme.dart

**Files:**
- Modify: `lib/theme/theme.dart`

- [ ] **Step 1: Read the file to locate `kCategoryColors` and `categoryColor`**

Read `lib/theme/theme.dart`.

- [ ] **Step 2: Remove `kCategoryColors` map and `categoryColor()` helper**

Delete the `kCategoryColors` constant and the `categoryColor()` function. Also remove the `TaskCategory` import if present.

- [ ] **Step 3: Final verify**

Run: `flutter analyze`
Expected: **No issues found.**

---

## Task 14: Update Firestore security rules

**Files:**
- Firebase Console → Firestore → Rules

- [ ] **Step 1: Open Firebase Console → Firestore → Rules tab**

- [ ] **Step 2: Replace rules with**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /tasks/{taskId} {
      allow read, write: if request.auth != null
        && (
          resource == null
          || resource.data.userId == request.auth.uid
        );
      allow create: if request.auth != null
        && request.resource.data.userId == request.auth.uid;
    }
    match /categories/{categoryId} {
      allow read, write: if request.auth != null
        && (
          resource == null
          || resource.data.userId == request.auth.uid
        );
      allow create: if request.auth != null
        && request.resource.data.userId == request.auth.uid;
    }
  }
}
```

- [ ] **Step 3: Click Publish**

- [ ] **Step 4: Hot-restart the app and verify**

Run: `flutter run -d <device-id>`
Expected:
- App launches, today/tomorrow views show tasks grouped under coloured category headers
- Sliders icon in home header opens Categories screen
- Categories screen shows 8 seeded defaults with matte colours
- Tapping a category name opens rename dialog
- Tapping a colour swatch opens palette picker
- Drag handle reorders categories
- Delete icon removes a category
- `+` opens add sheet with name field + colour palette
- Tasks whose category was deleted appear in grey "Uncategorised" group
