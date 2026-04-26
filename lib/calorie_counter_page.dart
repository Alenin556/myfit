import 'package:flutter/material.dart';

import 'add_product_page.dart';
import 'calorie_header.dart';
import 'personal_goal.dart';
import 'registration_page.dart';

class CalorieEntry {
  CalorieEntry({required this.name, required this.calories});

  final String name;
  final int calories;
}

class CalorieCounterPage extends StatefulWidget {
  const CalorieCounterPage({
    super.key,
    required this.bmr,
    required this.goal,
  });

  final double bmr;
  final PersonalGoal goal;

  @override
  State<CalorieCounterPage> createState() => _CalorieCounterPageState();
}

class _CalorieCounterPageState extends State<CalorieCounterPage> {
  final List<CalorieEntry> _entries = [];

  int get _totalCalories {
    return _entries.fold(0, (sum, entry) => sum + entry.calories);
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index);
    });
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.push<(String, int)>(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a1, a2) => const AddProductPage(),
        transitionsBuilder: (c, a, s, w) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: a, child: w),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (result == null || !mounted) return;
    final (name, calories) = result;
    setState(() {
      _entries.add(CalorieEntry(name: name, calories: calories));
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recommended = widget.bmr * switch (widget.goal) {
      PersonalGoal.gain => 1.10,
      PersonalGoal.maintain => 1.00,
      PersonalGoal.lose => 0.85,
    };
    final sendSummary = [
      'План питания (ориентир)',
      'Цель: ${personalGoalLabel(widget.goal)}',
      'Рекомендуемая норма: ${recommended.toStringAsFixed(0)} ккал/день',
    ].join('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подсчёт калорий'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalorieHeader(
              title:
                  '${personalGoalLabel(widget.goal)} • ${recommended.toStringAsFixed(0)} ккал/день',
              subtitle: 'Добавляйте продукты и следите за суммой за день.',
              totalCalories: _totalCalories,
              onSendPlan: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (c, a1, a2) => RegistrationPage(sendSummary: sendSummary),
                    transitionsBuilder: (c, a, s, w) {
                      return FadeTransition(opacity: a, child: w);
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              },
              onAddProduct: _openAddProduct,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _entries.isEmpty
                  ? Center(
                      child: Text(
                        'Список пуст. Нажмите «Добавить продукт» выше.',
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return ListTile(
                          title: Text(entry.name),
                          subtitle: Text('${entry.calories} ккал'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeEntry(index),
                            tooltip: 'Удалить',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
