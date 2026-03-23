import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final taskServiceProvider = Provider<TaskService>((ref) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final notifications = ref.read(notificationServiceProvider);
  return TaskService(uid, notifications);
});

final nowTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskServiceProvider).nowStream;
});

final soonTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskServiceProvider).soonStream;
});

final laterTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskServiceProvider).laterStream;
});
