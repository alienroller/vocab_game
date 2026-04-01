import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Syncs the local Hive profile to Supabase.
///
/// All sync operations are connectivity-aware and never crash the app.
/// Call [syncProfile] after every game session ends (not after every question).
class SyncService {
  static final _supabase = Supabase.instance.client;

  /// Upserts the local profile to Supabase.
  ///
  /// Safe to call even when offline — silently does nothing if no connection.
  static Future<void> syncProfile(UserProfile profile) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    try {
      await _supabase.from('profiles').upsert(
        {
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
        },
        onConflict: 'id',
      );
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

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

  /// Checks if a username is already taken in Supabase.
  ///
  /// Used during onboarding and profile editing for uniqueness validation.
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
      return false; // assume available on error
    }
  }

  /// Permanently deletes a profile from Supabase.
  ///
  /// This cascade-deletes all related data (duels, word_mastery, hall_of_fame)
  /// via foreign key constraints. Also clears all local Hive data.
  static Future<bool> deleteProfile(String userId) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return false;

      await _supabase.from('profiles').delete().eq('id', userId);

      // Clear all local data
      final box = Hive.box('userProfile');
      await box.clear();

      return true;
    } catch (e) {
      debugPrint('Delete profile failed: $e');
      return false;
    }
  }
}
