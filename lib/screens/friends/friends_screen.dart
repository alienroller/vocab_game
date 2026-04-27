import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../providers/friendship_provider.dart';
import '../../services/duel_service.dart';
import '../../services/friendship_service.dart';
import '../../theme/app_theme.dart';

/// Three-tab Friends hub: My Friends · Requests · Find People.
///
/// Friends are independent of class — a student in class A can friend a
/// student in class B and duel them. The classmate-scoped Challenge tab
/// inside the Duels lobby is unaffected by this screen.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? get _myId => Hive.box('userProfile').get('id') as String?;
  String? get _myUsername =>
      Hive.box('userProfile').get('username') as String?;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final incomingCount =
        ref.watch(incomingFriendRequestsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends',
            style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.violet,
          labelColor: isDark ? Colors.white : Colors.black87,
          unselectedLabelColor: isDark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondaryLight,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            const Tab(text: '👥 Friends'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⏳ Requests'),
                  if (incomingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$incomingCount',
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
            const Tab(text: '🔍 Find'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _FriendsListTab(myId: _myId, myUsername: _myUsername),
            _RequestsTab(myId: _myId),
            _FindPeopleTab(myId: _myId),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 1 — My Friends
// ═══════════════════════════════════════════════════════════════════════

class _FriendsListTab extends ConsumerWidget {
  final String? myId;
  final String? myUsername;

  const _FriendsListTab({required this.myId, required this.myUsername});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final friendsAsync = ref.watch(friendsListProvider);

    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _EmptyState(
        emoji: '⚠️',
        title: 'Could not load friends',
        subtitle: 'Pull down to retry.',
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return _EmptyState(
            emoji: '👥',
            title: 'No friends yet',
            subtitle:
                'Search for someone in the Find tab or accept a request.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final friend = row['friend'] as Map<String, dynamic>?;
            if (friend == null) return const SizedBox.shrink();
            return _FriendTile(
              friendshipId: row['id'] as String,
              userId: friend['id'] as String,
              username: friend['username'] as String? ?? '???',
              level: (friend['level'] as int?) ?? 1,
              xp: (friend['xp'] as int?) ?? 0,
              myId: myId,
              myUsername: myUsername,
              isDark: isDark,
            );
          },
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String friendshipId;
  final String userId;
  final String username;
  final int level;
  final int xp;
  final String? myId;
  final String? myUsername;
  final bool isDark;

  const _FriendTile({
    required this.friendshipId,
    required this.userId,
    required this.username,
    required this.level,
    required this.xp,
    required this.myId,
    required this.myUsername,
    required this.isDark,
  });

  Future<void> _challengeDuel(BuildContext context) async {
    if (myId == null || myUsername == null) return;
    final words = await DuelService.selectDuelWords(count: 10);
    if (words.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('No words available for duel. Add words to the library first.')),
        );
      }
      return;
    }
    final duelId = await DuelService.createDuel(
      challengerId: myId!,
      challengerUsername: myUsername!,
      opponentId: userId,
      opponentUsername: username,
      wordSet: words,
    );
    if (duelId != null && context.mounted) {
      // Navigate to the Duels tab so its realtime listener (and the
      // existing pending-list / auto-push-into-game-on-accept logic) is
      // alive. Without this, a user who has never opened the Duels tab
      // sends a challenge and the lobby state — which owns the
      // status='active' listener — never gets built.
      context.go('/duels');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge sent to $username! ⚔️'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmUnfriend(BuildContext context) async {
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
      await FriendshipService.unfriend(friendshipId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppTheme.borderRadiusMd,
      onTap: () => context.push('/friends/profile/$userId'),
      child: Container(
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
            _Avatar(letter: username.isNotEmpty ? username[0] : '?'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _LevelChip(level: level),
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
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.violet.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: () => _challengeDuel(context),
                icon: const Icon(Icons.flash_on, size: 16),
                label: const Text('Duel'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'profile') {
                  context.push('/friends/profile/$userId');
                } else if (value == 'remove') {
                  _confirmUnfriend(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'profile', child: Text('View profile')),
                PopupMenuItem(value: 'remove', child: Text('Remove friend')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 2 — Requests (incoming + outgoing)
// ═══════════════════════════════════════════════════════════════════════

class _RequestsTab extends ConsumerWidget {
  final String? myId;
  const _RequestsTab({required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final incoming = ref.watch(incomingFriendRequestsProvider).valueOrNull ?? [];
    final outgoing = ref.watch(outgoingFriendRequestsProvider).valueOrNull ?? [];

    if (incoming.isEmpty && outgoing.isEmpty) {
      return _EmptyState(
        emoji: '📭',
        title: 'No requests',
        subtitle:
            'When someone wants to friend you, their request shows up here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (incoming.isNotEmpty) ...[
          _SectionLabel(text: 'Incoming (${incoming.length})'),
          const SizedBox(height: 8),
          ...incoming.map((row) {
            final requester = row['requester'] as Map<String, dynamic>?;
            return _IncomingRequestTile(
              friendshipId: row['id'] as String,
              myId: myId,
              username: requester?['username'] as String? ?? '???',
              level: (requester?['level'] as int?) ?? 1,
              xp: (requester?['xp'] as int?) ?? 0,
              isDark: isDark,
            );
          }),
          const SizedBox(height: 16),
        ],
        if (outgoing.isNotEmpty) ...[
          _SectionLabel(text: 'Sent (${outgoing.length})'),
          const SizedBox(height: 8),
          ...outgoing.map((row) {
            final addressee = row['addressee'] as Map<String, dynamic>?;
            return _OutgoingRequestTile(
              friendshipId: row['id'] as String,
              username: addressee?['username'] as String? ?? '???',
              level: (addressee?['level'] as int?) ?? 1,
              xp: (addressee?['xp'] as int?) ?? 0,
              isDark: isDark,
            );
          }),
        ],
      ],
    );
  }
}

class _IncomingRequestTile extends StatelessWidget {
  final String friendshipId;
  final String? myId;
  final String username;
  final int level;
  final int xp;
  final bool isDark;

  const _IncomingRequestTile({
    required this.friendshipId,
    required this.myId,
    required this.username,
    required this.level,
    required this.xp,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(letter: username.isNotEmpty ? username[0] : '?'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$username wants to be friends',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _LevelChip(level: level),
                        const SizedBox(width: 8),
                        Text(
                          '$xp XP',
                          style: TextStyle(
                            fontSize: 12,
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
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: myId == null
                      ? null
                      : () async {
                          final ok = await FriendshipService.declineRequest(
                            friendshipId: friendshipId,
                            myId: myId!,
                          );
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Could not decline. Try again.')),
                            );
                          }
                        },
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
                    onPressed: myId == null
                        ? null
                        : () async {
                            final ok = await FriendshipService.acceptRequest(
                              friendshipId: friendshipId,
                              myId: myId!,
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Could not accept. Try again.')),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Accept',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutgoingRequestTile extends StatelessWidget {
  final String friendshipId;
  final String username;
  final int level;
  final int xp;
  final bool isDark;

  const _OutgoingRequestTile({
    required this.friendshipId,
    required this.username,
    required this.level,
    required this.xp,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(isDark: isDark),
      child: Row(
        children: [
          _Avatar(letter: username.isNotEmpty ? username[0] : '?'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _LevelChip(level: level),
                    const SizedBox(width: 8),
                    Text(
                      '$xp XP · waiting for reply',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
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
          TextButton(
            onPressed: () async {
              await FriendshipService.unfriend(friendshipId);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Tab 3 — Find People (search)
// ═══════════════════════════════════════════════════════════════════════

class _FindPeopleTab extends ConsumerStatefulWidget {
  final String? myId;
  const _FindPeopleTab({required this.myId});

  @override
  ConsumerState<_FindPeopleTab> createState() => _FindPeopleTabState();
}

class _FindPeopleTabState extends ConsumerState<_FindPeopleTab> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  bool _searching = false;
  String _query = '';
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final cleaned = value.trim();
    if (cleaned == _query) return;

    if (cleaned.length < 2) {
      setState(() {
        _query = cleaned;
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _query = cleaned;
      _searching = true;
    });

    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(cleaned));
  }

  Future<void> _runSearch(String query) async {
    final myId = widget.myId;
    if (myId == null) return;
    final results = await FriendshipService.searchUsers(query: query, myId: myId);
    if (!mounted || query != _query) return; // outdated response
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  /// Called from `ref.listen` callbacks when any friendship-state stream
  /// ticks. Only re-runs if the user actually has an active query — no
  /// point spinning the spinner on the empty-state screen.
  void _refreshIfActive() {
    if (_query.length >= 2) _runSearch(_query);
  }

  Future<void> _addFriend(Map<String, dynamic> user) async {
    final myId = widget.myId;
    if (myId == null) return;
    final status = await FriendshipService.sendRequest(
      myId: myId,
      otherId: user['id'] as String,
    );
    if (!mounted) return;
    final username = user['username'] as String? ?? 'user';
    final message = switch (status) {
      'pending' => 'Request sent to $username',
      'accepted' => 'You and $username are now friends! 🎉',
      'blocked' => 'Could not send request.',
      _ => 'Something went wrong. Try again.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
    // Re-run search so the CTA per row updates.
    if (_query.length >= 2) _runSearch(_query);
  }

  Future<void> _acceptInline(String friendshipId) async {
    final myId = widget.myId;
    if (myId == null) return;
    await FriendshipService.acceptRequest(
      friendshipId: friendshipId,
      myId: myId,
    );
    if (_query.length >= 2) _runSearch(_query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // When the friendship graph changes elsewhere (mutual auto-accept fired,
    // someone accepted my pending request, I cancelled an outgoing one,
    // etc.) re-run the active search so each row's CTA reflects the new
    // state instead of going stale until the user re-types.
    ref.listen(friendsListProvider, (_, __) => _refreshIfActive());
    ref.listen(incomingFriendRequestsProvider, (_, __) => _refreshIfActive());
    ref.listen(outgoingFriendRequestsProvider, (_, __) => _refreshIfActive());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Search by username',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                borderRadius: AppTheme.borderRadiusMd,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildBody(isDark),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_query.length < 2) {
      return _EmptyState(
        emoji: '🔍',
        title: 'Find people',
        subtitle: 'Type at least 2 characters to start searching.',
      );
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return _EmptyState(
        emoji: '🤷',
        title: 'No matches',
        subtitle: 'Try a different username.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return _SearchResultTile(
          user: user,
          myId: widget.myId,
          isDark: isDark,
          onAdd: () => _addFriend(user),
          onAccept: (id) => _acceptInline(id),
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String? myId;
  final bool isDark;
  final VoidCallback onAdd;
  final ValueChanged<String> onAccept;

  const _SearchResultTile({
    required this.user,
    required this.myId,
    required this.isDark,
    required this.onAdd,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final username = user['username'] as String? ?? '???';
    final level = (user['level'] as int?) ?? 1;
    final xp = (user['xp'] as int?) ?? 0;
    final friendship = user['friendship'] as Map<String, dynamic>?;
    final status = friendship?['status'] as String?;
    final requesterId = friendship?['requester_id'] as String?;
    final friendshipId = friendship?['id'] as String?;

    Widget cta;
    if (status == 'accepted') {
      cta = const _StatusChip(
        text: '✓ Friends',
        color: AppTheme.success,
      );
    } else if (status == 'pending' && requesterId == myId) {
      cta = const _StatusChip(
        text: 'Pending',
        color: AppTheme.fire,
      );
    } else if (status == 'pending' &&
        requesterId != myId &&
        friendshipId != null) {
      cta = FilledButton(
        onPressed: () => onAccept(friendshipId),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.violet,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        child: const Text('Accept'),
      );
    } else {
      cta = OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('Add'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      );
    }

    return InkWell(
      borderRadius: AppTheme.borderRadiusMd,
      onTap: () => context.push('/friends/profile/${user['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCard(isDark: isDark),
        child: Row(
          children: [
            _Avatar(letter: username.isNotEmpty ? username[0] : '?'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _LevelChip(level: level),
                      const SizedBox(width: 8),
                      Text(
                        '$xp XP',
                        style: TextStyle(
                          fontSize: 12,
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
            cta,
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Reusable bits
// ═══════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String letter;
  const _Avatar({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
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
        letter.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final int level;
  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.amber.withValues(alpha: isDark ? 0.15 : 0.1),
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
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.violet.withValues(alpha: isDark ? 0.1 : 0.06),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
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
      ),
    );
  }
}
