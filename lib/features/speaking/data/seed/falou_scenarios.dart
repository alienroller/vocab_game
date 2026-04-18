import '../../domain/models/speaking_exercise.dart';
import '../../domain/models/speaking_phrase.dart';
import '../../domain/models/speaking_scenario.dart';

/// Static Falou-style content for v1. Swap for Supabase-backed loader later.
///
/// Each scenario follows the same pedagogical arc:
///   for each phrase: listen → listen_repeat → word_breakdown
///   then: recall challenge on all phrases in shuffled order.
class FalouScenarios {
  FalouScenarios._();

  static List<SpeakingScenario> all = [
    _greetings,
    _classroom,
    _cafe,
  ];

  static SpeakingScenario? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ─── Greetings (A1) ────────────────────────────────────────────────

  static final _greetingsPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'greet_hello',
      l2Text: 'Hello, how are you?',
      l1Text: 'Salom, yaxshimisiz?',
      phonetic: 'he-loh, haw aar yoo?',
    ),
    const SpeakingPhrase(
      id: 'greet_name',
      l2Text: "What's your name?",
      l1Text: 'Ismingiz nima?',
      phonetic: 'wats yor naym?',
    ),
    const SpeakingPhrase(
      id: 'greet_from',
      l2Text: 'Where are you from?',
      l1Text: 'Qayerdansiz?',
      phonetic: 'wair aar yoo from?',
    ),
    const SpeakingPhrase(
      id: 'greet_nice',
      l2Text: 'Nice to meet you.',
      l1Text: 'Tanishganimdan xursandman.',
      phonetic: 'nays too meet yoo.',
    ),
  ];

  static SpeakingScenario get _greetings => SpeakingScenario(
        id: 'greetings',
        titleEn: 'Meeting a classmate',
        titleUz: 'Sinfdosh bilan tanishuv',
        contextEn: "You're meeting a new classmate. Introduce yourself.",
        contextUz: 'Yangi sinfdosh bilan tanishyapsiz. O‘zingizni tanishtiring.',
        emoji: '👋',
        estimatedMinutes: 4,
        cefr: FalouCefr.a1,
        xpReward: 40,
        phrases: _greetingsPhrases,
        exercises: _buildExercises('greet', _greetingsPhrases),
      );

  // ─── Classroom (A1) ────────────────────────────────────────────────

  static final _classroomPhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'class_repeat',
      l2Text: 'Can you repeat, please?',
      l1Text: 'Iltimos, qaytaring.',
      phonetic: 'kan yoo ree-peet, pleez?',
    ),
    const SpeakingPhrase(
      id: 'class_mean',
      l2Text: 'What does this word mean?',
      l1Text: 'Bu so‘z nimani anglatadi?',
      phonetic: 'wat duz this werd meen?',
    ),
    const SpeakingPhrase(
      id: 'class_spell',
      l2Text: 'How do you spell it?',
      l1Text: 'Uni qanday yoziladi?',
      phonetic: 'haw doo yoo spel it?',
    ),
    const SpeakingPhrase(
      id: 'class_slow',
      l2Text: 'Can you speak slowly?',
      l1Text: 'Sekinroq gapira olasizmi?',
      phonetic: 'kan yoo speek sloh-lee?',
    ),
  ];

  static SpeakingScenario get _classroom => SpeakingScenario(
        id: 'classroom',
        titleEn: 'Asking the teacher',
        titleUz: 'O‘qituvchidan so‘rash',
        contextEn:
            "You didn't catch what the teacher said. Ask politely for help.",
        contextUz: 'Siz o‘qituvchini eshitmadingiz. Iltimos bilan so‘rang.',
        emoji: '🎒',
        estimatedMinutes: 4,
        cefr: FalouCefr.a1,
        xpReward: 40,
        phrases: _classroomPhrases,
        exercises: _buildExercises('class', _classroomPhrases),
      );

  // ─── Café (A2) ─────────────────────────────────────────────────────

  static final _cafePhrases = <SpeakingPhrase>[
    const SpeakingPhrase(
      id: 'cafe_coffee',
      l2Text: 'A coffee, please.',
      l1Text: 'Bitta kofe, iltimos.',
      phonetic: 'uh kof-fee, pleez.',
    ),
    const SpeakingPhrase(
      id: 'cafe_how_much',
      l2Text: 'How much is it?',
      l1Text: 'Bu qancha turadi?',
      phonetic: 'haw much iz it?',
    ),
    const SpeakingPhrase(
      id: 'cafe_card',
      l2Text: 'Can I pay by card?',
      l1Text: 'Karta orqali to‘lasam bo‘ladimi?',
      phonetic: 'kan ay pay bay kard?',
    ),
    const SpeakingPhrase(
      id: 'cafe_thanks',
      l2Text: 'Thank you very much.',
      l1Text: 'Katta rahmat.',
      phonetic: 'thank yoo veh-ree much.',
    ),
  ];

  static SpeakingScenario get _cafe => SpeakingScenario(
        id: 'cafe',
        titleEn: 'Ordering at a café',
        titleUz: 'Kafeda buyurtma berish',
        contextEn: "You're at a café. Order a coffee and pay at the counter.",
        contextUz: 'Siz kafedasiz. Kofe buyurting va hisob-kitob qiling.',
        emoji: '☕',
        estimatedMinutes: 5,
        cefr: FalouCefr.a2,
        xpReward: 50,
        phrases: _cafePhrases,
        exercises: _buildExercises('cafe', _cafePhrases),
      );

  // ─── Exercise arc builder ──────────────────────────────────────────

  /// For each phrase: listen → listen_repeat → word_breakdown,
  /// followed by a recall exercise per phrase in original order.
  /// Keeping recall order stable (not shuffled) for v1 — shuffle
  /// can be introduced once content lands and variety matters more.
  static List<SpeakingExercise> _buildExercises(
    String prefix,
    List<SpeakingPhrase> phrases,
  ) {
    final out = <SpeakingExercise>[];
    for (var i = 0; i < phrases.length; i++) {
      final p = phrases[i];
      out.add(ListenExercise(id: '${prefix}_listen_$i', phrase: p));
      out.add(ListenRepeatExercise(id: '${prefix}_lr_$i', phrase: p));
      out.add(WordBreakdownExercise(id: '${prefix}_wb_$i', phrase: p));
    }
    for (var i = 0; i < phrases.length; i++) {
      out.add(RecallExercise(
        id: '${prefix}_recall_$i',
        phrase: phrases[i],
      ));
    }
    return out;
  }
}
