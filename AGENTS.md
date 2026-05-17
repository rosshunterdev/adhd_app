# AGENTS.md

## Project

`adhd_app` is a Flutter + Firebase task manager using a three-bucket urgency model:

- `NOW`
- `SOON`
- `LATER`

The app uses Firestore for task storage, anonymous Firebase Auth for user identity, Riverpod for state wiring, and local notifications for scheduled reminders.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run on a specific connected device
flutter devices
flutter run -d <device-id>

# Analyze and lint
flutter analyze

# Run tests
flutter test
flutter test test/widget_test.dart

# Build Android artifacts
flutter build apk
flutter build appbundle
```

Use `flutter pub upgrade` only when dependency updates are explicitly requested.

## Architecture

Data flow:

```text
Firestore -> TaskService streams -> Riverpod StreamProviders -> HomeScreen UI
```

Key files:

- `lib/services/task_service.dart` owns Firestore access. It is scoped to a `uid` and exposes bucket streams for `now`, `soon`, and `later`.
- `lib/providers/task_provider.dart` wires `TaskService` and `NotificationService` into Riverpod.
- `lib/screens/home_screen.dart` contains the primary UI: a `PageView` with three bucket pages and inline bottom sheets for adding tasks, steps, and snoozing.
- `lib/services/notification_service.dart` schedules local notifications with timezone support.

Auth is expected to be ready before the UI starts. `main.dart` signs in anonymously before `runApp`, so `taskServiceProvider` expects `FirebaseAuth.instance.currentUser` to be non-null.

## Task Model Notes

- `bucket`: one of `now`, `soon`, or `later`.
- `deadline`: user-visible due date, used for display and sorting.
- `dueDate`: snooze/visibility gate. A task should be hidden from its bucket stream until `dueDate` is in the past, compared against `startOfToday`.
- `manualOrder`: drag/drop position. Sort priority is `manualOrder`, then `priority` descending, then `deadline` ascending with nulls last.
- `steps` and `completedSteps`: parallel string lists, not a list of step objects.

Firestore uses one flat `tasks` collection filtered by `userId`.

## Notifications

`NotificationService` uses `flutter_local_notifications` and timezone-aware scheduling.

Notification IDs are derived from `task.id.hashCode`. Any task update or defer action should cancel and reschedule the related notification.

## Working Rules

- Do not stage, commit, or push changes unless explicitly asked.
- Read the relevant Dart file before changing it.
- Keep edits narrowly scoped to the requested behavior.
- Do not create new screens, routes, services, or large abstractions unless asked or clearly required.
- Prefer existing Riverpod, Firebase, and Flutter patterns already present in the app.
- Preserve the distinction between `deadline` and `dueDate`.
- Be careful with notification side effects when modifying task update or defer logic.
- Do not silently change generated platform files under `android`, `ios`, `linux`, `macos`, `web`, or `windows` unless the task specifically involves platform configuration.

## Verification

Before reporting work complete, run the most relevant checks:

```bash
flutter analyze
flutter test
```

For UI changes, also verify visually with the project screenshot workflow if one exists. If there is no project-specific screenshot tool, say that clearly and report the verification that was possible.
