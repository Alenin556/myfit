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

/// Протеин, гейнер, казеин, BCAA/EAA, изотоник — только **Полдник** или **Перед сном**,
/// и **не вместе** с молочными в одном приёме.
const _supplementProductIds = <String>{
  'whey_protein',
  'casein_slow',
  'protein_bar',
  'gainer_50',
  'bcaa_sport',
  'eaa_sport',
  'isotonic_sport',
};

List<FoodProduct> _menuCatalogNoGel(List<FoodProduct> all) {
  return all
      .where((e) => !e.name.toLowerCase().contains('гель'))
      .toList();
}

List<FoodProduct> _withoutSupplements(List<FoodProduct> all) {
  return all.where((e) => !_supplementProductIds.contains(e.id)).toList();
}

bool _isDairyProduct(FoodProduct e) {
  if (e.tag == 'dairy') {
    return true;
  }
  const ids = <String>{
    'cottage_5',
    'cottage_2',
    'cottage_9',
    'cottage_cheese_grainy',
    'syr_17',
    'brynza',
  };
  return ids.contains(e.id);
}

List<FoodProduct> _withoutDairyAndSupplements(List<FoodProduct> all) {
  return all
      .where(
        (e) => !_isDairyProduct(e) && !_supplementProductIds.contains(e.id),
      )
      .toList();
}

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
///
/// Завтрак — каша, яйца, орехи (+фрукт в части вариаций);
/// **второй завтрак** — злак/хлеб + фрукт, **без** молока и **без** спортдобавок;
/// **молочка** и **спортдобавки** — только **Полдник** и **Перед сном** (поздний приём);
/// в одном приёме: **либо** молоко, **либо** добавка.
/// Ужин — рыба + гарнир + масло.
class _DayPicks {
  const _DayPicks({
    required this.bfstPorridge,
    required this.bfstEgg,
    required this.bfstNuts,
    required this.bfstFruit,
    required this.secondCarb,
    required this.secondFruit,
    required this.lunchM,
    required this.lunchC,
    required this.lunchSalad,
    required this.lunchOil,
    required this.poludnikIsDairy,
    required this.cottage,
    required this.eveningDairy,
    required this.supp,
    required this.snackNut,
    required this.fruitSn,
    required this.fishD,
    required this.salD,
    required this.oilD,
    required this.nightN,
    required this.nightFruit,
  });

  final FoodProduct bfstPorridge;
  final FoodProduct bfstEgg;
  final FoodProduct bfstNuts;
  final FoodProduct bfstFruit;
  /// Гранола/хлеб, без молочки и спортпита.
  final FoodProduct secondCarb;
  final FoodProduct secondFruit;
  final FoodProduct lunchM;
  final FoodProduct lunchC;
  final FoodProduct lunchSalad;
  final FoodProduct lunchOil;
  /// true: полдник = творог, перед сном = добавка. false: наоборот.
  final bool poludnikIsDairy;
  final FoodProduct cottage;
  final FoodProduct eveningDairy;
  final FoodProduct supp;
  final FoodProduct snackNut;
  final FoodProduct fruitSn;
  final FoodProduct fishD;
  final FoodProduct salD;
  final FoodProduct oilD;
  final FoodProduct nightN;
  final FoodProduct nightFruit;
}

