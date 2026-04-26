import 'dart:math';

import '../models/food_product.dart';
import 'food_product_repository.dart';
import 'menu_balance.dart';

/// Одна строка продукта в приёме пищи (для PDF и детализации).
class MenuProductLine {
  const MenuProductLine({
    required this.name,
    required this.grams,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.kcal,
  });

  final String name;
  final int grams;
  final int proteinG;
  final int fatG;
  final int carbG;
  final int kcal;
}

class MenuRow {
  MenuRow({
    required this.title,
    required this.products,
    required this.grams,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.kcal,
    this.items = const [],
  });

  final String title;
  final String products;
  final String grams;
  final int proteinG;
  final int fatG;
  final int carbG;
  final int kcal;
  /// Покомпонентно по продуктам; если пусто — в PDF выводится сводно.
  final List<MenuProductLine> items;
}

class GeneratedMenu {
  GeneratedMenu({
    required this.rows,
    required this.targetKcal,
    required this.totalKcal,
    required this.totalProteinG,
    required this.totalFatG,
    required this.totalCarbG,
  });

  final List<MenuRow> rows;
  final int targetKcal;
  final int totalKcal;
  final int totalProteinG;
  final int totalFatG;
  final int totalCarbG;
}

class DailyMenuGenerator {
  DailyMenuGenerator(this._repo);

  final FoodProductRepository _repo;

  /// Порядок и доли ккал по приёмам (для «Что поесть» и плана).
  static const List<String> mealOrder = <String>[
    'Завтрак',
    'Второй завтрак',
    'Обед',
    'Полдник',
    'Ужин',
    'Перед сном',
  ];
  static const Map<String, double> mealKcalShare = <String, double>{
    'Завтрак': 0.19,
    'Второй завтрак': 0.12,
    'Обед': 0.30,
    'Полдник': 0.12,
    'Ужин': 0.20,
    'Перед сном': 0.07,
  };

  FoodProduct _pick(
    List<FoodProduct> pool,
    int salt,
  ) {
    if (pool.isEmpty) {
      throw StateError('empty product pool');
    }
    return pool[salt % pool.length];
  }

