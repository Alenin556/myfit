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

/// Рыба и морепродукты — не сочетать с молоком/завтраком.
const _seafoodIds = <String>{
  'red_fish',
  'white_fish',
  'cod_fillet',
  'tuna_canned',
  'shrimps',
};

List<FoodProduct> _productPool(
  List<FoodProduct> all,
  int sortSalt, {
  required List<String> tags,
  List<String> ids = const [],
  Set<String> excludeIds = const {},
}) {
  var t = all
      .where(
        (e) => tags.contains(e.tag) && !excludeIds.contains(e.id),
      )
      .toList();
  if (t.isEmpty) {
    for (final e in all) {
      if (ids.contains(e.id) && !excludeIds.contains(e.id)) {
        t.add(e);
      }
    }
  }
  if (t.isEmpty) {
    t = List<FoodProduct>.from(all);
  }
  t.sort(
    (a, b) =>
        (a.id.hashCode ^ sortSalt).compareTo(b.id.hashCode ^ sortSalt),
  );
  return t;
}

/// Готовый набор продуктов на день (один [seed] / один вызов [bump]).
class _DayPicks {
  const _DayPicks({
    required this.mornCarb,
    required this.mornProt,
    required this.gainerB,
    required this.dairy2,
    required this.fruit1,
    required this.sport2,
    required this.lunchM,
    required this.lunchC,
    required this.lunchSalad,
    required this.lunchOil,
    required this.lunchIso,
    required this.snackP,
    required this.snackNut,
    required this.fruitSn,
    required this.sportSn,
    required this.fishD,
    required this.salD,
    required this.oilD,
    required this.nightD,
    required this.nightN,
    required this.nightS,
  });

  final FoodProduct mornCarb;
  final FoodProduct mornProt;
  final FoodProduct gainerB;
  final FoodProduct dairy2;
  final FoodProduct fruit1;
  final FoodProduct sport2;
  final FoodProduct lunchM;
  final FoodProduct lunchC;
  final FoodProduct lunchSalad;
  final FoodProduct lunchOil;
  final FoodProduct lunchIso;
  final FoodProduct snackP;
  final FoodProduct snackNut;
  final FoodProduct fruitSn;
  final FoodProduct sportSn;
  final FoodProduct fishD;
  final FoodProduct salD;
  final FoodProduct oilD;
  final FoodProduct nightD;
  final FoodProduct nightN;
  final FoodProduct nightS;
}

