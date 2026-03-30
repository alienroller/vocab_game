import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _subscribeToRealtime();
  }

  Future<void> _loadData() async {
    final profileBox = Hive.box('userProfile');
    _classCode = profileBox.get('classCode') as String?;
    _myUsername = profileBox.get('username') as String?;
    final supabase = Supabase.instance.client;

    try {
      // Fetch all three boards
      final globalFuture = supabase
          .from('profiles')
          .select('username, xp, level')
          .order('xp', ascending: false)
          .limit(100);

      List<dynamic> classFuture = [];
      List<dynamic> weekFuture = [];

      if (_classCode != null && _classCode!.isNotEmpty) {
        classFuture = await supabase
            .from('profiles')
            .select('username, xp, level, streak_days')
            .eq('class_code', _classCode!)
            .order('xp', ascending: false)
            .limit(50);

        weekFuture = await supabase
            .from('profiles')
            .select('username, week_xp, level')
            .eq('class_code', _classCode!)
            .order('week_xp', ascending: false)
            .limit(50);
      }

      final globalResult = await globalFuture;

      if (mounted) {
        setState(() {
          _classBoard = List<Map<String, dynamic>>.from(classFuture);
          _globalBoard = List<Map<String, dynamic>>.from(globalResult);
          _weekBoard = List<Map<String, dynamic>>.from(weekFuture);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
                _buildBoard(_classBoard, scoreKey: 'xp'),
                _buildBoard(_globalBoard, scoreKey: 'xp'),
                _buildBoard(_weekBoard, scoreKey: 'week_xp'),
              ],
            ),
    );
  }

  Widget _buildBoard(List<Map<String, dynamic>> entries,
      {required String scoreKey}) {
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
              trailing: Text(
                '${entry[scoreKey] ?? 0} XP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isMe
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
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
    Supabase.instance.client.channel('leaderboard-updates').unsubscribe();
    super.dispose();
  }
}
