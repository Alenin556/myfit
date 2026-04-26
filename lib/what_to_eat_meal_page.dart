import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'services/daily_menu_generator.dart' show DailyMenuGenerator, MenuRow;
import 'services/food_product_repository.dart';

class WhatToEatMealPage extends StatefulWidget {
  const WhatToEatMealPage({
    super.key,
    required this.appState,
    required this.mealKey,
    required this.mealLabel,
    required this.targetKcal,
    required this.targetProteinG,
    required this.targetFatG,
    required this.targetCarbG,
  });

  final AppState appState;
  final String mealKey;
  final String mealLabel;
  final int targetKcal;
  final int targetProteinG;
  final int targetFatG;
  final int targetCarbG;

  @override
  State<WhatToEatMealPage> createState() => _WhatToEatMealPageState();
}

class _WhatToEatMealPageState extends State<WhatToEatMealPage> {
  final _gen = DailyMenuGenerator(FoodProductRepository());
  int _seed = 0;
  Future<MenuRow?>? _rowFuture;

  @override
  void initState() {
    super.initState();
    _rowFuture = _load();
  }

  Future<MenuRow?> _load() {
    return _gen.buildSingleMeal(
      mealKey: widget.mealKey,
      mealKcal: widget.targetKcal,
      seed: _seed,
    );
  }

  void _refresh() {
    setState(() {
      _seed++;
      _rowFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mealLabel),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Другое меню',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Ориентир на приём: ≈${widget.targetKcal} ккал',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: primary),
          ),
          const SizedBox(height: 4),
          Text(
            'КБЖУ: Б ${widget.targetProteinG} / Ж ${widget.targetFatG} / У ${widget.targetCarbG} г (доля суток)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.shuffle, size: 20),
            label: const Text('Предложить другое меню'),
          ),
          const SizedBox(height: 20),
          FutureBuilder<MenuRow?>(
            future: _rowFuture,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Ошибка: ${snap.error}');
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ));
              }
              final row = snap.data;
              if (row == null || row.items.isEmpty) {
                return const Text('Нет подходящих продуктов в справочнике.');
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FixedColumnWidth(48),
                      2: FixedColumnWidth(40),
                      3: FixedColumnWidth(40),
                      4: FixedColumnWidth(40),
                      5: FixedColumnWidth(44),
                    },
                    border: TableBorder.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                        ),
                        children: const [
                          _WteH('Продукт'),
                          _WteH('г'),
                          _WteH('Б'),
                          _WteH('Ж'),
                          _WteH('У'),
                          _WteH('ккал'),
                        ],
                      ),
                      for (final it in row.items)
                        TableRow(
                          children: [
                            _td(it.name, context),
                            _td('${it.grams}', context),
                            _td('${it.proteinG}', context),
                            _td('${it.fatG}', context),
                            _td('${it.carbG}', context),
                            _td('${it.kcal}', context),
                          ],
                        ),
                      TableRow(
                        children: [
                          const _WteH('Итого'),
                          const _WteH(''),
                          _WteH('${row.proteinG}'),
                          _WteH('${row.fatG}'),
                          _WteH('${row.carbG}'),
                          _WteH('${row.kcal}'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WteH extends StatelessWidget {
  const _WteH(this.s);
  final String s;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        s,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
        textAlign: s.isEmpty
            ? TextAlign.end
            : (s.length <= 3
                ? TextAlign.end
                : TextAlign.start),
      ),
    );
  }
}

Widget _td(String s, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(6),
    child: Text(
      s,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, height: 1.2),
    ),
  );
}