  /// [seed] — вариация подбора (кнопка «Обновить план»).
  Future<GeneratedMenu> build({
    required int targetKcal,
    int seed = 0,
  }) async {
    final all = await _repo.loadAll();
    if (all.isEmpty) {
      return GeneratedMenu(
        rows: [],
        targetKcal: targetKcal,
        totalKcal: 0,
        totalProteinG: 0,
        totalFatG: 0,
        totalCarbG: 0,
      );
    }
    var salt = (Random(seed).nextInt(0x0fffffff) ^ seed) & 0x7fffffff;
    int bump() {
      salt = (salt * 17 + 13) & 0x7fffffff;
      return salt;
    }

    List<FoodProduct> pool(
      List<String> tags, {
      List<String> ids = const [],
    }) {
      var t = all.where((e) => tags.contains(e.tag)).toList();
      if (t.isEmpty) {
        for (final id in ids) {
          for (final e in all) {
            if (e.id == id) {
              t.add(e);
            }
          }
        }
      }
      if (t.isEmpty) {
        t = List<FoodProduct>.from(all);
      }
      t.sort(
        (a, b) => (a.id.hashCode ^ salt).compareTo(b.id.hashCode ^ salt),
      );
      return t;
    }

    final pBreakfast = pool(['breakfast', 'dairy', 'fruit'], ids: const ['oats', 'cottage_5', 'banana', 'apple']);
    final pProtein = pool(['protein', 'lunch'], ids: const ['egg', 'chicken_breast', 'beefLean', 'red_fish', 'white_fish', 'cottage_5', 'cottage_5']);
    final pCarb = pool(['carb', 'breakfast'], ids: const ['buckwheat_dry', 'rice_dry', 'oats', 'pasta_dry', 'potato']);
    final pVeg = pool(['veg'], ids: const ['salad_mix', 'cucumber']);
    final pFat = pool(['fat'], ids: const ['olive_oil', 'almonds']);
    final pDairy = pool(['dairy', 'breakfast'], ids: const ['cottage_5', 'greek_yog', 'milk_20', 'cottage_5']);
    final pFruit = pool(['fruit'], ids: const ['banana', 'apple']);
    final pShake = pool(['protein', 'dairy', 'breakfast', 'fruit'], ids: const ['whey_protein', 'cottage_5', 'greek_yog', 'banana', 'apple', 'cottage_5']);

    final oats = _pick(pBreakfast, bump());
    final egg = _pick(pProtein, bump());
    final cottage = _pick(pDairy, bump());
    final apple = _pick(pFruit, bump());
    final chicken = _pick(pProtein, bump());
    final buckwheat = _pick(pCarb, bump());
    final salad = _pick(pVeg, bump());
    final oil = _pick(pFat, bump());
    final whey = _pick(pShake, bump());
    final banana = _pick(pFruit, bump());
    final whiteFish = _pick(pProtein, bump());

    final rows = <MenuRow>[];
    var tp = 0, tf = 0, tc = 0, tk = 0;

    void addRow(
      String title,
      List<(FoodProduct, int kcalPart)> parts,
    ) {
      final nameBits = <String>[];
      final gramBits = <String>[];
      final lineItems = <MenuProductLine>[];
      var p0 = 0, f0 = 0, c0 = 0, k0 = 0;
      for (final (prod, kPart) in parts) {
        final g = _gramsForKcal(prod, kPart);
        nameBits.add(prod.name);
        gramBits.add('$g');
        final pp = prod.proteinForGrams(g);
        final ff = prod.fatForGrams(g);
        final cc = prod.carbsForGrams(g);
        final kk = prod.kcalForGrams(g);
        p0 += pp;
        f0 += ff;
        c0 += cc;
        k0 += kk;
        lineItems.add(
          MenuProductLine(
            name: prod.name,
            grams: g,
            proteinG: pp,
            fatG: ff,
            carbG: cc,
            kcal: kk,
          ),
        );
      }
      rows.add(
        MenuRow(
          title: title,
          products: nameBits.join(', '),
          grams: gramBits.join('/'),
          proteinG: p0,
          fatG: f0,
          carbG: c0,
          kcal: k0,
          items: lineItems,
        ),
      );
      tp += p0;
      tf += f0;
      tc += c0;
      tk += k0;
    }

    for (final key in mealOrder) {
      final share = mealKcalShare[key]!;
      final mealK = (targetKcal * share).round();
      if (mealK < 50) {
        continue;
      }
      if (key == 'Завтрак') {
        final a = (mealK * 0.55).round();
        addRow('Завтрак', [(oats, a), (egg, mealK - a)]);
      } else if (key == 'Второй завтрак') {
        final a = (mealK * 0.6).round();
        addRow('Второй завтрак', [(cottage, a), (apple, mealK - a)]);
      } else if (key == 'Обед') {
        final a = (mealK * 0.42).round();
        final b = (mealK * 0.33).round();
        final r0 = mealK - a - b;
        final c0 = (r0 * 0.72).round();
        final d0 = r0 - c0;
        addRow('Обед', [(chicken, a), (buckwheat, b), (salad, c0), (oil, d0)]);
      } else if (key == 'Полдник') {
        final a = (mealK * 0.6).round();
        addRow('Полдник', [(whey, a), (banana, mealK - a)]);
      } else if (key == 'Ужин') {
        final a = (mealK * 0.55).round();
        final r1 = mealK - a;
        final s0 = (r1 * 0.68).round();
        addRow('Ужин', [(whiteFish, a), (salad, s0), (oil, r1 - s0)]);
      } else if (key == 'Перед сном') {
        final a = (mealK * 0.78).round();
        addRow('Перед сном', [(cottage, a), (oil, mealK - a)]);
      }
    }

    var out = GeneratedMenu(
      rows: rows,
      targetKcal: targetKcal,
      totalKcal: tk,
      totalProteinG: tp,
      totalFatG: tf,
      totalCarbG: tc,
    );
    out = MenuBalance.scaleToTarget(out, targetKcal);
    return out;
  }

  int _gramsForKcal(FoodProduct p, int kcal) {
    if (p.kcalPer100g <= 0) {
      return 0;
    }
    var g = (kcal * 100.0 / p.kcalPer100g).round();
    if (p.tag == 'fat' || p.id == 'olive_oil') {
      g = g.clamp(5, 25);
    } else {
      g = g.clamp(20, 500);
    }
    return g;
  }

