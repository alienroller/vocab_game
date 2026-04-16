import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_constants.dart';

/// Manages 1v1 live duel lifecycle.
///
/// Flow: create → accept → play → finish.
/// Both players answer the same word set. Scores update in real-time
/// via Supabase Realtime subscriptions.
class DuelService {
  static final _supabase = Supabase.instance.client;

  /// Creates a new duel challenge.
  ///
  /// [challengerId] — the user sending the challenge.
  /// [opponentId] — the user receiving the challenge.
  /// [wordSet] — list of word maps (id, word, translation) for both players.
  static Future<String?> createDuel({
    required String challengerId,
    required String challengerUsername,
    required String opponentId,
    required String opponentUsername,
    required List<Map<String, dynamic>> wordSet,
  }) async {
    try {
      final result = await _supabase
          .from('duels')
          .insert({
            'challenger_id': challengerId,
            'challenger_username': challengerUsername,
            'opponent_id': opponentId,
            'opponent_username': opponentUsername,
            'status': 'pending',
            'word_set': wordSet,
          })
          .select('id')
          .single();
      return result['id'] as String;
    } catch (e) {
      debugPrint('Create duel failed: $e');
      return null;
    }
  }

  /// Opponent accepts the duel — changes status to 'active'.
  static Future<bool> acceptDuel(String duelId) async {
    try {
      await _supabase
          .from('duels')
          .update({
            'status': 'active',
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', duelId);
      return true;
    } catch (e) {
      debugPrint('Accept duel failed: $e');
      return false;
    }
  }

  /// Opponent declines the duel.
  static Future<void> declineDuel(String duelId) async {
    try {
      await _supabase
          .from('duels')
          .update({'status': 'declined'}).eq('id', duelId);
    } catch (e) {
      debugPrint('Decline duel failed: $e');
    }
  }

  /// Updates a player's score during the duel (called after each answer).
  static Future<void> updateScore({
    required String duelId,
    required String playerId,
    required bool isChallenger,
    required int newScore,
  }) async {
    try {
      final field = isChallenger ? 'challenger_score' : 'opponent_score';
      await _supabase
          .from('duels')
          .update({field: newScore}).eq('id', duelId);
    } catch (e) {
      debugPrint('Update score failed: $e');
    }
  }

  /// Finishes the duel — determines winner and awards XP.
  ///
  /// P4 fix: Previously if the first XP RPC succeeded and the second failed,
  /// the duel was marked "finished" but only one player got XP. We now:
  ///   1. Mark the row as `settling` (not "finished") while awarding XP.
  ///   2. If either XP RPC fails, try to revert the row back to "active" so
  ///      the UI can retry or surface an error.
  ///   3. Only after both XP RPCs succeed do we commit `finished`.
  static Future<Map<String, dynamic>?> finishDuel({
    required String duelId,
    required String challengerId,
    required String opponentId,
    required int challengerScore,
    required int opponentScore,
  }) async {
    String? winnerId;
    final int challengerXp;
    final int opponentXp;

    if (challengerScore > opponentScore) {
      winnerId = challengerId;
      challengerXp = GameConstants.duelWinnerXp;
      opponentXp = GameConstants.duelLoserXp;
    } else if (opponentScore > challengerScore) {
      winnerId = opponentId;
      challengerXp = GameConstants.duelLoserXp;
      opponentXp = GameConstants.duelWinnerXp;
    } else {
      challengerXp = GameConstants.duelDrawXp;
      opponentXp = GameConstants.duelDrawXp;
    }

    // Step 1: mark the duel as settling (intermediate state).
    try {
      await _supabase.from('duels').update({
        'status': 'settling',
        'winner_id': winnerId,
        'challenger_xp_gain': challengerXp,
        'opponent_xp_gain': opponentXp,
        'settling_at': DateTime.now().toIso8601String(),
      }).eq('id', duelId);
    } catch (e) {
      debugPrint('Finish duel (mark settling) failed: $e');
      return null;
    }

    // Step 2: award XP to both players. Track what succeeded so we can
    // compensate if the second call fails.
    bool challengerAwarded = false;
    bool opponentAwarded = false;
    try {
      await _supabase.rpc('increment_xp',
          params: {'profile_id': challengerId, 'amount': challengerXp});
      challengerAwarded = true;

      await _supabase.rpc('increment_xp',
          params: {'profile_id': opponentId, 'amount': opponentXp});
      opponentAwarded = true;
    } catch (e) {
      debugPrint('Duel XP award failed (rolling back): $e');

      // Compensate the one that did land, so the cluster stays consistent.
      if (challengerAwarded && !opponentAwarded) {
        try {
          await _supabase.rpc('increment_xp', params: {
            'profile_id': challengerId,
            'amount': -challengerXp,
          });
        } catch (rollbackErr) {
          debugPrint('Challenger XP rollback failed (needs manual fix): '
              '$rollbackErr');
        }
      }

      // Revert the duel row so the UI can retry rather than leaving it
      // stranded in "settling".
      try {
        await _supabase.from('duels').update({
          'status': 'active',
          'winner_id': null,
          'challenger_xp_gain': null,
          'opponent_xp_gain': null,
          'settling_at': null,
        }).eq('id', duelId);
      } catch (revertErr) {
        debugPrint('Duel revert failed (stuck in settling): $revertErr');
      }
      return null;
    }

    // Step 3: commit — only now flip to finished.
    try {
      await _supabase.from('duels').update({
        'status': 'finished',
        'finished_at': DateTime.now().toIso8601String(),
      }).eq('id', duelId);
    } catch (e) {
      debugPrint('Duel commit to finished failed (XP already awarded): $e');
      // XP is already on both accounts; next retry can move the row forward.
    }

    return {
      'winner_id': winnerId,
      'challenger_xp': challengerXp,
      'opponent_xp': opponentXp,
    };
  }

  /// Gets pending duel invitations for a user.
  static Future<List<Map<String, dynamic>>> getPendingDuels(
      String userId) async {
    try {
      final data = await _supabase
          .from('duels')
          .select()
          .eq('opponent_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Get pending duels failed: $e');
      return [];
    }
  }

  /// Gets duel history for a user (last 20 finished duels).
  static Future<List<Map<String, dynamic>>> getDuelHistory(
      String userId) async {
    try {
      final data = await _supabase
          .from('duels')
          .select()
          .eq('status', 'finished')
          .or('challenger_id.eq.$userId,opponent_id.eq.$userId')
          .order('finished_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Get duel history failed: $e');
      return [];
    }
  }

  /// Selects random words for a duel from a unit, collection, or local Hive vocab.
  ///
  /// Falls back to the player's local vocabulary if the Supabase `words`
  /// table is empty (common before content seeding).
  static Future<List<Map<String, dynamic>>> selectDuelWords({
    String? unitId,
    String? collectionId,
    int count = 10,
  }) async {
    try {
      List<dynamic> words;

      if (unitId != null) {
        words = await _supabase
            .from('words')
            .select('id, word, translation')
            .eq('unit_id', unitId);
      } else if (collectionId != null) {
        words = await _supabase
            .from('words')
            .select('id, word, translation')
            .eq('collection_id', collectionId);
      } else {
        words = await _supabase
            .from('words')
            .select('id, word, translation')
            .limit(200);
      }

      final wordList = List<Map<String, dynamic>>.from(words);

      // Fallback: if Supabase has no words, use local Hive vocabulary
      if (wordList.isEmpty) {
        return _getLocalWords(count);
      }

      wordList.shuffle(Random.secure());
      return wordList.take(count).toList();
    } catch (e) {
      debugPrint('Select duel words failed: $e');
      // Fallback to local on network error too
      return _getLocalWords(count);
    }
  }

  /// Gets words from the local Hive vocabulary box.
  static List<Map<String, dynamic>> _getLocalWords(int count) {
    try {
      final vocabBox = Hive.box('vocab');
      final allVocab = vocabBox.values.toList();
      if (allVocab.isEmpty) return [];

      final words = allVocab.map((v) {
        final map = Map<String, dynamic>.from(v as Map);
        return {
          'id': map['id'] ?? '',
          'word': map['english'] ?? map['word'] ?? '',
          'translation': map['uzbek'] ?? map['translation'] ?? '',
        };
      }).where((w) =>
          (w['word'] as String).isNotEmpty &&
          (w['translation'] as String).isNotEmpty
      ).toList();

      words.shuffle(Random.secure());
      return words.take(count).toList();
    } catch (e) {
      debugPrint('Local word fallback failed: $e');
      return [];
    }
  }
}