_DayPicks _dayPicks(
  List<FoodProduct> all,
  int sortSalt,
  int Function() bump,
  FoodProduct Function(List<FoodProduct>, int) pick,
) {
  final catalog = _menuCatalogNoGel(all);
  final baseNoSupp = _withoutSupplements(catalog);
  final noDairyNoSupp = _withoutDairyAndSupplements(catalog);

  const bfstPorridgeIds = <String>['oats', 'buckwheat_dry', 'millet_dry'];
  const carbIds = <String>[
    'oats', 'granola', 'rye_bread', 'wheat_bread', 'buckwheat_dry', 'millet_dry', 'barley_dry', 'rice_dry',
    'pasta_dry', 'potato', 'sweet_potato', 'quinoa_dry', 'bulgur_dry',
  ];
  const lunchMeatOnlyIds = <String>[
    'chicken_breast', 'turkey_breast', 'beefLean', 'pork_tenderloin',
  ];
  const fishDinnerIds = <String>[
    'red_fish', 'white_fish', 'cod_fillet', 'tuna_canned', 'shrimps',
  ];
  const cottageIds = <String>['cottage_5', 'cottage_2', 'cottage_9', 'cottage_cheese_grainy'];
  const fruitIds = <String>[
    'banana', 'apple', 'kiwi', 'orange', 'pear', 'strawberry', 'blueberry', 'plum',
  ];
  const nutIds = <String>[
    'almonds', 'walnuts', 'hazelnuts', 'cashews', 'pistachios', 'peanut_butter',
    'sunflower_seeds',
  ];
  const nightDairyIds = <String>[
    'cottage_5', 'cottage_2', 'cottage_9', 'cottage_cheese_grainy', 'greek_yog', 'kefir_1', 'skyr',
    'ricotta', 'natural_yogurt', 'milk_20', 'ryazhenka_4', 'brynza',
  ];
  const secondSnackCarbIds = <String>['granola', 'rye_bread', 'wheat_bread'];

  final pBfstPorridge = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['carb', 'breakfast'],
    ids: bfstPorridgeIds,
  );
  final pBfstEgg = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['protein', 'lunch', 'breakfast'],
    ids: const ['egg'],
    excludeIds: _seafoodIds,
  );
  final pBfstNuts = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['fat', 'sports'],
    ids: nutIds,
  );
  final pBfstFruit = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['fruit'],
    ids: fruitIds,
  );
  final pSecondCarb = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['carb', 'breakfast'],
    ids: secondSnackCarbIds,
  );
  final pProteinBar = _productPool(
    catalog,
    sortSalt,
    tags: const ['protein', 'sports'],
    ids: const ['protein_bar'],
  );
  final pWhey = _productPool(
    catalog,
    sortSalt,
    tags: const ['protein', 'dairy', 'lunch', 'breakfast', 'sports'],
    ids: const ['whey_protein'],
  );
  final pFruit1 = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['fruit'],
    ids: fruitIds,
  );
  final pFruit2 = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['fruit'],
    ids: fruitIds,
  );
  final pFruitNight = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['fruit'],
    ids: fruitIds,
  );
  final pLunchMeat = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['lunch', 'protein'],
    ids: lunchMeatOnlyIds,
  );
  final pLunchCarb = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['carb', 'breakfast'],
    ids: carbIds,
  );
  final pVeg = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['veg'],
    ids: const ['salad_mix', 'cucumber', 'tomato', 'broccoli', 'pepper_sweet', 'cabbage_white'],
  );
  final pFat = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['fat'],
    ids: const ['olive_oil', 'almonds', 'flax_oil'],
  );
  final pSnackCottage = _productPool(
    baseNoSupp,
    sortSalt,
    tags: const ['dairy', 'breakfast', 'protein'],
    ids: cottageIds,
  );
  final pNuts = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['fat', 'sports'],
    ids: nutIds,
  );
  final pFishD = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['lunch', 'protein'],
    ids: fishDinnerIds,
  );
  final pNightDairy = _productPool(
    baseNoSupp,
    sortSalt,
    tags: const ['dairy', 'protein'],
    ids: nightDairyIds,
  );
  final pNightNuts = _productPool(
    noDairyNoSupp,
    sortSalt,
    tags: const ['fat'],
    ids: nutIds,
  );

  // Батончик / протеин — один сухой сид на [supp]; в паре с молоком — только в полдник+ночь.
  final useBar = (sortSalt & 1) == 0;
  final supp = useBar && pProteinBar.isNotEmpty
      ? pick(pProteinBar, bump())
      : (pWhey.isNotEmpty ? pick(pWhey, bump()) : pick(pProteinBar, bump()));
  final poludnikIsDairy = (sortSalt & 0x8) == 0;

  return _DayPicks(
    bfstPorridge: pick(pBfstPorridge, bump()),
    bfstEgg: pick(pBfstEgg, bump()),
    bfstNuts: pick(pBfstNuts, bump()),
    bfstFruit: pick(pBfstFruit, bump()),
    secondCarb: pick(pSecondCarb, bump()),
    secondFruit: pick(pFruit1, bump()),
    lunchM: pick(pLunchMeat, bump()),
    lunchC: pick(pLunchCarb, bump()),
    lunchSalad: pick(pVeg, bump()),
    lunchOil: pick(pFat, bump()),
    poludnikIsDairy: poludnikIsDairy,
    cottage: pick(pSnackCottage, bump()),
    eveningDairy: pick(pNightDairy, bump()),
    supp: supp,
    snackNut: pick(pNuts, bump()),
    fruitSn: pick(pFruit2, bump()),
    fishD: pick(pFishD, bump()),
    salD: pick(pVeg, bump()),
    oilD: pick(pFat, bump()),
    nightN: pick(pNightNuts, bump()),
    nightFruit: pick(pFruitNight, bump()),
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
        final withFruit = ((sortSalt >> 2) & 1) == 0;
        if (withFruit) {
          final a = (mealK * 0.35).round();
          final b = (mealK * 0.25).round();
          final c = (mealK * 0.25).round();
          final r = mealK - a - b - c;
          addRow('Завтрак', [
            (d.bfstPorridge, a),
            (d.bfstEgg, b),
            (d.bfstNuts, c),
            (d.bfstFruit, r),
          ]);
        } else {
          final a = (mealK * 0.40).round();
          final b = (mealK * 0.35).round();
          final c = mealK - a - b;
          addRow('Завтрак', [
            (d.bfstPorridge, a),
            (d.bfstEgg, b),
            (d.bfstNuts, c),
          ]);
        }
      } else if (key == 'Второй завтрак') {
        final a = (mealK * 0.45).round();
        final b = mealK - a;
        addRow('Второй завтрак', [(d.secondCarb, a), (d.secondFruit, b)]);
      } else if (key == 'Обед') {
        final a = (mealK * 0.40).round();
        final b = (mealK * 0.30).round();
        final c = (mealK * 0.20).round();
        final o = mealK - a - b - c;
        addRow(
          'Обед',
          [
            (d.lunchM, a),
            (d.lunchC, b),
            (d.lunchSalad, c),
            (d.lunchOil, o),
          ],
        );
      } else if (key == 'Полдник') {
        final a = (mealK * 0.45).round();
        final b = (mealK * 0.30).round();
        final c = mealK - a - b;
        if (d.poludnikIsDairy) {
          addRow('Полдник', [(d.cottage, a), (d.snackNut, b), (d.fruitSn, c)]);
        } else {
          addRow('Полдник', [(d.supp, a), (d.fruitSn, b), (d.snackNut, c)]);
        }
      } else if (key == 'Ужин') {
        final a = (mealK * 0.52).round();
        final r1 = mealK - a;
        final s0 = (r1 * 0.64).round();
        addRow('Ужин', [(d.fishD, a), (d.salD, s0), (d.oilD, r1 - s0)]);
      } else if (key == 'Перед сном') {
        final a = (mealK * 0.60).round();
        final b = (mealK * 0.22).round();
        final c = mealK - a - b;
        if (d.poludnikIsDairy) {
          addRow('Перед сном', [(d.supp, a), (d.nightN, b), (d.nightFruit, c)]);
        } else {
          addRow('Перед сном', [(d.eveningDairy, a), (d.nightN, b), (d.nightFruit, c)]);
        }
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
      final withFruit = ((sortSalt >> 2) & 1) == 0;
      if (withFruit) {
        final a = (mealK * 0.35).round();
        final b = (mealK * 0.25).round();
        final c = (mealK * 0.25).round();
        final r = mealK - a - b - c;
        parts = [
          (d.bfstPorridge, a),
          (d.bfstEgg, b),
          (d.bfstNuts, c),
          (d.bfstFruit, r),
        ];
      } else {
        final a = (mealK * 0.40).round();
        final b = (mealK * 0.35).round();
        final c = mealK - a - b;
        parts = [(d.bfstPorridge, a), (d.bfstEgg, b), (d.bfstNuts, c)];
      }
    } else if (mealKey == 'Второй завтрак') {
      final a = (mealK * 0.45).round();
      final b = mealK - a;
      parts = [(d.secondCarb, a), (d.secondFruit, b)];
    } else if (mealKey == 'Обед') {
      final a = (mealK * 0.40).round();
      final b = (mealK * 0.30).round();
      final c = (mealK * 0.20).round();
      final o = mealK - a - b - c;
      parts = [
        (d.lunchM, a),
        (d.lunchC, b),
        (d.lunchSalad, c),
        (d.lunchOil, o),
      ];
    } else if (mealKey == 'Полдник') {
      final a = (mealK * 0.45).round();
      final b = (mealK * 0.30).round();
      final c = mealK - a - b;
      if (d.poludnikIsDairy) {
        parts = [(d.cottage, a), (d.snackNut, b), (d.fruitSn, c)];
      } else {
        parts = [(d.supp, a), (d.fruitSn, b), (d.snackNut, c)];
      }
    } else if (mealKey == 'Ужин') {
      final a = (mealK * 0.52).round();
      final r1 = mealK - a;
      final s0 = (r1 * 0.64).round();
      parts = [(d.fishD, a), (d.salD, s0), (d.oilD, r1 - s0)];
    } else if (mealKey == 'Перед сном') {
      final a = (mealK * 0.60).round();
      final b = (mealK * 0.22).round();
      final c = mealK - a - b;
      if (d.poludnikIsDairy) {
        parts = [(d.supp, a), (d.nightN, b), (d.nightFruit, c)];
      } else {
        parts = [(d.eveningDairy, a), (d.nightN, b), (d.nightFruit, c)];
      }
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
