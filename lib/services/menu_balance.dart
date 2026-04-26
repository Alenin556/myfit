import 'daily_menu_generator.dart';

/// Целевые суточные КБЖУ (ориентир из расчёта плана).
class PlanMacroTargets {
  const PlanMacroTargets({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
  });

  final int kcal;
  final int proteinG;
  final int fatG;
  final int carbG;
}

/// Подгоняет итоги меню к целевой калорийности, сохраняя пропорции БЖУ по строкам.
class MenuBalance {
  static GeneratedMenu scaleToTarget(GeneratedMenu m, int targetKcal) {
    if (m.rows.isEmpty || m.totalKcal <= 0) {
      return m;
    }
    final f0 = targetKcal / m.totalKcal;
    if (f0 <= 0) {
      return m;
    }
    final newRows = <MenuRow>[];
    for (final r in m.rows) {
      final newItems = <MenuProductLine>[];
      for (final it in r.items) {
        newItems.add(
          MenuProductLine(
            name: it.name,
            grams: (it.grams * f0).round().clamp(1, 5000),
            proteinG: (it.proteinG * f0).round(),
            fatG: (it.fatG * f0).round(),
            carbG: (it.carbG * f0).round(),
            kcal: (it.kcal * f0).round(),
          ),
        );
      }
      newRows.add(
        MenuRow(
          title: r.title,
          products: r.products,
          grams: r.grams,
          proteinG: (r.proteinG * f0).round(),
          fatG: (r.fatG * f0).round(),
          carbG: (r.carbG * f0).round(),
          kcal: (r.kcal * f0).round(),
          items: newItems,
        ),
      );
    }
    var tk = 0;
    for (final r in newRows) {
      tk += r.kcal;
    }
    var d = targetKcal - tk;
    if (d != 0 && newRows.isNotEmpty) {
      final i = newRows.length - 1;
      final last = newRows[i];
      var patchedItems = last.items;
      if (last.items.isNotEmpty) {
        final li = last.items.length - 1;
        final it = last.items[li];
        patchedItems = List<MenuProductLine>.from(last.items);
        patchedItems[li] = MenuProductLine(
          name: it.name,
          grams: it.grams,
          proteinG: it.proteinG,
          fatG: it.fatG,
          carbG: it.carbG,
          kcal: it.kcal + d,
        );
      }
      newRows[i] = MenuRow(
        title: last.title,
        products: last.products,
        grams: last.grams,
        proteinG: last.proteinG,
        fatG: last.fatG,
        carbG: last.carbG,
        kcal: last.kcal + d,
        items: patchedItems,
      );
    }
    int tp = 0, tf = 0, tc = 0, tkk = 0;
    for (final r in newRows) {
      tp += r.proteinG;
      tf += r.fatG;
      tc += r.carbG;
      tkk += r.kcal;
    }
    return GeneratedMenu(
      rows: newRows,
      targetKcal: targetKcal,
      totalKcal: tkk,
      totalProteinG: tp,
      totalFatG: tf,
      totalCarbG: tc,
    );
  }
}
