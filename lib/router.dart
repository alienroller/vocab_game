import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vocab_game/screens/update.dart';

import 'games/fill_blank_game.dart';
import 'games/flashcard_game.dart';
import 'games/matching_game.dart';
import 'games/memory_game.dart';
import 'games/quiz_game.dart';
import 'screens/student/student_exam_lobby_screen.dart';
import 'screens/student/student_exam_results_screen.dart';
import 'screens/student/student_exam_screen.dart';
import 'screens/student_nav_shell.dart';
import 'screens/teacher_nav_shell.dart';
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
import 'models/class_student.dart';
import 'models/vocab.dart';
import 'screens/onboarding/class_code_reveal_screen.dart';
import 'screens/onboarding/teacher_class_setup_screen.dart';
import 'screens/teacher/teacher_analytics_screen.dart';
import 'screens/teacher/teacher_classes_screen.dart';
import 'screens/teacher/create_exam_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/teacher/teacher_exam_lobby_screen.dart';
import 'screens/teacher/teacher_exam_results_screen.dart';
import 'screens/teacher/teacher_exams_screen.dart';
import 'screens/teacher/teacher_library_screen.dart';
import 'screens/teacher/teacher_profile_screen.dart';
import 'screens/teacher/teacher_student_detail_screen.dart';
import 'features/speaking/presentation/screens/lesson_runner_screen.dart';
import 'features/speaking/presentation/screens/scenario_intro_screen.dart';
import 'features/speaking/presentation/screens/scenario_list_screen.dart';
import 'speaking/models/speaking_models.dart';
import 'speaking/screens/speaking_home_screen.dart';
import 'speaking/screens/speaking_lesson_screen.dart';

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

final _teacherDashboardNavKey = GlobalKey<NavigatorState>(debugLabel: 't_dash');
final _teacherClassesNavKey = GlobalKey<NavigatorState>(debugLabel: 't_class');
final _teacherLibraryNavKey = GlobalKey<NavigatorState>(debugLabel: 't_lib');
final _teacherAnalyticsNavKey = GlobalKey<NavigatorState>(debugLabel: 't_analytics');
final _teacherProfileNavKey = GlobalKey<NavigatorState>(debugLabel: 't_profile');
final _teacherExamsNavKey = GlobalKey<NavigatorState>(debugLabel: 't_exams');

