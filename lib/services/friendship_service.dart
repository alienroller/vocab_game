import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the friend graph: search → request → accept/decline → unfriend.
///
/// Mirrors the static-method shape of [DuelService]. The "send request" path
/// goes through the `send_friend_request` plpgsql RPC so the mutual-add race
/// (both users tap Add at the same instant) resolves cleanly to a single
/// accepted row.
///
/// Friend duels reuse [DuelService.createDuel] unchanged — this service only
/// owns the friendships table.
class FriendshipService {
  static final _supabase = Supabase.instance.client;

  /// Public profile fields safe to surface to friends. Mirrors the read-only
  /// fields shown on [FriendProfileScreen]. Excludes class_code (kids' app
  /// privacy), PIN, and any account-management state.
  static const _publicProfileFields =
      'id, username, xp, level, streak_days, longest_streak, '
      'total_words_answered, total_correct';

  // ─── Search ──────────────────────────────────────────────────────────

  /// Username-prefix search across all students. Excludes self and teachers.
  ///
  /// For each result we attach the existing friendship edge (if any) so the
  /// UI can render the correct CTA per row (Add Friend / Pending / Accept /
  /// ✓ Friends). Hidden from the result if the edge is `blocked`.
  ///
  /// Returns a list of maps shaped like:
  ///   { id, username, xp, level, streak_days, ..., friendship: { id, status,
  ///     requester_id, addressee_id }? }
  static Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    required String myId,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      // Case-insensitive prefix match. Migration 014 swapped the original
      // LOWER(username) btree (which ILIKE never used) for a pg_trgm gin
      // index on `username`, which Postgres does use for ILIKE prefix.
      final escaped = trimmed.replaceAll('%', r'\%').replaceAll('_', r'\_');
      final results = await _supabase
          .from('profiles')
          .select(_publicProfileFields)
          .ilike('username', '$escaped%')
          .neq('id', myId)
          .eq('is_teacher', false)
          .limit(25);

      final candidates = List<Map<String, dynamic>>.from(results);
      if (candidates.isEmpty) return [];

      // Fetch any friendship edges between me and any of the candidates.
      final candidateIds = candidates.map((c) => c['id'] as String).toList();
      final orFilter = candidateIds
          .map((id) =>
              'and(requester_id.eq.$myId,addressee_id.eq.$id),'
              'and(requester_id.eq.$id,addressee_id.eq.$myId)')
          .join(',');

      final edgesData = await _supabase
          .from('friendships')
          .select('id, status, requester_id, addressee_id')
          .or(orFilter);
      final edges = List<Map<String, dynamic>>.from(edgesData);

      // Index edges by the *other* user id for O(1) lookup.
      final edgeByOther = <String, Map<String, dynamic>>{};
      for (final e in edges) {
        final otherId = e['requester_id'] == myId
            ? e['addressee_id'] as String
            : e['requester_id'] as String;
        edgeByOther[otherId] = e;
      }

      final out = <Map<String, dynamic>>[];
      for (final c in candidates) {
        final edge = edgeByOther[c['id'] as String];
        if (edge != null && edge['status'] == 'blocked') continue;
        out.add({...c, 'friendship': edge});
      }
      return out;
    } catch (e) {
      debugPrint('Friend search failed: $e');
      return [];
    }
  }

  // ─── Mutations ───────────────────────────────────────────────────────

  /// Sends a friend request via the atomic `send_friend_request` RPC.
  /// Returns one of: 'pending', 'accepted' (mutual auto-accept), 'blocked',
  /// or 'error'. Returns 'error' on transport failure.
  static Future<String> sendRequest({
    required String myId,
    required String otherId,
  }) async {
    try {
      final result = await _supabase.rpc('send_friend_request', params: {
        'p_requester': myId,
        'p_addressee': otherId,
      });
      if (result is Map) {
        return (result['status'] as String?) ?? 'error';
      }
      return 'error';
    } catch (e) {
      debugPrint('send_friend_request RPC failed: $e');
      return 'error';
    }
  }

  /// Accepts a pending incoming request. The addressee_id WHERE-clause
  /// filter is the API-level guard that only the actual addressee can
  /// accept — RLS is open-anon so the server doesn't enforce ownership.
  static Future<bool> acceptRequest({
    required String friendshipId,
    required String myId,
  }) async {
    try {
      await _supabase
          .from('friendships')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId)
          .eq('addressee_id', myId);
      return true;
    } catch (e) {
      debugPrint('Accept friendship failed: $e');
      return false;
    }
  }

  /// Declines a pending incoming request. Same addressee_id guard as
  /// [acceptRequest]. The row stays as 'declined' so the requester can
  /// re-send later (the RPC re-opens declined edges).
  static Future<bool> declineRequest({
    required String friendshipId,
    required String myId,
  }) async {
    try {
      await _supabase
          .from('friendships')
          .update({
            'status': 'declined',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId)
          .eq('addressee_id', myId);
      return true;
    } catch (e) {
      debugPrint('Decline friendship failed: $e');
      return false;
    }
  }

  /// Unfriend (mutual delete) or cancel an outgoing pending request — both
  /// are a hard delete on the row.
  static Future<bool> unfriend(String friendshipId) async {
    try {
      await _supabase.from('friendships').delete().eq('id', friendshipId);
      return true;
    } catch (e) {
      debugPrint('Unfriend failed: $e');
      return false;
    }
  }

  // ─── Lists ───────────────────────────────────────────────────────────

  /// All accepted friends of [myId]. Each entry exposes the friendship row
  /// plus a `friend` key holding the *other* user's public profile fields.
  static Future<List<Map<String, dynamic>>> listFriends(String myId) async {
    try {
      final data = await _supabase
          .from('friendships')
          .select(
              'id, status, created_at, responded_at, requester_id, addressee_id, '
              'requester:profiles!friendships_requester_id_fkey($_publicProfileFields), '
              'addressee:profiles!friendships_addressee_id_fkey($_publicProfileFields)')
          .eq('status', 'accepted')
          .or('requester_id.eq.$myId,addressee_id.eq.$myId')
          .order('responded_at', ascending: false);

      return List<Map<String, dynamic>>.from(data).map((row) {
        final requester = row['requester'] as Map<String, dynamic>?;
        final addressee = row['addressee'] as Map<String, dynamic>?;
        final friend =
            row['requester_id'] == myId ? addressee : requester;
        return {...row, 'friend': friend};
      }).toList();
    } catch (e) {
      debugPrint('List friends failed: $e');
      return [];
    }
  }

  /// Pending requests where I am the addressee.
  static Future<List<Map<String, dynamic>>> listIncomingRequests(
      String myId) async {
    try {
      final data = await _supabase
          .from('friendships')
          .select('id, status, created_at, requester_id, addressee_id, '
              'requester:profiles!friendships_requester_id_fkey($_publicProfileFields)')
          .eq('addressee_id', myId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('List incoming requests failed: $e');
      return [];
    }
  }

  /// Pending requests where I am the requester (waiting on the other side).
  static Future<List<Map<String, dynamic>>> listOutgoingRequests(
      String myId) async {
    try {
      final data = await _supabase
          .from('friendships')
          .select('id, status, created_at, requester_id, addressee_id, '
              'addressee:profiles!friendships_addressee_id_fkey($_publicProfileFields)')
          .eq('requester_id', myId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('List outgoing requests failed: $e');
      return [];
    }
  }
}
