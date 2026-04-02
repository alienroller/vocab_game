import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/duel_service.dart';
import '../../theme/app_theme.dart';

/// Duel lobby — choose an opponent from your class to challenge.
class DuelLobbyScreen extends ConsumerStatefulWidget {
  const DuelLobbyScreen({super.key});

  @override
  ConsumerState<DuelLobbyScreen> createState() => _DuelLobbyScreenState();
}

class _DuelLobbyScreenState extends ConsumerState<DuelLobbyScreen> {
  List<Map<String, dynamic>> _classmates = [];
  List<Map<String, dynamic>> _pendingDuels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profileBox = Hive.box('userProfile');
    final classCode = profileBox.get('classCode') as String?;
    final userId = profileBox.get('id') as String?;

    if (classCode == null || userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Fetch classmates (exclude self)
      final classmatesData = await supabase
          .from('profiles')
          .select('id, username, xp, level')
          .eq('class_code', classCode)
          .neq('id', userId)
          .order('xp', ascending: false);

      // Fetch pending duels sent by me
      final pendingData = await supabase
          .from('duels')
          .select()
          .eq('challenger_id', userId)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _classmates = List<Map<String, dynamic>>.from(classmatesData);
          _pendingDuels = List<Map<String, dynamic>>.from(pendingData);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _challengePlayer(Map<String, dynamic> opponent) async {
    final profileBox = Hive.box('userProfile');
    final myId = profileBox.get('id') as String;
    final myUsername = profileBox.get('username') as String;

    // Select words for the duel
    final words = await DuelService.selectDuelWords(count: 10);
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No words available for duel')),
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
        ),
      );
      _loadData(); // refresh
    }
  }

  bool _hasPendingDuelWith(String opponentId) {
    return _pendingDuels.any((d) => d['opponent_id'] == opponentId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileBox = Hive.box('userProfile');
    final classCode = profileBox.get('classCode') as String?;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Duel Arena',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : classCode == null
                ? _buildNoClassState(theme)
                : _classmates.isEmpty
                    ? _buildNoClassmatesState(theme)
                    : _buildClassmatesList(theme),
      ),
    );
  }

  Widget _buildNoClassState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Join a class to duel!',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'You need to be in a class to challenge classmates.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoClassmatesState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👥', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('No classmates yet',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Invite friends to join your class!',
            style:
                TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
        padding: const EdgeInsets.all(16),
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
}

/// Incoming duel invitations screen.
class DuelInvitesScreen extends StatefulWidget {
  const DuelInvitesScreen({super.key});

  @override
  State<DuelInvitesScreen> createState() => _DuelInvitesScreenState();
}

class _DuelInvitesScreenState extends State<DuelInvitesScreen> {
  List<Map<String, dynamic>> _invites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    final userId = Hive.box('userProfile').get('id') as String?;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final invites = await DuelService.getPendingDuels(userId);
    if (mounted) {
      setState(() {
        _invites = invites;
        _loading = false;
      });
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
    _loadInvites();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Duel Invites',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _invites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📩', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text('No pending invites',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        16, kToolbarHeight + MediaQuery.of(context).padding.top + 16, 16, 24),
                    itemCount: _invites.length,
                    itemBuilder: (context, index) {
                      final invite = _invites[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassCard(isDark: isDark),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('⚔️',
                                    style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${invite['challenger_username']} challenges you!',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.violet
                                    .withValues(alpha: isDark ? 0.12 : 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(invite['word_set'] as List).length} words',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.violet,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      _declineDuel(invite['id'] as String),
                                  child: const Text('Decline'),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: AppTheme.borderRadiusMd,
                                  ),
                                  child: FilledButton(
                                    onPressed: () => _acceptDuel(invite),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                    ),
                                    child: const Text('Accept ⚔️'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
