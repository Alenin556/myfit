import 'package:flutter/foundation.dart';

@immutable
class FoodProduct {
  const FoodProduct({
    required this.id,
    required this.name,
    required this.kcalPer100g,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    this.tag = '',
  });

  final String id;
  final String name;
  final double kcalPer100g;
  final double proteinG;
  final double fatG;
  final double carbG;
  final String tag;

  int kcalForGrams(int grams) {
    return (grams * kcalPer100g / 100.0).round();
  }

  int proteinForGrams(int grams) {
    return (proteinG * grams / 100.0).round();
  }

  int fatForGrams(int grams) {
    return (fatG * grams / 100.0).round();
  }

  int carbsForGrams(int grams) {
    return (carbG * grams / 100.0).round();
  }

  static FoodProduct fromJson(Map<String, dynamic> j) {
    return FoodProduct(
      id: j['id'] as String,
      name: j['name'] as String,
      kcalPer100g: (j['kcalPer100g'] as num).toDouble(),
      proteinG: (j['proteinG'] as num).toDouble(),
      fatG: (j['fatG'] as num).toDouble(),
      carbG: (j['carbG'] as num).toDouble(),
      tag: j['tag'] as String? ?? '',
    );
  }
}
