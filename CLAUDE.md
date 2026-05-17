# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app (Android device/emulator must be connected)
flutter run

# Run on a specific device
flutter run -d <device-id>
flutter devices  # list available devices

# Build
flutter build apk          # Android APK
flutter build appbundle    # Android App Bundle

# Analyze & lint
flutter analyze

# Tests
flutter test                        # all tests
flutter test test/widget_test.dart  # single test file

# Dependencies
flutter pub get
flutter pub upgrade
```

## Architecture

The app is a Flutter + Firebase task manager with a three-bucket urgency model (NOW / SOON / LATER).

**Data flow:**
```
Firestore → TaskService (streams) → Riverpod StreamProviders → HomeScreen (UI)
```

**Key relationships:**

- `TaskService` (`services/task_service.dart`) owns all Firestore access. It is scoped to a `uid` and holds the three bucket streams (`nowStream`, `soonStream`, `laterStream`). Stream filtering uses `dueDate` (a snooze/defer field) while `deadline` is the user-facing due date — they are distinct fields on `Task`.

- `task_provider.dart` wires `TaskService` and `NotificationService` into Riverpod. `taskServiceProvider` requires `FirebaseAuth.instance.currentUser` to be non-null — auth is guaranteed by `main.dart` calling `AuthService().signInAnonymously()` before `runApp`.

- `HomeScreen` (`screens/home_screen.dart`) is the entire UI — one screen with a `PageView` of three `_BucketPage` widgets. All modals (add task, steps, snooze) are inline bottom sheets within this file.

**`Task` model fields to know:**
- `bucket`: `'now'` | `'soon'` | `'later'` — which bucket the task lives in
- `deadline`: user-visible due date, used for display and sorting
- `dueDate`: the snooze/visibility gate — a task is hidden from its bucket stream until `dueDate` is in the past (compared against `startOfToday`)
- `manualOrder`: drag-drop position; sort priority is `manualOrder` → `priority` (desc) → `deadline` (asc, nulls last)
- `steps` / `completedSteps`: parallel string lists (not a list of objects)

**Firestore collection:** `tasks` — all tasks in one flat collection, filtered by `userId` field.

**Notifications:** `NotificationService` uses `flutter_local_notifications` with timezone-aware scheduling. Notification ID is derived from `task.id.hashCode`. Any `updateTask` or `deferTask` cancels and reschedules the notification.
