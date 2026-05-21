import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final notifications = ref.read(notificationServiceProvider);
  return FirestoreService(uid, notifications);
});

final todayTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(firestoreServiceProvider).todayStream;
});

final tomorrowTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(firestoreServiceProvider).tomorrowStream;
});

final goalsTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(firestoreServiceProvider).goalsStream;
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(firestoreServiceProvider).categoriesStream;
});
