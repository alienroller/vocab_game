import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides a periodically-refreshed list of pending duel invitations.
///
/// Polls every 10 seconds for new duels targeting this user.
final duelInvitationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final profileBox = Hive.box('userProfile');
  final userId = profileBox.get('id') as String?;

  if (userId == null) {
    return Stream.value([]);
  }

  final supabase = Supabase.instance.client;

  // Poll every 10 seconds for new invitations
  return Stream.periodic(const Duration(seconds: 10), (tick) => tick)
      .asyncMap((tick) async {
    try {
      final data = await supabase
          .from('duels')
          .select()
          .eq('opponent_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  });
});

/// Fetches a single duel's data by ID.
final duelDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, duelId) async {
  try {
    final data = await Supabase.instance.client
        .from('duels')
        .select()
        .eq('id', duelId)
        .maybeSingle();
    return data;
  } catch (_) {
    return null;
  }
});
