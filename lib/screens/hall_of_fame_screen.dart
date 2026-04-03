import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Hall of Fame — permanent record of weekly tournament winners.
///
/// Displays top-3 winners grouped by week period, newest first.
class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final fame = await Supabase.instance.client
          .from('hall_of_fame')
          .select()
          .order('awarded_at', ascending: false)
          .limit(100);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final entry in (fame as List)) {
        final label = entry['period_label'] as String;
        grouped.putIfAbsent(label, () => []).add(Map<String, dynamic>.from(entry));
      }

      if (mounted) {
        setState(() {
          _grouped = grouped;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hall of Fame',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _grouped.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.amber.withValues(alpha: isDark ? 0.1 : 0.06),
                          ),
                          child: const Text('🏆', style: TextStyle(fontSize: 56)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No winners yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Top 3 players each week\nare immortalized here!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: _grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              entry.key,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ...entry.value.map((winner) {
                            final rank = winner['rank'] as int;
                            final medal = switch (rank) {
                              1 => '🥇',
                              2 => '🥈',
                              3 => '🥉',
                              _ => '🏅',
                            };
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: AppTheme.glassCard(isDark: isDark),
                              child: Row(
                                children: [
                                  Text(medal, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      winner['username'] ?? '???',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.amber.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${winner['week_xp'] ?? 0} XP',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          Divider(
                            height: 24,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
      ),
    );
  }
}
