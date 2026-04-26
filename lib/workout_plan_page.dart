import 'package:flutter/material.dart';

import 'app_state.dart';
import 'workout_types.dart';

class WorkoutPlanView extends StatefulWidget {
  const WorkoutPlanView({super.key, required this.appState});

  final AppState appState;

  @override
  State<WorkoutPlanView> createState() => _WorkoutPlanViewState();
}

class _WorkoutPlanViewState extends State<WorkoutPlanView> {
  late TextEditingController _note;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(
      text: widget.appState.user?.workoutPlanNote ?? '',
    );
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p0 = widget.appState.user;
    if (p0 == null) return;
    setState(() => _saving = true);
    await widget.appState.setUser(
      p0.copyWith(
        workoutPlanNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сохранено в профиле')),
    );
  }

  Future<void> _setPlan(WorkoutPlan? w) async {
    final p0 = widget.appState.user;
    if (p0 == null) return;
    if (w == null) {
      await widget.appState.setUser(p0.copyWith(clearWorkoutPlan: true));
    } else {
      await widget.appState.setUser(p0.copyWith(workoutPlan: w));
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.appState.user;
    if (p == null) {
      return const Center(child: Text('Профиль не найден'));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'План тренировок',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        const Text('Шаблон плана', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...WorkoutPlan.values.map(
          (w) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                child: ListTile(
                  title: Text(workoutPlanLabel(w)),
                  selected: p.workoutPlan == w,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  onTap: () {
                    if (p.workoutPlan == w) {
                      _setPlan(null);
                    } else {
                      _setPlan(w);
                    }
                  },
                ),
              ),
            );
          },
        ),
        if (p.workoutPlan != null) ...[
          const SizedBox(height: 12),
          const Text('Краткое описание', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            workoutPlanDetail(p.workoutPlan!),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Свои заметки (дополнения)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: _saving ? null : _save,
          child: const Text('Сохранить заметки'),
        ),
      ],
    );
  }
}
