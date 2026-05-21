import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String userId;
  final String name;
  final String colorHex; // e.g. "#5B8FBF"
  final int order;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorHex,
    required this.order,
  });

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }

  static String newId() => const Uuid().v4();

  Category copyWith({
    String? name,
    String? colorHex,
    int? order,
  }) =>
      Category(
        id: id,
        userId: userId,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
        order: order ?? this.order,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'colorHex': colorHex,
        'order': order,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        colorHex: map['colorHex'] as String? ?? '#888888',
        order: map['order'] as int? ?? 0,
      );
}
