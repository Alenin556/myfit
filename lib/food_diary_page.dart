import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'bmr_entry_page.dart';
import 'models/food_diary_entry.dart';
import 'models/food_product.dart';
import 'models/user_profile.dart';
import 'personal_goal.dart';
import 'services/food_product_repository.dart';
import 'services/meal_plan_narrative.dart' show computePlanMacroTargets;
import 'services/menu_balance.dart' show PlanMacroTargets;
import 'services/user_storage.dart';
import 'widgets/nutrition_plan_gate.dart';

String _dateKeyYmd(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Дневник питания: КБЖУ по весу, сохранение, предупреждение при превышении нормы.
class FoodDiaryPage extends StatefulWidget {
  const FoodDiaryPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<FoodDiaryPage> createState() => _FoodDiaryPageState();
}

class _FoodDiaryPageState extends State<FoodDiaryPage> {
  final _repo = FoodProductRepository();
  final ValueNotifier<List<FoodDiaryEntry>> _entriesN = ValueNotifier<List<FoodDiaryEntry>>([]);
  List<FoodProduct> _products = const [];
  UserStorage? _storage;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppState);
    _init();
  }

  void _onAppState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _init() async {
    _storage = await UserStorage.open();
    await _loadToday();
    final prods = await _repo.loadAll();
    if (mounted) {
      setState(() {
        _products = prods;
        _ready = true;
      });
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppState);
    _entriesN.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    final s = _storage;
    if (s == null) return;
    final raw = s.loadFoodDiaryV1();
    if (raw == null || raw.isEmpty) {
      _entriesN.value = [];
      return;
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final key = _dateKeyYmd(DateTime.now());
    final list = map[key] as List<dynamic>?;
    if (list == null) {
      _entriesN.value = [];
      return;
    }
    _entriesN.value = list
        .map((e) => FoodDiaryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _persist() async {
    final s = _storage;
    if (s == null) return;
    final key = _dateKeyYmd(DateTime.now());
    Map<String, dynamic> all = {};
    final prev = s.loadFoodDiaryV1();
    if (prev != null && prev.isNotEmpty) {
      all = Map<String, dynamic>.from(jsonDecode(prev) as Map<dynamic, dynamic>);
    }
    all[key] = _entriesN.value.map((e) => e.toJson()).toList();
    await s.saveFoodDiaryV1(jsonEncode(all));
  }

  ({int kcal, int p, int f, int c}) _sums(List<FoodDiaryEntry> e) {
    int k = 0, a = 0, b = 0, c = 0;
    for (final x in e) {
      k += x.kcal;
      a += x.proteinG;
      b += x.fatG;
      c += x.carbG;
    }
    return (kcal: k, p: a, f: b, c: c);
  }

  bool _exceedsPlan(PlanMacroTargets plan, {required int kcal, required int p, required int f, required int c}) {
    if (kcal > plan.kcal) return true;
    if (p > plan.proteinG) return true;
    if (f > plan.fatG) return true;
    if (c > plan.carbG) return true;
    return false;
  }

  Future<void> _openAddPanel(
    BuildContext context, {
    required PlanMacroTargets plan,
  }) async {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkAccent
        : AppTheme.lightAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SizedBox(
            height: h * 0.9,
            child: _FoodAddPanel(
              entriesN: _entriesN,
              products: _products,
              plan: plan,
              onPersist: _persist,
              primary: primary,
              isDark: isDark,
              exceedsPlan: _exceedsPlan,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.appState.user;
    if (p == null) {
      return const Center(child: Text('Профиль не найден'));
    }
    if (!p.canComputeBmr) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Сначала укажите цель и активность в «План питания».',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (c, a, b) => BmrEntryPage(appState: widget.appState),
                      transitionsBuilder: (c, a, s, w) => FadeTransition(opacity: a, child: w),
                    ),
                  );
                },
                child: const Text('Данные для расчёта калорий'),
              ),
            ],
          ),
        ),
      );
    }
    if (!widget.appState.hasMealPlan) {
      return NutritionPlanGate(appState: widget.appState);
    }

    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }

    final bmr = computeBmrMifflin(
      weightKg: p.weight,
      heightCm: p.heightCm!,
      age: p.age,
      gender: p.gender!,
      activityMult: p.activityMult!,
    );
    final rec = bmr *
        switch (p.goal!) {
          PersonalGoal.gain => 1.10,
          PersonalGoal.maintain => 1.00,
          PersonalGoal.lose => 0.85,
        };
    final targetKcal = rec.round();
    final plan = computePlanMacroTargets(p, targetKcal: targetKcal);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final cs = Theme.of(context).colorScheme;

    final embedded = ModalRoute.of(context)?.canPop != true;
    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Подсчёт калорий'),
            ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<List<FoodDiaryEntry>>(
          valueListenable: _entriesN,
          builder: (context, entries, _) {
            final t = _sums(entries);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${personalGoalLabel(p.goal!)} • норма: $targetKcal ккал/день',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Норма КБЖУ: Б ≈${plan.proteinG} / Ж ≈${plan.fatG} / У ≈${plan.carbG} г',
                          style: TextStyle(color: primary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('За сегодня', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        _KpiRow(label: 'Ккал', value: '${t.kcal}', plan: '$targetKcal', cs: cs),
                        _KpiRow(label: 'Белки, г', value: '${t.p}', plan: '${plan.proteinG}', cs: cs),
                        _KpiRow(label: 'Жиры, г', value: '${t.f}', plan: '${plan.fatG}', cs: cs),
                        _KpiRow(label: 'Углеводы, г', value: '${t.c}', plan: '${plan.carbG}', cs: cs),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _openAddPanel(context, plan: plan),
                          icon: const Icon(Icons.add),
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                          ),
                          label: const Text('Добавить продукт'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            'Список пуст. Нажмите «Добавить продукт» — список и форма ввода останутся в панели, пока не закроете её.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (context, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final e = entries[index];
                            return ListTile(
                              title: Text(e.name),
                              subtitle: Text(
                                '${e.grams} г · ${e.kcal} ккал · Б ${e.proteinG} / Ж ${e.fatG} / У ${e.carbG}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final list = List<FoodDiaryEntry>.from(_entriesN.value);
                                  list.removeAt(index);
                                  _entriesN.value = list;
                                  await _persist();
                                },
                                tooltip: 'Удалить',
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.label,
    required this.value,
    required this.plan,
    required this.cs,
  });

  final String label;
  final String value;
  final String plan;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const Spacer(),
          Text('норма $plan', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FoodAddPanel extends StatefulWidget {
  const _FoodAddPanel({
    required this.entriesN,
    required this.products,
    required this.plan,
    required this.onPersist,
    required this.primary,
    required this.isDark,
    required this.exceedsPlan,
  });

  final ValueNotifier<List<FoodDiaryEntry>> entriesN;
  final List<FoodProduct> products;
  final PlanMacroTargets plan;
  final Future<void> Function() onPersist;
  final Color primary;
  final bool isDark;
  final bool Function(PlanMacroTargets plan, {required int kcal, required int p, required int f, required int c})
      exceedsPlan;

  @override
  State<_FoodAddPanel> createState() => _FoodAddPanelState();
}

class _FoodAddPanelState extends State<_FoodAddPanel> {
  final _grams = TextEditingController();
  String _query = '';
  FoodProduct? _selected;
  int _bump = 0;

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  List<FoodProduct> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.products.take(50).toList();
    }
    return widget.products.where((e) => e.name.toLowerCase().contains(q)).take(50).toList();
  }

  ({int kcal, int p, int f, int c}) _sumsPlus(FoodDiaryEntry add, List<FoodDiaryEntry> base) {
    int k = 0, a = 0, b = 0, c = 0;
    for (final x in base) {
      k += x.kcal;
      a += x.proteinG;
      b += x.fatG;
      c += x.carbG;
    }
    k += add.kcal;
    a += add.proteinG;
    b += add.fatG;
    c += add.carbG;
    return (kcal: k, p: a, f: b, c: c);
  }

  Future<void> _tryAdd(BuildContext sheetContext) async {
    if (_selected == null) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('Выберите продукт из списка.')),
      );
      return;
    }
    final g = int.tryParse(_grams.text.trim().replaceAll(',', '.'));
    if (g == null || g < 1 || g > 10000) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('Введите массу в граммах (1–10000).')),
      );
      return;
    }
    final entry = FoodDiaryEntry.fromProduct(_selected!, grams: g);

    final list = List<FoodDiaryEntry>.from(widget.entriesN.value);
    final t = _sumsPlus(entry, list);

    if (widget.exceedsPlan(
      widget.plan,
      kcal: t.kcal,
      p: t.p,
      f: t.f,
      c: t.c,
    )) {
      final go = await showDialog<bool>(
        context: sheetContext,
        builder: (ctx) => AlertDialog(
          title: const Text('Внимание'),
          content: const Text('Вы превышаете норму. Уверены, что хотите отойти от плана?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Нет, отменить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Да, добавить'),
            ),
          ],
        ),
      );
      if (go != true) {
        return;
      }
    }

    list.add(entry);
    widget.entriesN.value = list;
    _grams.clear();
    _bump++;
    setState(() {});
    await widget.onPersist();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Продукты за сегодня',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Поиск продуктов',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InputChip(
                label: Text('Выбрано: ${_selected!.name}'),
                onDeleted: () => setState(() => _selected = null),
              ),
            ),
          SizedBox(
            height: 160,
            child: _filtered.isEmpty
                ? const Center(child: Text('Нет совпадений'))
                : ListView.builder(
                    key: ValueKey('${_query}_$_bump'),
                    itemCount: _filtered.length,
                    itemBuilder: (c, i) {
                      final p = _filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${p.kcalPer100g.toStringAsFixed(0)} ккал/100г · Б${p.proteinG}/Ж${p.fatG}/У${p.carbG}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () {
                          setState(() => _selected = p);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _grams,
            decoration: const InputDecoration(
              labelText: 'Вес, г',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _tryAdd(context),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _tryAdd(context),
            style: FilledButton.styleFrom(
              backgroundColor: widget.primary,
              foregroundColor: widget.isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Добавить в дневник'),
          ),
          const SizedBox(height: 4),
          Text(
            'Панель не закрывается после добавления — можно ввести следующий продукт.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),
          Text('Сегодня в дневнике', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Expanded(
            child: ValueListenableBuilder<List<FoodDiaryEntry>>(
              valueListenable: widget.entriesN,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  return const Center(child: Text('Пока пусто'));
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final e = entries[i];
                    return ListTile(
                      title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${e.grams} г · ${e.kcal} ккал · Б${e.proteinG} / Ж${e.fatG} / У${e.carbG}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Готово'),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }
}
