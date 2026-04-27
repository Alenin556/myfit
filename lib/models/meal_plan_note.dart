import 'package:flutter/foundation.dart';

@immutable
class MealPlanNoteEntry {
  const MealPlanNoteEntry({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  static MealPlanNoteEntry fromJson(Map<String, dynamic> j) {
    return MealPlanNoteEntry(
      id: j['id'] as String,
      text: j['text'] as String,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
