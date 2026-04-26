import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocab_game/config/environment_constants.dart';
import 'package:vocab_game/services/storage_provider.dart';
import 'package:vocab_game/services/version_service.dart';

import 'models/user_profile.dart';
import 'providers/theme_mode_provider.dart';
import 'router.dart';
import 'services/date_utils.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (existing)
  await StorageService.init();

  // Open the user profile box (for competitive features)
  await Hive.openBox('userProfile');

  // Open offline sync queue box
  await Hive.openBox('sync_queue');

  // Per-unit best XP cache — used to bank only the delta over a user's prior
  // best when they replay a library/assignment unit.
  await Hive.openBox('unitBestXp');

  // Security box holds the Hive encryption key and the PIN rate-limit state.
  // Must be opened after StorageService.init so the cipher helper works.
  await StorageService.openSecurityBox();

  // await NotificationService.instance.initialize();

  await LocalStorageProvider.init();

  // Validate build-time constants before using them
  EnvironmentConstants.validate();

  // Initialize Supabase
  await Supabase.initialize(url: EnvironmentConstants.url, anonKey: EnvironmentConstants.anonKey);

  // // Request notification permission (safe to call on every start—OS won't
  // // re-prompt if already granted. Covers the recovered-account case.)
  // await NotificationService.requestPermission(); TODO

  // Drain any pending offline syncs
  await SyncService.drainSyncQueue();

  // Subscribe to incoming duel challenges for the signed-in user, if any.
  await _subscribeForCurrentUser();

  await AppVersionInfo.instance.init();

  runApp(const ProviderScope(child: VocabGameApp()));
}

/// Global Supabase client getter — use anywhere in the app.
final supabase = Supabase.instance.client;

/// Holds the one realtime channel that listens for incoming duel challenges.
/// Stored at module scope so it can be cleanly unsubscribed on logout/app
/// lifecycle transitions — previously the reference was discarded, leaking
/// the subscription across hot restarts.
RealtimeChannel? _duelChallengeChannel;

/// Startup hooks for the signed-in user: weekly XP reset and the duel
/// realtime subscription. Streak handling is no longer here — it's derived
/// at render time via `streakProvider`, so there's nothing to "fix up" at
/// boot. See `lib/services/streak_calculator.dart`.
Future<void> _subscribeForCurrentUser() async {
  final profileBox = Hive.box('userProfile');
  final id = profileBox.get('id') as String?;
  if (id == null) return; // Not onboarded yet

  // Reset weekXp if a new ISO week has started.
  final profile = UserProfile()
    ..id = id
    ..username = profileBox.get('username', defaultValue: '') as String
    ..xp = profileBox.get('xp', defaultValue: 0) as int
    ..level = profileBox.get('level', defaultValue: 1) as int
    ..streakDays = profileBox.get('streakDays', defaultValue: 0) as int
    ..longestStreak = profileBox.get('longestStreak', defaultValue: 0) as int
    ..lastPlayedDate = profileBox.get('lastPlayedDate') as String?
    ..classCode = profileBox.get('classCode') as String?
    ..weekXp = profileBox.get('weekXp', defaultValue: 0) as int
    ..totalWordsAnswered =
        profileBox.get('totalWordsAnswered', defaultValue: 0) as int
    ..totalCorrect = profileBox.get('totalCorrect', defaultValue: 0) as int
    ..isTeacher = profileBox.get('isTeacher', defaultValue: false) as bool;
  await _resetWeekXpIfNeeded(profileBox, profile);

  // Subscribe to incoming duel challenges — fire and forget is OK here
  // because the subscribe call itself is async but we don't need the result.
  unawaited(_subscribeToDuelChallenges(id));
}

/// Resets weekXp to 0 if a new ISO week has started since the last reset.
/// Persists the reset to Hive and queues a Supabase sync.
Future<void> _resetWeekXpIfNeeded(Box profileBox, UserProfile profile) async {
  final currentWeek = AppDateUtils.isoWeekKey(DateTime.now());
  final lastResetWeek = profileBox.get('weekXpResetKey') as String?;

  if (lastResetWeek == currentWeek) return; // Same ISO week — nothing to do

  // New week has started (or first time tracking) — reset weekXp
  profile.weekXp = 0;
  await profileBox.put('weekXp', 0);
  await profileBox.put('weekXpResetKey', currentWeek);
  // Preserve the old Monday-based key for migration — harmless to keep.

  // Sync the reset to Supabase so the weekly leaderboard is accurate.
  // We intentionally don't await — the rest of app startup shouldn't block on
  // the network — but errors are logged inside syncProfile().
  unawaited(
    SyncService.syncProfile(profile).catchError((Object e, _) {
      debugPrint('Week-reset sync failed (will retry via queue): $e');
    }),
  );
}

/// Subscribes to incoming duel challenges. Stores the channel reference so
/// it can be unsubscribed on logout / hot restart (P1).
Future<void> _subscribeToDuelChallenges(String myId) async {
  // Clean up any prior subscription (handles hot restart + account recovery)
  try {
    await _duelChallengeChannel?.unsubscribe();
  } catch (e) {
    debugPrint('Duel channel unsubscribe failed (ignored): $e');
  }
  _duelChallengeChannel = null;

  try {
    final channel = Supabase.instance.client
        .channel('incoming-duels-$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'duels',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'opponent_id',
            value: myId,
          ),
          callback: (payload) {
            final challenger = payload.newRecord['challenger_username'] as String? ?? 'Someone';
            // NotificationService.notifyDuelChallenge(challenger); TODO
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint('Duel channel subscribe error: $error');
          }
        });
    _duelChallengeChannel = channel;
  } catch (e) {
    debugPrint('Failed to subscribe to duel channel: $e');
  }
}

/// Teardown hook for tests / logout flows.
@visibleForTesting
Future<void> disposeDuelChannel() async {
  try {
    await _duelChallengeChannel?.unsubscribe();
  } catch (_) {
    // already detached — swallow is safe here
  }
  _duelChallengeChannel = null;
}

class VocabGameApp extends ConsumerWidget {
  const VocabGameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Vocab Game',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
    );
  }
}
