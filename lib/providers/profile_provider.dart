import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  Future<void> _loadProfile() async {
    final box = Hive.box('userProfile');
    final id = box.get('id') as String?;
    if (id == null) {
      // No profile yet — user needs to complete onboarding
      state = null;
      return;
    }

    final profile = UserProfile()
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
      ..hasOnboarded = box.get('hasOnboarded', defaultValue: false) as bool;

    state = profile;
  }

  /// Creates a new profile during onboarding.
  Future<void> createProfile({
    required String id,
    required String username,
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

    state = UserProfile()
      ..id = id
      ..username = username
      ..xp = 0
      ..level = 1
      ..streakDays = 0
      ..weekXp = 0
      ..totalWordsAnswered = 0
      ..totalCorrect = 0
      ..hasOnboarded = true;
  }

  /// Adds XP to the profile and updates the level.
  Future<void> addXp(int amount) async {
    if (state == null) return;
    final profile = state!;
    profile.xp += amount;
    profile.weekXp += amount;
    profile.level = XpService.levelFromXp(profile.xp);

    await _saveToHive(profile);
    state = UserProfile()
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
      ..hasOnboarded = profile.hasOnboarded;
  }

  /// Records a question answer (updates stats).
  Future<void> recordAnswer({required bool correct}) async {
    if (state == null) return;
    final profile = state!;
    profile.totalWordsAnswered += 1;
    if (correct) profile.totalCorrect += 1;

    await _saveToHive(profile);
    // Trigger rebuild with a new UserProfile instance
    state = UserProfile()
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
      ..hasOnboarded = profile.hasOnboarded;
  }

  /// Updates the streak after a game session.
  Future<void> updateStreak(int newStreakDays, String lastPlayedDate) async {
    if (state == null) return;
    final profile = state!;
    profile.streakDays = newStreakDays;
    profile.lastPlayedDate = lastPlayedDate;

    await _saveToHive(profile);
    state = UserProfile()
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
      ..hasOnboarded = profile.hasOnboarded;
  }

  /// Sets the class code for this profile.
  Future<void> setClassCode(String code) async {
    if (state == null) return;
    final profile = state!;
    profile.classCode = code;

    await _saveToHive(profile);
    state = UserProfile()
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
      ..hasOnboarded = profile.hasOnboarded;
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
  }
}
