# User-Defined Categories — Design Spec

**Date:** 2026-05-20
**Status:** Approved

## Overview

Replace the hardcoded `TaskCategory` enum with a Firestore-backed `Category` model that users can fully control — add, rename, reorder, recolour, and delete. Existing tasks survive category deletion with a graceful "Uncategorised" fallback.

---

## Data Model

### Category document (`categories/{categoryId}`)

| Field | Type | Notes |
|---|---|---|
| `id` | String | UUID, same pattern as Task.id |
| `userId` | String | Scoped to authenticated user |
| `name` | String | User-defined display name |
| `colorHex` | String | e.g. `"#5B8FBF"` — from matte palette |
| `order` | int | Position in the list; used for sort and drag-to-reorder |

### Task model change

- Remove: `category: TaskCategory`
- Add: `categoryId: String`

Tasks whose `categoryId` no longer matches any live category are treated as uncategorised — displayed in a grey fallback group at the bottom of the list. No data is deleted from the task document.

---

## Colour Palette (12 matte colours)

| Name | Hex |
|---|---|
| Matte Red | `#BF6060` |
| Matte Rose | `#BF7EA0` |
| Matte Purple | `#9060BF` |
| Matte Indigo | `#6068BF` |
| Matte Blue | `#5B8FBF` |
| Matte Teal | `#5BA8A0` |
| Matte Green | `#5B9E6E` |
| Matte Olive | `#8BA85B` |
| Matte Amber | `#C49A45` |
| Matte Orange | `#C4784A` |
| Matte Brown | `#8C6B52` |
| Matte Slate | `#7A8A96` |

New categories default to the next unused palette colour (cycling if all are used).

---

## Default Seeding

On first launch for a user with no categories in Firestore, seed 8 defaults using matte palette colours:

| Name | Hex | Order |
|---|---|---|
| Web Dev | `#5B8FBF` | 0 |
| App Dev | `#9060BF` | 1 |
| Study | `#C49A45` | 2 |
| Work | `#BF6060` | 3 |
| Admin | `#7A8A96` | 4 |
| Life | `#5B9E6E` | 5 |
| Music | `#BF7EA0` | 6 |
| Goals | `#5BA8A0` | 7 |

Seeding runs once, guarded by a Firestore query — if any categories exist for the user, seeding is skipped.

---

## Architecture

### New files

- `lib/models/category.dart` — `Category` class (replaces enum)
- `lib/screens/categories_screen.dart` — management UI
- `lib/services/category_service.dart` — seeding logic

### Modified files

- `lib/models/task.dart` — `categoryId: String` replaces `category: TaskCategory`
- `lib/services/firestore_service.dart` — add `categoriesStream`, `addCategory`, `updateCategory`, `deleteCategory`, `reorderCategories`
- `lib/providers/task_provider.dart` — add `categoriesProvider` StreamProvider
- `lib/main.dart` — call `CategoryService().seedIfNeeded(uid)` after auth
- `lib/widgets/add_task_sheet.dart` — chips from `categoriesProvider`, not enum
- `lib/widgets/category_group.dart` — accepts `Category?` (null = uncategorised fallback)
- `lib/widgets/task_tile.dart` — colour from `Category` object
- `lib/widgets/today_view.dart` — group by `categoryId`, look up `Category`
- `lib/widgets/tomorrow_view.dart` — same
- `lib/screens/goals_screen.dart` — same
- `lib/screens/home_screen.dart` — add `tune` icon to header → navigates to CategoriesScreen

### Deleted files

- `lib/theme/theme.dart` — remove `kCategoryColors` map and `categoryColor()` helper; colour now on the `Category` model itself

---

## Categories Screen (`CategoriesScreen`)

**Navigation:** `tune` (sliders) icon in the home screen header row, between the goals flag and the segmented control.

**Layout:**
- AppBar: "Categories" title + `+` FAB / action button
- Body: `ReorderableListView` — each row:
  - Colour swatch circle (tappable → palette picker sheet)
  - Category name (tappable → rename dialog)
  - Drag handle
  - Delete button (trailing icon; no confirmation — follows option C)
- Reorder persists immediately (batch-writes updated `order` values)

**Add category sheet:**
- Name text field (required, autofocus)
- 12-colour palette grid (required; defaults to next unused colour)
- Save button

**Palette picker sheet:**
- 12 colour circles in a grid
- Currently selected colour highlighted with a check mark
- Saves immediately on tap

---

## Grouping Logic (Today / Tomorrow / Goals views)

```
categories = categoriesProvider value (List<Category>)
grouped = Map<String, List<Task>>  keyed by categoryId

for each categoryId in grouped:
  category = categories.firstWhereOrNull((c) => c.id == categoryId)
  if category != null → CategoryGroup(category: category, ...)
  else → CategoryGroup(category: null, ...)  // grey "Uncategorised" group

uncategorised group always renders last
```

---

## Error Handling

- Categories stream unavailable → views show existing task tiles without colour/grouping (degrade gracefully)
- Add/rename/delete failure → show SnackBar error, no optimistic update
- Empty name on add → Save button disabled

---

## Out of Scope

- Category emoji/icons
- Per-category notification defaults
- Sharing categories between users
