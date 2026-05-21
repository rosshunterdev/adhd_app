import 'package:uuid/uuid.dart';

import 'step.dart';

enum TaskStatus { yetToStart, inProgress, completed, moved }

extension TaskStatusX on TaskStatus {
  static TaskStatus fromString(String v) => TaskStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TaskStatus.yetToStart,
      );
}

class Task {
  final String id;
  final String userId;
  final String title;

  /// 'today' | 'tomorrow' | 'goals'
  final String bucket;
  final String categoryId;
  final TaskStatus status;

  /// Long-standing goal with no deadline pressure — lives in the goals section.
  final bool isGoal;
  final DateTime? deadline;

  /// Snooze gate: task is hidden from its bucket stream until this date passes.
  final DateTime? dueDate;
  final DateTime? notificationTime;

  /// Time-block start time (date portion reflects today when set from UI).
  final DateTime? scheduledTime;

  /// Duration in minutes for the time block.
  final int? durationMinutes;

  final List<Step> steps;
  final int priority;
  final int manualOrder;
  final DateTime createdAt;

  int get completedStepCount => steps.where((s) => s.isCompleted).length;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.bucket = 'today',
    this.categoryId = 'life',
    this.status = TaskStatus.yetToStart,
    this.isGoal = false,
    this.deadline,
    this.dueDate,
    this.notificationTime,
    this.scheduledTime,
    this.durationMinutes,
    List<Step>? steps,
    this.priority = 0,
    this.manualOrder = 0,
    required this.createdAt,
  }) : steps = steps ?? const [];

  static String newId() => const Uuid().v4();

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? bucket,
    String? categoryId,
    TaskStatus? status,
    bool? isGoal,
    DateTime? deadline,
    DateTime? dueDate,
    DateTime? notificationTime,
    DateTime? scheduledTime,
    int? durationMinutes,
    List<Step>? steps,
    int? priority,
    int? manualOrder,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      bucket: bucket ?? this.bucket,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      isGoal: isGoal ?? this.isGoal,
      deadline: deadline ?? this.deadline,
      dueDate: dueDate ?? this.dueDate,
      notificationTime: notificationTime ?? this.notificationTime,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      steps: steps ?? this.steps,
      priority: priority ?? this.priority,
      manualOrder: manualOrder ?? this.manualOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'bucket': bucket,
        'categoryId': categoryId,
        'status': status.name,
        'isGoal': isGoal,
        'deadline': deadline?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'notificationTime': notificationTime?.toIso8601String(),
        'scheduledTime': scheduledTime?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'steps': steps.map((s) => s.toMap()).toList(),
        'priority': priority,
        'manualOrder': manualOrder,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as String,
        userId: map['userId'] as String? ?? '',
        title: map['title'] as String,
        bucket: map['bucket'] as String? ?? 'today',
        categoryId: map['categoryId'] as String? ?? map['category'] as String? ?? 'life',
        status:
            TaskStatusX.fromString(map['status'] as String? ?? 'yetToStart'),
        isGoal: map['isGoal'] as bool? ?? false,
        deadline: map['deadline'] != null
            ? DateTime.parse(map['deadline'] as String)
            : null,
        dueDate: map['dueDate'] != null
            ? DateTime.parse(map['dueDate'] as String)
            : null,
        notificationTime: map['notificationTime'] != null
            ? DateTime.parse(map['notificationTime'] as String)
            : null,
        scheduledTime: map['scheduledTime'] != null
            ? DateTime.parse(map['scheduledTime'] as String)
            : null,
        durationMinutes: map['durationMinutes'] as int?,
        steps: (map['steps'] as List<dynamic>?)
                ?.map((s) => Step.fromMap(s as Map<String, dynamic>))
                .toList() ??
            [],
        priority: map['priority'] as int? ?? 0,
        manualOrder: map['manualOrder'] as int? ?? 0,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
