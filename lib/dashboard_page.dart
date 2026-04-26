import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'bmr_entry_page.dart';
import 'calorie_counter_page.dart';
import 'meal_plan_page.dart';
import 'models/user_profile.dart';
import 'personal_goal.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'widgets/user_avatar_view.dart';
import 'what_to_eat_page.dart';
import 'workout_plan_page.dart';
import 'workout_types.dart';

enum _HomeSection { whatToEat, home, meal, workout }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  _HomeSection _section = _HomeSection.home;
  bool _railExpanded = false;

  void _toCalories() {
    final p = widget.appState.user;
    if (p == null) return;
    if (!p.canComputeBmr) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (c, a, b) => BmrEntryPage(appState: widget.appState),
          transitionsBuilder: (c, a, s, w) {
            return FadeTransition(opacity: a, child: w);
          },
        ),
      );
    } else {
      final bmr = computeBmrMifflin(
        weightKg: p.weight,
        heightCm: p.heightCm!,
        age: p.age,
        gender: p.gender!,
        activityMult: p.activityMult!,
      );
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (c, a, b) => CalorieCounterPage(
            bmr: bmr,
            goal: p.goal!,
          ),
          transitionsBuilder: (c, a, s, w) {
            return FadeTransition(opacity: a, child: w);
          },
        ),
      );
    }
  }

  void _toSettings() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (c, a, b) => SettingsPage(appState: widget.appState),
        transitionsBuilder: (c, a, s, w) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: a, child: w),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final wide = cons.maxWidth >= 900;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                _DesktopRail(
                  expanded: _railExpanded,
                  onToggle: () {
                    setState(() => _railExpanded = !_railExpanded);
                  },
                  section: _section,
                  onSelect: (s) {
                    setState(() => _section = s);
                  },
                ),
                Expanded(
                  child: _DashboardScaffold(
                    appState: widget.appState,
                    section: _section,
                    onCalories: _toCalories,
                    onSettings: _toSettings,
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(switch (_section) {
              _HomeSection.whatToEat => 'Что поесть',
              _HomeSection.home => 'Главная',
              _HomeSection.meal => 'План питания',
              _HomeSection.workout => 'План тренировок',
            }),
            actions: [
              IconButton(
                onPressed: _toSettings,
                icon: const Icon(Icons.settings),
                tooltip: 'Настройки',
              ),
            ],
          ),
          drawer: _DrawerContent(
            section: _section,
            onSelect: (s) {
              setState(() => _section = s);
              Navigator.of(context).pop();
            },
          ),
          body: _DashboardScaffold(
            appState: widget.appState,
            section: _section,
            onCalories: _toCalories,
            onSettings: _toSettings,
            showAppBar: false,
          ),
        );
      },
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.expanded,
    required this.onToggle,
    required this.section,
    required this.onSelect,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final _HomeSection section;
  final void Function(_HomeSection) onSelect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.brightness == Brightness.dark
        ? AppTheme.darkAccent
        : AppTheme.lightAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: expanded ? 220 : 56,
      color: t.navigationRailTheme.backgroundColor,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: IconButton(
                tooltip: expanded ? 'Свернуть' : 'Меню',
                onPressed: onToggle,
                icon: Icon(expanded ? Icons.chevron_left : Icons.menu, color: primary),
              ),
            ),
            if (expanded) const Divider(height: 1),
            if (expanded) ...[
              const SizedBox(height: 8),
              _NavRow(
                icon: Icons.restaurant_menu,
                label: 'Что поесть',
                selected: section == _HomeSection.whatToEat,
                onTap: () => onSelect(_HomeSection.whatToEat),
                primary: primary,
              ),
              _NavRow(
                icon: Icons.home_outlined,
                label: 'Главная',
                selected: section == _HomeSection.home,
                onTap: () => onSelect(_HomeSection.home),
                primary: primary,
              ),
              _NavRow(
                icon: Icons.restaurant,
                label: 'План питания',
                selected: section == _HomeSection.meal,
                onTap: () => onSelect(_HomeSection.meal),
                primary: primary,
              ),
              _NavRow(
                icon: Icons.fitness_center,
                label: 'План тренировок',
                selected: section == _HomeSection.workout,
                onTap: () => onSelect(_HomeSection.workout),
                primary: primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: selected ? primary : null),
        title: Text(label),
        selected: selected,
        selectedTileColor: primary.withValues(alpha: 0.12),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  const _DrawerContent({required this.section, required this.onSelect});

  final _HomeSection section;
  final void Function(_HomeSection) onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: section.index,
      onDestinationSelected: (i) {
        onSelect(_HomeSection.values[i]);
      },
      header: const DrawerHeader(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            'My Pro Health\nNutrition',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      children: const [
        NavigationDrawerDestination(
          icon: Icon(Icons.restaurant_menu),
          label: Text('Что поесть'),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.home_outlined),
          label: Text('Главная'),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.restaurant),
          label: Text('План питания'),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.fitness_center),
          label: Text('План тренировок'),
        ),
      ],
    );
  }
}

