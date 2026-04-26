import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/food_product.dart';

/// Локальная «база» продуктов из [assets/data/products.json].
/// При появлении внешнего API (например Open Food Facts) достаточно
/// реализовать тот же контракт [loadAll] / подменить выборку в [DailyMenuGenerator].
class FoodProductRepository {
  List<FoodProduct>? _cache;

  Future<List<FoodProduct>> loadAll() async {
    if (_cache != null) {
      return _cache!;
    }
    final s = await rootBundle.loadString('assets/data/products.json');
    final list = jsonDecode(s) as List<dynamic>;
    _cache = list
        .map((e) => FoodProduct.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return _cache!;
  }
}
