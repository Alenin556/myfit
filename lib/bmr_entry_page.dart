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
    // Значения по умолчанию, чтобы кнопка «К плану» срабатывала без пустого dropdown.
    if (!widget.requireGoalSelection) {
      _goal ??= PersonalGoal.maintain;
    }
    _activity ??= 1.2;
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
    );
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
                      setState(() => _goal = g);
                    }
                  },
                ),
            ],
          ),
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
