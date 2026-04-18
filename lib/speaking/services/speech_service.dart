import 'dart:async';

import 'package:flutter/foundation.dart';

import 'legacy_speech_engine.dart';
import 'offline_model_manager.dart';
import 'sherpa_speech_engine.dart';
import 'speaking_preferences.dart';
import 'speech_engine.dart';

export 'speech_engine.dart' show RecognitionResult;

/// Unified entry point for speech recognition.
///
/// Picks a concrete [SpeechEngine] based on user preference:
/// - Offline engine (Sherpa-ONNX Zipformer) when enabled AND model installed
/// - Legacy engine (`speech_to_text`) otherwise
///
/// If an initialization fails mid-session we transparently fall back to the
/// legacy engine so the user is never stranded.
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final LegacySpeechEngine _legacy = LegacySpeechEngine();
  SherpaSpeechEngine? _sherpa;
  SpeechEngine? _active;

  /// The engine currently handling requests (`legacy-stt` or `sherpa-onnx`).
  /// Returns null before [init] completes.
  String? get activeEngineId => _active?.id;

  bool get isListening => _active?.isListening ?? false;
  bool get isAvailable => _active?.isReady ?? false;

  /// Pick the best engine based on saved preferences. Safe to call repeatedly.
  Future<bool> init() async {
    final prefs = SpeakingPreferences();
    final wantOffline = await prefs.offlineEngineEnabled();

    if (wantOffline) {
      final installed = await OfflineModelManager()
          .isInstalled(OfflineModelManager.defaultEnglishAsr);
      if (installed) {
        _sherpa ??= SherpaSpeechEngine();
        if (await _sherpa!.init()) {
          _active = _sherpa;
          return true;
        }
        debugPrint(
            'SpeechService: Sherpa init failed, falling back to legacy.');
      } else {
        debugPrint(
            'SpeechService: offline model not installed, using legacy.');
      }
    }

    _active = _legacy;
    return _legacy.init();
  }

  /// Force a re-pick of the active engine. Call this after the user toggles
  /// the offline setting or completes a model download.
  Future<bool> reconfigure() async {
    await _active?.cancel();
    _active = null;
    return init();
  }

  Future<void> startListening({
    required String languageCode,
    required void Function(RecognitionResult) onResult,
    void Function(double)? onSoundLevel,
  }) async {
    if (_active == null) await init();
    await _active?.startListening(
      languageCode: languageCode,
      onResult: onResult,
      onSoundLevel: onSoundLevel,
    );
  }

  Future<void> stopListening() async => _active?.stopListening();

  Future<void> cancel() async => _active?.cancel();

  Future<void> dispose() async {
    await _legacy.dispose();
    await _sherpa?.dispose();
  }

  // ─── Transcript Normalization ──────────────────────────────────────

  /// Normalize a raw transcript before sending to the evaluator.
  /// Strips fillers, punctuation, and normalizes whitespace.
  static String normalize(String raw) {
    return raw
        .toLowerCase()
        .trim()
        .replaceAll(
            RegExp(r'\b(um|uh|ah|hmm|er|like|you know)\b',
                caseSensitive: false),
            '')
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
