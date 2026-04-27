import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_engine.dart';

/// Default engine backed by the `speech_to_text` package.
///
/// Uses the platform's built-in recognizer, which on most devices routes
/// audio to Google/Apple cloud services — hence the network-dependent lag.
class LegacySpeechEngine implements SpeechEngine {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _listening = false;

  @override
  String get id => 'legacy-stt';

  @override
  bool get isReady => _initialized;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> init() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: _onError,
        debugLogging: kDebugMode,
      );
    } catch (e) {
      debugPrint('LegacySpeechEngine init failed: $e');
      _initialized = false;
    }
    return _initialized;
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('Speech error: ${error.errorMsg} (${error.permanent})');
    _listening = false;
  }

  @override
  Future<void> startListening({
    required String languageCode,
    required void Function(RecognitionResult) onResult,
    void Function(double)? onSoundLevel,
  }) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return;
    }
    if (_listening) await stopListening();

    _listening = true;
    await _speech.listen(
      onResult: (result) {
        onResult(RecognitionResult(
          transcript: result.recognizedWords,
          confidence: result.hasConfidenceRating ? result.confidence : 0.5,
          isFinal: result.finalResult,
        ));
        if (result.finalResult) _listening = false;
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

  @override
  Future<void> stopListening() async {
    if (_listening) {
      await _speech.stop();
      _listening = false;
    }
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _listening = false;
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}
