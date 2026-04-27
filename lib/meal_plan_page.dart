import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'bmr_entry_page.dart';
import 'food_diary_page.dart';
import 'models/meal_plan_note.dart';
import 'models/user_profile.dart';
import 'personal_goal.dart';
import 'registration_page.dart';
import 'widgets/nutrition_plan_gate.dart';
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
  bool _saving = false;
  bool _pdfBusy = false;
  int? _menuTargetKcal;
  int? _menuSeed;
  bool? _menuWeightOk;
  Future<GeneratedMenu>? _menuFuture;
  void _onAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  Future<String?> _promptNoteText({String? initial, required String title}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 6,
            minLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Текст заметки',
            ),
            textInputAction: TextInputAction.newline,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
    // Поддерево диалога снимается с дерева в следующем кадре; синхронный
    // dispose() контроллера даёт assert '_dependents.isEmpty' в framework.dart.
    final c = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.dispose();
    });
    if (result == null) {
      return null;
    }
    return result.trim();
  }

  Future<void> _persistNotes(List<MealPlanNoteEntry> list) async {
    final p0 = widget.appState.user;
    if (p0 == null) {
      return;
    }
    setState(() => _saving = true);
    await widget.appState.setUser(p0.copyWith(mealPlanNotes: list));
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Заметки сохранены в профиле')));
  }

  Future<void> _addNote() async {
    final t = await _promptNoteText(title: 'Новая заметка');
    if (t == null || t.isEmpty) {
      if (t != null && t.isEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Введите текст заметки')));
      }
      return;
    }
    final p0 = widget.appState.user;
    if (p0 == null) {
      return;
    }
    final next = List<MealPlanNoteEntry>.from(p0.mealPlanNotes);
    next.add(
      MealPlanNoteEntry(
        id: 'n${DateTime.now().microsecondsSinceEpoch}',
        text: t,
        createdAt: DateTime.now(),
      ),
    );
    await _persistNotes(next);
  }

  Future<void> _editNote(MealPlanNoteEntry n) async {
    final t = await _promptNoteText(initial: n.text, title: 'Редактировать заметку');
    if (t == null) {
      return;
    }
    if (t.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Текст не может быть пустым')));
      }
      return;
    }
    final p0 = widget.appState.user;
    if (p0 == null) {
      return;
    }
    final next = p0.mealPlanNotes
        .map(
          (e) => e.id == n.id
              ? MealPlanNoteEntry(
                  id: e.id,
                  text: t,
                  createdAt: e.createdAt,
                )
              : e,
        )
        .toList();
    await _persistNotes(next);
  }

  Future<void> _deleteNote(MealPlanNoteEntry n) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (go != true) {
      return;
    }
    final p0 = widget.appState.user;
    if (p0 == null) {
      return;
    }
    final next = p0.mealPlanNotes.where((e) => e.id != n.id).toList();
    await _persistNotes(next);
  }

  Future<void> _exportPdf(UserProfile p, int targetKcal, double bmr) async {
    if (p.goal == null) {
      return;
    }
    if (p.goal == PersonalGoal.gain || p.goal == PersonalGoal.lose) {
      if (!p.isWeightGoalRangeValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сохраните цель по весу в «Данные для расчёта калорий» перед экспортом.',
            ),
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
      _menuTargetKcal = null;
      _menuSeed = null;
      _menuWeightOk = null;
      _menuFuture = null;
    });
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
    if (!widget.appState.hasMealPlan) {
      return NutritionPlanGate(appState: widget.appState);
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
            'Для набора и снижения веса укажите и сохраните шаг и диапазон «От—До» в «Данные для расчёта калорий» (кнопка «Перейти к расчёту», если расчёт ещё не выполнен).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: variant,
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
                'Укажите и сохраните цель по весу в «Данные для расчёта калорий» '
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
        Text(
          'Личные заметки',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (p.mealPlanNotes.isEmpty)
          Text(
            'Заметок пока нет. Добавьте напоминания по питанию, продуктам или режиму.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: variant),
          )
        else
          ...p.mealPlanNotes.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(n.text),
                  subtitle: Text(
                    '${n.createdAt.day.toString().padLeft(2, '0')}.'
                    '${n.createdAt.month.toString().padLeft(2, '0')}.'
                    '${n.createdAt.year}',
                    style: TextStyle(fontSize: 12, color: variant),
                  ),
                  isThreeLine: n.text.length > 80,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Изменить',
                        onPressed: _saving ? null : () => _editNote(n),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Удалить',
                        onPressed: _saving ? null : () => _deleteNote(n),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : _addNote,
          icon: const Icon(Icons.add),
          label: const Text('Добавить заметку'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                pageBuilder: (c, a, b) => FoodDiaryPage(
                  appState: widget.appState,
                ),
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
            const SizedBox(height: 20),
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
