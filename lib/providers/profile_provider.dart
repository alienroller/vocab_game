import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
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
      ..isTeacher = box.get('isTeacher', defaultValue: false) as bool;
  }

  Future<void> _loadProfile() async {
    state = _buildProfileFromHive();
  }

  /// Force-reloads the profile from Hive into the provider state.
  /// Call this after external code writes directly to Hive (e.g. Library quiz,
  /// account recovery).
  Future<void> reload() async {
    state = _buildProfileFromHive();
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
      ..isTeacher = isTeacher;
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
      ..isTeacher = profile.isTeacher;
  }

  /// Adds XP to the profile and updates the level.
  Future<void> addXp(int amount) async {
    if (state == null) return;
    final profile = state!;
    profile.xp += amount;
    profile.weekXp += amount;
    profile.level = XpService.levelFromXp(profile.xp);

    await _saveToHive(profile);
    state = _cloneProfile(profile);

    // Sync to cloud immediately so leaderboard/rival data stays fresh
    await SyncService.syncProfile(state!);
  }

  /// Records answers for a game session (batch update).
  /// [totalQuestions] — total words answered in the session.
  /// [correctAnswers] — number of correct answers.
  Future<void> recordAnswers({
    required int totalQuestions,
    required int correctAnswers,
  }) async {
    if (state == null) return;
    final profile = state!;
    profile.totalWordsAnswered += totalQuestions;
    profile.totalCorrect += correctAnswers;

    await _saveToHive(profile);
    state = _cloneProfile(profile);
  }

  /// All-in-one post-game session handler.
  /// Adds XP, records per-word accuracy, and syncs to Supabase.
  /// This is the ONLY method games should call after finishing.
  Future<void> recordGameSession({
    required int xpGained,
    required int totalQuestions,
    required int correctAnswers,
  }) async {
    if (state == null) return;
    final profile = state!;

    // Update XP
    profile.xp += xpGained;
    profile.weekXp += xpGained;
    profile.level = XpService.levelFromXp(profile.xp);

    // Update accuracy stats (per-word, not per-session)
    profile.totalWordsAnswered += totalQuestions;
    profile.totalCorrect += correctAnswers;

    await _saveToHive(profile);
    state = _cloneProfile(profile);

    // Sync to cloud
    await SyncService.syncProfile(state!);
  }

  /// Updates the streak after a game session.
  Future<void> updateStreak(int newStreakDays, String lastPlayedDate) async {
    if (state == null) return;
    final profile = state!;
    profile.streakDays = newStreakDays;
    profile.lastPlayedDate = lastPlayedDate;

    await _saveToHive(profile);
    state = _cloneProfile(profile);

    // Sync streak to cloud so it's visible on other devices
    await SyncService.syncProfile(state!);
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

    // Update in Supabase first
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'username': newUsername}).eq('id', profile.id);
    } catch (_) {
      rethrow;
    }

    profile.username = newUsername;
    await _saveToHive(profile);
    state = _cloneProfile(profile);
  }

  /// Marks the user as a teacher.
  Future<void> setTeacher(bool isTeacher) async {
    if (state == null) return;
    final profile = state!;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_teacher': isTeacher}).eq('id', profile.id);
    } catch (_) {
      // Silently fail — local state still updates
    }

    profile.isTeacher = isTeacher;
    await _saveToHive(profile);
    state = _cloneProfile(profile);
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
  }
}
