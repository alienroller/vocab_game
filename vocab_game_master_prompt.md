# 🧠 Master Prompt — vocab_game Flutter Feature Development
> Senior-level prompt for Claude Opus to implement new features into the `alienroller/vocab_game` Flutter project.

---

## 📌 Project Context

You are a **senior Flutter engineer** working on `vocab_game` — a cross-platform English ↔ Uzbek vocabulary learning app built with Flutter.

### Tech Stack
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart), SDK `^3.7.2` |
| State Management | `flutter_riverpod ^2.6.1` |
| Local Storage | `hive ^2.2.3` + `hive_flutter ^1.1.0` |
| UI | `google_fonts ^6.2.1` + Material Design 3 |
| IDs | `uuid ^4.5.1` |

### Existing Game Modes (in `lib/games/`)
- `flashcard_game.dart`
- `quiz_game.dart`
- `fill_blank_game.dart`
- `matching_game.dart`
- `memory_game.dart`

### Existing Screens (in `lib/screens/`)
- `home_screen.dart`
- `game_selection_screen.dart`
- `result_screen.dart`

### Existing Models (in `lib/models/`)
- `vocab.dart` — core vocabulary model

### Existing Widgets (in `lib/widgets/`)
- `custom_button.dart`

---

## 🎯 Your Mission

Implement the following features **one phase at a time**, matching the existing code style, architecture, and patterns precisely. Do not introduce new packages unless explicitly instructed. Always use Riverpod for state, Hive for persistence, and follow Flutter best practices.

---

## 🏗️ Phase 1 — New Game Modes

### 1A. Typing Challenge (`lib/games/typing_game.dart`)

**Goal:** User sees an Uzbek word and must type the English translation from memory. Tests active recall.

**Requirements:**
- Show the Uzbek word prominently at the top
- A `TextField` for the user to type the English answer
- On submit: fuzzy-match the answer (case-insensitive, trim whitespace, allow minor typos using Levenshtein distance ≤ 1)
- Show green ✅ / red ❌ feedback inline, then auto-advance after 1.5 seconds
- Track: correct count, wrong count, skipped count
- On completion: navigate to `result_screen.dart` passing the score
- Riverpod `StateNotifier` to manage game state (current word index, answers, timer)
- Reuse `CustomButton` widget for the Submit and Skip buttons

**Code contract — match this pattern from existing games:**
```dart
// Use this Riverpod pattern (match existing games)
final typingGameProvider = StateNotifierProvider.autoDispose<
    TypingGameNotifier, TypingGameState>((ref) {
  return TypingGameNotifier(ref.watch(vocabListProvider));
});
```

---

### 1B. Speed Round (`lib/games/speed_round_game.dart`)

**Goal:** 60-second time attack. Answer as many quiz questions as possible. Shows words-per-minute at the end.

**Requirements:**
- Countdown timer displayed as an animated arc or progress bar at the top
- 4 multiple-choice options per question (same as `quiz_game.dart` but auto-advance on correct answer with no delay)
- Wrong answer deducts 3 seconds from the timer
- Final result screen shows: total answered, accuracy %, words per minute, personal best (stored in Hive)
- Personal best persisted in a Hive box called `'speedRoundStats'`
- Timer must use `dart:async` `Timer.periodic` — cancel it properly in `dispose()`

---

### 1C. Sentence Builder (`lib/games/sentence_builder_game.dart`)

**Goal:** Show a sentence with a blank, user picks the correct word from 4 options. Teaches vocabulary in context.

**Requirements:**
- Vocabulary sentences stored as a new model: `lib/models/sentence.dart`
  ```dart
  class Sentence {
    final String id;
    final String templateEn;   // e.g. "The ___ is on the table."
    final String templateUz;   // Uzbek version
    final String answer;       // correct word
    final List<String> distractors; // 3 wrong options
  }
  ```
- Highlight the blank `___` in a distinct color (use `RichText`)
- Animate wrong answer options with a red shake animation
- Score bonus: +2 points for first try, +1 for second try, 0 for third
- Include at least 20 hardcoded seed sentences in `lib/data/sentences_data.dart`

---

## 📊 Phase 2 — Progress Tracking & Stats

### 2A. New Hive Models

Create `lib/models/session_result.dart`:
```dart
@HiveType(typeId: 2)
class SessionResult extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String gameType;   // 'typing', 'speed', 'sentence', etc.
  @HiveField(2) final DateTime playedAt;
  @HiveField(3) final int score;
  @HiveField(4) final int totalQuestions;
  @HiveField(5) final int durationSeconds;
}
```

Create `lib/models/word_progress.dart`:
```dart
@HiveType(typeId: 3)
class WordProgress extends HiveObject {
  @HiveField(0) final String vocabId;
  @HiveField(1) int correctCount;
  @HiveField(2) int wrongCount;
  @HiveField(3) DateTime lastSeen;
  // Computed: accuracy = correctCount / (correctCount + wrongCount)
  // Spaced repetition interval based on accuracy
}
```

Register both adapters in `main.dart`.

### 2B. Stats Screen (`lib/screens/stats_screen.dart`)

