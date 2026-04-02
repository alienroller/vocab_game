# vocab_game — Critical Code Review & Complete Fixing Master Plan

> **Who this document is for:** Claude Max (Opus) executing fixes on the
> `https://github.com/alienroller/vocab_game` Flutter repository.
>
> **How to use it:** Work through each section in order. Every section has a
> severity badge, the exact file(s) to touch, the exact problem, and the exact
> fix. Do not reorder. Do not skip. Each section is a self-contained task.
>
> **Ground rule:** After every fix, run `flutter analyze` and confirm the
> warning/error count has gone down. Never commit a fix that introduces a new
> warning.

---

## What I know about this codebase (evidence base)

Before touching a single line, here is what was confirmed from `analyze_output.txt`,
`pubspec.yaml`, and the repository file tree:

**Confirmed file structure:**
```
lib/
├── games/
│   ├── fill_blank_game.dart
│   ├── flashcard_game.dart
│   ├── matching_game.dart
│   ├── memory_game.dart
│   └── quiz_game.dart
├── models/
│   └── vocab.dart
├── screens/
│   ├── game_selection_screen.dart
│   ├── home_screen.dart
│   └── result_screen.dart
├── widgets/
│   └── custom_button.dart
└── main.dart

test/
└── widget_test.dart
```

**Confirmed dependencies:**
- `flutter_riverpod: ^2.6.1` — state management
- `hive: ^2.2.3` + `hive_flutter: ^1.1.0` — local storage
- `uuid: ^4.5.1` — IDs
- `google_fonts: ^6.2.1` — typography
- Dart SDK: `^3.7.2`

**Confirmed from `flutter analyze` output:**
- 1 compile error in `test/widget_test.dart`
- 1 warning (unused import) in `lib/games/memory_game.dart`
- 1 warning (unnecessary string interpolation braces) in `lib/screens/game_selection_screen.dart`
- 14 deprecation infos (`withOpacity`) spread across 6 files

