import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocab_game/config/environment_constants.dart';

import 'models/user_profile.dart';
import 'router.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/streak_service.dart';
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

  // Initialize Supabase
  await Supabase.initialize(
    url: EnvironmentConstants.url,
    anonKey: EnvironmentConstants.anonKey,
  );

  // Initialize local notifications (streak warnings, duel alerts)
  await NotificationService.initialize();

  // Drain any pending offline syncs
  await SyncService.drainSyncQueue();

  // Check streak status on app open
  _checkStreakOnOpen();

  runApp(const ProviderScope(child: VocabGameApp()));
}

/// Global Supabase client getter — use anywhere in the app.
final supabase = Supabase.instance.client;

/// Check streak status and schedule warning notification if needed.
void _checkStreakOnOpen() {
  final profileBox = Hive.box('userProfile');
  final id = profileBox.get('id') as String?;
  if (id == null) return; // Not onboarded yet

  // Build a profile to check streak
  final profile = UserProfile()
    ..id = id
    ..username = profileBox.get('username', defaultValue: '') as String
    ..xp = profileBox.get('xp', defaultValue: 0) as int
    ..level = profileBox.get('level', defaultValue: 1) as int
    ..streakDays = profileBox.get('streakDays', defaultValue: 0) as int
    ..lastPlayedDate = profileBox.get('lastPlayedDate') as String?
    ..classCode = profileBox.get('classCode') as String?
    ..weekXp = profileBox.get('weekXp', defaultValue: 0) as int
    ..totalWordsAnswered =
        profileBox.get('totalWordsAnswered', defaultValue: 0) as int
    ..totalCorrect =
        profileBox.get('totalCorrect', defaultValue: 0) as int
    ..isTeacher =
        profileBox.get('isTeacher', defaultValue: false) as bool;

  // Check if streak was broken while app was closed
  StreakService.checkStreakOnAppOpen(profile);

  // Persist any streak reset back to Hive
  profileBox.put('streakDays', profile.streakDays);

  // Show streak warning notification if they haven't played today
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  if (profile.lastPlayedDate != today && profile.streakDays >= 2) {
    NotificationService.showStreakWarning(profile.streakDays);
  }

  // Subscribe to incoming duel challenges
  _subscribeToDuelChallenges(id);
}

void _subscribeToDuelChallenges(String myId) {
  try {
    Supabase.instance.client
        .channel('incoming-duels')
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
            final challenger =
                payload.newRecord['challenger_username'] as String? ??
                    'Someone';
            NotificationService.notifyDuelChallenge(challenger);
          },
        )
        .subscribe();
  } catch (_) {}
}

class VocabGameApp extends StatelessWidget {
  const VocabGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VocabGame Builder',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
    );
  }
}
