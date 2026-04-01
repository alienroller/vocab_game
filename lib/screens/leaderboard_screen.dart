import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'duel/duel_lobby_screen.dart';

/// Leaderboard screen with three tabs: My Class, Global, This Week.
///
/// Uses Supabase Realtime to update live when other players earn XP.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _classBoard = [];
  List<Map<String, dynamic>> _globalBoard = [];
  List<Map<String, dynamic>> _weekBoard = [];
  bool _loading = true;
  String? _classCode;
  String? _myUsername;
  Timer? _countdownTimer;
  String _weeklyCountdown = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _subscribeToRealtime();
    _startWeeklyCountdown();
  }

  void _startWeeklyCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateCountdown(),
    );
  }

  void _updateCountdown() {
    final now = DateTime.now().toUtc();
    // Next Monday 00:00 UTC
    final daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    final nextMonday = DateTime.utc(
      now.year, now.month, now.day + (daysUntilMonday == 0 ? 7 : daysUntilMonday),
    );
    final diff = nextMonday.difference(now);
    if (mounted) {
      setState(() {
        _weeklyCountdown =
            'Resets in ${diff.inDays}d ${diff.inHours % 24}h ${diff.inMinutes % 60}m';
      });
    }
  }

  Future<void> _loadData() async {
    final profileBox = Hive.box('userProfile');
    _classCode = profileBox.get('classCode') as String?;
    _myUsername = profileBox.get('username') as String?;

    // 1. Load cached data instantly (no loading spinner)
    _loadCachedLeaderboard();

    // 2. Refresh from Supabase in background
    await _refreshFromSupabase();
  }

  /// Loads cached leaderboard from Hive for instant display.
  void _loadCachedLeaderboard() {
    final box = Hive.box('userProfile');
    final cached = box.get('leaderboard_cache') as Map?;
    if (cached == null) return;

    if (mounted) {
      setState(() {
        _classBoard = _castList(cached['class']);
        _globalBoard = _castList(cached['global']);
        _weekBoard = _castList(cached['week']);
        _loading = false; // Show cached data immediately
      });
    }
  }

  /// Fetches fresh data from Supabase and caches it.
  Future<void> _refreshFromSupabase() async {
    final supabase = Supabase.instance.client;

    try {
      // Fetch global board
      final globalFuture = supabase
          .from('profiles')
          .select('username, xp, level')
          .order('xp', ascending: false)
          .limit(100);

      List<dynamic> classFuture = [];

      if (_classCode != null && _classCode!.isNotEmpty) {
        classFuture = await supabase
            .from('profiles')
            .select('username, xp, level, streak_days')
            .eq('class_code', _classCode!)
            .order('xp', ascending: false)
            .limit(50);
      }

      // Weekly board: class-scoped if class exists, otherwise global
      List<dynamic> weekFuture;
      if (_classCode != null && _classCode!.isNotEmpty) {
        weekFuture = await supabase
            .from('profiles')
            .select('username, week_xp, level')
            .eq('class_code', _classCode!)
            .order('week_xp', ascending: false)
            .limit(50);
      } else {
        weekFuture = await supabase
            .from('profiles')
            .select('username, week_xp, level')
            .order('week_xp', ascending: false)
            .limit(50);
      }

      final globalResult = await globalFuture;

      final classData = List<Map<String, dynamic>>.from(classFuture);
      final globalData = List<Map<String, dynamic>>.from(globalResult);
      final weekData = List<Map<String, dynamic>>.from(weekFuture);

      // Cache for offline use
      final box = Hive.box('userProfile');
      await box.put('leaderboard_cache', {
        'class': classData,
        'global': globalData,
        'week': weekData,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _classBoard = classData;
          _globalBoard = globalData;
          _weekBoard = weekData;
          _loading = false;
        });
      }
    } catch (e) {
      // Network error — cached data (if any) is already shown
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Safely casts a dynamic list from Hive cache to typed list.
  static List<Map<String, dynamic>> _castList(dynamic data) {
    if (data == null) return [];
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _subscribeToRealtime() {
    Supabase.instance.client
        .channel('leaderboard-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            _loadData(); // reload on any profile change
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Class'),
            Tab(text: 'Global'),
            Tab(text: 'This Week'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBoard(_classBoard, scoreKey: 'xp', showChallenge: true),
                _buildBoard(_globalBoard, scoreKey: 'xp'),
                _buildWeeklyBoard(),
              ],
            ),
    );
  }

  /// Wraps the weekly board with a countdown header
  Widget _buildWeeklyBoard() {
    return Column(
      children: [
        if (_weeklyCountdown.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  _weeklyCountdown,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: _buildBoard(_weekBoard, scoreKey: 'week_xp')),
      ],
    );
  }

  Widget _buildBoard(List<Map<String, dynamic>> entries,
      {required String scoreKey, bool showChallenge = false}) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              scoreKey == 'xp' && _classCode == null
                  ? 'Join a class to see\nyour class leaderboard'
                  : 'No data yet — play to appear here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final String medal = switch (index) {
            0 => '🥇',
            1 => '🥈',
            2 => '🥉',
            _ => '${index + 1}',
          };
          final isMe = entry['username'] == _myUsername;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isMe
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.4)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    medal,
                    style: TextStyle(
                      fontSize: index < 3 ? 24 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              title: Text(
                entry['username'] ?? '???',
                style: TextStyle(
                  fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text('Level ${entry['level'] ?? 1}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showChallenge && !isMe)
                    IconButton(
                      icon: Icon(Icons.sports_kabaddi,
                          color: Colors.red.shade400, size: 20),
                      tooltip: 'Challenge to duel',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DuelLobbyScreen(),
                          ),
                        );
                      },
                    ),
                  Text(
                    '${entry[scoreKey] ?? 0} XP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isMe
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    Supabase.instance.client.channel('leaderboard-updates').unsubscribe();
    super.dispose();
  }
}
