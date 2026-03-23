import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';
import 'notification_service.dart';

class TaskService {
  final String uid;
  final NotificationService _notifications;
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('tasks');

  TaskService(this.uid, this._notifications);

  Stream<List<Task>> _bucketStream(String bucket) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    return _collection
        .where('userId', isEqualTo: uid)
        .where('bucket', isEqualTo: bucket)
        .snapshots()
        .map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>))
          .where((task) =>
              task.dueDate == null || !task.dueDate!.isAfter(startOfToday))
          .toList();

      tasks.sort((a, b) {
        // Manual order ascending — explicit user ordering wins
        final byOrder = a.manualOrder.compareTo(b.manualOrder);
        if (byOrder != 0) return byOrder;

        // Priority descending — higher value = more urgent
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;

        // Deadline ascending, nulls last
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

  Stream<List<Task>> get nowStream => _bucketStream('now');
  Stream<List<Task>> get soonStream => _bucketStream('soon');
  Stream<List<Task>> get laterStream => _bucketStream('later');

  Future<void> addTask(Task task) async {
    await _collection.doc(task.id).set({
      ...task.toMap(),
      'userId': uid,
    });
    if (task.notificationTime != null) {
      await _notifications.scheduleNotification(
          task.id, task.title, task.notificationTime!);
    }
  }

  Future<void> updateTask(Task task) async {
    await _notifications.cancelNotification(task.id);
    await _collection.doc(task.id).update(task.toMap());
    if (task.notificationTime != null) {
      await _notifications.scheduleNotification(
          task.id, task.title, task.notificationTime!);
    }
  }

  Future<void> deleteTask(String id) async {
    await _notifications.cancelNotification(id);
    await _collection.doc(id).delete();
  }

  Future<void> moveTask(String id, String newBucket) async {
    await _collection.doc(id).update({'bucket': newBucket});
  }

  Future<void> deferTask(String id, DateTime newDueDate) async {
    await _notifications.cancelNotification(id);
    await _collection.doc(id).update({'dueDate': newDueDate.toIso8601String()});
  }

  Future<void> removeDeadline(String id) async {
    await _collection.doc(id).update({'deadline': null});
  }
}
