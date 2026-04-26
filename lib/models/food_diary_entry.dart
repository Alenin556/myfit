import 'package:flutter/foundation.dart';

import 'food_product.dart';

@immutable
class FoodDiaryEntry {
  const FoodDiaryEntry({
    required this.id,
    required this.productId,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
  });

  final String id;
  final String productId;
  final String name;
  final int grams;
  final int kcal;
  final int proteinG;
  final int fatG;
  final int carbG;

  static FoodDiaryEntry fromProduct(FoodProduct p, {required int grams, String? id}) {
    return FoodDiaryEntry(
      id: id ?? '${DateTime.now().microsecondsSinceEpoch}',
      productId: p.id,
      name: p.name,
      grams: grams,
      kcal: p.kcalForGrams(grams),
      proteinG: p.proteinForGrams(grams),
      fatG: p.fatForGrams(grams),
      carbG: p.carbsForGrams(grams),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'name': name,
        'grams': grams,
        'kcal': kcal,
        'proteinG': proteinG,
        'fatG': fatG,
        'carbG': carbG,
      };

  static FoodDiaryEntry fromJson(Map<String, dynamic> j) {
    return FoodDiaryEntry(
      id: j['id'] as String,
      productId: j['productId'] as String,
      name: j['name'] as String,
      grams: (j['grams'] as num).round(),
      kcal: (j['kcal'] as num).round(),
      proteinG: (j['proteinG'] as num).round(),
      fatG: (j['fatG'] as num).round(),
      carbG: (j['carbG'] as num).round(),
    );
  }
}
