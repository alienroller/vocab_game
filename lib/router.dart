import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'games/fill_blank_game.dart';
import 'games/flashcard_game.dart';
import 'games/matching_game.dart';
import 'games/memory_game.dart';
import 'games/quiz_game.dart';
import 'screens/app_shell.dart';
import 'screens/duel/duel_game_screen.dart';
import 'screens/duel/duel_history_screen.dart';
import 'screens/duel/duel_lobby_screen.dart';
import 'screens/duel/duel_results_screen.dart';
import 'screens/game_selection_screen.dart';
import 'screens/hall_of_fame_screen.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/onboarding/join_class_screen.dart';
import 'screens/onboarding/pin_setup_screen.dart';
import 'screens/onboarding/recovery_screen.dart';
import 'screens/onboarding/username_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/result_screen.dart';
import 'screens/search_screen.dart';
import 'screens/teacher_dashboard_screen.dart';

/// Smooth fade + slide page transition for all routes.
CustomTransitionPage<void> _buildPage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      final slideIn = Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(fadeIn);

      return FadeTransition(
        opacity: fadeIn,
        child: SlideTransition(
          position: slideIn,
          child: child,
        ),
      );
    },
  );
}

// Navigation keys for each tab branch
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _libraryNavKey = GlobalKey<NavigatorState>(debugLabel: 'library');
final _searchNavKey = GlobalKey<NavigatorState>(debugLabel: 'search');
final _duelsNavKey = GlobalKey<NavigatorState>(debugLabel: 'duels');
final _profileNavKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Centralized router — all navigation goes through named routes.
///
/// Uses StatefulShellRoute for bottom nav tabs (Home, Games, Ranks, Profile).
/// Redirect logic ensures unauthenticated users → /welcome, onboarded → /home.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final profileBox = Hive.box('userProfile');
    final hasOnboarded =
        profileBox.get('hasOnboarded', defaultValue: false) as bool;
    final path = state.matchedLocation;

    final isOnboarding = path == '/welcome' ||
        path.startsWith('/onboarding') ||
        path == '/recovery';

    if (!hasOnboarded && !isOnboarding) return '/welcome';
    if (hasOnboarded && path == '/welcome') return '/home';
    if (path == '/') return hasOnboarded ? '/home' : '/welcome';

    return null;
  },
  routes: [
    // ─── Root (always redirected) ───────────────────────────────
    GoRoute(path: '/', redirect: (_, __) => '/home'),

    // ─── Onboarding (no bottom nav) ─────────────────────────────
    GoRoute(
      path: '/welcome',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const WelcomeScreen(), state),
    ),
    GoRoute(
      path: '/onboarding/username',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const UsernameScreen(), state),
    ),
    GoRoute(
      path: '/onboarding/join-class',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const JoinClassScreen(), state),
    ),
    GoRoute(
      path: '/onboarding/pin',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const PinSetupScreen(), state),
    ),
    GoRoute(
      path: '/recovery',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const RecoveryScreen(), state),
    ),

    // ─── Bottom Nav Shell ───────────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // Tab 0: Home
        StatefulShellBranch(
          navigatorKey: _homeNavKey,
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (_, state) =>
                  _buildPage(const HomeScreen(), state),
              routes: [
                GoRoute(
                  path: 'hall-of-fame',
                  pageBuilder: (_, state) =>
                      _buildPage(const HallOfFameScreen(), state),
                ),
                GoRoute(
                  path: 'leaderboard',
                  pageBuilder: (_, state) =>
                      _buildPage(const LeaderboardScreen(), state),
                ),
                GoRoute(
                  path: 'games',
                  pageBuilder: (_, state) =>
                      _buildPage(const GameSelectionScreen(), state),
                ),
              ],
            ),
          ],
        ),

        // Tab 1: Library
        StatefulShellBranch(
          navigatorKey: _libraryNavKey,
          routes: [
            GoRoute(
              path: '/library',
              pageBuilder: (_, state) =>
                  _buildPage(const LibraryScreen(), state),
            ),
          ],
        ),

        // Tab 2: Search
        StatefulShellBranch(
          navigatorKey: _searchNavKey,
          routes: [
            GoRoute(
              path: '/search',
              pageBuilder: (_, state) =>
                  _buildPage(const SearchScreen(), state),
            ),
          ],
        ),

        // Tab 2: Duels
        StatefulShellBranch(
          navigatorKey: _duelsNavKey,
          routes: [
            GoRoute(
              path: '/duels',
              pageBuilder: (_, state) =>
                  _buildPage(const DuelLobbyScreen(), state),
            ),
          ],
        ),

        // Tab 3: Profile
        StatefulShellBranch(
          navigatorKey: _profileNavKey,
          routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: (_, state) =>
                  _buildPage(const ProfileScreen(), state),
            ),
          ],
        ),
      ],
    ),

    // ─── Full-screen overlays (no bottom nav) ───────────────────
    GoRoute(
      path: '/games/quiz',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const QuizGame(), state),
    ),
    GoRoute(
      path: '/games/flashcard',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const FlashcardGame(), state),
    ),
    GoRoute(
      path: '/games/matching',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const MatchingGame(), state),
    ),
    GoRoute(
      path: '/games/memory',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const MemoryGame(), state),
    ),
    GoRoute(
      path: '/games/fill-blank',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const FillBlankGame(), state),
    ),
    GoRoute(
      path: '/result',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final args = state.extra as Map<String, dynamic>;
        return _buildPage(
          ResultScreen(
            score: args['score'] as int,
            total: args['total'] as int,
            gameName: args['gameName'] as String,
            gameRoute: args['gameRoute'] as String,
            xpGained: args['xpGained'] as int? ?? 0,
          ),
          state,
        );
      },
    ),

    // ─── Duels (full-screen overlays) ───────────────────────────
    GoRoute(
      path: '/duels/invites',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const DuelInvitesScreen(), state),
    ),
    GoRoute(
      path: '/duels/game',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final args = state.extra as Map<String, dynamic>;
        return _buildPage(
          DuelGameScreen(
            duelId: args['duelId'] as String,
            words: args['words'] as List<Map<String, dynamic>>,
            isChallenger: args['isChallenger'] as bool,
          ),
          state,
        );
      },
    ),
    GoRoute(
      path: '/duels/results',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final args = state.extra as Map<String, dynamic>;
        return _buildPage(
          DuelResultsScreen(
            myScore: args['myScore'] as int,
            opponentScore: args['opponentScore'] as int,
            totalWords: args['totalWords'] as int,
            myXpGain: args['myXpGain'] as int,
            didWin: args['didWin'] as bool,
            isDraw: args['isDraw'] as bool,
            opponentUsername: args['opponentUsername'] as String,
          ),
          state,
        );
      },
    ),
    GoRoute(
      path: '/duels/history',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const DuelHistoryScreen(), state),
    ),

    // ─── Teacher Dashboard ──────────────────────────────────────
    GoRoute(
      path: '/teacher-dashboard',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final classCode = state.extra as String;
        return _buildPage(
          TeacherDashboardScreen(classCode: classCode),
          state,
        );
      },
    ),
  ],
);
