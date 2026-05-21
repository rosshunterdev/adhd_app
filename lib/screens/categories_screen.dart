import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../providers/task_provider.dart';
import '../theme/theme.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const _palette = [
    '#BF6060', // Matte Red
    '#BF7EA0', // Matte Rose
    '#9060BF', // Matte Purple
    '#6068BF', // Matte Indigo
    '#5B8FBF', // Matte Blue
    '#5BA8A0', // Matte Teal
    '#5B9E6E', // Matte Green
    '#8BA85B', // Matte Olive
    '#C49A45', // Matte Amber
    '#C4784A', // Matte Orange
    '#8C6B52', // Matte Brown
    '#7A8A96', // Matte Slate
  ];

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }

  String _nextUnusedColor(List<Category> existing) {
    final usedHexes = existing.map((c) => c.colorHex).toSet();
    for (final hex in _palette) {
      if (!usedHexes.contains(hex)) return hex;
    }
    // All colours used — cycle by index
    return _palette[existing.length % _palette.length];
  }

  Future<void> _showAddSheet(
    BuildContext context,
    WidgetRef ref,
    List<Category> existing,
  ) async {
    final service = ref.read(firestoreServiceProvider);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final nameController = TextEditingController();
    String selectedHex = _nextUnusedColor(existing);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Category name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _palette.map((hex) {
                      final isSelected = hex == selectedHex;
                      return GestureDetector(
                        onTap: () => setState(() => selectedHex = hex),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _hexToColor(hex),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: kTextDark, width: 2.5)
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: nameController,
                      builder: (_, value, _) {
                        final enabled = value.text.trim().isNotEmpty;
                        return ElevatedButton(
                          onPressed: enabled
                              ? () async {
                                  final name = nameController.text.trim();
                                  final cat = Category(
                                    id: Category.newId(),
                                    userId: uid,
                                    name: name,
                                    colorHex: selectedHex,
                                    order: existing.length,
                                  );
                                  Navigator.of(sheetContext).pop();
                                  try {
                                    await service.addCategory(cat);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text('Error: $e')));
                                    }
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Save'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  Future<void> _showPalettePicker(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    final service = ref.read(firestoreServiceProvider);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Colour',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _palette.map((hex) {
                  final isSelected = hex == cat.colorHex;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await service
                            .updateCategory(cat.copyWith(colorHex: hex));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _hexToColor(hex),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: kTextDark, width: 2.5)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    final service = ref.read(firestoreServiceProvider);
    final controller = TextEditingController(text: cat.name);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Rename'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, value, _) {
                    final trimmed = value.text.trim();
                    final enabled =
                        trimmed.isNotEmpty && trimmed != cat.name;
                    return TextButton(
                      onPressed: enabled
                          ? () async {
                              final newName = trimmed;
                              Navigator.of(dialogContext).pop();
                              try {
                                await service.updateCategory(
                                    cat.copyWith(name: newName));
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                          : null,
                      child: const Text('Save'),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(categoriesProvider);
    final service = ref.read(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Categories'),
        actions: [
          asyncCategories.valueOrNull != null
              ? IconButton(
                  icon: const Icon(Icons.add, color: kTextDark),
                  onPressed: () => _showAddSheet(
                    context,
                    ref,
                    asyncCategories.valueOrNull ?? [],
                  ),
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: asyncCategories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.label_outline,
                      size: 48, color: kTextMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No categories yet.',
                    style: TextStyle(color: kTextMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showAddSheet(context, ref, categories),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final reordered = List<Category>.from(categories);
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              try {
                await service.reorderCategories(reordered);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            itemBuilder: (ctx, index) {
              final cat = categories[index];
              return ListTile(
                key: ValueKey(cat.id),
                leading: GestureDetector(
                  onTap: () => _showPalettePicker(context, ref, cat),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                title: GestureDetector(
                  onTap: () => _showRenameDialog(context, ref, cat),
                  child: Text(
                    cat.name,
                    style: const TextStyle(
                      color: kTextDark,
                      fontSize: 16,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: kTextMuted),
                      onPressed: () async {
                        try {
                          await service.deleteCategory(cat.id);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle,
                          color: kTextMuted),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: asyncCategories.valueOrNull != null
          ? FloatingActionButton(
              onPressed: () => _showAddSheet(
                context,
                ref,
                asyncCategories.valueOrNull ?? [],
              ),
              backgroundColor: kPrimary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
