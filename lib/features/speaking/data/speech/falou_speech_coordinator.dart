import '../../../../speaking/models/speaking_models.dart' as legacy;
import '../../../../speaking/services/speech_service.dart';
import '../../../../speaking/services/tts_service.dart';
import '../../domain/models/speaking_scenario.dart';

/// Thin adapter that lets the Falou module talk to the existing
/// [SpeechService] + [TtsService] singletons without dragging their
/// legacy types into our presentation layer.
///
/// Exercise widgets call this; they never touch the singletons directly.
/// That way if we swap STT engines again (e.g. Groq Whisper HTTP), we
/// only edit one file.
class FalouSpeechCoordinator {
  FalouSpeechCoordinator({
    SpeechService? speech,
    TtsService? tts,
  })  : _speech = speech ?? SpeechService(),
        _tts = tts ?? TtsService();

  final SpeechService _speech;
  final TtsService _tts;

  /// Lazily initialize both services. Safe to call many times.
  Future<void> ensureReady() async {
    await _tts.init();
    if (!_speech.isAvailable) {
      await _speech.init();
    }
  }

  bool get isListening => _speech.isListening;
  bool get isSpeaking => _tts.isSpeaking;

  /// Speak the full phrase at a level-appropriate rate.
  Future<void> playPhrase(
    String l2Text, {
    FalouCefr cefr = FalouCefr.a1,
    String languageCode = 'en-US',
  }) async {
    await ensureReady();
    await _tts.speak(
      text: l2Text,
      languageCode: languageCode,
      level: _mapCefr(cefr),
    );
  }

  /// Speak a single word, always at the slowest rate. Used by word chips
  /// so beginners hear the shape clearly.
  Future<void> playWord(
    String word, {
    String languageCode = 'en-US',
  }) async {
    await ensureReady();
    await _tts.speak(
      text: word,
      languageCode: languageCode,
      level: legacy.CEFRLevel.a1,
    );
  }

  Future<void> stopSpeaking() => _tts.stop();

  /// Start listening. The caller gets a single final [RecognitionResult]
  /// through [onResult] — streaming partials are swallowed to keep
  /// exercise widgets simple.
  Future<void> startListening({
    required String languageCode,
    required void Function(RecognitionResult) onFinal,
    void Function(double)? onSoundLevel,
  }) async {
    await ensureReady();
    await _speech.startListening(
      languageCode: languageCode,
      onSoundLevel: onSoundLevel,
      onResult: (r) {
        if (r.isFinal) onFinal(r);
      },
    );
  }

  Future<void> stopListening() => _speech.stopListening();

  Future<void> cancelListening() => _speech.cancel();

  static legacy.CEFRLevel _mapCefr(FalouCefr c) => switch (c) {
        FalouCefr.a1 => legacy.CEFRLevel.a1,
        FalouCefr.a2 => legacy.CEFRLevel.a2,
        FalouCefr.b1 => legacy.CEFRLevel.b1,
        FalouCefr.b2 => legacy.CEFRLevel.b2,
        FalouCefr.c1 => legacy.CEFRLevel.c1,
      };
}
