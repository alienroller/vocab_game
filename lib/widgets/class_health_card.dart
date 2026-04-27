import 'package:flutter/material.dart';

import '../models/class_health_score.dart';

/// Compact card summarising a class's health score (number, label, accuracy
/// and active-students-this-week). Shown on the Analytics screen.
///
/// Tappable so callers can drill in to a fuller view if they want; pass
/// [onTap] = null to make it static.
class ClassHealthCard extends StatelessWidget {
  final ClassHealthScore score;
  final bool isDark;
  final VoidCallback? onTap;

  const ClassHealthCard({
    super.key,
    required this.score,
    required this.isDark,
    this.onTap,
  });

  Color _colorForTier(String tier) {
    switch (tier) {
      case 'green':
        return Colors.green;
      case 'amber':
        return Colors.orangeAccent;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForTier(score.colorTier);
    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            'Class Health',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${score.score.round()}',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1,
            ),
          ),
          Text(
            score.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    '${(score.avgAccuracy * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text('Avg Accuracy', style: TextStyle(fontSize: 12)),
                ],
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              Column(
                children: [
                  Text(
                    '${score.activeStudentsThisWeek}/${score.totalStudents}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text('Active (7d)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
