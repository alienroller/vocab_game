import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Leaderboard tab types.
enum LeaderboardType { myClass, global, weekly }

/// Fetches leaderboard data from Supabase based on type.
final leaderboardProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({LeaderboardType type, String? classCode})>((ref, params) async {
  final supabase = Supabase.instance.client;

  switch (params.type) {
    case LeaderboardType.myClass:
      if (params.classCode == null || params.classCode!.isEmpty) return [];
      return List<Map<String, dynamic>>.from(
        await supabase
            .from('profiles')
            .select('username, xp, level, streak_days')
            .eq('class_code', params.classCode!)
            .order('xp', ascending: false)
            .limit(50),
      );

    case LeaderboardType.global:
      return List<Map<String, dynamic>>.from(
        await supabase
            .from('profiles')
            .select('username, xp, level')
            .order('xp', ascending: false)
            .limit(100),
      );

    case LeaderboardType.weekly:
      if (params.classCode == null || params.classCode!.isEmpty) {
        return List<Map<String, dynamic>>.from(
          await supabase
              .from('profiles')
              .select('username, week_xp, level')
              .order('week_xp', ascending: false)
              .limit(50),
        );
      }
      return List<Map<String, dynamic>>.from(
        await supabase
            .from('profiles')
            .select('username, week_xp, level')
            .eq('class_code', params.classCode!)
            .order('week_xp', ascending: false)
            .limit(50),
      );
  }
});
