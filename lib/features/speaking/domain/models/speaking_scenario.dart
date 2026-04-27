import 'speaking_exercise.dart';
import 'speaking_phrase.dart';

/// CEFR difficulty bucket for scenario filtering.
enum FalouCefr { a1, a2, b1, b2, c1 }

extension FalouCefrExt on FalouCefr {
  String get label => switch (this) {
        FalouCefr.a1 => 'A1',
        FalouCefr.a2 => 'A2',
        FalouCefr.b1 => 'B1',
        FalouCefr.b2 => 'B2',
        FalouCefr.c1 => 'C1',
      };
}

/// Top-level unit: one scenario = one situation (café, airport, classroom).
///
/// For v1 we pack the whole lesson into the scenario — no separate
/// `SpeakingLesson` row. If content ever splits (multiple lessons per
/// scenario) the model can grow without breaking screens.
class SpeakingScenario {
  /// Stable slug (e.g. `greetings`). Used in GoRouter path params.
  final String id;

  /// L2 title (English), e.g. "Meeting a classmate".
  final String titleEn;

  /// L1 title (Uzbek), e.g. "Sinfdosh bilan tanishuv".
  final String titleUz;

  /// One-sentence context shown on the intro screen.
  final String contextEn;
  final String contextUz;

  /// Emoji fallback until we have proper illustrations.
  final String emoji;

  /// Approx time to completion. Used in the scenario list subtitle.
  final int estimatedMinutes;

  /// CEFR difficulty for filtering/sorting.
  final FalouCefr cefr;

  /// Base XP on completion, before perfect-phrase bonuses.
  final int xpReward;

  /// All phrases used by this scenario (referenced by exercises).
  final List<SpeakingPhrase> phrases;

  /// Ordered exercise sequence the runner plays back.
  final List<SpeakingExercise> exercises;

  const SpeakingScenario({
    required this.id,
    required this.titleEn,
    required this.titleUz,
    required this.contextEn,
    required this.contextUz,
    required this.emoji,
    required this.estimatedMinutes,
    required this.cefr,
    required this.xpReward,
    required this.phrases,
    required this.exercises,
  });

  int get totalExercises => exercises.length;
}
