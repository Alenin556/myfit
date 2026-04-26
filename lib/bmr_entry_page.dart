import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'models/user_profile.dart';
import 'personal_goal.dart';
import 'services/meal_plan_narrative.dart' show computePlanMacroTargets;

class BmrEntryPage extends StatefulWidget {
  const BmrEntryPage({
    super.key,
    required this.appState,
    this.requireGoalSelection = false,
  });

  final AppState appState;

  /// Если [true] и в профиле нет цели — не подставлять цель по умолчанию (нужно выбрать заново).
  final bool requireGoalSelection;

  @override
  State<BmrEntryPage> createState() => _BmrEntryPageState();
}

class _BmrEntryPageState extends State<BmrEntryPage> {
  String _gender = 'male';
  PersonalGoal? _goal;
  double? _activity;
  static const _levels = <Map<String, Object>>[
    {'label': 'Сидячий', 'value': 1.2},
    {'label': 'Лёгкий', 'value': 1.375},
    {'label': 'Умеренный', 'value': 1.55},
    {'label': 'Активный', 'value': 1.725},
    {'label': 'Очень активный', 'value': 1.9},
  ];

  final _wTo = TextEditingController();
  String? _weightRangeError;
  int? _selectedWeightStepKg;
  static const List<int> _weightSteps = [2, 4, 6, 8, 10];

  @override
  void initState() {
    super.initState();
    final u = widget.appState.user;
    if (u != null) {
      if (u.gender != null) {
        _gender = u.gender!;
      }
      _goal = u.goal;
      _activity = u.activityMult;
    }
    if (!widget.requireGoalSelection) {
      _goal ??= PersonalGoal.maintain;
    }
    _activity ??= 1.2;
    _syncWeightFromUser();
    widget.appState.addListener(_onAppState);
  }

  bool get _isWeightGoal =>
      _goal == PersonalGoal.gain || _goal == PersonalGoal.lose;

  void _onAppState() {
    if (!mounted) {
      return;
    }
    setState(_syncWeightFromUser);
  }

  void _syncWeightFromUser() {
    final u = widget.appState.user;
    if (u == null) {
      return;
    }
    _selectedWeightStepKg = u.targetWeightChangeKg;
    if (!_isWeightGoal) {
      _wTo.text = '';
      return;
    }
    final step = _selectedWeightStepKg;
    if (step != null && _weightSteps.contains(step)) {
      _recomputeToFromStep(step);
    } else if (u.goalWeightToKg != null) {
      final t = u.goalWeightToKg!;
      _wTo.text = t == t.roundToDouble() ? '${t.toInt()}' : t.toStringAsFixed(1);
    } else {
      _wTo.text = '';
    }
  }

