import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CarryForwardService {
  static const _lastRunKey = 'carry_forward_last_run';

  /// Runs carry-forward at most once per calendar day.
  /// Call this after auth on app open — safe to await before runApp.
  Future<void> runIfNeeded(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastRunStr = prefs.getString(_lastRunKey);
    if (lastRunStr != null) {
      final lastRun = DateTime.parse(lastRunStr);
      final lastRunDay = DateTime(lastRun.year, lastRun.month, lastRun.day);
      if (lastRunDay == today) return; // Already ran today
    }

    try {
      final count = await _carryForward(uid);
      await prefs.setString(_lastRunKey, now.toIso8601String());
      if (count > 0) {
        debugPrint('[CarryForward] moved $count task(s) to tomorrow');
      }
    } catch (e) {
      // Leave last-run date unset — will retry on next open.
      debugPrint('[CarryForward] failed: $e');
    }
  }

  Future<int> _carryForward(String uid) async {
    final col = FirebaseFirestore.instance.collection('tasks');

    final snap = await col
        .where('userId', isEqualTo: uid)
        .where('bucket', isEqualTo: 'today')
        .get();

    if (snap.docs.isEmpty) return 0;

    final batch = FirebaseFirestore.instance.batch();
    var count = 0;

    for (final doc in snap.docs) {
      final status = doc.data()['status'] as String? ?? 'yetToStart';
      if (status == 'completed') continue;

      // Clear dueDate so the task is immediately visible in tomorrow's stream.
      batch.update(doc.reference, {
        'bucket': 'tomorrow',
        'status': 'moved',
        'dueDate': null,
      });
      count++;
    }

    if (count > 0) await batch.commit();
    return count;
  }
}
