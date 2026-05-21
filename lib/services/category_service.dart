import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';

class CategoryService {
  final CollectionReference _cats =
      FirebaseFirestore.instance.collection('categories');

  Future<void> seedIfNeeded(String uid) async {
    final existing = await _cats
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    final defaults = [
      Category(id: 'webDev', userId: uid, name: 'Web Dev', colorHex: '#5B8FBF', order: 0),
      Category(id: 'appDev', userId: uid, name: 'App Dev', colorHex: '#9060BF', order: 1),
      Category(id: 'study', userId: uid, name: 'Study', colorHex: '#C49A45', order: 2),
      Category(id: 'work', userId: uid, name: 'Work', colorHex: '#BF6060', order: 3),
      Category(id: 'admin', userId: uid, name: 'Admin', colorHex: '#7A8A96', order: 4),
      Category(id: 'life', userId: uid, name: 'Life', colorHex: '#5B9E6E', order: 5),
      Category(id: 'music', userId: uid, name: 'Music', colorHex: '#BF7EA0', order: 6),
      Category(id: 'goals', userId: uid, name: 'Goals', colorHex: '#5BA8A0', order: 7),
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (final cat in defaults) {
      batch.set(_cats.doc(cat.id), cat.toMap());
    }
    await batch.commit();
  }
}