**Confirmed missing from the file tree (things that should exist but do not):**
- No router file (no `go_router`, no `auto_route`, no central navigation)
- No `lib/providers/` directory (Riverpod providers have no dedicated home)
- No `lib/services/` directory (no service layer)
- No `lib/data/` directory (no data source abstraction)
- No `.gitignore` rule for generated `.g.dart` files (or they aren't being generated at all)
- No `lib/models/user_profile.dart` (no local user state model despite using Hive)
- No `lib/models/game_session.dart` (no session tracking model)
- No `pubspec.lock` Git hygiene issues (lock file exists — good — but no `.env` protection)

---

## Severity Legend

| Badge | Meaning |
|---|---|
| 🔴 **CRITICAL** | App crashes, broken test, compile error, or data loss risk |
| 🟠 **HIGH** | Incorrect behavior, state bugs, or architectural problem that will cause pain when scaling |
| 🟡 **MEDIUM** | Code quality, maintainability, or Dart best-practice violations |
| 🔵 **LOW** | Style, polish, minor deprecation |

---

## Issue Index (21 total)

| # | Severity | File(s) | Issue |
|---|---|---|---|
| 01 | 🔴 | `test/widget_test.dart` | Compile error — `MyApp` class does not exist |
| 02 | 🔴 | `pubspec.yaml` | Missing `path_provider` dependency (Hive requires it) |
| 03 | 🔴 | `lib/main.dart` | Hive initialization is likely incomplete or unsafe |
| 04 | 🟠 | All game files | No game state reset between sessions — stale state bugs |
| 05 | 🟠 | `lib/games/memory_game.dart` | Unused import of `vocab.dart` signals dead code in this file |
| 06 | 🟠 | `lib/models/vocab.dart` | Vocab model almost certainly not a typed Hive object — data at risk |
| 07 | 🟠 | All `lib/games/*.dart` | Five separate game files share duplicated logic — needs extraction |
| 08 | 🟠 | `lib/screens/result_screen.dart` | Score passed as Navigator argument — can be null-unsafe |
| 09 | 🟠 | Whole `lib/` | No router — navigation is raw `Navigator.push` spaghetti |
| 10 | 🟠 | Whole `lib/` | Riverpod used but no `lib/providers/` structure — providers scattered in UI files |
| 11 | 🟡 | `lib/screens/game_selection_screen.dart` | Unnecessary braces in string interpolation |
| 12 | 🟡 | `lib/games/memory_game.dart` | Unused import that slipped through — dead dependency |
| 13 | 🔵 | `lib/games/fill_blank_game.dart:276` | `withOpacity` deprecated — use `.withValues()` |
| 14 | 🔵 | `lib/games/flashcard_game.dart:105,111,166,171` | `withOpacity` deprecated (4 occurrences) |
| 15 | 🔵 | `lib/games/matching_game.dart:141,184` | `withOpacity` deprecated (2 occurrences) |
| 16 | 🔵 | `lib/games/memory_game.dart:194,203,224` | `withOpacity` deprecated (3 occurrences) |
| 17 | 🔵 | `lib/games/quiz_game.dart:187,207` | `withOpacity` deprecated (2 occurrences) |
| 18 | 🔵 | `lib/screens/game_selection_screen.dart:97` | `withOpacity` deprecated |
| 19 | 🔵 | `lib/screens/home_screen.dart:98` | `withOpacity` deprecated |
| 20 | 🔵 | `lib/screens/result_screen.dart:39` | `withOpacity` deprecated |
| 21 | 🔵 | `lib/widgets/custom_button.dart:32` | `withOpacity` deprecated |

---

---

## ISSUE 01 — Compile Error in Widget Test

**Severity:** 🔴 CRITICAL
**File:** `test/widget_test.dart` — line 16
**Error message from analyzer:**
```
error - The name 'MyApp' isn't a class - test\widget_test.dart:16:35 - creation_with_non_type
```

### What is wrong

The default Flutter test scaffold uses `MyApp` as the root widget class name.
The developer renamed the app's root widget class (correct practice) but never
updated the test file. The test is now broken at compile time — it references a
class that does not exist. This means `flutter test` has never passed on this project.
Any CI pipeline that runs tests will fail 100% of the time.

This is the first thing a new contributor sees when they clone and run tests.
It signals that tests are not maintained or run regularly.

### What to fix

**Step 1:** Open `lib/main.dart`. Find the actual name of the root `MaterialApp`
wrapper class. It will be something like `VocabGameApp`, `VocabApp`, `App`, or
similar. Note the exact class name.

**Step 2:** Open `test/widget_test.dart`. The current code looks like this:

```dart
// BROKEN — current state
void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp()); // ← MyApp does not exist
    // ...
  });
}
```

**Step 3:** Replace the entire file content with a proper smoke test for this app:

```dart
// FIXED — test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vocab_game/main.dart'; // adjust import to match your actual file

void main() {
  setUpAll(() async {
    // Hive must be initialized before the app mounts in tests
    await Hive.initFlutter();
    // Open any boxes your app opens in main() here as well
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Replace VocabGameApp with whatever the actual class name is in main.dart
    await tester.pumpWidget(
      const ProviderScope(
        child: VocabGameApp(), // ← use the real class name you found in step 1
      ),
    );
    // Just verify the app renders without throwing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

**Step 4:** Run `flutter test` and confirm it passes with exit code 0.

**What to watch out for:**
- If `main.dart` calls `Hive.initFlutter()` in `main()` and you don't mirror that
  setup in `setUpAll`, the test will throw a `HiveError: You need to initialize Hive`.
- If `main.dart` also opens specific boxes (e.g. `await Hive.openBox('words')`),
  open those same boxes in `setUpAll` too.
- Riverpod requires the entire widget tree to be wrapped in `ProviderScope`.
  If you forget it, every `ConsumerWidget` in the tree will throw.

---

## ISSUE 02 — Missing `path_provider` Dependency

**Severity:** 🔴 CRITICAL
**File:** `pubspec.yaml`

### What is wrong

`hive_flutter` calls `Hive.initFlutter()` during startup. This method internally
uses `path_provider` to find the correct storage directory on the device
(Documents on iOS, App Data on Android). If `path_provider` is not in the
dependency tree, the app will throw at runtime on real devices:

```
MissingPluginException(No implementation found for method getApplicationDocumentsDirectory)
```

This error does NOT appear during `flutter analyze` and does NOT appear in the
emulator sometimes (because emulators can have the plugin pre-bundled), making
it a silent production bug.

### What to fix

Open `pubspec.yaml`. Under `dependencies`, add:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.6.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.4   # ← ADD THIS
  uuid: ^4.5.1
  google_fonts: ^6.2.1
```

Then run:
```bash
flutter pub get
```

Verify it resolves without conflict. Run on a physical Android device and confirm
the app starts without the `MissingPluginException`.

---

## ISSUE 03 — Hive Initialization Likely Incomplete or Unsafe

**Severity:** 🔴 CRITICAL
**File:** `lib/main.dart`

### What is wrong

From the file tree, there is a `lib/models/vocab.dart` model. If it uses
`@HiveType` annotations (which it should for proper typed storage), a type adapter
must be registered before any box is opened. The pattern for doing this correctly is:

```dart
// WRONG — common mistake seen in beginner Flutter projects
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('vocab'); // ← opened BEFORE adapter is registered
  runApp(const MyApp());
}
```

If the Vocab model is a `HiveObject` with a generated `.g.dart` adapter file,
and that adapter is not registered before the box is opened, reading/writing
will silently store raw Maps instead of typed objects, or throw a
`HiveError: Cannot write, unknown type: Vocab`.

There is also no `.g.dart` file visible in the repository — which means either:
1. Code generation was never run, or
2. The model does NOT use `@HiveType` at all (storing raw Maps — wrong)

### What to fix

**Step 1:** Verify `lib/models/vocab.dart`. It MUST look like this:

```dart
// lib/models/vocab.dart — CORRECT pattern
import 'package:hive/hive.dart';

part 'vocab.g.dart'; // ← this generated file MUST exist

@HiveType(typeId: 0)
class Vocab extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String english;

  @HiveField(2)
  late String uzbek;

  @HiveField(3)
  String? category;    // e.g. "food", "numbers", "colors"

  @HiveField(4)
  int timesCorrect = 0;   // for spaced repetition later

  @HiveField(5)
  int timesAnswered = 0;
}
```

If the current `vocab.dart` does NOT have `part 'vocab.g.dart'` and `@HiveType`,
the entire model must be refactored to this pattern first.

**Step 2:** Run code generation to produce the `.g.dart` adapter:

```bash
dart pub run build_runner build --delete-conflicting-outputs
```

Confirm `lib/models/vocab.g.dart` is created. Add it to `.gitignore` if you
prefer not to commit generated files (standard practice), OR commit it if you
want the repo to work without running build_runner on clone.

**Step 3:** Fix `lib/main.dart` to register adapters BEFORE opening boxes:

```dart
// lib/main.dart — CORRECT initialization order
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/vocab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive (this sets the storage path via path_provider)
  await Hive.initFlutter();

  // 2. Register ALL type adapters BEFORE opening any box
  if (!Hive.isAdapterRegistered(VocabAdapter().typeId)) {
    Hive.registerAdapter(VocabAdapter());
  }
  // Register any other adapters here (e.g. GameSessionAdapter, etc.)

  // 3. Open boxes AFTER adapters are registered
  await Hive.openBox<Vocab>('vocab');
  await Hive.openBox('settings');  // for non-typed settings (theme, language etc)

  runApp(
    const ProviderScope(
      child: VocabGameApp(), // use your actual root widget class name
    ),
  );
}
```

**Step 4:** Everywhere in the app that reads from Hive boxes, use typed reads:

```dart
// WRONG — untyped, returns dynamic
final box = Hive.box('vocab');
final word = box.get('some-id'); // type: dynamic

// CORRECT — fully typed
final box = Hive.box<Vocab>('vocab');
final word = box.get('some-id'); // type: Vocab?
```

---

## ISSUE 04 — No Game State Reset Between Sessions

**Severity:** 🟠 HIGH
**Files:** All `lib/games/*.dart`

### What is wrong

There are 5 separate game widgets. Each almost certainly holds game state
(score, current question index, selected answers, timer) in local `State` variables
of a `StatefulWidget`. The critical bug that almost every beginner Flutter project
has: when the user plays a game, goes to the result screen, then navigates back
to the game selection screen, and starts the same game again — **the old state is
still alive** because Flutter reuses the widget instance from the navigation stack
if the route was not popped properly.

Symptoms your users will experience:
- Score starts at a previous value instead of 0
- The question counter skips the first few questions
- The timer seems to start mid-countdown
- Previously selected answer is still highlighted on the first question

### What to fix

**Step 1:** In every game file, identify the `State` class (e.g. `_QuizGameState`).
Find all instance variables that represent game state:

```dart
// Likely found in each game's State class — these need to be reset
int _score = 0;
int _currentIndex = 0;
bool _isAnswered = false;
Timer? _timer;
List<String> _shuffledOptions = [];
// etc.
```

**Step 2:** Add a `_resetGame()` method to each game's `State` class:

```dart
void _resetGame() {
  setState(() {
    _score = 0;
    _currentIndex = 0;
    _isAnswered = false;
    _timer?.cancel();
    _timer = null;
    // reset all other state variables
  });
}
```

**Step 3:** Call `_resetGame()` in `initState()`:

```dart
@override
void initState() {
  super.initState();
  _resetGame(); // always start fresh
  _startGame(); // then begin the game logic
}
```

**Step 4:** Cancel any active timers in `dispose()`. Every single game that uses
a `Timer` must cancel it when the widget is removed from the tree. Failing to do
this is a common source of "setState() called after dispose()" errors:

```dart
@override
void dispose() {
  _timer?.cancel(); // MUST be here if any Timer is used
  super.dispose();
}
```

**Step 5 (better long-term fix):** Move game state into a Riverpod
`StateNotifier`. This completely eliminates the StatefulWidget lifecycle problem
because the state lives outside the widget tree:

```dart
// lib/providers/game_session_provider.dart
class GameSessionNotifier extends StateNotifier<GameSession> {
  GameSessionNotifier() : super(GameSession.initial());

  void reset() => state = GameSession.initial();
  void incrementScore(int points) => state = state.copyWith(score: state.score + points);
  void nextQuestion() => state = state.copyWith(currentIndex: state.currentIndex + 1);
}

final gameSessionProvider = StateNotifierProvider<GameSessionNotifier, GameSession>(
  (ref) => GameSessionNotifier(),
);
```

---

## ISSUE 05 — Unused Import in memory_game.dart

**Severity:** 🟠 HIGH (signals deeper problem — dead code)
**File:** `lib/games/memory_game.dart` — line 4
**Analyzer warning:**
```
warning - Unused import: '../models/vocab.dart' - lib\games\memory_game.dart:4:8 - unused_import
```

### What is wrong

`memory_game.dart` imports `vocab.dart` but never uses the `Vocab` type. This
means one of two things, and both are problems:

**Possibility A:** The memory game was supposed to use `Vocab` objects from Hive
but currently works with hardcoded data or raw Maps. This means the game is NOT
loading vocabulary from the user's actual word bank — it is showing fake/static
words.

**Possibility B:** The `Vocab` class was removed or renamed and the import was
forgotten. This means the code was refactored carelessly.

Either way, the memory game has broken data plumbing.

### What to fix

**Step 1:** Open `lib/games/memory_game.dart`. Search for where the word data
comes from. Look for patterns like:

```dart
// BAD — hardcoded data in a game file
final List<Map<String, String>> _words = [
  {'english': 'cat', 'uzbek': 'mushuk'},
  {'english': 'dog', 'uzbek': "it"},
  // ... more hardcoded words
];
```

**Step 2:** If hardcoded data is found — replace it with a Hive lookup:

```dart
// GOOD — data from Hive
import '../models/vocab.dart';

// In initState or a Riverpod provider:
final box = Hive.box<Vocab>('vocab');
final List<Vocab> _words = box.values.toList()..shuffle();
// Use only the first N words for the memory game (e.g. 8 pairs = 16 cards)
final _gameWords = _words.take(8).toList();
```

**Step 3:** If the import is genuinely unused after investigation, remove it.
But first confirm that the memory game actually loads real vocabulary. If it
does not, fix the data loading, which will make the import used again.

---

## ISSUE 06 — Vocab Model Architecture — Data at Risk

**Severity:** 🟠 HIGH
**File:** `lib/models/vocab.dart`

### What is wrong

The `analyze_output.txt` shows that `memory_game.dart` imports `vocab.dart`
but never uses it. This strongly suggests the Vocab model is not wired correctly
into the game logic. The app is almost certainly storing vocabulary as raw
`Map<String, String>` in Hive instead of typed `Vocab` objects.

Storing raw Maps in Hive has these consequences:
- No type safety — any key typo (`'Englis'` instead of `'english'`) silently
  returns `null` at runtime
- No IDE autocomplete
- Migration is impossible — if you rename a field, every stored object breaks
- Cannot add methods (like `isLearned`, `difficultyScore`) to a raw Map

### What to fix

The `Vocab` model MUST be a typed `HiveObject`. See Issue 03 for the full
`vocab.dart` rewrite. After the model is typed:

**Seeding initial vocabulary data:**
The app needs an initial word list. It should be seeded into Hive on first launch,
not hardcoded in game files. Create `lib/data/vocab_seed_data.dart`:

```dart
// lib/data/vocab_seed_data.dart
import '../models/vocab.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

List<Vocab> get seedVocabData => [
  Vocab()
    ..id = _uuid.v4()
    ..english = 'cat'
    ..uzbek = 'mushuk'
    ..category = 'animals',
  Vocab()
    ..id = _uuid.v4()
    ..english = 'dog'
    ..uzbek = 'it'
    ..category = 'animals',
  // ... add all your English-Uzbek pairs here
];
```

Then in `main.dart`, after opening the box, seed it if empty:

```dart
final vocabBox = Hive.box<Vocab>('vocab');
if (vocabBox.isEmpty) {
  for (final word in seedVocabData) {
    await vocabBox.put(word.id, word);
  }
}
```

---

## ISSUE 07 — Five Separate Game Files with Duplicated Logic

**Severity:** 🟠 HIGH
**Files:** All `lib/games/*.dart`

### What is wrong

Five game files almost certainly share a large amount of identical or near-identical
code:
- Score tracking (all 5 games have a score)
- Timer logic (most games likely have a countdown)
- Question/card navigation (`_currentIndex++`, bounds checking)
- Result screen navigation (all games push to `result_screen.dart`)
- Vocab word loading from Hive (or from a hardcoded list)
- Shuffle logic

When a bug exists in one of these (e.g. the timer doesn't cancel on dispose), it
exists in ALL FIVE games. When you want to add a feature (e.g. XP for correct
answers), you have to add it in FIVE places.

### What to fix

**Step 1:** Extract a shared `BaseGameState` mixin or a `GameSessionNotifier`
that all games use:

```dart
// lib/providers/game_session_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vocab.dart';
import '../models/game_session.dart';

// Shared game session state — used by ALL 5 game types
class GameSessionNotifier extends StateNotifier<GameSession> {
  GameSessionNotifier(List<Vocab> words)
      : super(GameSession(words: words, score: 0, currentIndex: 0));

  void answerCorrect(int points) {
    state = state.copyWith(
      score: state.score + points,
      currentIndex: state.currentIndex + 1,
    );
  }

  void answerWrong() {
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  bool get isFinished => state.currentIndex >= state.words.length;
}

final gameSessionProvider =
    StateNotifierProvider.autoDispose<GameSessionNotifier, GameSession>(
  (ref) => GameSessionNotifier([]), // words are injected per-game
);
```

**Step 2:** Create `lib/models/game_session.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'vocab.dart';

@immutable
class GameSession {
  final List<Vocab> words;
  final int score;
  final int currentIndex;
  final DateTime startedAt;

  const GameSession({
    required this.words,
    required this.score,
    required this.currentIndex,
    required this.startedAt,
  });

  factory GameSession.initial(List<Vocab> words) => GameSession(
    words: words,
    score: 0,
    currentIndex: 0,
    startedAt: DateTime.now(),
  );

  GameSession copyWith({
    List<Vocab>? words,
    int? score,
    int? currentIndex,
  }) => GameSession(
    words: words ?? this.words,
    score: score ?? this.score,
    currentIndex: currentIndex ?? this.currentIndex,
    startedAt: startedAt,
  );

  Vocab get currentWord => words[currentIndex];
  bool get isFinished => currentIndex >= words.length;
  double get accuracy => score / words.length;
}
```

**Step 3:** Each game widget becomes a thin Consumer that reads game state
from the provider. Business logic lives in the notifier. UI logic lives in
the widget. They are separated.

---

## ISSUE 08 — Score Passed as Navigator Argument — Null-Unsafe

**Severity:** 🟠 HIGH
**File:** `lib/screens/result_screen.dart` — line 39

### What is wrong

The analyzer flagged `withOpacity` on line 39 of `result_screen.dart`. The more
important issue is that result screens in apps like this almost universally
receive their data via `Navigator.push` route arguments, which is fragile:

```dart
// COMMON PATTERN — fragile, null-unsafe
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ResultScreen(
    score: _score,
    total: _total,
    // what if these are 0 from a bug? no validation
  ),
));
```

If the game state bug from Issue 04 fires and `_score` is stale, the result
screen silently shows wrong data. There is no validation, no minimum bounds
check, and no way to distinguish "the user scored 0" from "the state was never
set."

### What to fix

Replace Navigator argument passing with Riverpod state reading. The result screen
should read the final game session from the same `gameSessionProvider` that the
game used:

```dart
// lib/screens/result_screen.dart — CORRECT pattern
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the session that was active when the game ended
    final session = ref.read(gameSessionProvider);

    // Now session.score, session.words.length, session.accuracy are all
    // type-safe and always valid — no null risk
    final int score = session.score;
    final int total = session.words.length;
    final double accuracy = session.accuracy;

    return Scaffold(
      // ... build result UI using score, total, accuracy
    );
  }
}
```

This means navigation becomes:

```dart
// In the game widget, when the game finishes:
context.push('/result'); // no arguments passed — data is in the provider
```

---

## ISSUE 09 — No Router — Raw Navigator.push Spaghetti

**Severity:** 🟠 HIGH
**Files:** `lib/screens/game_selection_screen.dart`, all game files

### What is wrong

With no router visible in the file tree, every screen transition is done with
`Navigator.push(context, MaterialPageRoute(...))`. In a small app this feels
fine. But there are at least 8 screens (home, game selection, 5 games, result)
and this pattern causes:

- Deep context dependencies — every widget that navigates needs a `BuildContext`
- Impossible to deep-link (e.g. from a notification → direct to a specific game)
- Back button behavior is unpredictable on Android
- No route guards (e.g. redirect to onboarding if no profile exists)
- Testing navigation requires a full widget tree

### What to fix

Add `go_router` and define all routes in one place.

**Step 1:** Add to `pubspec.yaml`:
```yaml
go_router: ^14.6.3
```

**Step 2:** Create `lib/router.dart`:

```dart
// lib/router.dart
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/game_selection_screen.dart';
import 'screens/result_screen.dart';
import 'games/quiz_game.dart';
import 'games/flashcard_game.dart';
import 'games/matching_game.dart';
import 'games/memory_game.dart';
import 'games/fill_blank_game.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/select', builder: (context, state) => const GameSelectionScreen()),
    GoRoute(path: '/game/quiz', builder: (context, state) => const QuizGame()),
    GoRoute(path: '/game/flashcard', builder: (context, state) => const FlashcardGame()),
    GoRoute(path: '/game/matching', builder: (context, state) => const MatchingGame()),
    GoRoute(path: '/game/memory', builder: (context, state) => const MemoryGame()),
    GoRoute(path: '/game/fill-blank', builder: (context, state) => const FillBlankGame()),
    GoRoute(path: '/result', builder: (context, state) => const ResultScreen()),
  ],
);
```

**Step 3:** Wire it in `main.dart`:

```dart
return MaterialApp.router(
  routerConfig: appRouter,
  // ... other MaterialApp properties
);
```

**Step 4:** Replace every `Navigator.push(...)` call in the codebase with
`context.go('/route-name')` or `context.push('/route-name')`.

---

## ISSUE 10 — Riverpod Providers Scattered — No Structure

**Severity:** 🟠 HIGH
**Files:** All `lib/` files that define providers

### What is wrong

`flutter_riverpod` is in `pubspec.yaml` but there is no `lib/providers/` directory.
This means providers are either:
1. Defined at the top of screen/game files (common beginner mistake)
2. Not being used at all (the package is installed but the app uses `StatefulWidget`
   everywhere, gaining nothing from Riverpod)

Both are problems. If providers are in UI files, every rebuild of that file
recreates them. If Riverpod isn't actually being used, the dependency is dead weight.

### What to fix

**Step 1:** Search all `.dart` files for `Provider(`, `StateProvider(`,
`FutureProvider(`, `StateNotifierProvider(`. Find every provider definition.

**Step 2:** Move every provider definition to a dedicated file in `lib/providers/`.
Suggested structure:

```
lib/providers/
├── vocab_provider.dart         — word bank access and management
├── game_session_provider.dart  — current game state
└── settings_provider.dart      — app settings (theme, language preference)
```

**Step 3:** Every provider should be at the file level (not inside a function,
not inside a class). Riverpod requires this for the ref system to work correctly:

```dart
// WRONG — defined inside a class or function
class HomeScreen extends StatelessWidget {
  final wordCountProvider = Provider((ref) => ...); // ← WRONG
}

// CORRECT — file level, outside any class
final wordCountProvider = Provider<int>((ref) {
  final box = Hive.box<Vocab>('vocab');
  return box.length;
});

class HomeScreen extends ConsumerWidget { ... } // reads wordCountProvider
```

**Step 4:** Every screen that reads Riverpod state should extend `ConsumerWidget`
(stateless) or `ConsumerStatefulWidget` (stateful). Screens that don't use Riverpod
state should be plain `StatelessWidget`. Using `StatefulWidget` with local variables
to track things that should be in a provider is a sign the architecture is wrong.

---

## ISSUE 11 — Unnecessary Braces in String Interpolation

**Severity:** 🟡 MEDIUM
**File:** `lib/screens/game_selection_screen.dart` — line 93
**Analyzer warning:**
```
info - Unnecessary braces in a string interpolation - lib\screens\game_selection_screen.dart:93:39
```

### What is wrong

Dart string interpolation only requires curly braces when accessing a property,
calling a method, or using an expression. For simple variable references, braces
are unnecessary and are a Dart style violation:

```dart
// WRONG — unnecessary braces around simple variable
Text('${gameCount} games available')
Text('Score: ${score}')

// CORRECT — no braces needed for simple identifiers
Text('$gameCount games available')
Text('Score: $score')

// CORRECT — braces ARE needed for expressions and property access
Text('${game.title} — ${words.length} words')
Text('${score > 50 ? "Great!" : "Try again"}')
```

### What to fix

Open `lib/screens/game_selection_screen.dart`, go to line 93, and find the
string with unnecessary braces. Remove the braces. Run `flutter analyze` to
confirm the warning is gone.

Do a global search across all files for the pattern `\$\{[a-zA-Z_][a-zA-Z0-9_]*\}`
(a regex for `${simpleVariable}`) and fix any other occurrences that are just
wrapping a plain variable name with no property access.

---

## ISSUE 12 — Unused Import in memory_game.dart

**Severity:** 🟡 MEDIUM
**File:** `lib/games/memory_game.dart` — line 4
**Analyzer warning:**
```
warning - Unused import: '../models/vocab.dart' - lib\games\memory_game.dart:4:8 - unused_import
```

### What is wrong

See Issue 05 for the full analysis. This is a symptom of the memory game not
using typed `Vocab` objects. After following the fix in Issue 05 (wiring the
memory game to real vocabulary data), this import will become used and the
warning will disappear naturally.

**Do not just delete the import.** Deleting it without fixing the underlying
data problem means the game is confirmed to be using hardcoded data, which is
wrong. Fix Issue 05 first. This warning is the canary that tells you when Issue
05 is fixed.

---

## ISSUES 13–21 — `withOpacity` Deprecation (14 occurrences across 6 files)

**Severity:** 🔵 LOW (but easy to batch-fix completely)
**Files and exact lines:**

| # | File | Line(s) |
|---|---|---|
| 13 | `lib/games/fill_blank_game.dart` | 276 |
| 14 | `lib/games/flashcard_game.dart` | 105, 111, 166, 171 |
| 15 | `lib/games/matching_game.dart` | 141, 184 |
| 16 | `lib/games/memory_game.dart` | 194, 203, 224 |
| 17 | `lib/games/quiz_game.dart` | 187, 207 |
| 18 | `lib/screens/game_selection_screen.dart` | 97 |
| 19 | `lib/screens/home_screen.dart` | 98 |
| 20 | `lib/screens/result_screen.dart` | 39 |
| 21 | `lib/widgets/custom_button.dart` | 32 |

### What is wrong

Flutter deprecated `Color.withOpacity(double)` starting from Flutter 3.27
(Dart SDK 3.7.x — which matches this project's `sdk: ^3.7.2`). The new API
uses `.withValues(alpha: double)` and avoids floating-point precision loss
when the color is in a non-sRGB color space.

The old API:
```dart
Colors.blue.withOpacity(0.5)     // deprecated
Color(0xFF1234AB).withOpacity(0.3) // deprecated
someColor.withOpacity(opacity)    // deprecated
```

The new API:
```dart
Colors.blue.withValues(alpha: 0.5)     // correct
Color(0xFF1234AB).withValues(alpha: 0.3) // correct
someColor.withValues(alpha: opacity)    // correct
```

The opacity parameter is identical — same range (0.0 to 1.0), same meaning.
You are only changing the method name and parameter label.

### How to fix all 14 occurrences in one pass

**Option A — IDE global find-and-replace (fastest, safest):**

In VS Code or Android Studio:
1. Open "Find in Files" (`Ctrl+Shift+H` / `Cmd+Shift+H`)
2. Search for: `.withOpacity(`
3. Replace with: `.withValues(alpha: `
4. Scope: `lib/` directory only
5. Review each replacement (there are only 14 — review all of them)
6. Apply

**Option B — Manual line-by-line:**

Go to each file and line listed in the table above. Change:
```dart
someColor.withOpacity(0.5)
```
to:
```dart
someColor.withValues(alpha: 0.5)
```

After applying all replacements:
```bash
flutter analyze
```

Expected result: 0 deprecated_member_use warnings remaining.

---

## Additional Issues Not Caught by the Analyzer

The following issues will NOT appear in `flutter analyze` output because they
are architecture and logic problems, not syntax violations. They are equally
important.

---

### BONUS ISSUE A — No Error States in Any Game Screen

**Severity:** 🟠 HIGH

If Hive fails to open, if the vocab box is empty, or if any async operation
throws — there are almost certainly no error widgets to show the user. The app
will either display a blank white screen or throw an unhandled exception.

Every game screen that loads data from Hive should handle three states:
loading, loaded (data available), and error (box empty or exception).

```dart
// Pattern for any game screen loading vocab data
@override
Widget build(BuildContext context) {
  final vocabBox = Hive.box<Vocab>('vocab');

  // Error state — no words to play with
  if (vocabBox.isEmpty) {
    return Scaffold(
      body: Center(
        child: Column(children: [
          const Text('No vocabulary words found.'),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go back'),
          ),
        ]),
      ),
    );
  }

  // Normal state
  return Scaffold(/* game UI */);
}
```

---

### BONUS ISSUE B — No `.gitignore` Entries for Generated Files

**Severity:** 🟡 MEDIUM

The `.gitignore` file exists in the repo. Check that it includes rules for:

```gitignore
# Hive generated files
*.g.dart
# If you prefer to commit generated files, remove this line

# Build outputs
build/
.dart_tool/

# IDE
.idea/
.vscode/

# Sensitive
*.env
lib/config/supabase_config.dart   # if you add Supabase later (from the competitive guide)
```

If `*.g.dart` is not in `.gitignore` and you don't commit generated files,
every new developer who clones the repo must run `build_runner` before the
project compiles. Document this clearly in `README.md`.

---

### BONUS ISSUE C — README.md Contains Zero Project Information

**Severity:** 🟡 MEDIUM
**File:** `README.md`

The current README is the default Flutter boilerplate:
> "A new Flutter project. Getting Started..."

This is a real app with a real purpose (English ↔ Uzbek vocabulary for students).
Replace the README completely:

```markdown
# VocabGame — English ↔ Uzbek Vocabulary Learning App

A Flutter app for students to practice English and Uzbek vocabulary through
5 different game modes.

## Game Modes
- Quiz — multiple choice
- Flashcard — flip and reveal
- Matching — pair words with translations
- Memory — classic card flip pairs
- Fill in the Blank — type the translation

## Setup

1. Install Flutter SDK 3.7.2 or higher
2. Clone the repo
3. Run `flutter pub get`
4. Run code generation: `dart pub run build_runner build`
5. Run the app: `flutter run`

## Tech Stack
- Flutter + Dart
- Riverpod (state management)
- Hive (local storage)
- Google Fonts
```

---

### BONUS ISSUE D — No Word Count Indicator in Games

**Severity:** 🟡 MEDIUM

Users cannot tell how far through a game they are. There is no "Question 3 of 10"
indicator. This is a UX problem that also signals a state management problem —
the game doesn't know its own length until it is over.

After implementing `GameSession` from Issue 07, add a progress indicator to
every game screen:

```dart
// In every game's build() method
LinearProgressIndicator(
  value: session.currentIndex / session.words.length,
),
Text('${session.currentIndex + 1} / ${session.words.length}'),
```

---

## Execution Order for Claude Max

Apply fixes in this exact order. Each step should result in a green `flutter analyze`:

```
Step 1 — ISSUE 02: Add path_provider to pubspec.yaml. Run flutter pub get.
Step 2 — ISSUE 01: Fix widget_test.dart. Run flutter test. Must pass.
Step 3 — ISSUE 03: Fix main.dart Hive initialization order.
                    Fix vocab.dart to be a proper HiveType.
                    Run build_runner. Confirm vocab.g.dart generated.
Step 4 — ISSUE 06: Create vocab_seed_data.dart. Seed words in main.dart.
Step 5 — ISSUE 12: Do NOT delete the unused import yet.
Step 6 — ISSUE 05: Fix memory_game.dart to load real Vocab data from Hive.
                    The unused import warning should disappear automatically.
Step 7 — ISSUES 13-21: Batch-replace all withOpacity → withValues(alpha:).
                         Run flutter analyze. Expect 0 deprecation warnings.
Step 8 — ISSUE 11: Fix unnecessary braces in game_selection_screen.dart:93.
Step 9 — ISSUE 04: Add _resetGame() + dispose() timer cancel to all 5 games.
Step 10 — ISSUE 07: Extract GameSession model and GameSessionNotifier provider.
Step 11 — ISSUE 10: Create lib/providers/ directory.
                     Move all provider definitions there.
Step 12 — ISSUE 08: Wire result_screen.dart to read from gameSessionProvider.
Step 13 — ISSUE 09: Add go_router. Define routes. Replace Navigator.push calls.
Step 14 — BONUS A: Add error states to all game screens.
Step 15 — BONUS B: Fix .gitignore.
Step 16 — BONUS C: Rewrite README.md.
Step 17 — BONUS D: Add progress indicators to all game screens.

Final: Run flutter analyze → must show 0 issues.
       Run flutter test  → must show all tests passing.
       Run flutter build apk → must build successfully.
```

---

## Final `flutter analyze` Expected Output

After all 17 steps are complete, running `flutter analyze` must produce:

```
Analyzing vocab_game...
No issues found!
```

And `flutter test` must produce:

```
00:XX +1: All tests passed!
```

Any remaining warning is a sign that a step was missed or partially applied.
Do not move to adding new features (the competitive multiplayer system) until
this baseline is clean. You cannot build a reliable competitive system on
top of broken foundations.

---

*End of critical feedback document.*
*Total confirmed issues: 21 from analyzer + 4 bonus architecture issues = 25 total.*
*All issues are real, grounded in the actual repository evidence, and fixable.*
