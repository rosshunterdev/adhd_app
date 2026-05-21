# CLAUDE.md

Read this file at the start of every session. Also read [HANDOVER.md](HANDOVER.md) for current status and [DECISIONS.md](DECISIONS.md) for why things are the way they are before changing anything structural.

---

## What this app is

A Flutter + Firebase task manager designed for ADHD. Core philosophy: **minimum friction, maximum clarity**. Tasks live in one of three buckets (Today / Tomorrow / Goals), status is a dot not a checkbox, and the app carries forward unfinished work automatically each morning so nothing is lost.

Target platform: **Android** (tested on Pixel 8a). Single user — anonymous Firebase Auth, no login screen. App ID: `com.rosscrawford.adhdapp`. Display name: **Focus**.

---

## Stack

| Layer | Technology |
|-------|-----------|
| UI | Flutter 3.x, Material 3 |
| Language | Dart 3.x (null-safe, records, pattern matching) |
| State | Riverpod 2 (`StreamProvider`, `ConsumerWidget`) |
| Backend | Firebase Firestore (cloud_firestore ^5.0.0) |
| Auth | Firebase Auth — anonymous only (firebase_auth ^5.0.0) |
| Notifications | flutter_local_notifications ^18.0.0 |
| IDs | uuid ^4.0.0 |
| Date formatting | intl ^0.19.0 |
| Local persistence | shared_preferences ^2.2.0 (CarryForwardService only) |

---

## Commands

```powershell
flutter run                    # Run on connected Android device
flutter run -d <device-id>    # Specific device
flutter devices               # List available devices
flutter analyze               # Lint — must pass before reporting work done
flutter test                  # All tests
flutter build apk             # Android APK
flutter pub get               # Install dependencies
```

---

## File structure

```
lib/
  main.dart                     # Entry: Firebase init → auth → seeding → runApp
  models/
    task.dart                   # Task — central data object
    category.dart               # Category — user-defined, stored in Firestore
    step.dart                   # Step — embedded in Task
  providers/
    task_provider.dart          # All Riverpod providers
  screens/
    home_screen.dart            # Main screen: header + PageView (Today/Tomorrow) + swipe-up bar
    categories_screen.dart      # Manage categories (reorder, rename, recolour, add, delete)
    goals_screen.dart           # Goals list (separate pushed route)
  services/
    auth_service.dart           # Anonymous sign-in
    firestore_service.dart      # ALL Firestore access — widgets never touch FirebaseFirestore directly
    category_service.dart       # seedIfNeeded(): creates 8 default categories on first launch
    carry_forward_service.dart  # runIfNeeded(): moves unfinished Today → Tomorrow each morning
    notification_service.dart   # Local notifications for scheduled tasks
  theme/
    theme.dart                  # Colour constants + buildAppTheme()
  widgets/
    add_task_sheet.dart         # Modal bottom sheet for creating tasks/goals
    category_group.dart         # CategoryGroup widget + buildCategoryGroups() free function
    snooze_sheet.dart           # Modal: snooze options + time-block picker
    steps_sheet.dart            # DraggableScrollableSheet for viewing/editing task steps
    task_tile.dart              # Individual task row (Dismissible → Card → InkWell)
    today_view.dart             # Today bucket content (ListView of CategoryGroups)
    tomorrow_view.dart          # Tomorrow bucket content
```

---

## Data model

### Task (Firestore collection: `tasks`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | String | UUID v4 |
| `userId` | String | Anonymous UID — all queries filter by this |
| `title` | String | |
| `bucket` | String | `'today'` \| `'tomorrow'` \| `'goals'` |
| `categoryId` | String | References a `categories` document ID |
| `status` | String | `'yetToStart'` \| `'inProgress'` \| `'completed'` \| `'moved'` |
| `isGoal` | bool | Goals appear in GoalsScreen, not Today/Tomorrow |
| `deadline` | String? | ISO 8601 — user-visible due date |
| `dueDate` | String? | ISO 8601 — snooze gate: task hidden until this date passes |
| `scheduledTime` | String? | ISO 8601 — time-block start |
| `durationMinutes` | int? | Time-block duration |
| `steps` | List | Embedded `Step` objects `{id, title, isCompleted}` |
| `priority` | int | Sort weight |
| `manualOrder` | int | Drag-drop position |
| `createdAt` | String | ISO 8601 |

**`deadline` vs `dueDate` — do not confuse them.** `deadline` is what the user sets and sees. `dueDate` is set by snooze and gates stream visibility; the task stays hidden until `dueDate` is past. See DECISIONS.md #5.

