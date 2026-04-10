import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/speaking_models.dart';
import 'speech_service.dart';

/// Persistent evaluation cache using SharedPreferences.
///
/// Cache key is derived from: stepId + targetPhrase + normalizedTranscript + cefrLevel
/// This means the same learner speaking the same phrase for the same step
/// gets a cached result across sessions — eliminating redundant API calls.
///
/// Eviction policy: LRU-approximated via timestamp. Max 500 entries.
/// Free conversation turns are never cached (non-deterministic).
class EvalCacheService {
  static const _prefix = 'eval_cache_v2_';
  static const _timestampPrefix = 'eval_ts_v2_';
  static const _maxEntries = 500;

  // In-memory layer for current session (avoids SharedPreferences overhead
  // on repeated attempts within the same session)
  static final Map<String, EvaluationResult> _sessionCache = {};

  // ─── Key Construction ──────────────────────────────────────────

  static String _buildKey(LessonStep step, String transcript, CEFRLevel level) {
    final normalized = SpeechService.normalize(transcript);
    final raw =
        '${step.id}|${step.targetPhrase ?? ""}|$normalized|${level.label}';
    // Base64 encodes to make it safe as a SharedPreferences key
    final encoded = base64Url.encode(utf8.encode(raw));
    return _prefix + encoded;
  }

  // ─── Public API ────────────────────────────────────────────────

  /// Returns a cached [EvaluationResult] if one exists, or null.
  /// Checks in-memory session cache first, then SharedPreferences.
  static Future<EvaluationResult?> get(
    LessonStep step,
    String transcript,
    CEFRLevel level,
  ) async {
    // Never cache free conversation — responses depend on conversation history
    if (step.type == StepType.freeConversation) return null;

    final key = _buildKey(step, transcript, level);

    // 1. Check session cache (instant)
    if (_sessionCache.containsKey(key)) {
      return _sessionCache[key];
    }

    // 2. Check persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;

      final result = EvaluationResult.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // Warm up session cache
      _sessionCache[key] = result;
      return result;
    } catch (_) {
      // Corrupt cache entry — treat as miss
      return null;
    }
  }

  /// Stores an [EvaluationResult] in both caches.
  /// Does NOT cache: empty results, very low scores (garbage audio),
  /// or free conversation turns.
  static Future<void> set(
    LessonStep step,
    String transcript,
    CEFRLevel level,
    EvaluationResult result,
  ) async {
    if (step.type == StepType.freeConversation) return;
    if (result.isEmpty) return;
    if (result.score < 0.15) return; // Garbage audio — do not cache

    final key = _buildKey(step, transcript, level);

    // Update session cache immediately (synchronous)
    _sessionCache[key] = result;

    // Persist asynchronously
    try {
      final prefs = await SharedPreferences.getInstance();

      // Evict oldest entries if at capacity
      await _evictIfNeeded(prefs);

      await prefs.setString(key, jsonEncode(result.toJson()));
      // Record timestamp for LRU eviction
      await prefs.setInt(
        _timestampPrefix + key,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Cache write failure is non-fatal — evaluation result is still valid
    }
  }

  /// Clears only the in-memory session cache (call on lesson restart).
  static void clearSessionCache() {
    _sessionCache.clear();
  }

  /// Clears ALL cached evaluations including persistent storage.
  /// Use only for debugging or account reset.
  static Future<void> clearAll() async {
    _sessionCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys()
          .where((k) => k.startsWith(_prefix) || k.startsWith(_timestampPrefix))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  // ─── Internal ──────────────────────────────────────────────────

  /// Evicts the oldest entry if cache is at maximum capacity.
  static Future<void> _evictIfNeeded(SharedPreferences prefs) async {
    final cacheKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(_prefix))
        .toList();

    if (cacheKeys.length < _maxEntries) return;

    // Find oldest entry by timestamp
    String? oldestKey;
    int oldestTime = DateTime.now().millisecondsSinceEpoch;

    for (final key in cacheKeys) {
      final ts = prefs.getInt(_timestampPrefix + key) ?? 0;
      if (ts < oldestTime) {
        oldestTime = ts;
        oldestKey = key;
      }
    }

    if (oldestKey != null) {
      await prefs.remove(oldestKey);
      await prefs.remove(_timestampPrefix + oldestKey);
    }
  }
}