/// Centralized router — all navigation goes through named routes.
///
/// Uses StatefulShellRoute for bottom nav tabs (Home, Games, Ranks, Profile).
/// Redirect logic ensures unauthenticated users → /welcome, onboarded → /home.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    // Guard against box not being open (defensive — should not happen
    // after main.dart awaits Hive.openBox, but prevents cold-start crashes)
    if (!Hive.isBoxOpen('userProfile')) return '/welcome';

    final profileBox = Hive.box('userProfile');
    final hasOnboarded =
        profileBox.get('hasOnboarded', defaultValue: false) as bool;
    final path = state.matchedLocation;

    final isOnboarding = path == '/welcome' ||
        path.startsWith('/onboarding') ||
        path == '/recovery';

    if (!hasOnboarded && !isOnboarding) return '/welcome';
    if (hasOnboarded && path == '/welcome') return '/home';

    final isTeacher = profileBox.get('isTeacher', defaultValue: false) as bool;
    if (path == '/') {
      if (!hasOnboarded) return '/welcome';
      return isTeacher ? '/teacher/dashboard' : '/home';
    }

    if (isTeacher && (path == '/home' || path == '/library' || path == '/profile' || path.startsWith('/duels') || path.startsWith('/speaking'))) {
      return '/teacher/dashboard';
    }
    if (!isTeacher && path.startsWith('/teacher')) {
      return '/home';
    }

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
      path: '/update',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) => _buildPage(const UpdateScreen(), state),
    ),
    GoRoute(
      path: '/onboarding/pin',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        final isTeacher = args['isTeacher'] as bool? ?? false;
        final username = args['username'] as String? ?? '';
        return _buildPage(PinSetupScreen(isTeacher: isTeacher, username: username), state);
      },
    ),
    GoRoute(
      path: '/onboarding/teacher-class-setup',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const TeacherClassSetupScreen(), state),
    ),
    GoRoute(
      path: '/onboarding/class-code-reveal',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return _buildPage(
          ClassCodeRevealScreen(
            classCode: args['classCode'] as String? ?? '',
            className: args['className'] as String? ?? 'Class',
          ),
          state,
        );
      },
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
          StudentNavShell(navigationShell: navigationShell),
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

        // Tab 2: Speaking (Falou-style scenario list)
        StatefulShellBranch(
          navigatorKey: _searchNavKey, // re-used navKey for convenience without breaking global root scope
          routes: [
            GoRoute(
              path: '/speaking',
              pageBuilder: (_, state) =>
                  _buildPage(const ScenarioListScreen(), state),
              routes: [
                GoRoute(
                  path: 'scenario/:id',
                  pageBuilder: (_, state) {
                    final id = state.pathParameters['id']!;
                    return _buildPage(
                      ScenarioIntroScreen(scenarioId: id),
                      state,
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'run',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (_, state) {
                        final id = state.pathParameters['id']!;
                        return _buildPage(
                          LessonRunnerScreen(scenarioId: id),
                          state,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Tab 3: Duels
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

        // Tab 5: Profile
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
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _buildPage(QuizGame(
          customWords: extra?['customWords'] as List<Vocab>?,
          assignmentId: extra?['assignmentId'] as String?,
        ), state);
      },
    ),
    GoRoute(
      path: '/games/flashcard',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _buildPage(FlashcardGame(
          customWords: extra?['customWords'] as List<Vocab>?,
          assignmentId: extra?['assignmentId'] as String?,
        ), state);
      },
    ),
    GoRoute(
      path: '/games/matching',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _buildPage(MatchingGame(
          customWords: extra?['customWords'] as List<Vocab>?,
          assignmentId: extra?['assignmentId'] as String?,
        ), state);
      },
    ),
    GoRoute(
      path: '/games/memory',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _buildPage(MemoryGame(
          customWords: extra?['customWords'] as List<Vocab>?,
          assignmentId: extra?['assignmentId'] as String?,
        ), state);
      },
    ),
    GoRoute(
      path: '/games/fill-blank',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return _buildPage(FillBlankGame(
          customWords: extra?['customWords'] as List<Vocab>?,
          assignmentId: extra?['assignmentId'] as String?,
        ), state);
      },
    ),

    // ─── Search Overlay ──────────────────────────────────────────
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const SearchScreen(), state),
    ),

    GoRoute(
      path: '/speaking-legacy',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) =>
          _buildPage(const SpeakingHomeScreen(), state),
    ),
    GoRoute(
      path: '/speaking/lesson',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        if (state.extra is! SpeakingLesson) return '/speaking';
        return null;
      },
      pageBuilder: (_, state) {
        final lesson = state.extra as SpeakingLesson;
        return _buildPage(
          SpeakingLessonScreen(lesson: lesson),
          state,
        );
      },
    ),
    GoRoute(
      path: '/result',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) {
        if (state.extra is! Map<String, dynamic>) return '/home';
        return null; // safe to proceed
      },
      pageBuilder: (_, state) {
        final args = state.extra as Map<String, dynamic>;
        return _buildPage(
          ResultScreen(
            score: args['score'] as int,
            total: args['total'] as int,
            gameName: args['gameName'] as String,
            gameRoute: args['gameRoute'] as String,
            xpGained: args['xpGained'] as int? ?? 0,
            customWords: args['customWords'] as List<Vocab>?,
            assignmentId: args['assignmentId'] as String?,
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
      redirect: (context, state) {
        if (state.extra is! Map<String, dynamic>) return '/duels';
        return null;
      },
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
      redirect: (context, state) {
        if (state.extra is! Map<String, dynamic>) return '/duels';
        return null;
      },
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

    // ─── Student exam flow ──────────────────────────────────────────────
    GoRoute(
      path: '/student/exam/:sessionId/lobby',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return _buildPage(
          StudentExamLobbyScreen(sessionId: sessionId),
          state,
        );
      },
    ),
    GoRoute(
      path: '/student/exam/:sessionId/take',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return _buildPage(
          StudentExamScreen(sessionId: sessionId),
          state,
        );
      },
    ),
    GoRoute(
      path: '/student/exam/:sessionId/results',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final sessionId = state.pathParameters['sessionId']!;
        final args = state.extra as Map<String, dynamic>? ?? <String, dynamic>{};
        return _buildPage(
          StudentExamResultsScreen(
            sessionId: sessionId,
            correctCount: (args['correctCount'] as int?) ?? 0,
            totalCount: (args['totalCount'] as int?) ?? 0,
            totalQuestions: (args['totalQuestions'] as int?) ?? 0,
          ),
          state,
        );
      },
    ),

    // ─── Teacher Bottom Nav Shell ───────────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          TeacherNavShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _teacherDashboardNavKey,
          routes: [
            GoRoute(
              path: '/teacher/dashboard',
              pageBuilder: (_, state) => _buildPage(const TeacherDashboardScreen(), state),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _teacherClassesNavKey,
          routes: [
            GoRoute(
              path: '/teacher/classes',
              pageBuilder: (_, state) => _buildPage(const TeacherMyClassesScreen(), state),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _teacherLibraryNavKey,
          routes: [
            GoRoute(
              path: '/teacher/library',
              pageBuilder: (_, state) => _buildPage(const TeacherLibraryScreen(), state),
              routes: [
                GoRoute(
                  path: 'units',
                  pageBuilder: (_, state) {
                    final collection = state.extra as Map<String, dynamic>;
                    return _buildPage(TeacherUnitListScreen(collection: collection), state);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _teacherExamsNavKey,
          routes: [
            GoRoute(
              path: '/teacher/exams',
              pageBuilder: (_, state) =>
                  _buildPage(const TeacherExamsScreen(), state),
              routes: [
                GoRoute(
                  path: 'create',
                  pageBuilder: (_, state) =>
                      _buildPage(const CreateExamScreen(), state),
                ),
                GoRoute(
                  path: ':sessionId/lobby',
                  pageBuilder: (_, state) {
                    final sessionId = state.pathParameters['sessionId']!;
                    return _buildPage(
                      TeacherExamLobbyScreen(sessionId: sessionId),
                      state,
                    );
                  },
                ),
                GoRoute(
                  path: ':sessionId/results',
                  pageBuilder: (_, state) {
                    final sessionId = state.pathParameters['sessionId']!;
                    return _buildPage(
                      TeacherExamResultsScreen(sessionId: sessionId),
                      state,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _teacherAnalyticsNavKey,
          routes: [
            GoRoute(
              path: '/teacher/analytics',
              pageBuilder: (_, state) => _buildPage(const TeacherAnalyticsScreen(), state),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _teacherProfileNavKey,
          routes: [
            GoRoute(
              path: '/teacher/profile',
              pageBuilder: (_, state) => _buildPage(const TeacherProfileScreen(), state),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/teacher/student-detail',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (_, state) {
        final student = state.extra as ClassStudent;
        return _buildPage(TeacherStudentDetailScreen(student: student), state);
      },
    ),
  ],
);
