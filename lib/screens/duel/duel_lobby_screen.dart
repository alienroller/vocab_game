import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/duel_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

/// Duel lobby — two tabs: Challenge classmates + View incoming invites.
///
/// Auto-refreshes when the tab becomes visible and polls for new invites
/// every 15 seconds while the screen is active.
class DuelLobbyScreen extends ConsumerStatefulWidget {
  const DuelLobbyScreen({super.key});

  @override
  ConsumerState<DuelLobbyScreen> createState() => _DuelLobbyScreenState();
}

class _DuelLobbyScreenState extends ConsumerState<DuelLobbyScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  List<Map<String, dynamic>> _classmates = [];
  List<Map<String, dynamic>> _pendingDuels = [];
  List<Map<String, dynamic>> _incomingInvites = [];
  bool _loading = true;
  Timer? _pollTimer;
  RealtimeChannel? _pendingDuelsChannel;

  String? get _classCode => Hive.box('userProfile').get('classCode') as String?;
  String? get _userId => Hive.box('userProfile').get('id') as String?;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _startRealtimeSubscription();
    _loadData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_pendingDuelsChannel != null) {
      Supabase.instance.client.removeChannel(_pendingDuelsChannel!);
    }
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(); // Refresh when app comes back to foreground
    }
  }

  void _startRealtimeSubscription() {
    final userId = _userId;
    if (userId == null) return;

    _pendingDuelsChannel = Supabase.instance.client.channel('duel_lobby_$userId')
      // Challenger side: fires when my sent challenge is accepted (status → 'active').
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'duels',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'challenger_id',
          value: userId,
        ),
        callback: (payload) {
          if (!mounted) return;
          final newData = payload.newRecord;
          if (newData['status'] == 'active') {
            _navigateToGame(newData);
          }
        },
      )
      // Opponent side: fires when someone creates a new challenge targeting me.
      // Refreshes the invites list and fires a local notification immediately —
      // previously this was only discovered by the 10-second poll.
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'duels',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'opponent_id',
          value: userId,
        ),
        callback: (payload) {
          if (!mounted) return;
          _loadData();
          final challenger =
              payload.newRecord['challenger_username'] as String? ?? 'Someone';
          NotificationService.notifyDuelChallenge(challenger);
        },
      )
      ..subscribe();
  }

  void _navigateToGame(Map<String, dynamic> duelData) {
    if (!mounted) return;

    // Read the router's GLOBAL top-of-stack URI — not GoRouterState.of(context),
    // which returns the lobby's own branch URI ('/duels') and stays stuck on
    // that even after '/duels/game' is pushed on the root navigator. The
    // context-local version caused the 10-second poll timer to re-push the
    // game screen every tick while a duel was in progress.
    final currentRoute = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();
    if (currentRoute.startsWith('/duels/game') ||
        currentRoute.startsWith('/duels/results')) {
      return;
    }

    final words = List<Map<String, dynamic>>.from(
        (duelData['word_set'] as List).map((w) => Map<String, dynamic>.from(w)));

    context.push('/duels/game', extra: {
      'duelId': duelData['id'] as String,
      'words': words,
      'isChallenger': true,
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    final classCode = _classCode;
    final userId = _userId;

    if (classCode == null || classCode.isEmpty || userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Check if we have an active duel we should join right now
      final activeData = await supabase
          .from('duels')
          .select()
          .eq('challenger_id', userId)
          .eq('status', 'active');
          
      if (activeData.isNotEmpty && mounted) {
         _navigateToGame(activeData.first);
         return; // Skip loading lobby since we are entering a game
      }

      // Fetch teacher ID from classes table for double-exclusion
      final classData = await supabase
          .from('classes')
          .select('teacher_id')
          .eq('code', classCode)
          .maybeSingle();
      final teacherId = classData?['teacher_id'] as String?;

      var classmatesQuery = supabase
          .from('profiles')
          .select('id, username, xp, level')
          .eq('class_code', classCode)
          .eq('is_teacher', false) // Exclude teacher
          .neq('id', userId);

      if (teacherId != null) {
        classmatesQuery = classmatesQuery.neq('id', teacherId);
      }

      // Fetch classmates (exclude self and teachers)
      final classmatesData = await classmatesQuery.order('xp', ascending: false);

      // Fetch pending duels sent by me
      final pendingData = await supabase
          .from('duels')
          .select()
          .eq('challenger_id', userId)
          .eq('status', 'pending');

      // Fetch incoming duel invites for me
      final invitesData = await supabase
          .from('duels')
          .select()
          .eq('opponent_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        final hadInvites = _incomingInvites.length;

        // Auto-cancel duels sent by me that are older than 60 seconds
        final pending = List<Map<String, dynamic>>.from(pendingData);
        final now = DateTime.now();
        final expired = <Map<String, dynamic>>[];
        final active = <Map<String, dynamic>>[];
        for (final duel in pending) {
          final createdAt = DateTime.tryParse(
              duel['created_at']?.toString() ?? '');
          if (createdAt != null &&
              now.difference(createdAt).inSeconds > 60) {
            expired.add(duel);
          } else {
            active.add(duel);
          }
        }

        // Cancel expired duels in the background
        for (final duel in expired) {
          DuelService.declineDuel(duel['id'] as String);
        }

        setState(() {
          _classmates = List<Map<String, dynamic>>.from(classmatesData);
          _pendingDuels = active;
          _incomingInvites = List<Map<String, dynamic>>.from(invitesData)
              .where((d) {
            final createdAt = DateTime.tryParse(
                d['created_at']?.toString() ?? '');
            // Also hide expired incoming invites (>60s)
            return createdAt == null ||
                now.difference(createdAt).inSeconds <= 60;
          }).toList();
          _loading = false;
        });

        // Auto-switch to Invites tab when new invites arrive
        if (_incomingInvites.isNotEmpty && hadInvites == 0) {
          _tabController.animateTo(1);
        }
      }
    } catch (e) {
      debugPrint('Duel lobby load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _challengePlayer(Map<String, dynamic> opponent) async {
    final myId = _userId;
    final profileBox = Hive.box('userProfile');
    final myUsername = profileBox.get('username') as String?;

    if (myId == null || myUsername == null) return;

    // Select words for the duel
    final words = await DuelService.selectDuelWords(count: 10);
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No words available for duel. Add words to the library first.')),
        );
      }
      return;
    }

    final duelId = await DuelService.createDuel(
      challengerId: myId,
      challengerUsername: myUsername,
      opponentId: opponent['id'] as String,
      opponentUsername: opponent['username'] as String,
      wordSet: words,
    );

    if (duelId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge sent to ${opponent['username']}! ⚔️'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData(); // refresh
    }
  }

  Future<void> _acceptDuel(Map<String, dynamic> duel) async {
    final success = await DuelService.acceptDuel(duel['id'] as String);
    if (success && mounted) {
      final words = List<Map<String, dynamic>>.from(
          (duel['word_set'] as List).map((w) => Map<String, dynamic>.from(w)));
      context.push('/duels/game', extra: {
        'duelId': duel['id'] as String,
        'words': words,
        'isChallenger': false,
      });
    }
  }

  Future<void> _declineDuel(String duelId) async {
    await DuelService.declineDuel(duelId);
    _loadData();
  }

  bool _hasPendingDuelWith(String opponentId) {
    return _pendingDuels.any((d) => d['opponent_id'] == opponentId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final classCode = _classCode;
    final hasClass = classCode != null && classCode.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duel Arena',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'Duel History',
            onPressed: () => context.push('/duels/history'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
        bottom: hasClass
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.violet,
                labelColor: isDark ? Colors.white : Colors.black87,
                unselectedLabelColor: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
                tabs: [
                  const Tab(text: '⚔️ Challenge'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📩 Invites'),
                        if (_incomingInvites.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_incomingInvites.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !hasClass
                ? _buildNoClassState(theme, isDark)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Challenge classmates
                      _classmates.isEmpty
                          ? _buildNoClassmatesState(theme, isDark)
                          : _buildClassmatesList(theme),
                      // Tab 2: Incoming invites
                      _buildInvitesList(theme),
                    ],
                  ),
      ),
    );
  }

  Widget _buildNoClassState(ThemeData theme, bool isDark) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.violet.withValues(alpha: isDark ? 0.12 : 0.08),
                ),
                child: const Text('⚔️', style: TextStyle(fontSize: 56)),
              ),
              const SizedBox(height: 24),
              Text('Join a class to duel!',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'You need to be in a class to challenge classmates.\nGo to Profile → Join Class to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppTheme.borderRadiusMd,
                ),
                child: FilledButton.icon(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person_rounded),
                  label: const Text('Go to Profile'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoClassmatesState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.violet.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
            child: const Text('👥', style: TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 24),
          Text('No classmates yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          Text(
            'Invite friends to join your class!',
            style: TextStyle(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassmatesList(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _classmates.length,
        itemBuilder: (context, index) {
          final mate = _classmates[index];
          final hasPending = _hasPendingDuelWith(mate['id'] as String);
          final username = mate['username'] as String? ?? '???';
          final level = mate['level'] as int? ?? 1;
          final xp = mate['xp'] as int? ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.darkGlassGradient
                  : AppTheme.lightGlassGradient,
              borderRadius: AppTheme.borderRadiusMd,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: AppTheme.shadowSoft,
            ),
            child: Row(
              children: [
                // Avatar with gradient ring
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.violet.withValues(alpha: 0.25),
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
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.amber
                                  .withValues(alpha: isDark ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Lv $level',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.amber,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$xp XP',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.fire.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.fire.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Text(
                      '⏳ Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.fire,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6D00), Color(0xFFFF3D00)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.fire.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: () => _challengePlayer(mate),
                      icon: const Icon(Icons.flash_on, size: 16),
                      label: const Text('Fight'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvitesList(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_incomingInvites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.violet.withValues(alpha: isDark ? 0.1 : 0.06),
              ),
              child: const Text('📩', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 20),
            Text('No pending invites',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 6),
            Text(
              'When classmates challenge you, invites show here.\nAutomatic refresh every 15 seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _incomingInvites.length,
        itemBuilder: (context, index) {
          final invite = _incomingInvites[index];
          final challenger = invite['challenger_username'] as String? ?? '???';
          final wordCount = (invite['word_set'] as List?)?.length ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCard(isDark: isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Challenger avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6D00), Color(0xFFFF3D00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.fire.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        challenger[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$challenger challenges you!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.violet
                                  .withValues(alpha: isDark ? 0.12 : 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$wordCount words',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.violet,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _declineDuel(invite['id'] as String),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: AppTheme.borderRadiusMd,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.violet.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed: () => _acceptDuel(invite),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('⚔️ Accept',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// DuelInvitesScreen — kept for backward route compatibility.
/// Now redirects users to the main duel lobby's Invites tab.
class DuelInvitesScreen extends StatelessWidget {
  const DuelInvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to the duel lobby which now has invites built-in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/duels');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
