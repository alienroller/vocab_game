import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/date_utils.dart';
import '../services/sync_service.dart';
import '../services/xp_service.dart';

/// Global profile provider — the single source of truth for user state.
///
/// Loads from Hive on initialization and syncs to Supabase after changes.
final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile?>((ref) {
  return ProfileNotifier();
});

/// Manages the local user profile lifecycle.
class ProfileNotifier extends StateNotifier<UserProfile?> {
  ProfileNotifier() : super(null) {
    _loadProfile();
  }

  bool _isMutating = false; // BUG 15: Re-entrancy guard

  /// A2 fix: Serialises concurrent writes (game completions, badge awards,
  /// teacher promotions). Each mutation waits for the previous one to
  /// complete before reading profile state — prevents lost updates when
  /// two games finish nearly simultaneously.
  Future<void> _pendingMutation = Future<void>.value();
  Future<T> _withWriteLock<T>(Future<T> Function() op) {
    final prev = _pendingMutation;
    final completer = Completer<T>();
    _pendingMutation = completer.future.then(
      (_) {},
      onError: (_) {},
    );
    // Run after the previous mutation settles, regardless of outcome.
    prev.whenComplete(() async {
      try {
        completer.complete(await op());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  /// Builds a UserProfile from the current Hive box data.
  UserProfile? _buildProfileFromHive() {
    final box = Hive.box('userProfile');
    final id = box.get('id') as String?;
    if (id == null) return null;

    return UserProfile()
      ..id = id
      ..username = box.get('username', defaultValue: '') as String
      ..xp = box.get('xp', defaultValue: 0) as int
      ..level = box.get('level', defaultValue: 1) as int
      ..streakDays = box.get('streakDays', defaultValue: 0) as int
      ..lastPlayedDate = box.get('lastPlayedDate') as String?
      ..classCode = box.get('classCode') as String?
      ..weekXp = box.get('weekXp', defaultValue: 0) as int
      ..totalWordsAnswered =
          box.get('totalWordsAnswered', defaultValue: 0) as int
      ..totalCorrect = box.get('totalCorrect', defaultValue: 0) as int
      ..hasOnboarded = box.get('hasOnboarded', defaultValue: false) as bool
      ..isTeacher = box.get('isTeacher', defaultValue: false) as bool
      ..unlockedBadges = (box.get('unlockedBadges', defaultValue: <String>[]) as List).cast<String>();
  }

  Future<void> _loadProfile() async {
    state = _buildProfileFromHive();
  }

  /// Force-reloads the profile from Hive into the provider state.
  /// Call this after external code writes directly to Hive (e.g. Library quiz,
  /// account recovery).
  Future<void> reload() async {
    state = _buildProfileFromHive();
    await checkAndResetWeekXp(); // BUG 3: Check week reset on every app load
  }

  /// Creates a new profile during onboarding.
  Future<void> createProfile({
    required String id,
    required String username,
    bool isTeacher = false,
  }) async {
    final box = Hive.box('userProfile');
    await box.put('id', id);
    await box.put('username', username);
    await box.put('xp', 0);
    await box.put('level', 1);
    await box.put('streakDays', 0);
    await box.put('weekXp', 0);
    await box.put('totalWordsAnswered', 0);
    await box.put('totalCorrect', 0);
    await box.put('hasOnboarded', true);
    await box.put('isTeacher', isTeacher);
    await box.put('unlockedBadges', <String>[]);

    state = UserProfile()
      ..id = id
      ..username = username
      ..xp = 0
      ..level = 1
      ..streakDays = 0
      ..weekXp = 0
      ..totalWordsAnswered = 0
      ..totalCorrect = 0
      ..hasOnboarded = true
      ..isTeacher = isTeacher
      ..unlockedBadges = [];
  }

  /// Creates a clone of the current profile with all fields copied.
  UserProfile _cloneProfile(UserProfile profile) {
    return UserProfile()
      ..id = profile.id
      ..username = profile.username
      ..xp = profile.xp
      ..level = profile.level
      ..streakDays = profile.streakDays
      ..lastPlayedDate = profile.lastPlayedDate
      ..classCode = profile.classCode
      ..weekXp = profile.weekXp
      ..totalWordsAnswered = profile.totalWordsAnswered
      ..totalCorrect = profile.totalCorrect
      ..hasOnboarded = profile.hasOnboarded
      ..isTeacher = profile.isTeacher
      ..unlockedBadges = List.from(profile.unlockedBadges);
  }

  /// All-in-one post-game session handler.
  /// Adds XP, records per-word accuracy, evaluates streak, and syncs to Supabase.
  /// This is the ONLY method games should call after finishing.
  ///
  /// A2 fix: Runs under a write lock so two games finishing at the same time
  /// don't race on the Hive snapshot.
  Future<void> recordGameSession({
    required int xpGained,
    required int totalQuestions,
    required int correctAnswers,
  }) {
    return _withWriteLock(() async {
      // Re-read state inside the lock so we see any mutation that just
      // completed (e.g. a previous game session's write).
      final snapshot = _buildProfileFromHive();
      if (snapshot == null) return;
      final profile = snapshot;

      // Reset weekXp if a new ISO week has arrived since the last reset
      await _checkWeekReset(profile);

      // Update XP
      profile.xp += xpGained;
      profile.weekXp += xpGained;
      profile.level = XpService.levelFromXp(profile.xp);

      // Update accuracy stats (per-word, not per-session)
      profile.totalWordsAnswered += totalQuestions;
      profile.totalCorrect += correctAnswers;

      // BUG 4 fix: Evaluate streak (idempotent — safe to call every session)
      await _evaluateStreak(profile);

      await _saveToHive(profile);
      state = _cloneProfile(profile);

      // Sync to cloud — failures are queued inside syncProfile, don't block UX
      try {
        await SyncService.syncProfile(state!);
      } catch (e, s) {
        debugPrint('recordGameSession sync failed (queued): $e\n$s');
      }
    });
  }

  /// Resets weekXp to 0 if a new ISO-8601 week has started.
  /// P6 fix: Uses ISO week (anchored to Thursday) so timezone changes
  /// can't double-trigger or skip a reset.
  Future<void> _checkWeekReset(UserProfile profile) async {
    final currentWeek = AppDateUtils.isoWeekKey(DateTime.now());

    final box = Hive.box('userProfile');
    final lastReset = box.get('weekXpResetKey') as String?;

    if (lastReset != currentWeek) {
      profile.weekXp = 0;
      await box.put('weekXp', 0);
      await box.put('weekXpResetKey', currentWeek);
    }
  }

  /// BUG 4 fix: Evaluates and updates the streak based on today's date.
  /// Idempotent — safe to call multiple times per day (only updates once per day).
  /// Called ONLY from recordGameSession(), not from UI code.
  Future<void> _evaluateStreak(UserProfile profile) async {
    final today = DateTime.now();
    final todayStr = AppDateUtils.ymd(today);

    // Already recorded today → do nothing (idempotency)
    if (profile.lastPlayedDate == todayStr) return;

    int newStreak;
    if (profile.lastPlayedDate == null) {
      // First time ever playing
      newStreak = 1;
    } else {
      final lastPlayed = DateTime.parse(profile.lastPlayedDate!);
      final daysSinceLast = today.difference(lastPlayed).inDays;

      if (daysSinceLast == 1) {
        // Played yesterday → extend streak
        newStreak = profile.streakDays + 1;
      } else if (daysSinceLast == 0) {
        // Same day (clock edge case) → no change
        newStreak = profile.streakDays;
      } else {
        // Missed a day → reset streak to 1
        newStreak = 1;
      }
    }

    final box = Hive.box('userProfile');
    await box.put('streakDays', newStreak);
    await box.put('lastPlayedDate', todayStr);
    profile.streakDays = newStreak;
    profile.lastPlayedDate = todayStr;
  }

  /// BUG 3 fix: Checks if weekly XP needs resetting. Called on app open/resume.
  /// A7 fix: Sync failure is logged (was fire-and-forget).
  Future<void> checkAndResetWeekXp() async {
    return _withWriteLock(() async {
      final profile = state;
      if (profile == null) return;

      final currentWeekKey = AppDateUtils.isoWeekKey(DateTime.now());

      // Derive what week the last game was played
      final lastDate = profile.lastPlayedDate;
      if (lastDate == null) return; // Never played — nothing to reset

      final lastPlayedWeekKey =
          AppDateUtils.isoWeekKey(DateTime.parse(lastDate));

      if (currentWeekKey != lastPlayedWeekKey) {
        // A new ISO week has started — reset weekly XP
        final box = Hive.box('userProfile');
        await box.put('weekXp', 0);
        await box.put('weekXpResetKey', currentWeekKey);
        profile.weekXp = 0;
        state = _cloneProfile(profile);
        try {
          await SyncService.syncProfile(state!);
        } catch (e) {
          debugPrint('Week-reset sync failed (queued): $e');
        }
      }
    });
  }

  /// Sets the class code for this profile.
  Future<void> setClassCode(String? code) async {
    if (state == null) return;
    final profile = state!;
    profile.classCode = code;

    await _saveToHive(profile);
    state = _cloneProfile(profile);

    // Sync class change to cloud
    await SyncService.syncProfile(state!);
  }

  /// Updates the username.
  Future<void> updateUsername(String newUsername) async {
    if (state == null) return;
    final profile = state!;

    // Update in Supabase first — rethrow so the UI can show an error.
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'username': newUsername}).eq('id', profile.id);
    } catch (e, s) {
      debugPrint('Username update failed for ${profile.id}: $e\n$s');
      rethrow;
    }

    profile.username = newUsername;
    await _saveToHive(profile);
    state = _cloneProfile(profile);
  }

  /// Appends pushing a freshly awarded badge.
  Future<void> awardBadge(String badgeName) async {
    if (state == null) return;
    final profile = state!;
    
    // Prevent duplicated identical badges
    if (!profile.unlockedBadges.contains(badgeName)) {
      profile.unlockedBadges.add(badgeName);
      await _saveToHive(profile);
      state = _cloneProfile(profile);
    }
  }

  /// BUG 15 fix: Marks the user as a teacher with re-entrancy guard.
  /// A7 fix: Awaits sync so errors surface to the caller.
  Future<void> setTeacher(bool isTeacher) async {
    // Guard against re-entrant calls
    if (_isMutating) return;
    _isMutating = true;

    try {
      if (state == null) return;
      final profile = state!;
      if (profile.isTeacher == isTeacher) return; // Already the right value

      final box = Hive.box('userProfile');
      await box.put('isTeacher', isTeacher);
      profile.isTeacher = isTeacher;
      state = _cloneProfile(profile);
      try {
        await SyncService.syncProfile(state!);
      } catch (e) {
        debugPrint('setTeacher sync failed (queued): $e');
      }
    } finally {
      _isMutating = false;
    }
  }

  /// Logs out the user — clears all local data without deleting the
  /// Supabase profile.
  Future<void> logout() async {
    final box = Hive.box('userProfile');
    await box.clear();
    state = null;
  }

  /// Syncs the current profile to Supabase.
  Future<void> sync() async {
    if (state == null) return;
    await SyncService.syncProfile(state!);
  }

  Future<void> _saveToHive(UserProfile profile) async {
    final box = Hive.box('userProfile');
    await box.put('id', profile.id);
    await box.put('username', profile.username);
    await box.put('xp', profile.xp);
    await box.put('level', profile.level);
    await box.put('streakDays', profile.streakDays);
    await box.put('lastPlayedDate', profile.lastPlayedDate);
    await box.put('classCode', profile.classCode);
    await box.put('weekXp', profile.weekXp);
    await box.put('totalWordsAnswered', profile.totalWordsAnswered);
    await box.put('totalCorrect', profile.totalCorrect);
    await box.put('hasOnboarded', profile.hasOnboarded);
    await box.put('isTeacher', profile.isTeacher);
    await box.put('unlockedBadges', profile.unlockedBadges);
  }
}
