import 'package:flutter/material.dart';

class CalorieHeader extends StatelessWidget {
  const CalorieHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.totalCalories,
    required this.onSendPlan,
    required this.onAddProduct,
  });

  final String title;
  final String subtitle;
  final int totalCalories;
  final VoidCallback onSendPlan;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Всего калорий', style: textTheme.titleMedium),
                Text('$totalCalories', style: textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить продукт'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSendPlan,
                    icon: const Icon(Icons.outgoing_mail),
                    label: const Text('План питания'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
