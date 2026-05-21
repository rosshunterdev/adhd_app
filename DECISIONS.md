# Architectural & UX Decisions

A running log of significant decisions made during development. Ordered roughly chronologically. Consult this before changing anything structural.

---

## 1. Three-bucket urgency model (Today / Tomorrow / Goals)

**What:** Tasks live in one of three buckets: Today, Tomorrow, or Goals. No priority numbers, no labels, no due-date sorting as the primary UX.

**Why:** ADHD brains struggle with abstract priority systems. "Is this a 3 or a 4?" is friction. "Is this today or tomorrow?" is a binary decision that maps to actual time. Goals are persistent intentions, not actionable tasks, so they live separately.

**Alternatives considered:** Priority levels (P1–P3); labels/tags; a single flat list with due dates. All rejected because they require more cognitive load to maintain.

**Session:** MVP

---

## 2. Anonymous Firebase Auth (no login)

**What:** Users are signed in anonymously on first launch via `AuthService().signInAnonymously()`. No email, no password, no OAuth.

**Why:** This is a personal productivity app for a single user. Login friction is a barrier to building the habit. Anonymous auth still gives a stable UID for Firestore scoping.

**Alternatives considered:** Google Sign-In (adds friction); no auth at all (can't scope Firestore rules).

**Trade-off:** If the user clears app data, they lose their UID and effectively lose their data. Acceptable for now; can be migrated to a linked account later.

**Session:** MVP

---

## 3. Riverpod 2 for state management

**What:** All providers are Riverpod `StreamProvider` or `Provider`. Widgets are `ConsumerWidget` or `ConsumerStatefulWidget`. No `setState` at the top level.

**Why:** Firestore streams map naturally to `StreamProvider`. Riverpod's provider graph handles dependency injection (e.g., `firestoreServiceProvider` depends on auth state). Less boilerplate than BLoC, more testable than plain `setState`.

**Alternatives considered:** `setState` + `StreamBuilder` (too verbose, hard to share state); BLoC (overkill for this scope); Provider package (older, less ergonomic).

**Session:** MVP

---

## 4. FirestoreService as the single Firestore access point

**What:** All Firestore reads and writes go through `FirestoreService` (`lib/services/firestore_service.dart`). Widgets never touch `FirebaseFirestore.instance` directly.

**Why:** Centralises query logic, makes it easy to add caching or swap backends later, keeps widget code clean.

**Alternatives considered:** Repositories per entity (overkill for this scale); direct Firestore calls in widgets (hard to audit and change).

**Session:** MVP

---

## 5. `dueDate` (snooze gate) is separate from `deadline` (user-visible due date)

**What:** `Task` has two date fields: `deadline` (the date the user sees and cares about) and `dueDate` (a snooze/visibility gate — the task is hidden from its bucket stream until `dueDate` is in the past).

**Why:** Snoozing a task shouldn't change its deadline. "This is due Friday but I don't want to see it until Wednesday" requires two fields. Conflating them means snoozing loses the original deadline.

**Alternatives considered:** Single `dueDate` field that serves both purposes — rejected because snoozing would overwrite the user-set deadline.

**Session:** MVP

---

## 6. TaskStatus enum over boolean flags

**What:** `TaskStatus` is an enum: `yetToStart | inProgress | completed | moved`. Not separate booleans like `isCompleted`, `isStarted`.

**Why:** States are mutually exclusive. An enum enforces this and makes exhaustive switch matching easy. `moved` is a special state for carry-forward tasks (shown with reduced opacity and "↑ carried forward" label).

**Alternatives considered:** `isCompleted: bool` + `isInProgress: bool` — allows invalid combinations; `Map<String, bool>` — even worse.

**Session:** MVP

---

## 7. Steps stored as `List<Step>` on the Task document (not a subcollection)

**What:** Steps are embedded in the Task Firestore document as a JSON array, not stored in a `steps` subcollection.

**Why:** Steps are never queried independently — they're always loaded with their parent task. Embedding avoids extra reads and keeps the data model simple.

**Alternatives considered:** Subcollection per task — adds reads, complexity, and Firestore rules; nested map — less typed.

**Trade-off:** Firestore document size limit (1 MB) applies. Not a concern unless a task has thousands of steps.

**Session:** MVP

---

## 8. CarryForwardService runs once per day at startup

**What:** On launch, `CarryForwardService().runIfNeeded(uid)` checks whether today's carry-forward has already run (via `shared_preferences`). If not, it moves unfinished Today tasks to Tomorrow and marks them as `TaskStatus.moved`.

**Why:** ADHD users benefit from a clean slate each morning. "Yesterday's tasks don't disappear — they carry forward so nothing is lost."

**Alternatives considered:** Manual carry-forward button; scheduled background job. Startup check is simpler and guaranteed to run before the user sees any data.

**Session:** MVP

---

## 9. Zero-downtime migration from `TaskCategory` enum to `String categoryId`

**What:** Old tasks stored `category: 'webDev'` (the enum name). New tasks store `categoryId: 'webDev'`. The seeded default categories use the old enum names as their Firestore document IDs. `Task.fromMap` falls back: `map['categoryId'] ?? map['category'] ?? 'life'`.

**Why:** Existing Firestore data must continue to work without a migration script. By using enum names as category IDs and adding the fallback, old documents resolve to the correct category automatically on first read.

**Alternatives considered:** Migration script to rewrite all documents — risky and requires downtime; new `categoryId` field with no fallback — breaks existing tasks.

**Session:** 2026-05-21

---

## 10. User-defined categories with a fixed 12-colour matte palette

**What:** Categories have a `colorHex` field. Users choose from a fixed palette of 12 matte colours. No free colour picker.

**Palette:** `#BF6060` (Red), `#BF7EA0` (Rose), `#9060BF` (Purple), `#6068BF` (Indigo), `#5B8FBF` (Blue), `#5BA8A0` (Teal), `#5B9E6E` (Green), `#8BA85B` (Olive), `#C49A45` (Amber), `#C4784A` (Orange), `#8C6B52` (Brown), `#7A8A96` (Slate).

**Why:** A constrained palette ensures all category colours look good together on screen. Free colour pickers introduce clashing or near-identical colours. Matte tones (desaturated, medium-brightness) work well against white card backgrounds and the app's overall calm aesthetic.

**Alternatives considered:** Full colour picker — visual chaos; no colour choice (auto-assigned) — users want ownership.

**Session:** 2026-05-21

---

## 11. `buildCategoryGroups` as a shared free function

**What:** `lib/widgets/category_group.dart` exports `buildCategoryGroups({tasks, categories, currentBucket})` which returns `List<Widget>`. Called by `TodayView`, `TomorrowView`, and `GoalsScreen`.

**Why:** All three views need the same grouping and rendering logic. Extracting it avoids three copies of the same code. A free function (not a method on a class) keeps it simple — no state, pure transformation.

**Alternatives considered:** Mixin; abstract base class; inline in each view. All more complex than a free function for what is essentially a pure list transformation.

**Session:** 2026-05-21

---

## 12. `IntrinsicHeight` wrapping `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` in TaskTile

**What:** The overdue red bar on the left of a task tile is implemented as `Container(width: 4)` inside a `Row` with `crossAxisAlignment: CrossAxisAlignment.stretch`. This requires the Row to know its height. Inside a `Column` (which gives unbounded height), this caused a "BoxConstraints forces infinite height" crash. Fixed by wrapping the Row in `IntrinsicHeight`.

**Why:** `IntrinsicHeight` measures the intrinsic height of its child (the maximum of all Row children's natural heights) and constrains the Row to that value, giving it the bounded height that `stretch` requires.

**Performance note:** `IntrinsicHeight` does a two-pass layout. For a list of tasks this is fine. Don't use it in deeply-nested frequently-rebuilt widgets.

**Session:** 2026-05-21

---

## 13. `steps_sheet.dart` as a `StatefulWidget` (not a closure)

**What:** The steps sheet originally created `FocusNode` and `TextEditingController` outside the widget tree and disposed them in `.whenComplete()`. Converted to a `StatefulWidget` (`_StepsSheet`) where `dispose()` handles teardown.

**Why:** The closure pattern caused "FocusNode used after being disposed" and cascade "attached" assertion errors when the sheet closed while the keyboard was animating. Flutter's focus system holds references to `FocusNode` past the `.whenComplete()` callback. `StatefulWidget.dispose()` is the correct lifecycle hook.

**Session:** 2026-05-21

---

## 14. Swipe-up add bar replacing FAB

**What:** The floating action button in `HomeScreen` was replaced with a persistent `_AddBar` widget at the bottom of the screen. Tap to open the add sheet; swipe up with enough velocity or distance to trigger it. The bar shifts up as you drag (max 24px) and turns blue when the threshold is reached.

**Why:** FABs are a universal pattern but they cover content and feel disconnected from the gesture-first design. A full-width bar makes the add affordance always visible without floating over content, and the swipe-up gesture maps naturally to "bring something forward" — which is what adding a task is.

**Alternatives considered:** FAB (removed); invisible swipe zone with no visual cue (too hidden for ADHD users who need clear affordances); plus button in the header (too far from the content).

**Session:** 2026-05-21
