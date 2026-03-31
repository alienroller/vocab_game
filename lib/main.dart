import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocab_game/config/environment_constants.dart';

import 'models/user_profile.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/streak_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (existing)
  await StorageService.init();

  // Open the user profile box (new — for competitive features)
  await Hive.openBox('userProfile');

  // Initialize Supabase
  await Supabase.initialize(
    url: EnvironmentConstants.url,
    anonKey: EnvironmentConstants.anonKey,
  );

  // Initialize local notifications (streak warnings, duel alerts)
  await NotificationService.initialize();

  runApp(const ProviderScope(child: VocabGameApp()));
}

/// Global Supabase client getter — use anywhere in the app.
final supabase = Supabase.instance.client;

class VocabGameApp extends StatelessWidget {
  const VocabGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VocabGame Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const _AppRouter(),
    );
  }
}

/// Routes to onboarding or home based on whether the user has onboarded.
/// Also checks streak status on app open.
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  @override
  void initState() {
    super.initState();
    _checkStreakOnOpen();
  }

  void _checkStreakOnOpen() {
    final profileBox = Hive.box('userProfile');
    final id = profileBox.get('id') as String?;
    if (id == null) return; // Not onboarded yet

    // Build a profile to check streak
    final profile =
        UserProfile()
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
              profileBox.get('totalCorrect', defaultValue: 0) as int;

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

  @override
  void dispose() {
    try {
      Supabase.instance.client.channel('incoming-duels').unsubscribe();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileBox = Hive.box('userProfile');
    final hasOnboarded =
        profileBox.get('hasOnboarded', defaultValue: false) as bool;

    if (hasOnboarded) {
      return const HomeScreen();
    }
    return const WelcomeScreen();
  }
}
