import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'bmr_entry_page.dart';
import 'calorie_counter_page.dart';
import 'models/user_profile.dart';
import 'personal_goal.dart';
import 'registration_page.dart';
import 'services/daily_menu_generator.dart';
import 'services/food_product_repository.dart';
import 'services/meal_plan_narrative.dart'
    show buildMealPlanNarrative, computePlanMacroTargets, regimeTipsText;
import 'services/menu_pdf_service.dart';

class MealPlanView extends StatefulWidget {
  const MealPlanView({super.key, required this.appState});

  final AppState appState;

  @override
  State<MealPlanView> createState() => _MealPlanViewState();
}

class _MealPlanViewState extends State<MealPlanView> {
  final _gen = DailyMenuGenerator(FoodProductRepository());
  final _pdf = MenuPdfService();
  final _note = TextEditingController();
  final _wFrom = TextEditingController();
  final _wTo = TextEditingController();
  String? _weightRangeError;
  bool _saving = false;
  bool _savingRange = false;
  bool _pdfBusy = false;
  int? _menuTargetKcal;
  int? _menuSeed;
  bool? _menuWeightOk;
  Future<GeneratedMenu>? _menuFuture;
  /// Когда [AppState.hasMealPlan] — блок цели/заметок скрыт, пока не нажмут «Поставить новую цель».
  bool _goalBlockExpanded = false;
  /// Выбранный шаг 2, 4, 6, 8 или 10 кг (набор/снижение).
  int? _selectedWeightStepKg;
  static const List<int> _weightSteps = [2, 4, 6, 8, 10];

