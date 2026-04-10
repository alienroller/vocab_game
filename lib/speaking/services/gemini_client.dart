import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/environment_constants.dart';
import '../models/speaking_models.dart';

/// Gemini API client for the speaking module.
///
/// Uses `responseMimeType: "application/json"` on evaluation calls
/// to guarantee valid JSON output — Gemini's killer feature for
/// structured evaluations.
class GeminiClient {
  GeminiClient._();

  static const _flashModel = 'gemini-2.0-flash';
  static const _proModel = 'gemini-1.5-pro';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Call Gemini API with the given prompt.
  ///
  /// [model] defaults to Flash for fast evaluations.
  /// [expectJSON] forces `responseMimeType: "application/json"`.
  /// Returns the raw text response.
  static Future<String> call({
    required String prompt,
    String model = _flashModel,
    bool expectJSON = true,
  }) async {
    final apiKey = EnvironmentConstants.geminiApiKey;
    if (apiKey.isEmpty) {
      throw GeminiUnavailableException('No Gemini API key configured');
    }

    final url = '$_baseUrl/$model:generateContent?key=$apiKey';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': expectJSON ? 0.1 : 0.7,
        'maxOutputTokens': expectJSON ? 512 : 1024,
        if (expectJSON) 'responseMimeType': 'application/json',
      },
    };

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('Gemini API error ${response.statusCode}: ${response.body}');
        throw GeminiUnavailableException(
            'API returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiUnavailableException('No candidates in response');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw GeminiUnavailableException('No parts in response');
      }

      return parts[0]['text'] as String;
    } catch (e) {
      if (e is GeminiUnavailableException) rethrow;
      debugPrint('Gemini call failed: $e');
      throw GeminiUnavailableException('Network error: $e');
    }
  }

  /// Call with retry — retries once on JSON parse failure.
  static Future<Map<String, dynamic>> callJSON({
    required String prompt,
    String model = _flashModel,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final raw = await call(prompt: prompt, model: model, expectJSON: true);
        return jsonDecode(raw) as Map<String, dynamic>;
      } on FormatException {
        if (attempt == 1) rethrow;
        debugPrint('JSON parse failed, retrying...');
      }
    }
    // Unreachable but Dart needs it
    throw GeminiUnavailableException('JSON parse failed after retries');
  }

  /// Call Gemini with conversation history (for free conversation).
  static Future<String> callConversation({
    required String systemInstruction,
    required List<ConversationTurn> history,
    required String prompt,
  }) async {
    final apiKey = EnvironmentConstants.geminiApiKey;
    if (apiKey.isEmpty) {
      throw GeminiUnavailableException('No Gemini API key configured');
    }

    final url = '$_baseUrl/$_proModel:generateContent?key=$apiKey';

    final contents = [
      ...history.map((t) => t.toJson()),
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ]
      }
    ];

    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7, // Higher temp for natural conversation
        'maxOutputTokens': 512,
      },
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw GeminiUnavailableException('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final rawText = data['candidates'][0]['content']['parts'][0]['text'];
      return rawText as String;
    } catch (e) {
      if (e is GeminiUnavailableException) rethrow;
      throw GeminiUnavailableException(e.toString());
    }
  }

  /// Use Pro model (for free conversation).
  static String get proModel => _proModel;

  /// Use Flash model (for evaluations).
  static String get flashModel => _flashModel;

  // ─── Fallback: Levenshtein Distance ───────────────────────────────

  /// Compute a 0.0–1.0 similarity score using Levenshtein distance.
  /// Used as a fallback when Gemini is unavailable.
  static double levenshteinScore(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    a = a.toLowerCase().trim();
    b = b.toLowerCase().trim();

    final n = a.length;
    final m = b.length;

    // Optimisation: if they're equal, perfect score
    if (a == b) return 1.0;

    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));

    for (var i = 0; i <= n; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= m; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    final maxLen = max(n, m);
    return 1.0 - (dp[n][m] / maxLen);
  }
}

/// Thrown when Gemini API is unavailable (no key, network error, etc.)
class GeminiUnavailableException implements Exception {
  final String message;
  GeminiUnavailableException(this.message);

  @override
  String toString() => 'GeminiUnavailableException: $message';
}