  /// Один приём пищи (для «Что поесть») — новый [seed] даёт другой набор продуктов.
  Future<MenuRow?> buildSingleMeal({
    required String mealKey,
    required int mealKcal,
    int seed = 0,
  }) async {
    if (mealKcal < 50) {
      return null;
    }
    final all = await _repo.loadAll();
    if (all.isEmpty) {
      return null;
    }
    var salt = (Random(seed).nextInt(0x0fffffff) ^ seed) & 0x7fffffff;
    int bump() {
      salt = (salt * 17 + 13) & 0x7fffffff;
      return salt;
    }

    List<FoodProduct> pool(
      List<String> tags, {
      List<String> ids = const [],
    }) {
      var t = all.where((e) => tags.contains(e.tag)).toList();
      if (t.isEmpty) {
        for (final id in ids) {
          for (final e in all) {
            if (e.id == id) {
              t.add(e);
            }
          }
        }
      }
      if (t.isEmpty) {
        t = List<FoodProduct>.from(all);
      }
      t.sort(
        (a, b) => (a.id.hashCode ^ salt).compareTo(b.id.hashCode ^ salt),
      );
      return t;
    }

    final pBreakfast = pool(['breakfast', 'dairy', 'fruit'], ids: const ['oats', 'cottage_5', 'banana', 'apple']);
    final pProtein = pool(['protein', 'lunch'], ids: const ['egg', 'chicken_breast', 'beefLean', 'red_fish', 'white_fish', 'cottage_5', 'cottage_5']);
    final pCarb = pool(['carb', 'breakfast'], ids: const ['buckwheat_dry', 'rice_dry', 'oats', 'pasta_dry', 'potato']);
    final pVeg = pool(['veg'], ids: const ['salad_mix', 'cucumber']);
    final pFat = pool(['fat'], ids: const ['olive_oil', 'almonds']);
    final pDairy = pool(['dairy', 'breakfast'], ids: const ['cottage_5', 'greek_yog', 'milk_20', 'cottage_5']);
    final pFruit = pool(['fruit'], ids: const ['banana', 'apple']);
    final pShake = pool(['protein', 'dairy', 'breakfast', 'fruit'], ids: const ['whey_protein', 'cottage_5', 'greek_yog', 'banana', 'apple', 'cottage_5']);

    final oats = _pick(pBreakfast, bump());
    final egg = _pick(pProtein, bump());
    final cottage = _pick(pDairy, bump());
    final apple = _pick(pFruit, bump());
    final chicken = _pick(pProtein, bump());
    final buckwheat = _pick(pCarb, bump());
    final salad = _pick(pVeg, bump());
    final oil = _pick(pFat, bump());
    final whey = _pick(pShake, bump());
    final banana = _pick(pFruit, bump());
    final whiteFish = _pick(pProtein, bump());

    final mealK = mealKcal;
    final List<(FoodProduct, int)> parts;
    if (mealKey == 'Завтрак') {
      final a = (mealK * 0.55).round();
      parts = [(oats, a), (egg, mealK - a)];
    } else if (mealKey == 'Второй завтрак') {
      final a = (mealK * 0.6).round();
      parts = [(cottage, a), (apple, mealK - a)];
    } else if (mealKey == 'Обед') {
      final a = (mealK * 0.42).round();
      final b = (mealK * 0.33).round();
      final r0 = mealK - a - b;
      final c0 = (r0 * 0.72).round();
      final d0 = r0 - c0;
      parts = [(chicken, a), (buckwheat, b), (salad, c0), (oil, d0)];
    } else if (mealKey == 'Полдник') {
      final a = (mealK * 0.6).round();
      parts = [(whey, a), (banana, mealK - a)];
    } else if (mealKey == 'Ужин') {
      final a = (mealK * 0.55).round();
      final r1 = mealK - a;
      final s0 = (r1 * 0.68).round();
      parts = [(whiteFish, a), (salad, s0), (oil, r1 - s0)];
    } else if (mealKey == 'Перед сном') {
      final a = (mealK * 0.78).round();
      parts = [(cottage, a), (oil, mealK - a)];
    } else {
      return null;
    }
    return _oneMenuRowFromParts(mealKey, parts);
  }

  MenuRow _oneMenuRowFromParts(
    String title,
    List<(FoodProduct, int)> parts,
  ) {
    final nameBits = <String>[];
    final gramBits = <String>[];
    final lineItems = <MenuProductLine>[];
    var p0 = 0, f0 = 0, c0 = 0, k0 = 0;
    for (final (prod, kPart) in parts) {
      final g = _gramsForKcal(prod, kPart);
      nameBits.add(prod.name);
      gramBits.add('$g');
      final pp = prod.proteinForGrams(g);
      final ff = prod.fatForGrams(g);
      final cc = prod.carbsForGrams(g);
      final kk = prod.kcalForGrams(g);
      p0 += pp;
      f0 += ff;
      c0 += cc;
      k0 += kk;
      lineItems.add(
        MenuProductLine(
          name: prod.name,
          grams: g,
          proteinG: pp,
          fatG: ff,
          carbG: cc,
          kcal: kk,
        ),
      );
    }
    return MenuRow(
      title: title,
      products: nameBits.join(', '),
      grams: gramBits.join('/'),
      proteinG: p0,
      fatG: f0,
      carbG: c0,
      kcal: k0,
      items: lineItems,
    );
  }
}
