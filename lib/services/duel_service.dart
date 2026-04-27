import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Finishes the duel via the atomic `finish_duel` RPC.
  ///
  /// The RPC handles CAS, XP awards, and commit inside a single Postgres
  /// transaction — any failure auto-rolls back. Returns:
  ///   - `{status: 'finished', ...}` when both players have posted their
  ///      final score and the duel is fully settled.
  ///   - `{status: 'waiting'}` when the caller has posted but the opponent
  ///      hasn't yet — UI should wait for the Postgres Changes 'finished'
  ///      event (or call [forceFinishDuel] after a timeout).
  ///   - `{status: 'error', reason: ...}` on unexpected states.
  ///   - `null` only on transport failure (network down, etc.).
  static Future<Map<String, dynamic>?> finishDuel({
    required String duelId,
    required bool isChallenger,
    required int myFinalScore,
  }) async {
    try {
      final result = await _supabase.rpc('finish_duel', params: {
        'p_duel_id': duelId,
        'p_is_challenger': isChallenger,
        'p_my_final_score': myFinalScore,
      });
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } catch (e) {
      debugPrint('finish_duel RPC failed: $e');
      return null;
    }
  }

  /// Force-finishes a duel that's stuck waiting for an absent opponent.
  /// Uses whatever scores are currently in the DB. Awards XP and commits.
  /// Safe to call when the opponent is presumed gone (timeout reached).
  static Future<Map<String, dynamic>?> forceFinishDuel(String duelId) async {
    try {
      final result = await _supabase.rpc('force_finish_duel', params: {
        'p_duel_id': duelId,
      });
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } catch (e) {
      debugPrint('force_finish_duel RPC failed: $e');
      return null;
    }
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
