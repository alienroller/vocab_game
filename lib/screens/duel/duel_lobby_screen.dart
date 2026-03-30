import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/duel_service.dart';
import 'duel_game_screen.dart';

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
    final profileBox = Hive.box('userProfile');
    final classCode = profileBox.get('classCode') as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duel Arena',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : classCode == null
              ? _buildNoClassState(theme)
              : _classmates.isEmpty
                  ? _buildNoClassmatesState(theme)
                  : _buildClassmatesList(theme),
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
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _classmates.length,
        itemBuilder: (context, index) {
          final mate = _classmates[index];
          final hasPending = _hasPendingDuelWith(mate['id'] as String);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  (mate['username'] as String? ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              title: Text(
                mate['username'] ?? '???',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Level ${mate['level'] ?? 1} • ${mate['xp'] ?? 0} XP',
              ),
              trailing: hasPending
                  ? Chip(
                      label: const Text('Pending'),
                      backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    )
                  : FilledButton.icon(
                      onPressed: () => _challengePlayer(mate),
                      icon: const Icon(Icons.flash_on, size: 18),
                      label: const Text('Challenge'),
                    ),
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DuelGameScreen(
            duelId: duel['id'] as String,
            words: words,
            isChallenger: false,
          ),
        ),
      );
    }
  }

  Future<void> _declineDuel(String duelId) async {
    await DuelService.declineDuel(duelId);
    _loadInvites();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duel Invites',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📩', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text('No pending invites',
                          style: theme.textTheme.titleLarge),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invites.length,
                  itemBuilder: (context, index) {
                    final invite = _invites[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${invite['challenger_username']} challenges you! ⚔️',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(invite['word_set'] as List).length} words',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      _declineDuel(invite['id'] as String),
                                  child: const Text('Decline'),
                                ),
                                const SizedBox(width: 12),
                                FilledButton(
                                  onPressed: () => _acceptDuel(invite),
                                  child: const Text('Accept'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