**`fromMap` migration fallback:** `categoryId: map['categoryId'] ?? map['category'] ?? 'life'`. The `map['category']` leg handles old documents written before the categories feature. Do not remove it.

### Category (Firestore collection: `categories`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | String | UUID v4 (seeded defaults use old enum names: `'life'`, `'work'`, etc.) |
| `userId` | String | |
| `name` | String | Display name |
| `colorHex` | String | e.g. `'#5B9E6E'` |
| `order` | int | Position in list |

**Required Firestore composite index:** `categories` needs `(userId ASC, order ASC)`. If the categories stream throws `FAILED_PRECONDITION`, create the index in Firebase Console → Firestore → Indexes.

---

## Providers (`lib/providers/task_provider.dart`)

| Provider | Returns |
|----------|---------|
| `firestoreServiceProvider` | `FirestoreService` — requires non-null `currentUser`; guaranteed by startup sequence |
| `notificationServiceProvider` | `NotificationService` |
| `todayTasksProvider` | `StreamProvider<List<Task>>` |
| `tomorrowTasksProvider` | `StreamProvider<List<Task>>` |
| `goalsTasksProvider` | `StreamProvider<List<Task>>` |
| `categoriesProvider` | `StreamProvider<List<Category>>` — ordered by `order` field |

---

## Theme constants (`lib/theme/theme.dart`)

```dart
kPrimary       = Color(0xFF3D5AFE)  // Blue — primary actions
kSurface       = Color(0xFFF8F9FF)  // Off-white — scaffold background
kTextDark      = Color(0xFF1A1A2E)  // Near-black — body text
kTextMuted     = Color(0xFF888888)  // Grey — secondary text, icons
kTodayColor    = Color(0xFFE53935)  // Red — Today header
kTomorrowColor = Color(0xFFFB8C00)  // Orange — Tomorrow header
kGoalsColor    = Color(0xFF43A047)  // Green — Goals header
```

Category colours come from `Category.color` (parsed from `colorHex`). Do not add category colours to `theme.dart`.

---

## Startup sequence

```
Firebase.initializeApp()
  → NotificationService().init()
  → AuthService().signInAnonymously()     ← UID guaranteed from here on
  → CarryForwardService().runIfNeeded()   ← moves yesterday's unfinished tasks
  → CategoryService().seedIfNeeded()      ← creates defaults if no categories exist
  → runApp(ProviderScope(MyApp()))
```

---

## Coding conventions

- **No direct Firestore calls in widgets.** Always use `ref.read(firestoreServiceProvider)`.
- **`ref.watch` for streams, `ref.read` for one-off writes.** Never `ref.watch` inside a callback.
- **`StatefulWidget` for anything owning `FocusNode`, `TextEditingController`, or `AnimationController`.** Closure-based disposal causes lifecycle bugs. See DECISIONS.md #13.
- **`flutter analyze` must pass before any task is reported done.**
- **`IntrinsicHeight` wraps the `Row` in `TaskTile`** — do not remove it. It fixes a layout crash caused by `crossAxisAlignment: CrossAxisAlignment.stretch` in an unbounded-height context. See DECISIONS.md #12.
- **`buildCategoryGroups()`** is the single rendering path for all three views — do not inline category grouping elsewhere.
- Category colour fallback pattern: `category?.color ?? const Color(0xFF888888)`.

---

## What not to touch without asking

| Thing | Why |
|-------|-----|
| `Task.fromMap` `map['category']` fallback | Removing it silently breaks old Firestore documents |
| `CarryForwardService` logic | Subtle timing; changes affect what users see on morning launch |
| `dueDate` / `deadline` distinction | Conflating them breaks snooze behaviour |
| `firestoreServiceProvider` auth assumption | Cascading effect on all providers |
| Firestore security rules | Partially configured; verify before changing |
| The 8 seeded category IDs | They match old `TaskCategory` enum values used as foreign keys in existing task documents |

---

## Current phase

**Post-MVP. Categories feature complete. Uncommitted.**

All work from the last session is uncommitted. The immediate next step is a single git commit covering the entire categories implementation.

See [HANDOVER.md](HANDOVER.md) for what's next and what's still open.

---

## Firebase project

- Project ID: `adhd-app-6c04f`
- Required Firestore index: `categories (userId ASC, order ASC)` — may still be building
- Security rules: tasks collection secured; verify categories collection rules are in place
