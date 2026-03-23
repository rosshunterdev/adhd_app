class Task {
  final String id;
  final String title;
  final String bucket;
  final DateTime? deadline;
  final DateTime? dueDate;
  final DateTime? notificationTime;
  final bool isComplete;
  final List<String> steps;
  final List<String> completedSteps;
  final int priority;
  final int manualOrder;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.bucket = 'now',
    this.deadline,
    this.dueDate,
    this.notificationTime,
    this.isComplete = false,
    List<String>? steps,
    List<String>? completedSteps,
    this.priority = 0,
    this.manualOrder = 0,
    required this.createdAt,
  })  : steps = steps ?? [],
        completedSteps = completedSteps ?? [];

  Task copyWith({
    String? id,
    String? title,
    String? bucket,
    DateTime? deadline,
    DateTime? dueDate,
    DateTime? notificationTime,
    bool? isComplete,
    List<String>? steps,
    List<String>? completedSteps,
    int? priority,
    int? manualOrder,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      bucket: bucket ?? this.bucket,
      deadline: deadline ?? this.deadline,
      dueDate: dueDate ?? this.dueDate,
      notificationTime: notificationTime ?? this.notificationTime,
      isComplete: isComplete ?? this.isComplete,
      steps: steps ?? this.steps,
      completedSteps: completedSteps ?? this.completedSteps,
      priority: priority ?? this.priority,
      manualOrder: manualOrder ?? this.manualOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'bucket': bucket,
      'deadline': deadline?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'notificationTime': notificationTime?.toIso8601String(),
      'isComplete': isComplete,
      'steps': steps,
      'completedSteps': completedSteps,
      'priority': priority,
      'manualOrder': manualOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      bucket: map['bucket'] as String? ?? 'now',
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      notificationTime: map['notificationTime'] != null
          ? DateTime.parse(map['notificationTime'] as String)
          : null,
      isComplete: map['isComplete'] as bool? ?? false,
      steps: List<String>.from(map['steps'] as List? ?? []),
      completedSteps: List<String>.from(map['completedSteps'] as List? ?? []),
      priority: map['priority'] as int? ?? 0,
      manualOrder: map['manualOrder'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
