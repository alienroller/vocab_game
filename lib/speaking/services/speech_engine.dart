import 'dart:async';

/// Unified recognition result used by any speech engine.
///
/// The legacy `speech_to_text` package and Sherpa-ONNX produce different
/// native types; this class is the only shape the rest of the app sees.
class RecognitionResult {
  final String transcript;
  final double confidence;
  final bool isFinal;

  const RecognitionResult({
    required this.transcript,
    required this.confidence,
    required this.isFinal,
  });
}

/// Engine-agnostic speech recognition contract.
///
/// Implementations: [LegacySpeechEngine] (online via `speech_to_text`),
/// [SherpaSpeechEngine] (offline Zipformer).
abstract class SpeechEngine {
  /// Human-readable identifier for logs/settings UI.
  String get id;

  /// Whether this engine's prerequisites are ready (permissions, models).
  bool get isReady;

  /// Whether the engine is currently listening.
  bool get isListening;

  /// Prepare the engine. Returns true if speech recognition is available.
  Future<bool> init();

  /// Start listening for speech.
  ///
  /// [languageCode] is a BCP-47 tag (e.g. `en-US`). Legacy engines honor it;
  /// Sherpa uses whatever language the loaded model was trained on.
  Future<void> startListening({
    required String languageCode,
    required void Function(RecognitionResult) onResult,
    void Function(double)? onSoundLevel,
  });

  /// Stop listening and deliver a final result if one is pending.
  Future<void> stopListening();

  /// Cancel without emitting a final result.
  Future<void> cancel();

  /// Release resources. Called on module teardown.
  Future<void> dispose();
}
