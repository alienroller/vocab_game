/// Centralised tuning constants for the game modes.
///
/// Keeping these in one place makes tuning easier and prevents
/// magic numbers being scattered throughout the codebase.
class GameConstants {
  const GameConstants._();

  // ─── Session sizing ───────────────────────────────────────────
  /// Default number of questions per quiz/flashcard/fill-blank session.
  static const int defaultSessionSize = 10;

  /// Number of distractor options shown for a multi-choice question.
  static const int multipleChoiceDistractors = 3;

  /// Fallback Uzbek words used when a user has < 4 total vocab entries.
  static const List<String> fallbackDistractors = <String>[
    'olma',
    'kitob',
    'mashina',
    'uy',
    'qalam',
    'maktab',
    'suv',
    'non',
  ];

  // ─── Timing ───────────────────────────────────────────────────
  /// Seconds allotted per question before speed bonus reaches 0.
  static const int questionTimerSeconds = 20;

  /// Delay after answer reveal before advancing to the next question.
  static const Duration answerRevealDelay = Duration(milliseconds: 1500);

  /// How long the floating "+XP" widget stays visible after a correct answer.
  static const Duration xpFloatDuration = Duration(milliseconds: 1200);

  // ─── Duel rewards ─────────────────────────────────────────────
  static const int duelWinnerXp = 50;
  static const int duelLoserXp = 20;
  static const int duelDrawXp = 30;

  // ─── Security / rate limiting ─────────────────────────────────
  /// Max consecutive failed PIN attempts before lockout.
  static const int maxPinAttempts = 3;

  /// Lockout duration after hitting [maxPinAttempts].
  /// Escalates: first lockout = 60s, each additional trigger doubles.
  static const Duration initialPinLockout = Duration(seconds: 60);
  static const Duration maxPinLockout = Duration(hours: 24);
}
