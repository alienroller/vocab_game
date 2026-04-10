import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/speaking_models.dart';

/// Text-to-speech service for playing target phrases.
///
/// Speed adjusts based on learner level:
/// A1 = slow, A2 = moderate, B1+ = normal.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  /// Initialize TTS engine.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // setSharedInstance is iOS-only; fails on web/desktop
      if (!kIsWeb) {
        await _tts.setSharedInstance(true);
      }
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('TTS init warning (non-critical): $e');
    }

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS error: $msg');
    });

    _isInitialized = true;
  }

  /// Speak a phrase in the given language at a speed appropriate
  /// for the learner's CEFR level.
  Future<void> speak({
    required String text,
    required String languageCode,
    CEFRLevel level = CEFRLevel.a1,
  }) async {
    if (!_isInitialized) await init();
    if (_isSpeaking) await stop();

    // Adjust speech rate based on proficiency
    final rate = _rateForLevel(level);
    await _tts.setSpeechRate(rate);
    await _tts.setLanguage(languageCode);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _isSpeaking = true;
    await _tts.speak(text);
  }

  /// Stop speaking.
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Speech rate based on learner level.
  /// Lower values = slower speech.
  double _rateForLevel(CEFRLevel level) {
    switch (level) {
      case CEFRLevel.a1:
        return 0.35; // Very slow for beginners
      case CEFRLevel.a2:
        return 0.42;
      case CEFRLevel.b1:
        return 0.5; // Normal
      case CEFRLevel.b2:
        return 0.55;
      case CEFRLevel.c1:
        return 0.6; // Near-native speed
    }
  }

  /// Get available languages.
  Future<List<String>> getLanguages() async {
    if (!_isInitialized) await init();
    final langs = await _tts.getLanguages;
    if (langs is List) {
      return langs.map((e) => e.toString()).toList();
    }
    return [];
  }
}
