import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hall of Fame',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _grouped.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        'No winners yet',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Top 3 players each week\nare immortalized here!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            entry.key,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Text(medal,
                                  style: const TextStyle(fontSize: 28)),
                              title: Text(
                                winner['username'] ?? '???',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              trailing: Text(
                                '${winner['week_xp'] ?? 0} XP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        }),
                        const Divider(height: 24),
                      ],
                    );
                  }).toList(),
                ),
    );
  }
}
