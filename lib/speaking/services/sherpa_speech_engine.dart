import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'offline_model_manager.dart';
import 'speech_engine.dart';

/// Offline streaming speech recognition via Sherpa-ONNX Zipformer.
///
/// Call [init] once at app startup (cheap — just loads the FFI bindings).
/// On the first [startListening] call, we lazily build the recognizer from
/// model files on disk. If the model isn't installed yet, [init] fails and
/// callers should fall back to the legacy engine.
///
/// Audio capture uses the `record` package in PCM16 mono at 16 kHz; samples
/// are normalized to `[-1, 1]` floats and fed to the streaming recognizer.
class SherpaSpeechEngine implements SpeechEngine {
  final OfflineModelSpec modelSpec;
  SherpaSpeechEngine({
    this.modelSpec = OfflineModelManager.defaultEnglishAsr,
  });

  static bool _bindingsInitialized = false;

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;
  Timer? _decodeTimer;

  String _lastText = '';
  bool _listening = false;

  @override
  String get id => 'sherpa-onnx';

  @override
  bool get isReady => _recognizer != null;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> init() async {
    if (_recognizer != null) return true;
    try {
      if (!_bindingsInitialized) {
        sherpa.initBindings();
        _bindingsInitialized = true;
      }

      final paths = await OfflineModelManager().resolve(modelSpec);
      if (paths == null) {
        debugPrint('SherpaSpeechEngine: model not installed (${modelSpec.id})');
        return false;
      }

      final config = sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: paths.encoder,
            decoder: paths.decoder,
            joiner: paths.joiner,
          ),
          tokens: paths.tokens,
          numThreads: 1,
          debug: kDebugMode,
          provider: 'cpu',
          modelType: 'zipformer2',
        ),
        decodingMethod: 'greedy_search',
        enableEndpoint: true,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 20.0,
      );
      _recognizer = sherpa.OnlineRecognizer(config);
      return true;
    } catch (e, stack) {
      debugPrint('SherpaSpeechEngine init failed: $e\n$stack');
      await _disposeRecognizer();
      return false;
    }
  }

  @override
  Future<void> startListening({
    required String languageCode,
    required void Function(RecognitionResult) onResult,
    void Function(double)? onSoundLevel,
  }) async {
    if (_recognizer == null) {
      final ok = await init();
      if (!ok) return;
    }
    if (_listening) await stopListening();

    _lastText = '';
    _stream = _recognizer!.createStream();
    _recorder = AudioRecorder();

    if (!await _recorder!.hasPermission()) {
      debugPrint('SherpaSpeechEngine: microphone permission denied');
      await _teardownAudio();
      return;
    }

    final pcmStream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _listening = true;

    _audioSub = pcmStream.listen(
      (chunk) {
        if (!_listening || _stream == null || _recognizer == null) return;
        final samples = _pcm16ToFloat32(chunk);
        if (onSoundLevel != null) {
          onSoundLevel(_rms(samples));
        }
        _stream!.acceptWaveform(samples: samples, sampleRate: 16000);
      },
      onError: (Object e, StackTrace s) {
        debugPrint('SherpaSpeechEngine capture error: $e');
        _emitFinal(onResult);
      },
      onDone: () => _emitFinal(onResult),
      cancelOnError: false,
    );

    _decodeTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _decodeStep(onResult);
    });
  }

  void _decodeStep(void Function(RecognitionResult) onResult) {
    final recog = _recognizer;
    final stream = _stream;
    if (recog == null || stream == null || !_listening) return;

    while (recog.isReady(stream)) {
      recog.decode(stream);
    }
    final text = recog.getResult(stream).text.trim();
    final endpoint = recog.isEndpoint(stream);

    if (text != _lastText && text.isNotEmpty) {
      _lastText = text;
      onResult(RecognitionResult(
        transcript: text,
        confidence: 0.85,
        isFinal: false,
      ));
    }
    if (endpoint) {
      final finalText = text.isEmpty ? _lastText : text;
      onResult(RecognitionResult(
        transcript: finalText,
        confidence: 0.9,
        isFinal: true,
      ));
      _lastText = '';
      recog.reset(stream);
      _listening = false;
      _teardownAudio();
    }
  }

  void _emitFinal(void Function(RecognitionResult) onResult) {
    final recog = _recognizer;
    final stream = _stream;
    if (recog != null && stream != null) {
      stream.inputFinished();
      while (recog.isReady(stream)) {
        recog.decode(stream);
      }
      final text = recog.getResult(stream).text.trim();
      onResult(RecognitionResult(
        transcript: text,
        confidence: text.isEmpty ? 0.0 : 0.9,
        isFinal: true,
      ));
    }
    _listening = false;
    _teardownAudio();
  }

  @override
  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;
    final recog = _recognizer;
    final stream = _stream;
    if (recog != null && stream != null) {
      stream.inputFinished();
      while (recog.isReady(stream)) {
        recog.decode(stream);
      }
    }
    await _teardownAudio();
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    await _teardownAudio();
  }

  Future<void> _teardownAudio() async {
    _decodeTimer?.cancel();
    _decodeTimer = null;
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _recorder?.stop();
    } catch (_) {}
    await _recorder?.dispose();
    _recorder = null;
    _stream?.free();
    _stream = null;
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _disposeRecognizer();
  }

  Future<void> _disposeRecognizer() async {
    _recognizer?.free();
    _recognizer = null;
  }

  /// Convert little-endian PCM16 bytes to normalized mono float32 samples.
  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final count = bytes.length ~/ 2;
    final out = Float32List(count);
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i < count; i++) {
      final sample = bd.getInt16(i * 2, Endian.little);
      out[i] = sample / 32768.0;
    }
    return out;
  }

  /// Simple RMS → normalized `[0, 1]` level for a waveform UI.
  static double _rms(Float32List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    final rms = math.sqrt(sum / samples.length);
    return rms.clamp(0.0, 1.0);
  }
}
