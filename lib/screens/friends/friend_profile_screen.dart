import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/duel_service.dart';
import '../../services/friendship_service.dart';
import '../../theme/app_theme.dart';

/// Public, read-only profile of another user (or pending friend).
///
/// Surfaces only the fields a peer should see: username, level, total XP,
/// streak (current + longest), accuracy %, total answered. Excludes
/// class_code, PIN, recovery options, and any account-management actions
/// from [ProfileScreen] — kids' app, peer-visible profile is deliberately
/// minimal.
///
/// The footer CTA changes based on the friendship state:
///   - accepted   → ⚔️ Challenge to Duel  (overflow has Remove friend)
///   - pending(me)→ Pending (disabled)
///   - pending(them) → Accept request
///   - none       → Add friend
class FriendProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const FriendProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _friendship; // null when no edge exists
  bool _loading = true;
  bool _busy = false;

  String? get _myId => Hive.box('userProfile').get('id') as String?;
  String? get _myUsername =>
      Hive.box('userProfile').get('username') as String?;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myId = _myId;
    if (myId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      final profile = await supabase
          .from('profiles')
          .select(
              'id, username, xp, level, streak_days, longest_streak, total_words_answered, total_correct')
          .eq('id', widget.userId)
          .maybeSingle();

      final edges = await supabase
          .from('friendships')
          .select('id, status, requester_id, addressee_id')
          .or(
              'and(requester_id.eq.$myId,addressee_id.eq.${widget.userId}),'
              'and(requester_id.eq.${widget.userId},addressee_id.eq.$myId)')
          .limit(1);

      if (!mounted) return;
      setState(() {
        _profile = profile == null ? null : Map<String, dynamic>.from(profile);
        _friendship = (edges as List).isEmpty
            ? null
            : Map<String, dynamic>.from(edges.first as Map);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addFriend() async {
    final myId = _myId;
    if (myId == null) return;
    setState(() => _busy = true);
    final status =
        await FriendshipService.sendRequest(myId: myId, otherId: widget.userId);
    if (!mounted) return;
    setState(() => _busy = false);
    final username = _profile?['username'] as String? ?? '';
    final message = switch (status) {
      'pending' => 'Request sent to $username',
      'accepted' => 'You and $username are now friends! 🎉',
      'blocked' => 'Could not send request.',
      _ => 'Something went wrong. Try again.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
    _load();
  }

  Future<void> _acceptRequest() async {
    final id = _friendship?['id'] as String?;
    final myId = _myId;
    if (id == null || myId == null) return;
    setState(() => _busy = true);
    await FriendshipService.acceptRequest(friendshipId: id, myId: myId);
    if (!mounted) return;
    setState(() => _busy = false);
    _load();
  }

  Future<void> _challengeDuel() async {
    final myId = _myId;
    final myUsername = _myUsername;
    final username = _profile?['username'] as String?;
    if (myId == null || myUsername == null || username == null) return;

    setState(() => _busy = true);
    final words = await DuelService.selectDuelWords(count: 10);
    if (words.isEmpty) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No words available for duel. Add words to the library first.')),
        );
      }
      return;
    }
    final duelId = await DuelService.createDuel(
      challengerId: myId,
      challengerUsername: myUsername,
      opponentId: widget.userId,
      opponentUsername: username,
      wordSet: words,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (duelId != null) {
      // Navigate to the Duels tab — guarantees its realtime listener is
      // alive so the existing accept→push-into-game flow fires. See the
      // matching call in friends_screen.dart for the full rationale.
      context.go('/duels');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge sent to $username! ⚔️'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmUnfriend() async {
    final id = _friendship?['id'] as String?;
    if (id == null) return;
    final username = _profile?['username'] as String? ?? 'this user';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text('$username will no longer be in your friends list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FriendshipService.unfriend(id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profile = _profile;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          profile?['username'] as String? ?? 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_friendship?['status'] == 'accepted')
            IconButton(
              icon: const Icon(Icons.person_remove_alt_1_rounded),
              tooltip: 'Remove friend',
              onPressed: _confirmUnfriend,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : profile == null
                ? const Center(
                    child: Text('User not found.'),
                  )
                : _buildBody(profile, isDark, theme),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> profile, bool isDark, ThemeData theme) {
    final username = profile['username'] as String? ?? '???';
    final xp = (profile['xp'] as int?) ?? 0;
    final level = (profile['level'] as int?) ?? 1;
    final streak = (profile['streak_days'] as int?) ?? 0;
    final longest = (profile['longest_streak'] as int?) ?? 0;
    final answered = (profile['total_words_answered'] as int?) ?? 0;
    final correct = (profile['total_correct'] as int?) ?? 0;
    final accuracy = answered > 0 ? (correct / answered * 100).round() : 0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24,
          kToolbarHeight + MediaQuery.of(context).padding.top + 16,
          24,
          24),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: AppTheme.shadowGlow(AppTheme.violet),
            ),
            alignment: Alignment.center,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            username,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          _RelationshipChip(
            friendship: _friendship,
            myId: _myId,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _StatCard(
                icon: Icons.star,
                label: 'Level',
                value: '$level',
                color: Colors.amber,
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.bolt,
                label: 'Total XP',
                value: '$xp',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                icon: Icons.local_fire_department,
                label: 'Streak',
                value: '$streak',
                color: AppTheme.fire,
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.emoji_events_rounded,
                label: 'Best streak',
                value: '$longest',
                color: AppTheme.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                icon: Icons.check_circle,
                label: 'Accuracy',
                value: '$accuracy%',
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.quiz,
                label: 'Answered',
                value: '$answered',
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildPrimaryAction(),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction() {
    final status = _friendship?['status'] as String?;
    final requesterId = _friendship?['requester_id'] as String?;

    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CircularProgressIndicator(),
      );
    }

    if (status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6D00), Color(0xFFFF3D00)],
            ),
            borderRadius: AppTheme.borderRadiusMd,
            boxShadow: [
              BoxShadow(
                color: AppTheme.fire.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _challengeDuel,
            icon: const Icon(Icons.flash_on),
            label: const Text('⚔️  Challenge to Duel'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      );
    }

    if (status == 'pending' && requesterId == _myId) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_top_rounded),
          label: const Text('Request pending'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
    }

    if (status == 'pending' && requesterId != _myId) {
      return SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: AppTheme.borderRadiusMd,
          ),
          child: FilledButton.icon(
            onPressed: _acceptRequest,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Accept friend request'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.borderRadiusMd,
        ),
        child: FilledButton.icon(
          onPressed: _addFriend,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add friend'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _RelationshipChip extends StatelessWidget {
  final Map<String, dynamic>? friendship;
  final String? myId;

  const _RelationshipChip({required this.friendship, required this.myId});

  @override
  Widget build(BuildContext context) {
    final status = friendship?['status'] as String?;
    final requesterId = friendship?['requester_id'] as String?;

    String label;
    Color color;
    if (status == 'accepted') {
      label = '✓ Friends';
      color = AppTheme.success;
    } else if (status == 'pending' && requesterId == myId) {
      label = 'Request pending';
      color = AppTheme.fire;
    } else if (status == 'pending') {
      label = 'Wants to be friends';
      color = AppTheme.violet;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
