import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';
import '../models/task.dart';
import 'notification_service.dart';

class FirestoreService {
  final String uid;
  final NotificationService _notifications;
  final CollectionReference _col =
      FirebaseFirestore.instance.collection('tasks');
  final CollectionReference _cats =
      FirebaseFirestore.instance.collection('categories');

  FirestoreService(this.uid, this._notifications);

  Stream<List<Task>> _bucketStream(String bucket) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    return _col
        .where('userId', isEqualTo: uid)
        .where('bucket', isEqualTo: bucket)
        .snapshots()
        .map((snap) {
      final tasks = snap.docs
          .map((d) => Task.fromMap(d.data() as Map<String, dynamic>))
          .where((t) =>
              t.dueDate == null || !t.dueDate!.isAfter(startOfToday))
          .toList();

      tasks.sort((a, b) {
        // 1. Overdue tasks surface to top.
        final aOverdue =
            a.deadline != null && a.deadline!.isBefore(startOfToday);
        final bOverdue =
            b.deadline != null && b.deadline!.isBefore(startOfToday);
        if (aOverdue != bOverdue) return aOverdue ? -1 : 1;
        // 2. Scheduled tasks in time order, before unscheduled.
        final aTime = a.scheduledTime;
        final bTime = b.scheduledTime;
        if (aTime == null && bTime != null) return 1;
        if (aTime != null && bTime == null) return -1;
        if (aTime != null && bTime != null) {
          final cmp = aTime.compareTo(bTime);
          if (cmp != 0) return cmp;
        }
        // 3. manualOrder → priority → deadline.
        final byOrder = a.manualOrder.compareTo(b.manualOrder);
        if (byOrder != 0) return byOrder;
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;
        if (a.deadline != null && b.deadline != null) {
          return a.deadline!.compareTo(b.deadline!);
        }
        if (a.deadline != null) return -1;
        if (b.deadline != null) return 1;
        return 0;
      });

      return tasks;
    });
  }

  Stream<List<Task>> get todayStream    => _bucketStream('today');
  Stream<List<Task>> get tomorrowStream => _bucketStream('tomorrow');

  Stream<List<Task>> get goalsStream => _col
      .where('userId', isEqualTo: uid)
      .where('isGoal', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => Task.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> addTask(Task task) async {
    await _col.doc(task.id).set(task.toMap());
    if (task.notificationTime != null) {
      await _notifications.scheduleNotification(
          task.id, task.title, task.notificationTime!);
    }
  }

  Future<void> updateTask(Task task) async {
    await _notifications.cancelNotification(task.id);
    await _col.doc(task.id).update(task.toMap());
    if (task.notificationTime != null) {
      await _notifications.scheduleNotification(
          task.id, task.title, task.notificationTime!);
    }
  }

  Future<void> deleteTask(String id) async {
    await _notifications.cancelNotification(id);
    await _col.doc(id).delete();
  }

  Future<void> moveTask(String id, String newBucket) async {
    await _col.doc(id).update({'bucket': newBucket});
  }

  Future<void> deferTask(String id, DateTime newDueDate) async {
    await _notifications.cancelNotification(id);
    await _col.doc(id).update({'dueDate': newDueDate.toIso8601String()});
  }

  Future<void> removeDeadline(String id) async {
    await _col.doc(id).update({'deadline': null});
  }

  Future<void> clearTimeBlock(String id) async {
    await _col.doc(id).update({'scheduledTime': null, 'durationMinutes': null});
  }

  Stream<List<Category>> get categoriesStream => _cats
      .where('userId', isEqualTo: uid)
      .orderBy('order')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => Category.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> addCategory(Category category) =>
      _cats.doc(category.id).set(category.toMap());

  Future<void> updateCategory(Category category) =>
      _cats.doc(category.id).update(category.toMap());

  Future<void> deleteCategory(String id) => _cats.doc(id).delete();

  Future<void> reorderCategories(List<Category> categories) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < categories.length; i++) {
      batch.update(_cats.doc(categories[i].id), {'order': i});
    }
    await batch.commit();
  }
}