_DayPicks _dayPicks(
  List<FoodProduct> all,
  int sortSalt,
  int Function() bump,
  FoodProduct Function(List<FoodProduct>, int) pick,
) {
  const carbIds = <String>[
    'oats', 'granola', 'rye_bread', 'wheat_bread', 'buckwheat_dry', 'rice_dry',
    'pasta_dry', 'potato', 'sweet_potato', 'quinoa_dry', 'bulgur_dry',
  ];
  const meatIds = <String>[
    'egg', 'chicken_breast', 'turkey_breast', 'beefLean', 'pork_tenderloin',
    'cottage_5', 'cottage_2', 'cottage_9', 'cottage_cheese_grainy',
  ];
  const fishDinnerIds = <String>[
    'red_fish', 'white_fish', 'cod_fillet', 'tuna_canned', 'shrimps',
  ];
  const dairyIds = <String>[
    'cottage_5', 'greek_yog', 'milk_20', 'kefir_1', 'ryazhenka_4', 'skyr',
    'ricotta', 'natural_yogurt', 'cottage_2', 'brynza',
  ];
  const fruitIds = <String>[
    'banana', 'apple', 'kiwi', 'orange', 'pear', 'strawberry', 'blueberry', 'plum',
  ];
  const nutIds = <String>[
    'almonds', 'walnuts', 'hazelnuts', 'cashews', 'pistachios', 'peanut_butter',
    'sunflower_seeds',
  ];
  const snackProteinIds = <String>[
    'whey_protein', 'casein_slow', 'protein_bar', 'cottage_5', 'gainer_50', 'cottage_9',
  ];
  const nightProteinIds = <String>[
    'casein_slow', 'cottage_5', 'greek_yog', 'kefir_1', 'whey_protein', 'skyr', 'ricotta',
  ];
  const sportsIds = <String>[
    'gainer_50', 'isotonic_sport', 'bcaa_sport', 'energy_gel_sport', 'eaa_sport', 'whey_protein',
  ];

  final pMornCarb = _productPool(
    all,
    sortSalt,
    tags: const ['breakfast', 'carb'],
    ids: carbIds,
  );
  final pMornProtein = _productPool(
    all,
    sortSalt,
    tags: const ['protein', 'lunch', 'breakfast'],
    ids: meatIds,
    excludeIds: _seafoodIds,
  );
  final pGainer = _productPool(
    all,
    sortSalt,
    tags: const ['sports'],
    ids: const ['gainer_50'],
  );
  final pDairy2 = _productPool(
    all,
    sortSalt,
    tags: const ['dairy', 'breakfast'],
    ids: dairyIds,
  );
  final pFruit = _productPool(
    all,
    sortSalt,
    tags: const ['fruit'],
    ids: fruitIds,
  );
  final pSports2 = _productPool(
    all,
    sortSalt,
    tags: const ['sports', 'protein'],
    ids: const ['eaa_sport', 'bcaa_sport', 'gainer_50', 'whey_protein', 'isotonic_sport'],
  );
  final pLunchMeat = _productPool(
    all,
    sortSalt,
    tags: const ['lunch', 'protein'],
    ids: const [
      'chicken_breast', 'turkey_breast', 'beefLean', 'pork_tenderloin', 'egg',
      'cottage_5', 'cottage_9',
    ],
  );
  final pLunchCarb = _productPool(
    all,
    sortSalt,
    tags: const ['carb', 'breakfast'],
    ids: carbIds,
  );
  final pVeg = _productPool(
    all,
    sortSalt,
    tags: const ['veg'],
    ids: const ['salad_mix', 'cucumber', 'tomato', 'broccoli', 'pepper_sweet', 'cabbage_white'],
  );
  final pFat = _productPool(
    all,
    sortSalt,
    tags: const ['fat'],
    ids: const ['olive_oil', 'almonds', 'flax_oil'],
  );
  final pIsotonic = _productPool(
    all,
    sortSalt,
    tags: const ['sports'],
    ids: const ['isotonic_sport', 'bcaa_sport'],
  );
  final pSnackP = _productPool(
    all,
    sortSalt,
    tags: const ['protein', 'dairy', 'sports', 'breakfast'],
    ids: snackProteinIds,
  );
  final pNuts = _productPool(
    all,
    sortSalt,
    tags: const ['fat', 'sports'],
    ids: nutIds,
  );
  final pFruit2 = _productPool(
    all,
    sortSalt,
    tags: const ['fruit'],
    ids: fruitIds,
  );
  final pSportSnack = _productPool(
    all,
    sortSalt,
    tags: const ['sports', 'protein'],
    ids: const ['whey_protein', 'bcaa_sport', 'eaa_sport', 'gainer_50', 'energy_gel_sport'],
  );
  final pFishD = _productPool(
    all,
    sortSalt,
    tags: const ['lunch', 'protein'],
    ids: fishDinnerIds,
  );
  final pNightDairy = _productPool(
    all,
    sortSalt,
    tags: const ['dairy', 'protein'],
    ids: nightProteinIds,
  );
  final pNightNuts = _productPool(
    all,
    sortSalt,
    tags: const ['fat'],
    ids: nutIds,
  );
  final pNightSport = _productPool(
    all,
    sortSalt,
    tags: const ['sports', 'protein'],
    ids: const ['casein_slow', 'whey_protein', 'bcaa_sport', 'eaa_sport', 'gainer_50'],
  );
  final pSports = _productPool(
    all,
    sortSalt,
    tags: const [
      'sports', 'protein', 'dairy', 'carb', 'breakfast', 'lunch', 'fruit', 'fat', 'veg',
    ],
    ids: sportsIds,
  );

  final gBpick = pGainer.isNotEmpty ? pick(pGainer, bump()) : pick(pSports, bump());
  final s2 = pSports2.isNotEmpty ? pick(pSports2, bump()) : pick(pSports, bump());
  final lIso = pIsotonic.isNotEmpty ? pick(pIsotonic, bump()) : pick(pSports, bump());
  final sS = pSportSnack.isNotEmpty ? pick(pSportSnack, bump()) : pick(pSports, bump());
  final nS = pNightSport.isNotEmpty ? pick(pNightSport, bump()) : pick(pSports, bump());

  return _DayPicks(
    mornCarb: pick(pMornCarb, bump()),
    mornProt: pick(pMornProtein, bump()),
    gainerB: gBpick,
    dairy2: pick(pDairy2, bump()),
    fruit1: pick(pFruit, bump()),
    sport2: s2,
    lunchM: pick(pLunchMeat, bump()),
    lunchC: pick(pLunchCarb, bump()),
    lunchSalad: pick(pVeg, bump()),
    lunchOil: pick(pFat, bump()),
    lunchIso: lIso,
    snackP: pick(pSnackP, bump()),
    snackNut: pick(pNuts, bump()),
    fruitSn: pick(pFruit2, bump()),
    sportSn: sS,
    fishD: pick(pFishD, bump()),
    salD: pick(pVeg, bump()),
    oilD: pick(pFat, bump()),
    nightD: pick(pNightDairy, bump()),
    nightN: pick(pNightNuts, bump()),
    nightS: nS,
  );
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
    final sortSalt = salt;
    int bump() {
      salt = (salt * 17 + 13) & 0x7fffffff;
      return salt;
    }

    final d = _dayPicks(all, sortSalt, bump, _pick);

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
        final a = (mealK * 0.48).round();
        final b = (mealK * 0.35).round();
        final c = mealK - a - b;
        addRow('Завтрак', [(d.mornCarb, a), (d.mornProt, b), (d.gainerB, c)]);
      } else if (key == 'Второй завтрак') {
        final a = (mealK * 0.58).round();
        final b = (mealK * 0.30).round();
        final c = mealK - a - b;
        addRow('Второй завтрак', [(d.dairy2, a), (d.fruit1, b), (d.sport2, c)]);
      } else if (key == 'Обед') {
        final a = (mealK * 0.40).round();
        final b = (mealK * 0.28).round();
        final r0 = mealK - a - b;
        final c0 = (r0 * 0.58).round();
        final d0 = (r0 * 0.32).round();
        final e0 = r0 - c0 - d0;
        addRow(
          'Обед',
          [
            (d.lunchM, a),
            (d.lunchC, b),
            (d.lunchSalad, c0),
            (d.lunchOil, d0),
            (d.lunchIso, e0),
          ],
        );
      } else if (key == 'Полдник') {
        final a = (mealK * 0.40).round();
        final b = (mealK * 0.30).round();
        final c = (mealK * 0.22).round();
        final p4 = mealK - a - b - c;
        addRow(
          'Полдник',
          [(d.snackP, a), (d.snackNut, b), (d.fruitSn, c), (d.sportSn, p4)],
        );
      } else if (key == 'Ужин') {
        final a = (mealK * 0.52).round();
        final r1 = mealK - a;
        final s0 = (r1 * 0.64).round();
        addRow('Ужин', [(d.fishD, a), (d.salD, s0), (d.oilD, r1 - s0)]);
      } else if (key == 'Перед сном') {
        final a = (mealK * 0.60).round();
        final b = (mealK * 0.22).round();
        final c = mealK - a - b;
        addRow('Перед сном', [(d.nightD, a), (d.nightN, b), (d.nightS, c)]);
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
    } else if (p.tag == 'sports' && p.kcalPer100g < 50) {
      g = g.clamp(100, 600);
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
    final sortSalt = salt;
    int bump() {
      salt = (salt * 17 + 13) & 0x7fffffff;
      return salt;
    }
    final d = _dayPicks(all, sortSalt, bump, _pick);
    final mealK = mealKcal;
    final List<(FoodProduct, int)> parts;
    if (mealKey == 'Завтрак') {
      final a = (mealK * 0.48).round();
      final b = (mealK * 0.35).round();
      final c = mealK - a - b;
      parts = [(d.mornCarb, a), (d.mornProt, b), (d.gainerB, c)];
    } else if (mealKey == 'Второй завтрак') {
      final a = (mealK * 0.58).round();
      final b = (mealK * 0.30).round();
      final c = mealK - a - b;
      parts = [(d.dairy2, a), (d.fruit1, b), (d.sport2, c)];
    } else if (mealKey == 'Обед') {
      final a = (mealK * 0.40).round();
      final b = (mealK * 0.28).round();
      final r0 = mealK - a - b;
      final c0 = (r0 * 0.58).round();
      final d0 = (r0 * 0.32).round();
      final e0 = r0 - c0 - d0;
      parts = [
        (d.lunchM, a),
        (d.lunchC, b),
        (d.lunchSalad, c0),
        (d.lunchOil, d0),
        (d.lunchIso, e0),
      ];
    } else if (mealKey == 'Полдник') {
      final a = (mealK * 0.40).round();
      final b = (mealK * 0.30).round();
      final c = (mealK * 0.22).round();
      final p4 = mealK - a - b - c;
      parts = [(d.snackP, a), (d.snackNut, b), (d.fruitSn, c), (d.sportSn, p4)];
    } else if (mealKey == 'Ужин') {
      final a = (mealK * 0.52).round();
      final r1 = mealK - a;
      final s0 = (r1 * 0.64).round();
      parts = [(d.fishD, a), (d.salD, s0), (d.oilD, r1 - s0)];
    } else if (mealKey == 'Перед сном') {
      final a = (mealK * 0.60).round();
      final b = (mealK * 0.22).round();
      final c = mealK - a - b;
      parts = [(d.nightD, a), (d.nightN, b), (d.nightS, c)];
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
