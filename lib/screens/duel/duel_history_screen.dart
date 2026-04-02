import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

/// Duel history screen — shows all finished duels for the current user.
///
/// Displays opponent name, score, win/loss, XP gained, and date.
class DuelHistoryScreen extends StatefulWidget {
  const DuelHistoryScreen({super.key});

  @override
  State<DuelHistoryScreen> createState() => _DuelHistoryScreenState();
}

class _DuelHistoryScreenState extends State<DuelHistoryScreen> {
  List<Map<String, dynamic>> _duels = [];
  bool _loading = true;
  late String _myId;

  @override
  void initState() {
    super.initState();
    _myId = Hive.box('userProfile').get('id', defaultValue: '') as String;
    _loadDuels();
  }

  Future<void> _loadDuels() async {
    try {
      final data = await Supabase.instance.client
          .from('duels')
          .select()
          .or('challenger_id.eq.$_myId,opponent_id.eq.$_myId')
          .eq('status', 'finished')
          .order('finished_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _duels = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Duel History',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _duels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚔️', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text('No duels yet',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          'Challenge a classmate to your first duel!',
                          style: TextStyle(
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadDuels,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _duels.length,
                      itemBuilder: (context, index) {
                        return _DuelHistoryCard(
                          duel: _duels[index],
                          myId: _myId,
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _DuelHistoryCard extends StatelessWidget {
  final Map<String, dynamic> duel;
  final String myId;

  const _DuelHistoryCard({required this.duel, required this.myId});

  @override
  Widget build(BuildContext context) {

    final isChallenger = duel['challenger_id'] == myId;
    final opponentName = isChallenger
        ? duel['opponent_username'] as String? ?? '???'
        : duel['challenger_username'] as String? ?? '???';
    final myScore = isChallenger
        ? duel['challenger_score'] as int? ?? 0
        : duel['opponent_score'] as int? ?? 0;
    final opponentScore = isChallenger
        ? duel['opponent_score'] as int? ?? 0
        : duel['challenger_score'] as int? ?? 0;
    final isWinner = duel['winner_id'] == myId;
    final isDraw = myScore == opponentScore;
    final xpGained = isChallenger
        ? duel['challenger_xp_gain'] as int? ?? 0
        : duel['opponent_xp_gain'] as int? ?? 0;

    // Parse date
    final finishedAt = duel['finished_at'] as String?;
    String dateLabel = '';
    if (finishedAt != null) {
      final dt = DateTime.tryParse(finishedAt);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          dateLabel = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          dateLabel = '${diff.inHours}h ago';
        } else {
          dateLabel = '${diff.inDays}d ago';
        }
      }
    }

    final resultColor = isDraw
        ? Colors.grey
        : isWinner
            ? Colors.green
            : Colors.red;
    final resultIcon = isDraw
        ? '🤝'
        : isWinner
            ? '🏆'
            : '😤';
    final resultLabel = isDraw
        ? 'Draw'
        : isWinner
            ? 'Won'
            : 'Lost';

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          // Result icon with gradient bg
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  resultColor.withValues(alpha: 0.2),
                  resultColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: resultColor.withValues(alpha: 0.25),
              ),
            ),
            child: Center(
              child: Text(resultIcon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs $opponentName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: resultColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        resultLabel,
                        style: TextStyle(
                          color: resultColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$myScore - $opponentScore',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // XP gained badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.amber.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '+$xpGained XP',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.amber,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
