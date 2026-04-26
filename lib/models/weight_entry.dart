import 'package:flutter/foundation.dart';

@immutable
class WeightEntry {
  const WeightEntry({
    required this.recordedAt,
    required this.weightKg,
  });

  final DateTime recordedAt;
  final double weightKg;

  Map<String, dynamic> toJson() => {
        't': recordedAt.millisecondsSinceEpoch,
        'w': weightKg,
      };

  static WeightEntry fromJson(Map<String, dynamic> m) {
    return WeightEntry(
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['t'] as num).toInt(),
      ),
      weightKg: (m['w'] as num).toDouble(),
    );
  }
}
