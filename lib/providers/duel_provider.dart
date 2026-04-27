import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Realtime stream of pending duel invitations targeting the current user.
///
/// Powers the badge count on the bottom nav. Replaces the previous 10-sec
/// polling implementation: the channel listens to inserts/updates on the
/// duels table filtered by `opponent_id = userId`, and re-queries the
/// pending list on any change. Cold start emits an initial fetch
/// immediately so the badge isn't blank for 10 seconds on app open.
final duelInvitationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final profileBox = Hive.box('userProfile');
  final userId = profileBox.get('id') as String?;

  if (userId == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }

  final supabase = Supabase.instance.client;
  final controller =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Future<void> refresh() async {
    try {
      final data = await supabase
          .from('duels')
          .select()
          .eq('opponent_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      if (!controller.isClosed) {
        controller.add(List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
      if (!controller.isClosed) {
        controller.add(<Map<String, dynamic>>[]);
      }
    }
  }

  refresh();

  final channel = supabase.channel('duel_invites_$userId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'duels',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'opponent_id',
        value: userId,
      ),
      callback: (_) => refresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'duels',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'opponent_id',
        value: userId,
      ),
      callback: (_) => refresh(),
    )
    ..subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});
