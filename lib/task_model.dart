import 'dart:convert';

class Task {
  final String id;
  final String title;
  final String? description;
  final String? notes;
  final bool isComplete;
  final String? priority;
  final String? createdTime;
  final String? createdDate;
  final String? dueDate;
  final String? category;
  final bool isNotified;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.notes,
    this.isComplete = false,
    this.priority,
    this.createdTime,
    this.createdDate,
    this.dueDate,
    this.category,
    this.isNotified = false, // Default to false
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? notes,
    bool? isComplete,
    String? priority,
    String? createdTime,
    String? createdDate,
    String? dueDate,
    String? category,
    bool? isNotified,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      isComplete: isComplete ?? this.isComplete,
      priority: priority ?? this.priority,
      createdTime: createdTime ?? this.createdTime,
      createdDate: createdDate ?? this.createdDate,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      isNotified: isNotified ?? this.isNotified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'notes': notes,
      'isComplete': isComplete,
      'priority': priority,
      'createdTime': createdTime,
      'createdDate': createdDate,
      'dueDate': dueDate,
      'category': category,
      'isNotified': isNotified,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      notes: map['notes'],
      isComplete: map['isComplete'] ?? false,
      priority: map['priority'],
      createdTime: map['createdTime'],
      createdDate: map['createdDate'],
      dueDate: map['dueDate'],
      category: map['category'],
      isNotified: map['isNotified'] ?? false, // Handle legacy tasks without this field
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}