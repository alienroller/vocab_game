import 'dart:convert';
import '../models/speaking_models.dart';

/// Implements Phase 7.2 of the Spec: Caching Common Evaluations.
///
/// Prevents the Gemini API from being hammered when users attempt
/// the exact same phrases repeatedly during a session, mitigating
/// QuotaExceeded errors.
class EvalCacheService {
  EvalCacheService._();

  // In-memory cache for the duration of the session
  static final Map<String, EvaluationResult> _cache = {};

  static String _generateKey(
      LessonStep step, String transcript, GeminiSessionContext ctx) {
    final rawKey =
        '${step.id}|${step.targetPhrase}|${transcript.trim().toLowerCase()}|${ctx.learnerLevel.label}';
    return base64Encode(utf8.encode(rawKey));
  }

  /// Attempts to retrieve a formally cached API response.
  static EvaluationResult? getCachedResult(
      LessonStep step, String transcript, GeminiSessionContext ctx) {
    // Dynamic open-ended conversations should not be cached
    if (step.type == StepType.freeConversation) return null;

    final key = _generateKey(step, transcript, ctx);
    return _cache[key];
  }

  /// Saves the evaluation outcome to memory.
  static void cacheResult(LessonStep step, String transcript,
      GeminiSessionContext ctx, EvaluationResult result) {
    if (step.type == StepType.freeConversation) return;

    // We only cache if it was a decent attempt (good or bad)
    // Don't cache garbage audio or empty hits so they get freshly evaluated if retried.
    if (result.isEmpty || (!result.passed && result.score < 0.2)) return;

    final key = _generateKey(step, transcript, ctx);
    _cache[key] = result;
  }
  
  /// Exposes cache clear functionality if needed across lesson sweeps.
  static void clearCache() {
    _cache.clear();
  }
}
