import 'package:uuid/uuid.dart';

class Step {
  final String id;
  final String title;
  final bool isCompleted;

  const Step({required this.id, required this.title, this.isCompleted = false});

  factory Step.create(String title) =>
      Step(id: const Uuid().v4(), title: title);

  Step copyWith({String? id, String? title, bool? isCompleted}) => Step(
        id: id ?? this.id,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory Step.fromMap(Map<String, dynamic> map) => Step(
        id: map['id'] as String? ?? const Uuid().v4(),
        title: map['title'] as String,
        isCompleted: map['isCompleted'] as bool? ?? false,
      );
}
