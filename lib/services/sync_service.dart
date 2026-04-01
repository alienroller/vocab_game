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
      'last_played_date': profile.lastPlayedDate,
      'class_code': profile.classCode,
      'week_xp': profile.weekXp,
      'total_words_answered': profile.totalWordsAnswered,
      'total_correct': profile.totalCorrect,
      'is_teacher': profile.isTeacher,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // ─── Offline Sync Queue ───────────────────────────────────────────

  /// Queues a failed operation for later retry.
  static void _enqueue(String type, Map<String, dynamic> data) {
    try {
      final box = Hive.box('sync_queue');
      box.add({
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('Sync queued (${box.length} pending)');
    } catch (e) {
      debugPrint('Failed to enqueue sync: $e');
    }
  }

  /// Drains the sync queue — call on app start after confirming connectivity.
  ///
  /// Retries all queued profile syncs. Successfully synced items are removed.
  /// Failed items remain in the queue for the next drain attempt.
  static Future<void> drainSyncQueue() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    try {
      final box = Hive.box('sync_queue');
      if (box.isEmpty) return;

      debugPrint('Draining sync queue (${box.length} items)...');

      // Process from newest to oldest (newest data is most accurate)
      final keysToRemove = <dynamic>[];
      final processedIds = <String>{}; // Deduplicate — only sync latest per profile

      for (final key in box.keys.toList().reversed) {
        final item = box.get(key);
        if (item == null) continue;

        final data = Map<String, dynamic>.from(item['data'] as Map);
        final profileId = data['id'] as String?;

        // Skip if we already synced a newer version of this profile
        if (profileId != null && processedIds.contains(profileId)) {
          keysToRemove.add(key);
          continue;
        }

        try {
          await _supabase.from('profiles').upsert(
            data,
            onConflict: 'id',
          );
          keysToRemove.add(key);
          if (profileId != null) processedIds.add(profileId);
          debugPrint('  ✅ Synced queued profile ${data['username']}');
        } catch (e) {
          debugPrint('  ❌ Retry failed, keeping in queue: $e');
          // Leave in queue for next drain
        }
      }

      // Remove successfully synced items
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

  /// Permanently deletes a profile from Supabase and clears all local data.
  static Future<bool> deleteProfile(String userId) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return false;

      await _supabase.from('profiles').delete().eq('id', userId);

      final box = Hive.box('userProfile');
      await box.clear();

      // Clear sync queue too — no point syncing a deleted profile
      try {
        final syncBox = Hive.box('sync_queue');
        await syncBox.clear();
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Delete profile failed: $e');
      return false;
    }
  }
}