  void _onAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppStateChanged);
    _syncWeightFields(widget.appState.user);
    _wFrom.addListener(_onFromWeightChanged);
    _note.text = widget.appState.user?.mealPlanNote ?? '';
    final tw = widget.appState.user?.targetWeightChangeKg;
    if (tw != null && _weightSteps.contains(tw)) {
      _recomputeToFromStep(tw);
    }
  }

  void _syncWeightFields(UserProfile? p) {
    if (p == null) {
      return;
    }
    _selectedWeightStepKg = p.targetWeightChangeKg;
    final from = p.goalWeightFromKg ?? p.weight;
    _wFrom.text = from == from.roundToDouble() ? '${from.toInt()}' : from.toStringAsFixed(1);
    if (p.goalWeightToKg != null) {
      final t = p.goalWeightToKg!;
      _wTo.text = t == t.roundToDouble() ? '${t.toInt()}' : t.toStringAsFixed(1);
    } else {
      _wTo.text = '';
    }
  }

  void _onFromWeightChanged() {
    if (!mounted) {
      return;
    }
    final step = _selectedWeightStepKg;
    if (step == null) {
      return;
    }
    _recomputeToFromStep(step);
  }

  void _recomputeToFromStep(int step) {
    final p0 = widget.appState.user;
    if (p0 == null) {
      return;
    }
    if (p0.goal != PersonalGoal.gain && p0.goal != PersonalGoal.lose) {
      return;
    }
    final fromS = _wFrom.text.trim().replaceAll(',', '.');
    final from = double.tryParse(fromS);
    if (from == null) {
      return;
    }
    final to = p0.goal == PersonalGoal.gain ? from + step : from - step;
    if (to < 30 || to > 300) {
      return;
    }
    _wTo.text = to == to.roundToDouble() ? '${to.toInt()}' : to.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _wFrom.removeListener(_onFromWeightChanged);
    widget.appState.removeListener(_onAppStateChanged);
    _note.dispose();
    _wFrom.dispose();
    _wTo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p0 = widget.appState.user;
    if (p0 == null) {
      return;
    }
    setState(() => _saving = true);
    await widget.appState.setUser(
      p0.copyWith(
        mealPlanNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    await widget.appState.setHasMealPlan(true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Сохранено в профиле')));
  }

  Future<void> _exportPdf(UserProfile p, int targetKcal, double bmr) async {
    if (p.goal == null) {
      return;
    }
    if (p.goal == PersonalGoal.gain || p.goal == PersonalGoal.lose) {
      if (!p.isWeightGoalRangeValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сохраните корректный диапазон веса (от/до) перед экспортом.'),
          ),
        );
        return;
      }
    }
    setState(() => _pdfBusy = true);
    final menu = await _gen.build(
      targetKcal: targetKcal,
      seed: widget.appState.mealPlanRefreshSeed,
    );
    final narrative = buildMealPlanNarrative(
      p,
      bmr: bmr,
      targetKcal: targetKcal,
    );
    final bytes = await _pdf.buildDailyMenuPdf(
      userName: p.name,
      targetKcal: targetKcal,
      goal: p.goal!,
      menu: menu,
      narrative: narrative,
    );
    await _pdf.sharePdf(bytes);
    if (!mounted) {
      return;
    }
    await widget.appState.setHasMealPlan(true);
    if (!mounted) {
      return;
    }
    setState(() => _pdfBusy = false);
  }

  Future<void> _updateGoal(PersonalGoal g) async {
    final p0 = widget.appState.user;
    if (p0 == null) {
      return;
    }
    await widget.appState.setUser(
      p0.copyWith(
        goal: g,
        clearWeightGoalRange: g == PersonalGoal.maintain,
      ),
    );
    if (mounted) {
      _syncWeightFields(widget.appState.user);
      setState(() {});
    }
  }

  Future<void> _saveWeightRange(UserProfile p) async {
    if (p.goal != PersonalGoal.gain && p.goal != PersonalGoal.lose) {
      return;
    }
    setState(() {
      _weightRangeError = null;
    });
    final step = _selectedWeightStepKg;
    if (step == null || !_weightSteps.contains(step)) {
      setState(
        () => _weightRangeError = 'Выберите шаг изменения веса: 2, 4, 6, 8 или 10 кг',
      );
      return;
    }
    final fromS = _wFrom.text.trim().replaceAll(',', '.');
    final toS = _wTo.text.trim().replaceAll(',', '.');
    final from = double.tryParse(fromS);
    final to = double.tryParse(toS);
    if (from == null) {
      setState(() => _weightRangeError = 'Укажите вес «От»');
      return;
    }
    if (to == null) {
      setState(() => _weightRangeError = 'Сначала выберите шаг — поле «До» рассчитается автоматически');
      return;
    }
    if (from < 30 || from > 300 || to < 30 || to > 300) {
      setState(() => _weightRangeError = 'Вес в допустимом диапазоне 30–300 кг');
      return;
    }
    if (p.goal == PersonalGoal.lose && to >= from) {
      setState(() => _weightRangeError = 'При снижении веса цель «До» должна быть меньше «От»');
      return;
    }
    if (p.goal == PersonalGoal.gain && to <= from) {
      setState(() => _weightRangeError = 'При наборе веса цель «До» должна быть больше «От»');
      return;
    }
    final d = (to - from).abs();
    if ((d - step).abs() > 0.2) {
      setState(
        () => _weightRangeError = '«От» и «До» должны отличаться на выбранный шаг ($step кг)',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить цель по весу?'),
        content: Text(
          'От ${from.toStringAsFixed(1)} кг → до ${to.toStringAsFixed(1)} кг',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() => _savingRange = true);
    await widget.appState.setUser(
      p.copyWith(
        goalWeightFromKg: from,
        goalWeightToKg: to,
        targetWeightChangeKg: step,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _savingRange = false;
      _weightRangeError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Цель по весу сохранена')),
    );
  }

  Future<void> _startNewPlan() async {
    final p = widget.appState.user;
    if (p == null) {
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый план питания?'),
        content: const Text(
          'Текущая цель, диапазон веса и заметки по плану будут сброшены. '
          'Далее нужно заново ввести данные для расчёта (пол, активность, цель).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить и продолжить'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) {
      return;
    }
    await widget.appState.setUser(
      p.copyWith(
        clearGoal: true,
        clearWeightGoalRange: true,
        clearLastBmr: true,
        clearMealPlanNote: true,
      ),
    );
    await widget.appState.resetMealPlanWorkspace();
    if (!mounted) {
      return;
    }
    setState(() {
      _note.clear();
      _weightRangeError = null;
      _goalBlockExpanded = true;
      _menuTargetKcal = null;
      _menuSeed = null;
      _menuWeightOk = null;
      _menuFuture = null;
    });
    _syncWeightFields(widget.appState.user);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (c, a, b) => BmrEntryPage(
          appState: widget.appState,
          requireGoalSelection: true,
        ),
        transitionsBuilder: (c, a, s, w) {
          return FadeTransition(opacity: a, child: w);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.appState.user;
    if (p == null) {
      return const Center(child: Text('Профиль не найден'));
    }
    if (!p.canComputeBmr) {
      return _NeedBmr(
        onOpen: () {
          Navigator.of(context).push(
            PageRouteBuilder<void>(
              pageBuilder: (c, a, b) => BmrEntryPage(appState: widget.appState),
              transitionsBuilder: (c, a, s, w) {
                return FadeTransition(opacity: a, child: w);
              },
            ),
          );
        },
      );
    }
    final bmr = computeBmrMifflin(
      weightKg: p.weight,
      heightCm: p.heightCm!,
      age: p.age,
      gender: p.gender!,
      activityMult: p.activityMult!,
    );
    final rec =
        bmr *
        switch (p.goal!) {
          PersonalGoal.gain => 1.10,
          PersonalGoal.maintain => 1.00,
          PersonalGoal.lose => 0.85,
        };
    final targetKcal = rec.round();
    final weightPlanOk = p.goal == PersonalGoal.maintain || p.isWeightGoalRangeValid;
    final seed = widget.appState.mealPlanRefreshSeed;
    if (_menuTargetKcal != targetKcal ||
        _menuSeed != seed ||
        _menuWeightOk != weightPlanOk) {
      _menuTargetKcal = targetKcal;
      _menuSeed = seed;
      _menuWeightOk = weightPlanOk;
      if (weightPlanOk) {
        _menuFuture = _gen.build(
          targetKcal: targetKcal,
          seed: seed,
        );
      } else {
        _menuFuture = Future.value(
          GeneratedMenu(
            rows: const [],
            targetKcal: targetKcal,
            totalKcal: 0,
            totalProteinG: 0,
            totalFatG: 0,
            totalCarbG: 0,
          ),
        );
      }
    }
    final narrative = buildMealPlanNarrative(
      p,
      bmr: bmr,
      targetKcal: targetKcal,
    );
    final sendSummary = _buildSendSummary(p, targetKcal: targetKcal);
    final hideGoalPanel = widget.appState.hasMealPlan && !_goalBlockExpanded;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 360;
            final refresh = OutlinedButton.icon(
              onPressed: () {
                widget.appState.refreshMealPlan();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пример меню обновлён')),
                );
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Обновить план'),
            );
            final newPlan = OutlinedButton.icon(
              onPressed: _startNewPlan,
              icon: const Icon(Icons.add_task_outlined, size: 20),
              label: const Text('Новый план'),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  newPlan,
                  const SizedBox(height: 8),
                  refresh,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: newPlan),
                const SizedBox(width: 12),
                Expanded(child: refresh),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          narrative.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          narrative.introBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 20),
        Text(
          'Основные параметры',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _bullet(narrative.kcalLine, variant),
        _bullet(narrative.proteinLine, variant),
        _bullet(narrative.fatLine, variant),
        _bullet(narrative.carbLine, variant),
        _bullet(narrative.waterLine, variant),
        _bullet(narrative.mealsPerDayLine, variant),
        if (p.goal == PersonalGoal.gain || p.goal == PersonalGoal.lose) ...[
          const SizedBox(height: 20),
          Text(
            'Цель по весу',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            p.goal == PersonalGoal.lose
                ? 'На сколько снизить вес: шаг 2–10 кг. Затем укажите вес «От» — «До» подставится.'
                : 'На сколько увеличить вес: шаг 2–10 кг. Укажите вес «От» — «До» подставится автоматически.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: variant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            p.goal == PersonalGoal.lose
                ? 'На сколько снизить вес'
                : 'На сколько увеличить вес',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _weightSteps)
                ChoiceChip(
                  label: Text('$s кг'),
                  selected: _selectedWeightStepKg == s,
                  onSelected: (sel) {
                    if (!sel) {
                      return;
                    }
                    setState(() {
                      _selectedWeightStepKg = s;
                      if (_wFrom.text.trim().isEmpty) {
                        final w = p.weight;
                        _wFrom.text = w == w.roundToDouble()
                            ? '${w.toInt()}'
                            : w.toStringAsFixed(1);
                      }
                      _recomputeToFromStep(s);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 400;
              final fromField = TextField(
                controller: _wFrom,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'От, кг (текущий/стартовый вес)',
                  border: OutlineInputBorder(),
                ),
              );
              final toField = TextField(
                controller: _wTo,
                readOnly: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'До, кг (по шагу)',
                  border: OutlineInputBorder(),
                  helperText: 'Рассчитывается от «От» и выбранного шага',
                ),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fromField,
                    const SizedBox(height: 12),
                    toField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: fromField),
                  const SizedBox(width: 12),
                  Expanded(child: toField),
                ],
              );
            },
          ),
          if (_weightRangeError != null) ...[
            const SizedBox(height: 8),
            Text(
              _weightRangeError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: _savingRange
                  ? null
                  : () => _saveWeightRange(p),
              child: _savingRange
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сохранить цель по весу'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Пример меню на день (≈$targetKcal ккал)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        if (!weightPlanOk) ...[
          Card(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Укажите и сохраните корректный диапазон веса в полях «От» и «До» '
                '— пример меню и PDF будут доступны после сохранения.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ] else ...[
          FutureBuilder<GeneratedMenu>(
            future: _menuFuture!,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Не удалось собрать меню: ${snap.error}');
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _MenuTable(data: snap.data!);
            },
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: !weightPlanOk || _pdfBusy
              ? null
              : () => _exportPdf(p, targetKcal, bmr),
          style: FilledButton.styleFrom(
            backgroundColor: primary.withValues(alpha: 0.2),
            foregroundColor: isDark ? Colors.white : const Color(0xFF0D47A1),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _pdfBusy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Скачать PDF меню на день'),
        ),
        const SizedBox(height: 6),
        Text(
          'PDF повторяет структуру экрана: текст плана, таблица с БЖУ.',
          style: TextStyle(color: variant, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Text(
          narrative.footerNote,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        Text(
          'Рекомендации по режиму',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        for (final line in regimeTipsText().split('\n').skip(1)) ...[
          if (line.isNotEmpty)
            _bullet(line, variant)
          else
            const SizedBox(height: 4),
        ],
        const SizedBox(height: 24),
        if (hideGoalPanel) ...[
          OutlinedButton(
            onPressed: () {
              setState(() {
                _goalBlockExpanded = true;
              });
            },
            child: const Text('Поставить новую цель'),
          ),
          const SizedBox(height: 20),
        ] else ...[
          const Text('Цель', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in PersonalGoal.values)
                ChoiceChip(
                  label: Text(personalGoalLabel(g)),
                  selected: p.goal == g,
                  onSelected: (s) {
                    if (s) {
                      _updateGoal(g);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(p.summaryLine, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Личные заметки (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _saving ? null : _save,
              child: const Text('Сохранить заметки'),
            ),
          ),
          if (widget.appState.hasMealPlan) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _goalBlockExpanded = false;
                  });
                },
                child: const Text('Свернуть'),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
        FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                pageBuilder: (c, a, b) =>
                    CalorieCounterPage(bmr: bmr, goal: p.goal!),
                transitionsBuilder: (c, a, s, w) {
                  return FadeTransition(opacity: a, child: w);
                },
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: isDark ? Colors.black : Colors.white,
          ),
          child: const Text('Подсчёт калорий'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: !weightPlanOk
              ? null
              : () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (c, a, b) => RegistrationPage(
                        sendSummary: sendSummary,
                      ),
                      transitionsBuilder: (c, a, s, w) {
                        return FadeTransition(opacity: a, child: w);
                      },
                    ),
                  );
                },
          child: const Text('Отправить план (почта / Telegram)'),
        ),
        const SizedBox(height: 24),
        if (!widget.appState.hasMealPlan)
          Text(
            'Используйте расчёты в приложении как ориентир; план согласуйте с врачом.',
            style: TextStyle(color: variant),
          ),
      ],
    );
  }
}

String _buildSendSummary(UserProfile p, {required int targetKcal}) {
  final g = p.goal;
  final m = computePlanMacroTargets(p, targetKcal: targetKcal);
  final b = StringBuffer();
  b.writeln('My Pro Health Nutrition — сводка плана');
  b.writeln('Цель: ${g != null ? personalGoalLabel(g) : "—"}');
  b.writeln('Суточная калорийность: $targetKcal ккал');
  b.writeln(
    'КБЖУ: белки ≈${m.proteinG} г, жиры ≈${m.fatG} г, углеводы ≈${m.carbG} г',
  );
  if (g == PersonalGoal.gain || g == PersonalGoal.lose) {
    final a = p.goalWeightFromKg;
    final t = p.goalWeightToKg;
    if (a != null && t != null) {
      b.writeln('Вес: ${a.toStringAsFixed(1)} → ${t.toStringAsFixed(1)} кг');
    }
    final step = p.targetWeightChangeKg;
    if (step != null) {
      final sign = g == PersonalGoal.gain ? '+' : '−';
      b.writeln('План изменения: $sign$step кг');
    }
  }
  return b.toString();
}

class _MenuTable extends StatelessWidget {
  const _MenuTable({required this.data});

  final GeneratedMenu data;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (data.rows.isEmpty) {
      return const Text('Нет продуктов в справочнике.');
    }
    final heading = t.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 11,
    );
    final cell = t.labelSmall?.copyWith(fontSize: 11, height: 1.2);

    Widget table(double minW) {
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: minW),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
          columnWidths: const {
            0: FixedColumnWidth(90),
            1: FlexColumnWidth(2.0),
            2: FixedColumnWidth(64),
            3: FixedColumnWidth(40),
            4: FixedColumnWidth(40),
            5: FixedColumnWidth(44),
            6: FixedColumnWidth(40),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              children: [
                _th('Приём', heading),
                _th('Продукты', heading),
                _th('Граммы', heading),
                _th('Белки', heading),
                _th('Жиры', heading),
                _th('Углев.', heading),
                _th('Ккал', heading),
              ],
            ),
            for (final r in data.rows)
              TableRow(
                children: [
                  _td(r.title, cell),
                  _td(r.products, cell, alignStart: true),
                  _td(r.grams, cell),
                  _td('${r.proteinG}', cell),
                  _td('${r.fatG}', cell),
                  _td('${r.carbG}', cell),
                  _td('${r.kcal}', cell),
                ],
              ),
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.2),
              ),
              children: [
                _th(
                  'Итого',
                  t.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                _th('', t.labelSmall),
                _th('', t.labelSmall),
                _th(
                  '${data.totalProteinG}',
                  t.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                _th(
                  '${data.totalFatG}',
                  t.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                _th(
                  '${data.totalCarbG}',
                  t.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                _th(
                  '${data.totalKcal}',
                  t.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 640) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table(600),
          );
        }
        return table(c.maxWidth);
      },
    );
  }

  Widget _th(String s, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Text(s, textAlign: TextAlign.center, style: style),
    );
  }

  Widget _td(String s, TextStyle? style, {bool alignStart = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        s,
        textAlign: alignStart ? TextAlign.start : TextAlign.center,
        style: style,
      ),
    );
  }
}

class _NeedBmr extends StatelessWidget {
  const _NeedBmr({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant, size: 48),
            const SizedBox(height: 12),
            Text(
              'Сначала введите данные для расчёта калорий (цель, активность) — в разделе «Подсчёт калорий» на главной. Рост задаётся при регистрации (профиль).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onOpen,
              child: const Text('Перейти к расчёту'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _bullet(String text, Color color) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('— ', style: TextStyle(color: color)),
        Expanded(
          child: Text(text, style: TextStyle(color: color, height: 1.4)),
        ),
      ],
    ),
  );
}
