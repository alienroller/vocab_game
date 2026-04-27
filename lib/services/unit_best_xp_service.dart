import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks the best XP a user has ever earned on a given library/assignment unit.
///
/// On replay, only the *delta* over the previous best is banked to the user's
/// profile XP. This rewards genuine improvement (faster, more accurate plays)
/// while preventing leaderboard farming from grinding the same unit.
///
/// Storage:
/// - Hive box `unitBestXp` is the source of truth (offline-first, instant reads).
/// - Supabase `unit_best_xp` is a best-effort upsert for cross-device persistence.
///   If the upsert fails, Hive still has the value; we don't queue retries
///   because the cap only matters on the device the user is actually playing on.
class UnitBestXpService {
  static const _boxName = 'unitBestXp';

  static Box get _box => Hive.box(_boxName);

  /// Returns the user's best XP for [unitId], or 0 if never played.
  static int getBest(String unitId) {
    final v = _box.get(unitId);
    if (v is int) return v;
    return 0;
  }

  /// Records a finished run on [unitId] with [runXp] earned. Returns the
  /// delta to bank on the user's profile XP:
  ///
  ///   delta = max(0, runXp - previousBest)
  ///
  /// If the run beats the prior best, the new best is persisted to Hive and
  /// upserted to Supabase (fire-and-forget).
  static Future<int> recordRun({
    required String unitId,
    required int runXp,
  }) async {
    final previousBest = getBest(unitId);
    if (runXp <= previousBest) return 0;

    await _box.put(unitId, runXp);
    unawaited(_upsertRemote(unitId: unitId, bestXp: runXp));
    return runXp - previousBest;
  }

  static Future<void> _upsertRemote({
    required String unitId,
    required int bestXp,
  }) async {
    try {
      final profileBox = Hive.box('userProfile');
      final profileId = profileBox.get('id') as String?;
      if (profileId == null) return;

      await Supabase.instance.client.from('unit_best_xp').upsert(
        {
          'profile_id': profileId,
          'unit_id': unitId,
          'best_xp': bestXp,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'profile_id,unit_id',
      );
    } catch (e) {
      debugPrint('UnitBestXpService remote upsert failed (kept local): $e');
    }
  }
}