  void _recomputeToFromStep(int step) {
    if (!_isWeightGoal || _goal == null) {
      return;
    }
    final u = widget.appState.user;
    if (u == null) {
      return;
    }
    final from = u.weight;
    final to = _goal == PersonalGoal.gain ? from + step : from - step;
    if (to < 30 || to > 300) {
      return;
    }
    _wTo.text = to == to.roundToDouble() ? '${to.toInt()}' : to.toStringAsFixed(1);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppState);
    _wTo.dispose();
    super.dispose();
  }

  /// Возврат: (from, to, step) или null при ошибке (показан SnackBar).
  (double, double, int)? _parseWeightOrNotify(PersonalGoal goal) {
    setState(() {
      _weightRangeError = null;
    });
    final u = widget.appState.user;
    if (u == null) {
      const msg = 'Профиль не найден';
      setState(() => _weightRangeError = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(msg)),
      );
      return null;
    }
    final from = u.weight;
    if (from < 30 || from > 300) {
      setState(
        () => _weightRangeError =
            'Вес в профиле должен быть 30–300 кг. Измените вес в настройках профиля.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_weightRangeError!)),
      );
      return null;
    }
    final step = _selectedWeightStepKg;
    if (step == null || !_weightSteps.contains(step)) {
      setState(
        () => _weightRangeError = 'Выберите шаг изменения веса: 2, 4, 6, 8 или 10 кг',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_weightRangeError!)),
      );
      return null;
    }
    final toS = _wTo.text.trim().replaceAll(',', '.');
    final to = double.tryParse(toS);
    if (to == null) {
      setState(
        () => _weightRangeError = 'Сначала выберите шаг — поле «До» рассчитается автоматически',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_weightRangeError!)),
      );
      return null;
    }
    if (to < 30 || to > 300) {
      setState(() => _weightRangeError = 'Вес «До» в допустимом диапазоне 30–300 кг');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_weightRangeError!)),
      );
      return null;
    }
    if (goal == PersonalGoal.lose && to >= from) {
      setState(
        () => _weightRangeError = 'При снижении веса цель «До» должна быть меньше «От»',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_weightRangeError!)),
      );
      return null;
    }
    if (goal == PersonalGoal.gain && to <= from) {
      setState(
        () => _weightRangeError = 'При наборе веса цель «До» должна быть больше «От»',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_weightRangeError!)),
      );
      return null;
    }
    final d = (to - from).abs();
    if ((d - step).abs() > 0.2) {
      setState(
        () => _weightRangeError = '«От» и «До» должны отличаться на выбранный шаг ($step кг)',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_weightRangeError!)),
      );
      return null;
    }
    return (from, to, step);
  }

  Future<void> _saveAndShowKbjU() async {
    final u = widget.appState.user;
    if (u == null) {
      return;
    }
    if (_goal == null || _activity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите цель и уровень активности')),
      );
      return;
    }
    final h = u.heightCm;
    if (h == null || h < 100 || h > 250) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите рост (см) в профиле — он задаётся при регистрации'),
        ),
      );
      return;
    }
    (double, double, int)? weightTriple;
    if (_goal == PersonalGoal.gain || _goal == PersonalGoal.lose) {
      final parsed = _parseWeightOrNotify(_goal!);
      if (parsed == null) {
        return;
      }
      weightTriple = parsed;
    }
    final bmr = computeBmrMifflin(
      weightKg: u.weight,
      heightCm: h,
      age: u.age,
      gender: _gender,
      activityMult: _activity!,
    );
    var updated = u.copyWith(
      gender: _gender,
      goal: _goal,
      activityMult: _activity,
      lastBmr: bmr,
      clearWeightGoalRange: _goal == PersonalGoal.maintain,
    );
    if (weightTriple != null) {
      final (from, to, step) = weightTriple;
      updated = updated.copyWith(
        goalWeightFromKg: from,
        goalWeightToKg: to,
        targetWeightChangeKg: step,
      );
    }
    await widget.appState.setUser(updated);
    if (updated.canComputeBmr) {
      await widget.appState.setHasMealPlan(true);
    }
    if (!mounted) {
      return;
    }
    final targetKcal = (bmr *
            switch (_goal!) {
              PersonalGoal.gain => 1.10,
              PersonalGoal.maintain => 1.00,
              PersonalGoal.lose => 0.85,
            })
        .round();
    final m = computePlanMacroTargets(
      updated,
      targetKcal: targetKcal,
    );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Суточные нормы (КБЖУ)'),
        content: SingleChildScrollView(
          child: Table(
            border: TableBorder.all(
              color: Theme.of(ctx).colorScheme.outlineVariant,
            ),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.2),
            },
            children: [
              _kbjuRow('Калорийность', '${m.kcal} ккал/день', ctx, isHeader: true),
              _kbjuRow('Белки', '${m.proteinG} г', ctx),
              _kbjuRow('Жиры', '${m.fatG} г', ctx),
              _kbjuRow('Углеводы', '${m.carbG} г', ctx),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  TableRow _kbjuRow(
    String name,
    String value,
    BuildContext ctx, {
    bool isHeader = false,
  }) {
    final t = Theme.of(ctx).textTheme;
    final style = isHeader
        ? t.titleSmall?.copyWith(fontWeight: FontWeight.w600)
        : t.bodyMedium;
    return TableRow(
      decoration: isHeader
          ? BoxDecoration(
              color: Theme.of(ctx)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(name, style: style),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(value, style: style, textAlign: TextAlign.end),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.appState.user;
    if (u == null) {
      return const Scaffold(body: Center(child: Text('Профиль не найден')));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Данные для расчёта калорий')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Возраст: ${u.age} лет, вес: ${u.weight} кг (из профиля)',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          const Text('Пол', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('Мужчина')),
              ButtonSegment(value: 'female', label: Text('Женщина')),
            ],
            selected: {_gender},
            onSelectionChanged: (s) {
              setState(() => _gender = s.first);
            },
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((st) {
                if (st.contains(WidgetState.selected)) {
                  return isDark ? Colors.black : Colors.white;
                }
                return null;
              }),
            ),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          const Text('Цель', style: TextStyle(fontWeight: FontWeight.w600)),
          if (widget.requireGoalSelection && _goal == null) ...[
            const SizedBox(height: 6),
            Text(
              'Выберите цель питания, чтобы продолжить',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in PersonalGoal.values)
                ChoiceChip(
                  label: Text(personalGoalLabel(g)),
                  selected: _goal == g,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _goal = g;
                        if (g == PersonalGoal.gain || g == PersonalGoal.lose) {
                          _weightRangeError = null;
                          _syncWeightFromUser();
                          final t = _selectedWeightStepKg;
                          if (t != null) {
                            _recomputeToFromStep(t);
                          }
                        } else {
                          _weightRangeError = null;
                        }
                      });
                    }
                  },
                ),
            ],
          ),
          if (_isWeightGoal) ...[
            const SizedBox(height: 20),
            Text(
              'Цель по весу',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _goal == PersonalGoal.lose
                  ? 'На сколько снизить вес: шаг 2–10 кг. Текущий вес из профиля; «До» подставляется по шагу.'
                  : 'На сколько увеличить вес: шаг 2–10 кг. Текущий вес из профиля; «До» подставляется по шагу.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: variant,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              _goal == PersonalGoal.lose
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
                        _recomputeToFromStep(s);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                const weightHint =
                    'Рассчитывается от веса в профиле и выбранного шага';
                final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: variant,
                    );
                final narrow = c.maxWidth < 400;
                final wDisplay = u.weight;
                final fromStr = wDisplay == wDisplay.roundToDouble()
                    ? '${wDisplay.toInt()}'
                    : wDisplay.toStringAsFixed(1);
                final fromField = InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'От, кг (текущий вес из профиля)',
                    helperText: 'Изменить вес в разделе «Профиль»',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.45),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      fromStr,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
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
                    isDense: true,
                  ),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fromField,
                      const SizedBox(height: 12),
                      toField,
                      const SizedBox(height: 6),
                      Text(weightHint, style: hintStyle),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: fromField),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: toField),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(weightHint, style: hintStyle),
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
            const SizedBox(height: 8),
          ],
          if (u.heightCm != null && u.heightCm! >= 100 && u.heightCm! <= 250) ...[
            const SizedBox(height: 8),
            Text(
              'Рост: ${u.heightCm} см (из регистрации, правка в профиле)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Рост не указан. Добавьте рост в разделе «Профиль» (значок аватара на главной).',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<double>(
            decoration: const InputDecoration(
              labelText: 'Уровень активности',
              border: OutlineInputBorder(),
            ),
            // ignore: deprecated_member_use
            value: _activity,
            items: _levels
                .map(
                  (e) => DropdownMenuItem(
                    value: e['value'] as double,
                    child: Text(e['label'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _activity = v),
          ),
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('bmr_to_plan'),
            onPressed: _saveAndShowKbjU,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('К плану'),
          ),
        ],
      ),
    );
  }
}
