import 'speaking_phrase.dart';

/// Sealed hierarchy of exercise payloads.
///
/// Each subtype carries exactly what its widget needs to render —
/// no `payload` blobs, no enum switches at render time.
sealed class SpeakingExercise {
  /// Stable identifier within a lesson (e.g. `greet_hello_ex2`).
  final String id;
  const SpeakingExercise({required this.id});
}

/// Passive listen — mascot plays the phrase once, no mic.
class ListenExercise extends SpeakingExercise {
  final SpeakingPhrase phrase;
  const ListenExercise({required super.id, required this.phrase});
}

/// Listen & repeat — the main loop. Mic on, auto-advance on pass.
class ListenRepeatExercise extends SpeakingExercise {
  final SpeakingPhrase phrase;
  const ListenRepeatExercise({required super.id, required this.phrase});
}

/// Word-by-word breakdown — tap chips to hear each word, then say it all.
class WordBreakdownExercise extends SpeakingExercise {
  final SpeakingPhrase phrase;
  const WordBreakdownExercise({required super.id, required this.phrase});
}

/// Recall — L1 prompt only, 3 hearts, no L2 text visible at first.
class RecallExercise extends SpeakingExercise {
  final SpeakingPhrase phrase;
  const RecallExercise({required super.id, required this.phrase});
}

/// Available exercise types, used for analytics + display only.
enum SpeakingExerciseKind {
  listen,
  listenRepeat,
  wordBreakdown,
  recall,
}

extension SpeakingExerciseKindExt on SpeakingExercise {
  SpeakingExerciseKind get kind => switch (this) {
        ListenExercise() => SpeakingExerciseKind.listen,
        ListenRepeatExercise() => SpeakingExerciseKind.listenRepeat,
        WordBreakdownExercise() => SpeakingExerciseKind.wordBreakdown,
        RecallExercise() => SpeakingExerciseKind.recall,
      };

  /// The underlying phrase this exercise is built around.
  SpeakingPhrase get phrase => switch (this) {
        ListenExercise(phrase: final p) => p,
        ListenRepeatExercise(phrase: final p) => p,
        WordBreakdownExercise(phrase: final p) => p,
        RecallExercise(phrase: final p) => p,
      };
}
