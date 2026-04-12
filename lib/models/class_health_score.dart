class ClassHealthScore {
  final double score;          // 0-100
  final double avgAccuracy;    // 0.0 - 1.0
  final double engagementRate; // 0.0 - 1.0: fraction of students active this week
  final int totalStudents;
  final int activeStudentsThisWeek;
  final int atRiskCount;

  const ClassHealthScore({
    required this.score,
    required this.avgAccuracy,
    required this.engagementRate,
    required this.totalStudents,
    required this.activeStudentsThisWeek,
    required this.atRiskCount,
  });

  // Score label for display
  String get label {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Attention';
  }

  // Color tier for display (return a string key, map to Color in UI)
  // 'green' = score >= 80
  // 'amber' = score >= 60
  // 'orange' = score >= 40
  // 'red'   = score < 40
  String get colorTier {
    if (score >= 80) return 'green';
    if (score >= 60) return 'amber';
    if (score >= 40) return 'orange';
    return 'red';
  }
}
