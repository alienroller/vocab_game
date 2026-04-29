import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocab_game/config/environment_constants.dart';
import 'package:vocab_game/services/key_constants.dart';
import 'package:vocab_game/services/notification_service.dart';
import 'package:vocab_game/services/storage_provider.dart';
import 'package:vocab_game/services/version_service.dart';
import 'package:vocab_game/widgets/empty_vocab_list.dart';

import '../models/teacher_message.dart';
import '../models/vocab.dart';
import '../providers/assignment_provider.dart';
import '../providers/friendship_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/student_exam_provider.dart';
import '../providers/vocab_provider.dart';
import '../services/streak_calculator.dart';
import '../services/teacher_message_service.dart';
import '../services/word_session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/exam_banner_widget.dart';
import '../widgets/streak_widget.dart';
import '../widgets/vocab_tile.dart';
import '../widgets/xp_bar_widget.dart';
import 'library/library_screen.dart' show UnitGameSelectionScreen;

/// Home screen with premium gradient design, hero header, vocabulary list,
/// and floating add-word bottom sheet.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  String? _rivalName;
  int _rivalXp = 0; // store rival's actual XP, calculate gap live in build()
  TeacherMessage? _teacherMessage;
  Timer? _pollTimer;
  bool _isLaunchingAssignment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadClassData();

      final isUpdateAvailable = await AppVersionInfo.instance.checkForUpdate();

      if (isUpdateAvailable && mounted) context.pushReplacement('/update');

      _maybeRequestNotificationPermission();
    });

    _fetchRival();

    _checkStreakMilestone();

    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadClassData();
        _fetchRival();
      }
    });
  }

  /// One-shot permission request the first time a student lands on Home.
  /// Skipped on later launches so we don't keep prompting if they declined
  /// (BUG C1). The OS de-dupes the system dialog anyway, but tracking the
  /// "we asked" bit means we can stop calling the API entirely.
  void _maybeRequestNotificationPermission() async {
    final lastRequested = LocalStorageProvider.cache.getString(
      KeyConstants.lastNotifReqTime,
    );

    bool should = true;

    if (lastRequested.isNotEmpty) {
      final date = DateTime.tryParse(lastRequested);

      if (date != null) {
        final diff = DateTime.now().difference(date).inSeconds;

        if (diff < EnvironmentConstants.notificationRequestDiff) should = false;
      }
    }

    if (!should) return;

    final hasNotificationPermission = await Permission.notification.isGranted;

    if (hasNotificationPermission) return;

    await NotificationService.instance.requestPermission(
      onGranted: () {},
      onDenied: () {},
    );

    final time = DateTime.now().toIso8601String();

    await LocalStorageProvider.cache.setString(
      KeyConstants.lastNotifReqTime,
      time,
    );
  }

  void _loadClassData() async {
    final profile = ref.read(profileProvider);
    if (profile == null || profile.classCode == null) return;

    await ref
        .read(assignmentProvider.notifier)
        .loadStudentAssignments(
          classCode: profile.classCode!,
          studentId: profile.id,
        );

    // Diff fetched assignments against the Hive 'seen' set. New ones fire
    // a local notification so the student knows a teacher just posted
    // something — without this, polling silently updates the home screen
    // and the student misses it (BUG C1).
    _notifyOnNewAssignments();

    final msg = await TeacherMessageService.getMessage(profile.classCode!);
    if (mounted) {
      setState(() => _teacherMessage = msg);
    }
    _notifyOnNewMessage(msg);
  }

  /// Compares the current assignment list against the Hive 'seen' set and
  /// fires a local notification for any IDs we've never shown. On the
  /// very first run for a student, the seen set is seeded silently so we
  /// don't spam notifications for pre-existing assignments.
  void _notifyOnNewAssignments() {
    try {
      final box = Hive.box('notif_state');
      final assignments =
          ref.read(assignmentProvider).assignments.map((a) => a.id).toSet();
      final seenList =
          (box.get('seen_assignments') as List?)
              ?.map((e) => e.toString())
              .toSet();
      if (seenList == null) {
        // First poll for this device — seed silently.
        box.put('seen_assignments', assignments.toList());
        return;
      }
      final newIds = assignments.difference(seenList);
      if (newIds.isEmpty) return;
      final fresh = ref
          .read(assignmentProvider)
          .assignments
          .where((a) => newIds.contains(a.id));
      for (final a in fresh) {
        //unawaited(
        // NotificationService.notifyNewAssignment(
        // unitTitle: a.unitTitle,
        // bookTitle: a.bookTitle,
        // assignmentHashId: NotificationService.idFromString(a.id),
        //),
        //);
      }
      box.put('seen_assignments', assignments.toList());
    } catch (e) {
      debugPrint('Assignment notify diff failed: $e');
    }
  }

  void _notifyOnNewMessage(TeacherMessage? msg) {
    try {
      final box = Hive.box('notif_state');
      final lastId = box.get('seen_message_id') as String?;
      if (msg == null) {
        // Message was cleared — drop the seen pointer so a re-pin notifies.
        if (lastId != null) box.delete('seen_message_id');
        return;
      }
      // We use updated_at + classCode as a synthetic id since teacher_messages
      // PK is class_code (one-row-per-class), and the message body changes
      // whenever the teacher edits.
      final synthetic = '${msg.classCode}|${msg.message.hashCode}';
      if (lastId == null) {
        // First-run seed: don't notify.
        box.put('seen_message_id', synthetic);
        return;
      }
      if (lastId == synthetic) return;
      box.put('seen_message_id', synthetic);
      //unawaited(NotificationService.notifyTeacherMessage(msg.message));
    } catch (e) {
      debugPrint('Message notify diff failed: $e');
    }
  }

  /// Listens to the active-exams provider and fires a notification when a
  /// new (lobby OR in_progress) exam appears that we haven't seen before.
  /// Called from build() via ref.listen so it tracks across polls.
  void _notifyOnNewExams(List<dynamic> exams) {
    try {
      final box = Hive.box('notif_state');
      final ids = exams.map((e) => e.id as String).toSet();
      final seenList =
          (box.get('seen_exams') as List?)?.map((e) => e.toString()).toSet();
      if (seenList == null) {
        box.put('seen_exams', ids.toList());
        return;
      }
      final newIds = ids.difference(seenList);
      for (final newId in newIds) {
        final session = exams.firstWhere(
          (e) => e.id == newId,
          orElse: () => null,
        );
        if (session == null) continue;
        //unawaited(
        //NotificationService.notifyNewExam(
        //examTitle: session.title as String,
        //sessionHashId: NotificationService.idFromString(newId),
        //),
        //);
      }
      box.put('seen_exams', ids.toList());
    } catch (e) {
      debugPrint('Exam notify diff failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchRival(); // re-fetch rival when returning from a game
      _loadClassData(); // fetch new assignments if teacher added them
    }
  }

  void _checkStreakMilestone() {
    final profileBox = Hive.box('userProfile');
    final streakDays = profileBox.get('streakDays', defaultValue: 0) as int;
    final lastMilestone =
        profileBox.get('lastStreakMilestone', defaultValue: 0) as int;

    const milestones = [30, 14, 7, 3];
    for (final milestone in milestones) {
      if (streakDays >= milestone && lastMilestone < milestone) {
        profileBox.put('lastStreakMilestone', milestone);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (_) => _StreakMilestoneDialog(
                    milestone: milestone,
                    currentStreak: streakDays,
                  ),
            );
          }
        });
        break;
      }
    }
  }

  void _fetchRival() async {
    final profileBox = Hive.box('userProfile');
    final classCode = profileBox.get('classCode') as String?;
    final myUsername = profileBox.get('username') as String?;
    // Guard: an empty/null class_code would otherwise query all
    // class-less profiles globally (cross-school orphans) — verified the
    // existing isEmpty check covers this (P8 audit).
    if (classCode == null || classCode.isEmpty || myUsername == null) return;

    try {
      // Fetch teacher ID from classes table for double-exclusion
      final classData =
          await Supabase.instance.client
              .from('classes')
              .select('teacher_id')
              .eq('code', classCode)
              .maybeSingle();
      final teacherId = classData?['teacher_id'] as String?;

      var query = Supabase.instance.client
          .from('profiles')
          .select('username, xp')
          .eq('class_code', classCode)
          .eq(
            'is_teacher',
            false,
          ); // BUG 10 fix: exclude teacher from rival candidates

      if (teacherId != null) {
        query = query.neq('id', teacherId); // Belt-and-suspenders exclusion
      }

      final data = await query.order('xp', ascending: false).limit(50);

      final list = List<Map<String, dynamic>>.from(data);

      // Remove self from the list
      final others = list.where((e) => e['username'] != myUsername).toList();
      if (others.isEmpty) return;

      // Use local XP to determine who the closest rival above us is
      final myXp = profileBox.get('xp', defaultValue: 0) as int;

      // Find the person directly above us (closest rival with higher XP)
      Map<String, dynamic>? rivalAbove;
      for (final person in others.reversed) {
        final theirXp = person['xp'] as int? ?? 0;
        if (theirXp > myXp) {
          rivalAbove = person;
          break;
        }
      }

      if (rivalAbove != null && mounted) {
        setState(() {
          _rivalName = rivalAbove!['username'] as String?;
          _rivalXp = rivalAbove['xp'] as int? ?? 0;
        });
      } else if (mounted) {
        // User is #1 — show the person just below as "chasing you"
        final closestBelow = others.firstWhere(
          (e) => (e['xp'] as int? ?? 0) <= myXp,
          orElse: () => others.first,
        );
        setState(() {
          _rivalName = closestBelow['username'] as String?;
          _rivalXp = closestBelow['xp'] as int? ?? 0;
        });
      }
    } catch (e, s) {
      debugPrint('Rival lookup failed: $e\n$s');
    }
  }

  void _showEditDialog(Vocab vocab) {
    final engCtrl = TextEditingController(text: vocab.english);
    final uzCtrl = TextEditingController(text: vocab.uzbek);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Word'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: engCtrl,
                  decoration: const InputDecoration(hintText: 'English'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: uzCtrl,
                  decoration: const InputDecoration(hintText: 'Uzbek'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  ref
                      .read(vocabProvider.notifier)
                      .updateVocab(vocab.id, engCtrl.text, uzCtrl.text);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vocabList = ref.watch(vocabProvider);
    final profile = ref.watch(profileProvider);
    final assignmentState = ref.watch(assignmentProvider);

    // Drives the new-exam local notification. The provider auto-polls
    // every 15s; we react to value changes (not loading states) so we
    // don't spam notifications while it cycles. (BUG C1)
    ref.listen(studentActiveExamsProvider, (prev, next) {
      next.whenData(_notifyOnNewExams);
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPlay = vocabList.length >= 4;

    final profileBox = Hive.box('userProfile');
    final xp = profile?.xp ?? profileBox.get('xp', defaultValue: 0) as int;

    // The rival gap is computed LIVE below using _rivalXp - xp,
    // so it updates instantly when profile XP changes via ref.watch.

    final streak = ref.watch(streakProvider);
    final username =
        profile?.username ??
        profileBox.get('username', defaultValue: '') as String;
    // The "play today!" banner shows when the streak is alive but we haven't
    // played yet — i.e. yesterday was the last play. When broken, hide the
    // banner: the streak is already gone, no rescue is possible today.
    final needsToPlayToday = streak.status == StreakStatus.atRisk;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🧠', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Text(
              'VocabGame',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: const [_FriendsAppBarButton(), SizedBox(width: 4)],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.violet,
            onRefresh: () async {
              _loadClassData();
              _fetchRival();
              // Optional small delay for tactile feedback
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // BUG O7 — preview-mode banner. Only renders when a
                  // teacher tapped "Preview as student" from their
                  // profile. Tapping it pops them back to the dashboard.
                  if (Hive.box(
                        'userProfile',
                      ).get('previewAsStudent', defaultValue: false)
                      as bool)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Material(
                        color: AppTheme.violet.withValues(
                          alpha: isDark ? 0.18 : 0.1,
                        ),
                        borderRadius: AppTheme.borderRadiusSm,
                        child: InkWell(
                          borderRadius: AppTheme.borderRadiusSm,
                          onTap: () async {
                            await Hive.box(
                              'userProfile',
                            ).delete('previewAsStudent');
                            if (context.mounted) {
                              context.go('/teacher/dashboard');
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.visibility,
                                  color: AppTheme.violet,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Previewing as a student.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.violet,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Exit preview',
                                  style: TextStyle(
                                    color: AppTheme.violet,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: AppTheme.violet,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // ─── Hero Header ────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCard(isDark: isDark),
                    child: Column(
                      children: [
                        // Username + Streak row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (username.isNotEmpty)
                              Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppTheme.primaryGradient,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.violet.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      username[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Hi, $username! 👋',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            StreakWidget(snapshot: streak),
                          ],
                        ),
                        const SizedBox(height: 14),
                        XpBarWidget(totalXp: xp),
                      ],
                    ),
                  ),

                  // ─── Exam invitations ─────────────────────────────
                  const ExamBannerWidget(),

                  // ─── Assignments ────────────────────────────────────
                  if (assignmentState.assignments.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment,
                            color: AppTheme.violet,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Assignments',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: assignmentState.assignments.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final assignment = assignmentState.assignments[index];
                          final progress =
                              assignmentState.progressMap[assignment.id];
                          final mastered = progress?.wordsMastered ?? 0;
                          final total = assignment.wordCount;
                          final pct = total > 0 ? mastered / total : 0.0;
                          final isCompleted = progress?.isCompleted ?? false;

                          return GestureDetector(
                            onTap: () async {
                              if (_isLaunchingAssignment)
                                return; // Locked while launching
                              setState(() => _isLaunchingAssignment = true);
                              try {
                                // Fetch words for the assigned unit (same as library)
                                final words =
                                    await WordSessionService.selectSessionWords(
                                      unitId: assignment.unitId,
                                    );
                                if (words.isEmpty) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No words found for this assignment.',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                // Convert to Vocab model
                                final vocabWords =
                                    words
                                        .map(
                                          (w) => Vocab(
                                            id: w['id'] as String,
                                            english: w['word'] as String,
                                            uzbek: w['translation'] as String,
                                          ),
                                        )
                                        .toList();
                                if (!context.mounted) return;
                                // Navigate to game selection (reuse library's screen)
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => UnitGameSelectionScreen(
                                          unitTitle: assignment.unitTitle,
                                          unitId: assignment.unitId,
                                          words: vocabWords,
                                          assignmentId: assignment.id,
                                        ),
                                  ),
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error loading assignment: $e',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted)
                                  setState(
                                    () => _isLaunchingAssignment = false,
                                  );
                              }
                            },
                            child: Container(
                              width: 240,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? const Color(0xFF1A1D3A)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isCompleted
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : AppTheme.violet.withValues(
                                            alpha: 0.2,
                                          ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          assignment.unitTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCompleted)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                  Text(
                                    assignment.bookTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor:
                                              isCompleted
                                                  ? Colors.green.withValues(
                                                    alpha: 0.2,
                                                  )
                                                  : AppTheme.violet.withValues(
                                                    alpha: 0.2,
                                                  ),
                                          color:
                                              isCompleted
                                                  ? Colors.green
                                                  : AppTheme.violet,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$mastered/$total',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color:
                                              isCompleted ? Colors.green : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (assignment.dueDate != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Due: ${assignment.dueDate}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // ─── Teacher Message ────────────────────────────────
                  if (_teacherMessage != null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.violet.withValues(
                          alpha: isDark ? 0.15 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.violet.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('📌', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Class Announcement',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.violet,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _teacherMessage!.message,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ─── Play Today Banner ──────────────────────────────
                  if (needsToPlayToday)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.fire.withValues(
                              alpha: isDark ? 0.15 : 0.1,
                            ),
                            AppTheme.amber.withValues(
                              alpha: isDark ? 0.1 : 0.06,
                            ),
                          ],
                        ),
                        borderRadius: AppTheme.borderRadiusMd,
                        border: Border.all(
                          color: AppTheme.fire.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Play today to keep your ${streak.displayCount}-day streak alive!',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.fire,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ─── Rival Card ─────────────────────────────────────
                  if (_rivalName != null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.error.withValues(
                              alpha: isDark ? 0.12 : 0.08,
                            ),
                            AppTheme.violet.withValues(
                              alpha: isDark ? 0.08 : 0.04,
                            ),
                          ],
                        ),
                        borderRadius: AppTheme.borderRadiusMd,
                        border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('⚔️', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Your rival: ',
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? AppTheme.textSecondaryDark
                                              : AppTheme.textSecondaryLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _rivalName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextSpan(
                                    text: () {
                                      final gap = _rivalXp - xp;
                                      if (gap > 0) return ' — $gap XP ahead';
                                      if (gap == 0) return ' — tied!';
                                      return ' — you lead by ${gap.abs()} XP 🔥';
                                    }(),
                                    style: TextStyle(
                                      color:
                                          (_rivalXp - xp) > 0
                                              ? (isDark
                                                  ? AppTheme.textSecondaryDark
                                                  : AppTheme.textSecondaryLight)
                                              : AppTheme.success,
                                      fontWeight:
                                          (_rivalXp - xp) <= 0
                                              ? FontWeight.w600
                                              : null,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ─── Quick Links Row ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _QuickChip(
                          label: '🏆 Leaderboard',
                          onTap: () => context.push('/home/leaderboard'),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _QuickChip(
                          label: '📜 History',
                          onTap: () => context.push('/duels/history'),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _QuickChip(
                          label: '🏅 Hall of Fame',
                          onTap: () => context.push('/home/hall-of-fame'),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // ─── Practice Button ────────────────────────────────
                  if (canPlay)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: AppTheme.borderRadiusMd,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.violet.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push('/home/games'),
                            borderRadius: AppTheme.borderRadiusMd,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Play',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ─── Vocab List Header ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Vocabulary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${vocabList.length} words',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppTheme.violet,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ─── Vocab List ─────────────────────────────────────
                  vocabList.isEmpty
                      ? EmptyVocabList()
                      : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: vocabList.length,
                        itemBuilder: (context, index) {
                          final vocab = vocabList[index];
                          return VocabTile(
                            key: ValueKey(vocab.id),
                            vocab: vocab,
                            onDelete: () {
                              ref
                                  .read(vocabProvider.notifier)
                                  .deleteVocab(vocab.id);
                            },
                            onEdit: () => _showEditDialog(vocab),
                          );
                        },
                      ),

                  // ─── Progress bar (< 4 words) ──────────────────────
                  if (!canPlay)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color:
                                  isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.04),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: vocabList.length / 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: AppTheme.primaryGradient,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add ${4 - vocabList.length} more words to play games',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.violet,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/search'),
        backgroundColor: AppTheme.violet,
        foregroundColor: Colors.white,
        elevation: 8,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

// ─── Friends AppBar Button ────────────────────────────────────────────

/// Badged people icon in the Home AppBar — entry point to the Friends hub.
/// Watches [incomingFriendRequestsProvider] so the red count badge updates
/// in realtime as requests arrive, without rebuilding the rest of Home.
class _FriendsAppBarButton extends ConsumerWidget {
  const _FriendsAppBarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(incomingFriendRequestsProvider).valueOrNull?.length ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: 'Friends',
      onPressed: () => context.push('/friends'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.people_alt_rounded, size: 24),
          if (count > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isDark ? const Color(0xFF0F1228) : Colors.white,
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Quick Chip ───────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickChip({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
            borderRadius: AppTheme.borderRadiusSm,
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Streak Milestone Celebration Dialog ──────────────────────────────

class _StreakMilestoneDialog extends StatefulWidget {
  final int milestone;
  final int currentStreak;

  const _StreakMilestoneDialog({
    required this.milestone,
    required this.currentStreak,
  });

  @override
  State<_StreakMilestoneDialog> createState() => _StreakMilestoneDialogState();
}

class _StreakMilestoneDialogState extends State<_StreakMilestoneDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (emoji, title, message) = switch (widget.milestone) {
      3 => (
        '🔥',
        'You\'re on a roll!',
        '${widget.currentStreak}-day streak! Keep it up!',
      ),
      7 => ('💪', 'One week strong!', 'You\'re a habit now. Incredible!'),
      14 => ('🏆', 'Two weeks!', 'You\'re in the top players. Amazing!'),
      30 => ('👑', 'One month!', 'You are LEGENDARY. Unstoppable!'),
      _ => ('🔥', 'Streak milestone!', '${widget.currentStreak}-day streak!'),
    };

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AlertDialog(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.violet,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.fire.withValues(alpha: 0.15),
                      AppTheme.amber.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: AppTheme.borderRadiusSm,
                  border: Border.all(
                    color: AppTheme.fire.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '🔥 ${widget.currentStreak}-day streak',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.fire,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Keep Going! 💪',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