class _DashboardScaffold extends StatelessWidget {
  const _DashboardScaffold({
    required this.appState,
    required this.section,
    required this.onCalories,
    required this.onSettings,
    this.showAppBar = true,
  });

  final AppState appState;
  final _HomeSection section;
  final VoidCallback onCalories;
  final VoidCallback onSettings;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showAppBar && MediaQuery.sizeOf(context).width >= 900)
          AppBar(
            title: Text(
              switch (section) {
                _HomeSection.whatToEat => 'Что поесть',
                _HomeSection.home => 'Главная',
                _HomeSection.meal => 'План питания',
                _HomeSection.workout => 'План тренировок',
              },
            ),
            actions: [
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.settings),
                tooltip: 'Настройки',
              ),
            ],
          ),
        Expanded(
          child: switch (section) {
            _HomeSection.whatToEat => WhatToEatPage(appState: appState),
            _HomeSection.home => _HomeBody(appState: appState, onCalories: onCalories),
            _HomeSection.meal => MealPlanView(appState: appState),
            _HomeSection.workout => WorkoutPlanView(appState: appState),
          },
        ),
      ],
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.appState, required this.onCalories});

  final AppState appState;
  final VoidCallback onCalories;

  @override
  Widget build(BuildContext context) {
    final p = appState.user;
    if (p == null) {
      return const Center(child: Text('Нет данных профиля'));
    }
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatarView(avatarBase64: p.avatarBase64, radius: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              pageBuilder: (c, a, b) => ProfilePage(appState: appState),
                              transitionsBuilder: (c, a, s, w) {
                                return SlideTransition(
                                  position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
                                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                                  child: FadeTransition(opacity: a, child: w),
                                );
                              },
                            ),
                          );
                        },
                        child: Text(
                          p.name,
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: primary,
                            decoration: TextDecoration.underline,
                            decorationColor: primary,
                          ),
                        ),
                      ),
                      if (p.username != null && p.username!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${p.username}',
                          style: t.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text('Вес: ${p.weight} кг', style: t.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!appState.hasMealPlan)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'У вас нет плана питания',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        FilledButton(
          key: const Key('dashboard_calories'),
          onPressed: onCalories,
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: isDark ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Подсчёт калорий'),
        ),
        const SizedBox(height: 16),
        if (p.goal != null)
          Card(
            child: ExpansionTile(
              title: const Text('План питания'),
              subtitle: Text(_mealPlanTileSubtitle(p)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    p.mealPlanNote != null && p.mealPlanNote!.isNotEmpty
                        ? p.mealPlanNote!
                        : p.summaryLine,
                    style: t.bodyMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        final go = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить план питания?'),
                            content: const Text(
                              'Будут сброшены настройки плана питания, цель и заметки. '
                              'Восстановить план можно в любой момент в разделе «План питания».',
                            ),
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
                        if (go == true && context.mounted) {
                          final u0 = appState.user;
                          if (u0 != null) {
                            await appState.setUser(
                              u0.copyWith(
                                clearGoal: true,
                                clearWeightGoalRange: true,
                                clearMealPlanNote: true,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Удалить план',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Card(
            child: ListTile(
              title: const Text('План питания'),
              subtitle: const Text(
                'План не настроен. Задайте план питания в соответствующем разделе.',
              ),
            ),
          ),
        if (p.workoutPlan != null) ...[
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              title: const Text('План тренировок'),
              subtitle: Text(workoutPlanLabel(p.workoutPlan!)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    p.workoutPlanNote != null && p.workoutPlanNote!.isNotEmpty
                        ? '${workoutPlanDetail(p.workoutPlan!)}\n\n${p.workoutPlanNote!}'
                        : workoutPlanDetail(p.workoutPlan!),
                    style: t.bodyMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        final go = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Удалить план тренировок?'),
                            content: const Text(
                              'Будут сброшены план тренировок и заметки. '
                              'Создать новый план можно в разделе «План тренировок».',
                            ),
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
                        if (go == true && context.mounted) {
                          final u0 = appState.user;
                          if (u0 != null) {
                            await appState.setUser(
                              u0.copyWith(clearWorkoutPlan: true),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Удалить план',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('План тренировок'),
              subtitle: const Text(
                'У вас нет плана тренировок. Создайте план в разделе «План тренировок».',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _mealPlanTileSubtitle(UserProfile p) {
  final g = p.goal;
  if (g == null) {
    return '';
  }
  if (g != PersonalGoal.gain && g != PersonalGoal.lose) {
    return personalGoalLabel(g);
  }
  if (!p.isWeightGoalRangeValid) {
    return personalGoalLabel(g);
  }
  final from = (p.goalWeightFromKg ?? p.weight).toStringAsFixed(1);
  final to = (p.goalWeightToKg ?? p.weight).toStringAsFixed(1);
  var line = '${personalGoalLabel(g)} — вес: $from → $to кг';
  final step = p.targetWeightChangeKg;
  if (step != null) {
    final sign = g == PersonalGoal.gain ? '+' : '−';
    line += ', план: $sign$step кг';
  }
  return line;
}