**Requirements:**
- Add `fl_chart: ^0.69.0` to `pubspec.yaml`
- Weekly bar chart: games played per day for the last 7 days
- Accuracy pie chart: correct vs wrong across all sessions
- "Weakest Words" list: top 10 words with lowest accuracy, tappable to start a Flashcard session with just those words
- Streak counter at the top (consecutive days with at least 1 session)
- Pull data from Hive via a Riverpod `FutureProvider`

### 2C. Spaced Repetition Logic (`lib/services/spaced_repetition_service.dart`)

Implement a simplified SM-2 algorithm:
- Words with accuracy < 50% appear 3x more often
- Words with accuracy 50–80% appear 2x more often  
- Words with accuracy > 80% appear at normal frequency
- Expose a `getNextWord(List<Vocab> all, List<WordProgress> progress)` method
- Use this in all game modes instead of `list.shuffle()`

---

## 🎨 Phase 3 — UI/UX Polish

### 3A. Fix All Deprecations

Replace every instance of `.withOpacity(x)` with `.withValues(alpha: x)` across:
- `lib/games/fill_blank_game.dart` (line 276)
- `lib/games/flashcard_game.dart` (lines 105, 111, 166, 171)
- `lib/games/matching_game.dart` (lines 141, 184)
- `lib/games/memory_game.dart` (lines 194, 203, 224)
- `lib/games/quiz_game.dart` (lines 187, 207)
- `lib/screens/game_selection_screen.dart` (line 97)
- `lib/screens/home_screen.dart` (line 98)
- `lib/screens/result_screen.dart` (line 39)
- `lib/widgets/custom_button.dart` (line 32)

Also fix:
- Remove unused import in `lib/games/memory_game.dart` (line 4)
- Fix unnecessary brace in `lib/screens/game_selection_screen.dart` (line 93)
- Fix `test/widget_test.dart` — replace `MyApp` with the correct root widget class name

### 3B. Dark Mode

- Add a `themeModeProvider` in `lib/providers/theme_provider.dart`:
  ```dart
  final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
  ```
- Persist theme choice in Hive box `'settings'`
- Add a toggle in the home screen's AppBar

### 3C. Streak Widget (`lib/widgets/streak_widget.dart`)

- Show a flame 🔥 icon + streak count on the home screen
- Stored in Hive, increments if user plays at least one game per calendar day
- Animate the flame on streak increase using `AnimationController`

### 3D. Page Transitions

Wrap all `Navigator.push` calls with a custom `PageRouteBuilder`:
```dart
// lib/utils/page_transitions.dart
Route slideUpRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, animation, __, child) =>
    SlideTransition(
      position: Tween(begin: Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
);
```

---

## ☁️ Phase 4 — User Accounts & Cloud Sync

### 4A. Add Firebase

Add to `pubspec.yaml`:
```yaml
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4
google_sign_in: ^6.2.2
```

Run `flutterfire configure` for Android, iOS, and Web targets.

### 4B. Auth (`lib/services/auth_service.dart`)

- Email/password + Google Sign-In
- Wrap `MaterialApp` with a `StreamBuilder` on `FirebaseAuth.instance.authStateChanges()`
- Show `LoginScreen` if unauthenticated, `HomeScreen` if authenticated
- Store `userId` in a Riverpod `Provider` for use throughout the app

### 4C. Sync Service (`lib/services/sync_service.dart`)

- On app foreground: pull latest `WordProgress` and `SessionResult` from Firestore
- On game completion: write new `SessionResult` to both Hive (local) and Firestore (remote)
- Conflict resolution: last-write-wins using `DateTime` timestamps
- Firestore structure:
  ```
  users/{userId}/sessions/{sessionId}
  users/{userId}/wordProgress/{vocabId}
  users/{userId}/customVocab/{vocabId}
  ```

---

## ✅ General Code Standards

Follow these rules in **every file you produce**:

1. **Riverpod everywhere** — no `setState` in business logic, only in purely local UI state
2. **Const constructors** — use `const` wherever possible
3. **Named parameters** — all widget constructors use named params with `required` where appropriate
4. **No magic numbers** — extract to constants at the top of the file or in `lib/utils/constants.dart`
5. **Error handling** — wrap all Hive and Firestore calls in try/catch with user-facing error messages via `SnackBar`
6. **File naming** — snake_case for files, PascalCase for classes
7. **Dispose properly** — cancel all `Timer`, `AnimationController`, and stream subscriptions in `dispose()`
8. **No hardcoded colors** — use `Theme.of(context).colorScheme.*` tokens
9. **Accessibility** — add `Semantics` wrappers to all interactive game elements
10. **Comments** — add a doc comment (`///`) to every public class and method

---

## 📋 How to Use This Prompt with Claude Opus

For each task, paste this full prompt **plus** the relevant existing file(s) and say:

> *"Using the project context and standards above, implement [specific task, e.g. '1A: Typing Challenge']. Here is my existing `quiz_game.dart` for reference: [paste code]"*

Opus will match your architecture exactly. Work phase by phase — don't attempt all 4 phases in one session.

---

*Generated for alienroller/vocab_game · March 2026*
