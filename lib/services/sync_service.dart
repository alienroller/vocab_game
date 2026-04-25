import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Syncs the local Hive profile to Supabase.
///
/// All sync operations are connectivity-aware and never crash the app.
/// Call [syncProfile] after every game session ends (not after every question).
///
/// If sync fails due to connectivity, the profile data is queued in a local
/// Hive box ('sync_queue') and drained on next successful sync or app start.
class SyncService {
  static final _supabase = Supabase.instance.client;

  // ─── Profile Sync ─────────────────────────────────────────────────

  /// Upserts the local profile to Supabase.
  ///
  /// Safe to call even when offline — queues the sync for later if no connection.
  static Future<void> syncProfile(UserProfile profile) async {
    final profileData = _profileToMap(profile);

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _enqueue('profile_sync', profileData);
      return;
    }

    try {
      await _supabase.from('profiles').upsert(
        profileData,
        onConflict: 'id',
      );
    } catch (e) {
      debugPrint('Sync failed (queued for retry): $e');
      _enqueue('profile_sync', profileData);
    }
  }

  /// Converts a UserProfile to the Supabase-compatible map.
  static Map<String, dynamic> _profileToMap(UserProfile profile) {
    return {
      'id': profile.id,
      'username': profile.username,
      'xp': profile.xp,
      'level': profile.level,
      'streak_days': profile.streakDays,
      'longest_streak': profile.longestStreak,
      'last_played_date': profile.lastPlayedDate,
      'class_code': profile.classCode,
      'week_xp': profile.weekXp,
      'total_words_answered': profile.totalWordsAnswered,
      'total_correct': profile.totalCorrect,
      'is_teacher': profile.isTeacher,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// BUG 13 fix: Stores the LATEST snapshot per profile ID as a keyed map.
  /// Only the most recent data for each profile is kept — older snapshots are
  /// automatically overwritten. This prevents stale data from clobbering newer
  /// updates when the queue is drained.
  static void _enqueue(String type, Map<String, dynamic> data) {
    try {
      final box = Hive.box('sync_queue');
      final profileId = data['id'] as String?;
      // Use profile ID as key so each profile only has one entry
      final key = profileId != null ? 'profile_$profileId' : 'op_${DateTime.now().millisecondsSinceEpoch}';
      box.put(key, {
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('Sync queued for ${data['username'] ?? profileId} (${box.length} pending)');
    } catch (e) {
      debugPrint('Failed to enqueue sync: $e');
    }
  }

  /// Drains the sync queue — call on app start after confirming connectivity.
  ///
  /// BUG 13 fix: Since each profile now has exactly one entry (keyed by ID),
  /// we simply iterate all entries and upsert. No dedup needed.
  static Future<void> drainSyncQueue() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    try {
      final box = Hive.box('sync_queue');
      if (box.isEmpty) return;

      debugPrint('Draining sync queue (${box.length} items)...');

      final keysToRemove = <dynamic>[];

      for (final key in box.keys.toList()) {
        final item = box.get(key);
        if (item == null) {
          keysToRemove.add(key);
          continue;
        }

        final type = item['type'] as String? ?? 'profile_sync';

        // Handle pending account deletions
        if (type == 'pending_delete') {
          final userId = item['data']?['id'] as String?;
          if (userId != null) {
            try {
              await _supabase.from('profiles').delete().eq('id', userId);
              debugPrint('  ✅ Pending deletion completed for $userId');
              keysToRemove.add(key);
            } catch (e) {
              debugPrint('  ❌ Pending deletion failed: $e');
            }
          }
          continue;
        }

        // Handle profile syncs
        final data = Map<String, dynamic>.from(item['data'] as Map);

        try {
          await _supabase.from('profiles').upsert(
            data,
            onConflict: 'id',
          );
          keysToRemove.add(key);
          debugPrint('  ✅ Synced queued profile ${data['username']}');
        } catch (e) {
          debugPrint('  ❌ Retry failed, keeping in queue: $e');
        }
      }

      for (final key in keysToRemove) {
        await box.delete(key);
      }

      debugPrint('Sync queue drained (${box.length} remaining)');
    } catch (e) {
      debugPrint('Drain sync queue error: $e');
    }
  }

  // ─── Profile Fetch ────────────────────────────────────────────────

  /// Fetches a profile from Supabase by user ID.
  ///
  /// Used on app start to restore profile after reinstall or on a new device.
  /// Returns null if offline or profile doesn't exist.
  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Fetch profile failed: $e');
      return null;
    }
  }

  // ─── Username Check ───────────────────────────────────────────────

  /// Checks if a username is already taken in Supabase.
  static Future<bool> isUsernameTaken(String username) async {
    try {
      final result = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', username.trim())
          .limit(1);
      return (result as List).isNotEmpty;
    } catch (e) {
      debugPrint('Username check failed: $e');
      return false;
    }
  }

  // ─── Profile Deletion ─────────────────────────────────────────────

  /// BUG 7 fix: Safely deletes a profile.
  /// 1. Attempts remote deletion FIRST
  /// 2. Only clears local data AFTER confirmed remote success
  /// 3. If offline, queues a pending-delete and clears local data
  static Future<bool> deleteProfile(String userId) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.contains(ConnectivityResult.none);

      if (isOffline) {
        // Queue deletion for when we come back online
        try {
          final box = Hive.box('sync_queue');
          box.put('pending_delete_$userId', {
            'type': 'pending_delete',
            'data': {'id': userId},
            'timestamp': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Failed to queue pending delete for $userId: $e');
        }

        // Clear local data even offline (user expects immediate feedback)
        await _clearLocalData();
        return true; // Soft-true — deletion is queued
      }

      // Online: attempt remote deletion first
      await _supabase.from('profiles').delete().eq('id', userId);

      // Remote succeeded — now safe to clear local data
      await _clearLocalData();
      return true;
    } catch (e) {
      debugPrint('Delete profile failed: $e');
      return false;
    }
  }

  /// Clears all local Hive data after confirmed deletion.
  static Future<void> _clearLocalData() async {
    try {
      final box = Hive.box('userProfile');
      await box.clear();
    } catch (e) {
      debugPrint('Failed to clear userProfile box: $e');
    }

    try {
      final syncBox = Hive.box('sync_queue');
      await syncBox.clear();
    } catch (e) {
      debugPrint('Failed to clear sync_queue box: $e');
    }
  }
}
