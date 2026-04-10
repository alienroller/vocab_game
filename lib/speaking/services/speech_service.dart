import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text service wrapper.
///
/// Handles initialization, listening, transcript normalization,
/// and confidence-based retry logic.
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;

  /// Initialize the speech recognition engine.
  /// Returns true if speech recognition is available.
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: _onError,
        debugLogging: kDebugMode,
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('Speech error: ${error.errorMsg} (${error.permanent})');
    _isListening = false;
  }

  /// Start listening for speech.
  ///
  /// [languageCode] — BCP-47 code like "en-US", "uz-UZ"
  /// [onResult] — called with each recognition result (interim + final)
  /// [onSoundLevel] — called with microphone sound level (for waveform)
  Future<void> startListening({
    required String languageCode,
    required void Function(SpeechRecognitionResult) onResult,
    void Function(double)? onSoundLevel,
  }) async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) return;
    }

    if (_isListening) await stopListening();

    _isListening = true;
    await _speech.listen(
      onResult: (result) {
        onResult(result);
        if (result.finalResult) {
          _isListening = false;
        }
      },
      onSoundLevelChange: onSoundLevel,
      localeId: languageCode,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  /// Stop listening.
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Cancel listening without processing.
  Future<void> cancel() async {
    await _speech.cancel();
    _isListening = false;
  }

  /// Get list of available locales for speech recognition.
  Future<List<String>> getAvailableLocales() async {
    if (!_isInitialized) await init();
    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

  // ─── Transcript Normalization ──────────────────────────────────────

  /// Normalize a raw transcript before sending to Gemini.
  /// Strips fillers, punctuation, and normalizes whitespace.
  static String normalize(String raw) {
    return raw
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\b(um|uh|ah|hmm|er|like|you know)\b',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'[.,!?;:]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Check if a transcript result is usable or should trigger a retry.
  static TranscriptQuality assessQuality(
      String transcript, double confidence) {
    if (transcript.trim().length < 2) {
      return TranscriptQuality.empty;
    }
    if (confidence < 0.35) {
      return TranscriptQuality.lowConfidence;
    }
    return TranscriptQuality.good;
  }
}

enum TranscriptQuality {
  good,
  lowConfidence,
  empty,
}
