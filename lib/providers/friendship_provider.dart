import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/friendship_service.dart';

/// Realtime stream of pending incoming friend requests targeting the current
/// user. Powers the red-dot badge on the Duels-lobby Friends icon and the
/// "Pending requests: N" subtitle on the Profile tab's Friends action.
///
/// Mirrors `duelInvitationsProvider` in [duel_provider.dart]: a single
/// channel filters on `addressee_id = userId`, and any insert/update on the
/// friendships table triggers a re-query. Cold-start emits an immediate
/// fetch so the badge isn't blank for the first second after app open.
final incomingFriendRequestsProvider =
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
    final data = await FriendshipService.listIncomingRequests(userId);
    if (!controller.isClosed) controller.add(data);
  }

  refresh();

  final channel = supabase.channel('friendships_in_$userId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'friendships',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'addressee_id',
        value: userId,
      ),
      callback: (_) => refresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'friendships',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'addressee_id',
        value: userId,
      ),
      callback: (_) => refresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'friendships',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'addressee_id',
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

/// Realtime stream of accepted friends of the current user.
///
/// Listens to two channels: one filtered on `requester_id = me`, one on
/// `addressee_id = me`. Either side of the edge can change (accept, decline,
/// unfriend), so we need both filters. On any event, the full list is
/// re-fetched — small lists, simple code, matches `duelInvitationsProvider`.
final friendsListProvider =
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
    final data = await FriendshipService.listFriends(userId);
    if (!controller.isClosed) controller.add(data);
  }

  refresh();

  void onChange(_) => refresh();

  final asRequester = supabase.channel('friendships_req_$userId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friendships',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'requester_id',
        value: userId,
      ),
      callback: onChange,
    )
    ..subscribe();

  final asAddressee = supabase.channel('friendships_add_$userId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friendships',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'addressee_id',
        value: userId,
      ),
      callback: onChange,
    )
    ..subscribe();

  ref.onDispose(() {
    supabase.removeChannel(asRequester);
    supabase.removeChannel(asAddressee);
    controller.close();
  });

  return controller.stream;
});

/// Pending outgoing requests (mine, waiting on the other side). Used by the
/// Requests tab's "Sent" sub-section. Same realtime fan-out as the friends
/// list — any change on a row where `requester_id = me` triggers refetch.
final outgoingFriendRequestsProvider =
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
    final data = await FriendshipService.listOutgoingRequests(userId);
    if (!controller.isClosed) controller.add(data);
  }

  refresh();

  final channel = supabase.channel('friendships_out_$userId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friendships',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'requester_id',
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
