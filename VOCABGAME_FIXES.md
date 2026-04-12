# VOCABGAME — COMPLETE BUG FIX & IMPLEMENTATION DOCUMENT
## Every Bug Fixed. Assignment Mode Fully Implemented. Nothing Skipped.

> **READ THIS ENTIRE DOCUMENT BEFORE TOUCHING ANY FILE.**
> Fixes are ordered by severity. Implement Phase 0 first — the app does not compile without it.
> Every code block is exact. Every method call is exact. Do not paraphrase. Do not improvise.
> If something in this document conflicts with the current code, this document wins.

---

## TABLE OF CONTENTS

1. [Phase 0 — Compile Error (Do This First)](#phase-0--compile-error)
2. [Phase 1 — Data Integrity (Prevents Data Loss)](#phase-1--data-integrity)
3. [Phase 2 — Null Safety and Crash Prevention](#phase-2--null-safety)
4. [Phase 3 — Assignment Mode (The Core Missing Feature)](#phase-3--assignment-mode)
5. [Phase 4 — Navigation Fix](#phase-4--navigation-fix)
6. [Phase 5 — Architecture Fix](#phase-5--architecture-fix)
7. [Phase 6 — Race Condition Fixes](#phase-6--race-conditions)
8. [Phase 7 — Low Priority Cleanup](#phase-7--low-priority)
9. [Order of Implementation](#order-of-implementation)
10. [Verification Checklist](#verification-checklist)

---

## PHASE 0 — COMPILE ERROR

### BUG 1: `try` block without `catch` in TeacherDashboardScreen

**File:** `lib/screens/teacher/teacher_dashboard_screen.dart`

**Problem:** The Save button's `onPressed` handler opens a `try` block and never closes it with `catch` or `finally`. The app will not compile.

**Find this exact broken code:**
```dart
onPressed: () async {
  try {
    if (controller.text.trim().isNotEmpty) {
      await TeacherMessageService.setMessage(...);
      final newMsg = await TeacherMessageService.getMessage(classCode);
      setState(() => _message = newMsg);
    }
    if (context.mounted) Navigator.pop(context);
  },   // <-- THIS IS WRONG. try has no catch/finally.
```

**Replace the entire `onPressed` handler with:**
```dart
onPressed: () async {
  try {
    final trimmed = controller.text.trim();
    if (trimmed.isNotEmpty) {
      await TeacherMessageService.setMessage(
        classCode: classCode,
        teacherId: profile.id,
        message: trimmed,
      );
      final newMsg = await TeacherMessageService.getMessage(classCode);
      if (context.mounted) setState(() => _message = newMsg);
    }
    if (context.mounted) Navigator.pop(context);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save message. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
},
```

**Why:** The `catch` block must exist. Without it, `try` is a syntax error. The catch also gives the teacher feedback if the Supabase call fails instead of silently losing their message.

---

## PHASE 1 — DATA INTEGRITY

### BUG 2: Teacher Delete Account Skips Supabase Deletion

**File:** `lib/screens/teacher/teacher_profile_screen.dart`

**Problem:** The delete account handler calls `profileProvider.logout()` but never calls `SyncService.deleteProfile()`. The teacher's `profiles` row, their `classes` row, all their `assignments`, and all `assignment_progress` rows linked to their class remain in Supabase permanently. Students can still join a class whose teacher no longer exists.

**Find the broken delete handler. It looks like this:**
```dart
// WRONG — only clears local, leaves Supabase intact
await profileProvider.notifier.logout();
if (context.mounted) context.go('/welcome');
```

**Replace the entire delete account confirmation handler with:**
```dart
Future<void> _handleDeleteAccount(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(profileProvider);
  if (profile == null) return;

  // Step 1: Soft-delete class and assignments in Supabase
  // This must happen BEFORE profile deletion so we still have the class code.
  if (profile.classCode != null) {
    try {
      // Deactivate all assignments for this class (soft delete)
      await Supabase.instance.client
          .from('assignments')
          .update({'is_active': false})
          .eq('class_code', profile.classCode!);

      // Delete the class row entirely
      await Supabase.instance.client
          .from('classes')
          .delete()
          .eq('code', profile.classCode!);

      // Orphan any students in this class (set their class_code to null)
      // This is important: students should not be stuck in a non-existent class.
      await Supabase.instance.client
          .from('profiles')
          .update({'class_code': null})
          .eq('class_code', profile.classCode!)
          .eq('is_teacher', false);
    } catch (e) {
      // Log but do not abort — profile deletion should still proceed
      debugPrint('Teacher class cleanup error: $e');
    }
  }

  // Step 2: Delete the teacher's profile (same as student path)
  // SyncService.deleteProfile handles online/offline correctly:
  // - If online: deletes from Supabase first, then clears Hive
  // - If offline: queues pending_delete in sync_queue, clears Hive immediately
  await SyncService.deleteProfile(profile.id);

  // Step 3: Navigate away
  if (context.mounted) context.go('/welcome');
}
```

**Call this method from the delete confirmation dialog's confirm button:**
```dart
// In the confirm button onPressed:
onPressed: () async {
  Navigator.pop(context); // close the confirm dialog
  await _handleDeleteAccount(context, ref);
},
```

**Why the order matters:** Class cleanup must happen before profile deletion because after the profile is deleted, we have no class code to reference. Students are orphaned (class_code set to null) so they are not stuck in a ghost class with no teacher.

**Also add this import at the top of `teacher_profile_screen.dart` if not already present:**
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

---

## PHASE 2 — NULL SAFETY

### BUG 4: Force-Unwrap of `healthScore` in Teacher Dashboard

**File:** `lib/screens/teacher/teacher_dashboard_screen.dart`

**Problem:** `classesState.healthScore!` is force-unwrapped inside a block that only checks `classesState.students.isNotEmpty`. Students can be non-empty (cached from a previous load) while `healthScore` is null (computation failed on reload). This crashes with a `Null check operator used on a null value`.

**Find all occurrences of `classesState.healthScore!` in the file.**

**Replace every `classesState.healthScore!.someField` with null-safe access:**

```dart
// WRONG:
Text('⚠️ At Risk — ${classesState.healthScore!.atRiskCount} students')

// CORRECT — use null-safe fallback:
Text('⚠️ At Risk — ${classesState.healthScore?.atRiskCount ?? 0} students')
```

**Replace the entire health card rendering block with a null-aware version:**

```dart
// WRONG guard:
if (classesState.students.isNotEmpty) {
  _buildHealthCard(classesState.healthScore!) // crashes if healthScore is null
}

// CORRECT guard — check both:
if (classesState.students.isNotEmpty && classesState.healthScore != null) {
  _buildHealthCard(classesState.healthScore!)
} else if (classesState.students.isNotEmpty && classesState.healthScore == null) {
  // Students loaded but health score computation failed
  _buildHealthCardError() // see below
}
```

**Add a `_buildHealthCardError()` method:**
```dart
Widget _buildHealthCardError() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Text('Health score unavailable — pull to refresh'),
        ],
      ),
    ),
  );
}
```

**Search the entire file for any other `!` force-unwrap on `healthScore` and apply the same null-safe treatment.**

---

## PHASE 3 — ASSIGNMENT MODE (THE CORE MISSING FEATURE)

This is the largest section. Read it completely before writing a single line.

### What Assignment Mode Is

When a student taps "Practice Now" on an assignment card, the game must:
1. Fetch the actual vocabulary words for that library unit from Supabase
2. Pass those words to a game screen as the word source (instead of the student's personal Hive vocab list)
3. After the session: record progress against the specific assignment in `assignment_progress` table
4. Record per-word accuracy in `word_stats` table
5. Update the assignment card's progress bar locally without a full reload

### 3A — Database: Word Storage for Library Units

The `units` table has `id, collection_id, title, unit_number, word_count` but no actual words. Words must be stored in a separate table. **If this table does not already exist, create it:**

```sql
CREATE TABLE IF NOT EXISTS unit_words (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id       UUID NOT NULL,              -- FK to units.id
  english       TEXT NOT NULL,
  uzbek         TEXT NOT NULL,
  unit_number   INTEGER NOT NULL,           -- display order within unit
  CONSTRAINT fk_unit FOREIGN KEY (unit_id) REFERENCES units(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_unit_words_unit_id ON unit_words(unit_id);
```

**If unit words are already stored in a differently-named table or with different column names:** adapt the field names in Section 3B below, but keep all logic identical.

**RLS for `unit_words`:**
```sql
ALTER TABLE unit_words ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated (student or teacher) can read unit words
CREATE POLICY "unit_words_read_all" ON unit_words
  FOR SELECT USING (true);

-- Only service role can insert/update (content is managed server-side)
-- No client-side insert policy needed
```

### 3B — New Model: `AssignmentModeParams`

**File:** `lib/models/assignment_mode_params.dart`

Create this file if it does not exist:

```dart
import 'assignment.dart';

/// Passed as GoRouter `extra` when launching a game in Assignment Mode.
/// Contains everything a game screen needs — no additional Supabase calls needed inside the game.
class AssignmentModeParams {
  final Assignment assignment;   // the full Assignment object (has id, unitTitle, wordCount, dueDate)
  final List<UnitWord> words;    // the actual words to quiz the student on
  final int wordsMasteredSoFar;  // from AssignmentProgress, 0 if student has never started this

  const AssignmentModeParams({
    required this.assignment,
    required this.words,
    required this.wordsMasteredSoFar,
  });
}

/// A single vocabulary word from a library unit.
/// Separate from the student's personal Vocab model stored in Hive.
class UnitWord {
  final String id;       // UUID from unit_words table
  final String english;
  final String uzbek;

  const UnitWord({
    required this.id,
    required this.english,
    required this.uzbek,
  });

  factory UnitWord.fromMap(Map<String, dynamic> map) {
    return UnitWord(
      id: map['id'] as String,
      english: map['english'] as String,
      uzbek: map['uzbek'] as String,
    );
  }
}
```

### 3C — New Method in `AssignmentService`: Fetch Unit Words

**File:** `lib/services/assignment_service.dart`

Add this method to the existing `AssignmentService` class:

```dart
/// Fetches all vocabulary words for a specific library unit.
/// Called before navigating to an assignment game — not inside the game itself.
/// Returns an empty list if the unit has no words (should not happen in production).
static Future<List<UnitWord>> getUnitWords(String unitId) async {
  final data = await _supabase
      .from('unit_words')
      .select('id, english, uzbek')
      .eq('unit_id', unitId)
      .order('unit_number', ascending: true); // preserve display order

  return (data as List)
      .map((e) => UnitWord.fromMap(e as Map<String, dynamic>))
      .toList();
}
```

**Add the `UnitWord` import at the top of the file:**
```dart
import '../models/assignment_mode_params.dart';
```

### 3D — New GoRouter Route for Assignment Game Selection

**File:** `lib/router.dart`

Add a new route inside the student shell branches. This route accepts `AssignmentModeParams` as `extra`:

```dart
// Add inside the /home branch sub-routes (as a sibling to hall-of-fame, leaderboard, etc.):
GoRoute(
  path: '/assignment-game-select',
  pageBuilder: (context, state) => _buildPage(
    state,
    AssignmentGameSelectScreen(params: state.extra as AssignmentModeParams),
  ),
),
```

### 3E — New Screen: `AssignmentGameSelectScreen`

**File:** `lib/screens/assignment_game_select_screen.dart`

This screen shows the student which game modes they can use to practice this assignment, then launches the selected game in assignment mode.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/assignment_mode_params.dart';
import '../models/assignment.dart';

class AssignmentGameSelectScreen extends ConsumerWidget {
  final AssignmentModeParams params;

  const AssignmentGameSelectScreen({required this.params, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignment = params.assignment;
    final wordsCount = params.words.length;
    final mastered = params.wordsMasteredSoFar;
    final progress = wordsCount == 0 ? 0.0 : mastered / wordsCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(assignment.unitTitle),
        subtitle: Text(assignment.bookTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Progress summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$mastered / $wordsCount words mastered',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                  if (assignment.dueDate != null) ...[
                    const SizedBox(height: 8),
                    _DueDateChip(assignment: assignment),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Choose a game mode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          // One card per game mode
          _GameModeCard(
            icon: Icons.quiz_rounded,
            title: 'Quiz',
            subtitle: 'Multiple choice — choose the correct translation',
            onTap: () => context.push('/quiz', extra: params),
          ),
          _GameModeCard(
            icon: Icons.style_rounded,
            title: 'Flashcards',
            subtitle: 'Flip cards to review all words',
            onTap: () => context.push('/flashcard', extra: params),
          ),
          _GameModeCard(
            icon: Icons.join_inner_rounded,
            title: 'Matching',
            subtitle: 'Match English words to their Uzbek meanings',
            onTap: () => context.push('/matching', extra: params),
          ),
          _GameModeCard(
            icon: Icons.grid_on_rounded,
            title: 'Memory',
            subtitle: 'Find matching pairs',
            onTap: () => context.push('/memory', extra: params),
          ),
          _GameModeCard(
            icon: Icons.edit_rounded,
            title: 'Fill in the Blank',
            subtitle: 'Type the missing word from context',
            onTap: () => context.push('/fill-blank', extra: params),
          ),
        ],
      ),
    );
  }
}

class _GameModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GameModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _DueDateChip extends StatelessWidget {
  final Assignment assignment;
  const _DueDateChip({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final days = assignment.daysRemaining;
    final isOverdue = assignment.isOverdue;

    String label;
    Color color;
    if (isOverdue) {
      label = 'Overdue';
      color = Colors.red;
    } else if (days == 0) {
      label = 'Due today';
      color = Colors.orange;
    } else if (days == 1) {
      label = 'Due tomorrow';
      color = Colors.orange;
    } else {
      label = 'Due in $days days';
      color = Colors.blue;
    }

    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: EdgeInsets.zero,
    );
  }
}
```

### 3F — Student Home Screen: Wire Up the Assignment Card Tap

**File:** `lib/screens/home_screen.dart`

**Find the TODO comment inside the assignment card tap handler:**
```dart
// TODO: Launch AssignmentModeGame (Phase 7)
```

**Replace the entire `onTap` or `GestureDetector.onTap` for the assignment card with:**

```dart
onTap: () async {
  final profile = ref.read(profileProvider);
  if (profile == null) return;

  // Retrieve the student's current progress on this assignment
  final progressMap = ref.read(assignmentProvider).progressMap;
  final existingProgress = progressMap[assignment.id];
  final wordsMasteredSoFar = existingProgress?.wordsMastered ?? 0;

  // Show a loading indicator while fetching words
  // Use a small loading dialog so the student sees feedback
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // Fetch the actual words for this unit from Supabase
    final words = await AssignmentService.getUnitWords(assignment.unitId);

    if (!context.mounted) return;
    Navigator.pop(context); // close loading dialog

    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This unit has no words yet. Check back later.'),
        ),
      );
      return;
    }

    // Build the params object that gets passed to the game
    final params = AssignmentModeParams(
      assignment: assignment,
      words: words,
      wordsMasteredSoFar: wordsMasteredSoFar,
    );

    // Navigate to game selection screen
    context.push('/assignment-game-select', extra: params);

  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context); // close loading dialog on error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not load assignment: ${e.toString()}')),
    );
  }
},
```

**Add these imports at the top of `home_screen.dart` if not already present:**
```dart
import '../models/assignment_mode_params.dart';
import '../services/assignment_service.dart';
```

### 3G — Game Screens: Detect Assignment Mode and Adapt Word Source

**This section applies to ALL FIVE game screens:**
- Quiz game screen
- Flashcard game screen
- Matching game screen
- Memory game screen
- Fill-in-the-Blank game screen

**The pattern is identical for every game. Apply it to each one.**

#### How Each Game Currently Gets Its Words

Each game screen currently reads from the student's personal Hive vocabulary list. The exact call looks something like:

```dart
// Current pattern (exact variable names may differ per game):
final words = Hive.box('vocabWords').values.toList();
// OR via a Riverpod provider:
final words = ref.read(vocabProvider).words;
```

#### The New Pattern — Detect Assignment Mode First

At the top of each game screen's `initState` or `build` method, where words are currently loaded, replace with this pattern:

```dart
// At the top of the game screen class, add these fields:
List<UnitWord>? _assignmentWords;      // non-null = assignment mode
AssignmentModeParams? _assignmentParams; // non-null = assignment mode

// In initState or the first build call, detect mode:
@override
void initState() {
  super.initState();
  _detectMode();
}

void _detectMode() {
  // GoRouter passes extra to the widget. Check if it's AssignmentModeParams.
  // Access GoRouterState.of(context).extra in a ConsumerStatefulWidget:
  final extra = GoRouterState.of(context).extra;
  if (extra is AssignmentModeParams) {
    _assignmentParams = extra;
    _assignmentWords = extra.words;
    _loadWordsFromAssignment(extra.words);
  } else {
    _loadWordsFromPersonalVocab();
  }
}
```

**NOTE:** `GoRouterState.of(context).extra` requires that `context` is available. In a `ConsumerStatefulWidget`, access it in `didChangeDependencies()` instead of `initState()` if needed:

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_modeDetected) {
    _modeDetected = true;
    _detectMode();
  }
}
bool _modeDetected = false;
```

#### Converting `UnitWord` to the Game's Internal Word Type

Every game uses the student's personal `Vocab` type (or equivalent) that has `english` and `uzbek` fields. `UnitWord` has the same fields. Create a conversion in each game screen:

```dart
// Convert UnitWord list to whatever type this game uses internally.
// If the game uses a class called `Vocab`:
List<Vocab> _unitWordsToVocab(List<UnitWord> unitWords) {
  return unitWords.map((w) => Vocab(
    english: w.english,
    uzbek: w.uzbek,
    // id: not needed for gameplay — leave empty or generate a temp one
  )).toList();
}

// If the game uses Map<String, String>:
Map<String, String> _unitWordsToMap(List<UnitWord> unitWords) {
  return { for (var w in unitWords) w.english: w.uzbek };
}
```

**Use whichever format the existing game code already expects.**

#### Per-Word Answer Tracking in Games

In every game, there is a point where the student answers a question and the code determines if they were correct. **Find that exact point** — it is typically inside an `_onAnswerSelected()`, `_checkAnswer()`, or similar method.

**At that exact point, add a fire-and-forget call to `WordStatsService`:**

```dart
// After determining correctness, add this line:
// profile is ref.read(profileProvider)
unawaited(WordStatsService.recordWordAnswer(
  studentId: profile.id,
  classCode: profile.classCode,       // null if student has no class — service handles this
  wordEnglish: currentWord.english,   // the English side of the word just answered
  wordUzbek: currentWord.uzbek,       // the Uzbek side of the word just answered
  wasCorrect: isCorrect,              // the boolean you already have
));
```

**Import `dart:async` for `unawaited()`:**
```dart
import 'dart:async';
```

**This call is fire-and-forget. It must never block the game UI. The `try-catch` is inside `WordStatsService.recordWordAnswer()` already — if it fails, the game continues normally.**

### 3H — Game Screens: Post-Session Handling for Assignment Mode

Every game screen already calls `profileProvider.notifier.recordGameSession()` when the session ends. This must still happen in assignment mode — XP is still awarded. But in assignment mode, an additional call is required.

**Find the exact location in each game where `recordGameSession()` is called. It is at the end of the game, typically in a `_onGameComplete()` or `_showResultScreen()` method.**

**After the existing `recordGameSession()` call, add:**

```dart
// After the existing recordGameSession call:
if (_assignmentParams != null) {
  // Compute how many words were answered correctly this session.
  // correctAnswers is a variable already available at this point in every game.
  // wordsMasteredDelta = how many NEW words were mastered (not total correct).
  // Use correctAnswers as the delta — the service caps at totalWords.
  final wordsMasteredDelta = correctAnswers;

  // Fire-and-forget — do not await. Post-session sync must not block the result screen.
  unawaited(_recordAssignmentProgress(wordsMasteredDelta));
}
```

**Add this helper method to the game screen class:**

```dart
Future<void> _recordAssignmentProgress(int wordsMasteredDelta) async {
  if (_assignmentParams == null) return;
  final profile = ref.read(profileProvider);
  if (profile == null) return;

  try {
    // Update progress in Supabase
    await AssignmentService.updateAssignmentProgress(
      assignmentId: _assignmentParams!.assignment.id,
      studentId: profile.id,
      classCode: profile.classCode ?? '',
      wordsMasteredDelta: wordsMasteredDelta,
      totalWords: _assignmentParams!.assignment.wordCount,
    );

    // Optimistically update the local provider so the home screen progress bar
    // reflects the new progress immediately without a full reload.
    // Fetch the updated progress row and push it to the provider.
    final updatedProgressMap = await AssignmentService.getStudentProgressMap(
      studentId: profile.id,
    );
    final updatedProgress = updatedProgressMap[_assignmentParams!.assignment.id];
    if (updatedProgress != null) {
      ref.read(assignmentProvider.notifier).updateLocalProgress(updatedProgress);
    }
  } catch (e) {
    // Silently fail — the student's XP and session are already saved.
    // Progress will sync correctly on next full reload.
    debugPrint('Assignment progress sync error: $e');
  }
}
```

**Add these imports to each game screen file:**
```dart
import 'dart:async';
import '../models/assignment_mode_params.dart';
import '../services/assignment_service.dart';
import '../services/word_stats_service.dart';
import '../providers/assignment_provider.dart';
```

### 3I — Assignment Card on Home Screen: Show Updated Progress

The `assignmentProvider` already has `updateLocalProgress()`. After `_recordAssignmentProgress()` calls it, the home screen must react to the change.

**In `home_screen.dart`, ensure the assignment card builds from the provider state, not from a local variable:**

```dart
// WRONG — using a snapshot that doesn't update:
final progress = _cachedProgressMap[assignment.id];

// CORRECT — always read from provider which gets updated via updateLocalProgress:
final assignmentState = ref.watch(assignmentProvider);
final progress = assignmentState.progressMap[assignment.id];
```

**This means the assignment card widget must be inside a `Consumer` or the screen must be a `ConsumerWidget`/`ConsumerStatefulWidget`.** If the home screen is already a `ConsumerStatefulWidget`, this is already satisfied — just make sure the progress value is read from `ref.watch(assignmentProvider).progressMap` and not from a local field set once during `initState`.

### 3J — Complete Assignment Mode: End-to-End Flow Summary

After implementing sections 3A through 3I, the complete flow is:

```
Student sees assignment card on HomeScreen
  ↓
Taps "Practice Now"
  ↓
AssignmentService.getUnitWords(unitId) — fetches words from Supabase
  ↓
AssignmentModeParams built with {assignment, words, wordsMasteredSoFar}
  ↓
context.push('/assignment-game-select', extra: params)
  ↓
AssignmentGameSelectScreen — student picks a game mode
  ↓
context.push('/quiz', extra: params)  ← (or whichever game)
  ↓
Game screen detects extra is AssignmentModeParams
  ↓
Word source = params.words (not personal Hive vocab)
  ↓
Per word answered: WordStatsService.recordWordAnswer() [fire-and-forget]
  ↓
Game ends
  ↓
profileProvider.recordGameSession() — XP awarded (unchanged)
  ↓
AssignmentService.updateAssignmentProgress() — progress saved to Supabase
  ↓
assignmentProvider.updateLocalProgress() — home screen card updates immediately
  ↓
Student returns to HomeScreen — progress bar shows new value
```

---

## PHASE 4 — NAVIGATION FIX

### BUG 6: Teacher Library Uses `Navigator.push` Instead of GoRouter

**File:** `lib/screens/teacher/teacher_library_screen.dart`

**Problem:** `TeacherUnitListScreen` is pushed via `Navigator.push(context, MaterialPageRoute(...))`. This means it has no route path, no deep-link support, and gets a different page transition than every other screen.

**Step 1 — Add a new route in `router.dart`:**

Add inside the teacher shell branches, as a sub-route of `/teacher/library`:

```dart
GoRoute(
  path: '/teacher/library',
  pageBuilder: (context, state) => _buildPage(
    state,
    const TeacherLibraryScreen(),
  ),
  routes: [
    GoRoute(
      path: 'units',  // full path: /teacher/library/units
      pageBuilder: (context, state) {
        // Collection object passed as extra
        final collection = state.extra as LibraryCollection;
        return _buildPage(state, TeacherUnitListScreen(collection: collection));
      },
    ),
  ],
),
```

**Step 2 — In `teacher_library_screen.dart`, find the `Navigator.push` call:**

```dart
// WRONG:
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => TeacherUnitListScreen(collection: c)),
);
```

**Replace with:**
```dart
// CORRECT:
context.push('/teacher/library/units', extra: c);
```

**Step 3 — Remove the `TeacherUnitListScreen` constructor parameter and use `GoRouterState.extra` inside it:**

In `TeacherUnitListScreen`, change how it receives the collection. If it currently has a constructor:

```dart
// WRONG (constructor parameter, only works with Navigator):
class TeacherUnitListScreen extends StatefulWidget {
  final LibraryCollection collection;
  const TeacherUnitListScreen({required this.collection, super.key});
}
```

**Change to:**
```dart
// CORRECT (reads from GoRouter extra):
class TeacherUnitListScreen extends ConsumerStatefulWidget {
  const TeacherUnitListScreen({super.key});

  @override
  ConsumerState<TeacherUnitListScreen> createState() => _TeacherUnitListScreenState();
}

class _TeacherUnitListScreenState extends ConsumerState<TeacherUnitListScreen> {
  late final LibraryCollection _collection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _collection = GoRouterState.of(context).extra as LibraryCollection;
  }
  // ... rest of the screen unchanged, replace widget.collection with _collection
}
```

---

## PHASE 5 — ARCHITECTURE FIX

### BUG 3: AppShell Uses Same Builder for Both StatefulShellRoutes

**File:** `lib/router.dart`

**Problem:** Both `StatefulShellRoute`s use:
```dart
builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
```

`AppShell` then reads `isTeacher` to decide which shell to render. If the role flag changes while on a teacher route (edge case during logout race condition), the student nav shell renders with teacher tab indices — producing a broken UI state.

**The fix:** Give each `StatefulShellRoute` its own builder that renders the correct shell directly, bypassing the dispatcher.

**In `router.dart`, change the student `StatefulShellRoute` builder:**

```dart
// Student StatefulShellRoute
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    // Student shell renders directly — no isTeacher check needed here
    return StudentNavShell(navigationShell: navigationShell);
  },
  branches: [ /* student branches unchanged */ ],
),
```

**Change the teacher `StatefulShellRoute` builder:**

```dart
// Teacher StatefulShellRoute
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    // Teacher shell renders directly — no isTeacher check needed here
    return TeacherNavShell(navigationShell: navigationShell);
  },
  branches: [ /* teacher branches unchanged */ ],
),
```

**Remove `AppShell` entirely** — it is no longer needed. Both shells are now called directly by their respective route builders.

**Delete:** `lib/screens/app_shell.dart`

**Remove** all imports of `AppShell` from other files.

**Why this is safe:** The router's redirect logic already prevents a student from ever reaching teacher routes and vice versa. The shell builder never needs to check `isTeacher` — by the time the builder runs, the redirect has already guaranteed the correct route tree is active.

---

## PHASE 6 — RACE CONDITIONS

### BUG 9: TeacherUnitListScreen Assignment Check Race Condition

**File:** `lib/screens/teacher/teacher_library_screen.dart` (inside `TeacherUnitListScreen`)

**Problem:** On first load, `assignmentState.assignments` is empty because `loadTeacherAssignments()` is fired via `addPostFrameCallback` but the ListView builds before it completes. All units show "Assign to Class" even if they're already assigned — teacher taps it, creates a duplicate, gets confused.

**Step 1 — Add a loading gate before rendering unit buttons:**

```dart
// In the build method of TeacherUnitListScreen, wrap the ListView:
final assignmentState = ref.watch(assignmentProvider);

// Show a shimmer or loading indicator while assignments are loading
if (assignmentState.isLoading) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

// Only build the unit list after assignments are confirmed loaded
return Scaffold(
  // ... your existing AppBar ...
  body: ListView.builder(
    // ... existing item builder ...
  ),
);
```

**Step 2 — Move `loadTeacherAssignments()` to trigger BEFORE navigation:**

In `teacher_library_screen.dart`, when the teacher taps a collection card (before `context.push` to the unit list screen), ensure assignments are already loaded:

```dart
onTap: () async {
  final profile = ref.read(profileProvider);
  if (profile == null) return;

  // Pre-load assignments before opening the unit list.
  // This eliminates the race condition: units always know their assigned state.
  if (ref.read(assignmentProvider).assignments.isEmpty) {
    await ref.read(assignmentProvider.notifier).loadTeacherAssignments(
      classCode: profile.classCode!,
      teacherId: profile.id,
    );
  }

  if (context.mounted) {
    context.push('/teacher/library/units', extra: collection);
  }
},
```

**Why this works:** The `await` ensures assignments are loaded before the unit list screen renders. The loading state in `TeacherUnitListScreen` is now a fallback only, not the primary mechanism.

### BUG 7: Teacher Filter Race Condition on Rank Reveal and Rival Card

**Files:**
- `lib/screens/onboarding/join_class_screen.dart`
- `lib/screens/home_screen.dart`

**Problem:** Both queries filter by `is_teacher = false` to exclude teachers. This relies on the teacher's Supabase row being synced with `is_teacher = true` before the student queries it. If the teacher just created the class and their profile hasn't synced yet, they appear in student queries.

**Fix for `join_class_screen.dart` — rank reveal query:**

```dart
// CURRENT (fragile — relies on is_teacher sync):
.eq('class_code', classCode)
.eq('is_teacher', false)

// IMPROVED — also exclude by teacher_id fetched from classes table:
// First, fetch the teacher_id from the classes table:
final classData = await _supabase
    .from('classes')
    .select('teacher_id')
    .eq('code', classCode)
    .single();
final teacherId = classData['teacher_id'] as String;

// Then query classmates excluding both is_teacher flag AND the specific teacher ID:
final classmates = await _supabase
    .from('profiles')
    .select('id, username, xp')
    .eq('class_code', classCode)
    .eq('is_teacher', false)
    .neq('id', teacherId)   // belt-and-suspenders exclusion by ID
    .order('xp', ascending: false);
```

**Apply the same double-exclusion in `home_screen.dart`'s rival card fetch:**

```dart
// Fetch teacher_id for this class (cache it in a local variable — only fetched once):
Future<void> _loadRival(String classCode, String myId) async {
  // Get the teacher's ID for this class to exclude them definitively
  String? teacherId;
  try {
    final classData = await _supabase
        .from('classes')
        .select('teacher_id')
        .eq('code', classCode)
        .maybeSingle();
    teacherId = classData?['teacher_id'] as String?;
  } catch (_) {
    // If classes lookup fails, fall back to is_teacher filter only
  }

  var query = _supabase
      .from('profiles')
      .select('id, username, xp')
      .eq('class_code', classCode)
      .eq('is_teacher', false)
      .neq('id', myId);    // exclude self

  // Also exclude by teacher ID if available
  if (teacherId != null) {
    query = query.neq('id', teacherId);
  }

  final classmates = await query.order('xp', ascending: false);
  // ... rest of rival logic unchanged ...
}
```

---

## PHASE 7 — LOW PRIORITY CLEANUP

### BUG 8: Non-Standard Week Key Format

**File:** `lib/providers/profile_provider.dart`

**Problem:** `_getIsoWeekKey()` generates `2026-W04-12` (year-month-day of Monday) instead of proper ISO week format `2026-W15`. This works correctly but is confusing and non-standard.

**Find:**
```dart
String _getIsoWeekKey(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year}-W${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}
```

**Replace with:**
```dart
String _getIsoWeekKey(DateTime date) {
  // Calculate the ISO week number correctly.
  // ISO 8601: week 1 is the week containing the first Thursday of the year.
  // Dart does not have a built-in ISO week number — compute it manually.
  final monday = date.subtract(Duration(days: date.weekday - 1));

  // Find the Thursday of this week (Monday + 3 days)
  final thursday = monday.add(const Duration(days: 3));

  // Week 1 of a year contains January 4th. Find the Monday of week 1.
  final jan4 = DateTime(thursday.year, 1, 4);
  final mondayOfWeek1 = jan4.subtract(Duration(days: jan4.weekday - 1));

  // ISO week number = how many weeks since week 1's Monday
  final weekNumber = ((monday.difference(mondayOfWeek1).inDays) / 7).floor() + 1;

  // Format: YYYY-Www (e.g. "2026-W15")
  return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
}
```

**IMPORTANT — Data Migration Warning:** If you change this format, any stored `weekXpResetDate` values in existing users' Hive boxes will no longer match. This means all existing users will have their `weekXp` reset to 0 once after the update (treated as a new week). This is acceptable — it's a one-time reset, not data corruption. Document it as a known migration side effect.

---

## ORDER OF IMPLEMENTATION

**Do exactly this sequence. Do not skip. Do not reorder.**

```
Phase 0: BUG 1 — Fix compile error in teacher_dashboard_screen.dart        [5 min]
         ↳ Verify: flutter analyze shows no errors

Phase 1: BUG 2 — Fix teacher delete account in teacher_profile_screen.dart [15 min]
         ↳ Verify: delete a test teacher → check Supabase, profiles row gone

Phase 2: BUG 4 — Fix healthScore null safety in teacher_dashboard_screen   [5 min]
         ↳ Verify: flutter analyze shows no ! on healthScore

Phase 3: Assignment Mode — implement in this exact sub-order:
  3A — Create unit_words table in Supabase SQL Editor
  3B — Create lib/models/assignment_mode_params.dart
  3C — Add getUnitWords() to lib/services/assignment_service.dart
  3D — Add /assignment-game-select route to lib/router.dart
  3E — Create lib/screens/assignment_game_select_screen.dart
  3F — Wire up home_screen.dart assignment card tap
       ↳ Verify: tap an assignment card → loading spinner → game select screen appears
  3G — Modify all 5 game screens to detect assignment mode and use UnitWord source
       ↳ Verify: launching quiz from assignment select → words are unit words, not personal vocab
  3H — Add post-session assignment progress recording to all 5 game screens
       ↳ Verify: complete an assignment game → check assignment_progress table in Supabase
  3I — Verify home screen progress bar updates after returning from game
       ↳ Verify: progress bar increases on HomeScreen without pulling to refresh

Phase 4: BUG 6 — Fix Navigator.push to GoRouter in teacher_library_screen  [20 min]
         ↳ Verify: tap collection → unit list opens with correct page transition

Phase 5: BUG 3 — Fix AppShell dual builder in router.dart                  [15 min]
         ↳ Verify: delete AppShell, app still compiles and both shells work

Phase 6: BUG 9 — Fix unit list race condition                               [10 min]
         ↳ Verify: open unit list immediately → no units flash "Assign to Class" incorrectly
         BUG 7 — Fix teacher filter double-exclusion                         [15 min]
         ↳ Verify: fresh teacher, student joins immediately → teacher not in rank reveal

Phase 7: BUG 8 — Fix week key format (optional, low priority)               [10 min]
         ↳ Note the one-time weekXp reset side effect in release notes
```

---

## VERIFICATION CHECKLIST

Run all checks after full implementation. Do not mark anything ✓ until manually verified.

### Phase 0 Check
- [ ] `flutter analyze` returns 0 errors, 0 warnings related to try/catch

### Phase 1 Check
- [ ] Log in as a teacher. Go to Profile. Tap Delete Account. Type "DELETE". Confirm.
- [ ] Open Supabase → `profiles` table. The teacher's row is GONE.
- [ ] Open Supabase → `classes` table. The teacher's class row is GONE.
- [ ] Open Supabase → `profiles` table. Students who were in that class have `class_code = null`.
- [ ] Open Supabase → `assignments` table. All assignments for that class have `is_active = false`.

### Phase 2 Check
- [ ] Open the teacher dashboard with students present.
- [ ] In Supabase: find one student. Set their `last_played_date` to a date 5 days ago via SQL.
- [ ] Pull to refresh on dashboard.
- [ ] Dashboard renders without crashing. Health card shows with valid numbers.
- [ ] At-risk section shows the student whose date was set 5 days ago.
- [ ] Force the scenario: set `healthScore` to null manually in a test build. Verify `_buildHealthCardError()` renders instead of crashing.

### Phase 3 Assignment Mode Checks

#### Tap Flow
- [ ] Student is in a class. Teacher has assigned at least one unit. Student's home screen shows an assignment card.
- [ ] Student taps "Practice Now" on the card.
- [ ] A loading spinner appears briefly.
- [ ] `AssignmentGameSelectScreen` appears with: unit title in AppBar, progress bar, due date chip (if set), all 5 game mode cards.

#### Word Source
- [ ] Student picks "Quiz" from the game select screen.
- [ ] Words shown in the quiz are from the assigned library unit — NOT from the student's personal vocabulary.
- [ ] If the student has zero personal words but the unit has 10 words: quiz still works.

#### Per-Word Tracking
- [ ] Student answers 5 quiz questions.
- [ ] Open Supabase → `word_stats` table. 5 new or updated rows exist for this student's `student_id` and their `class_code`.
- [ ] `times_shown` incremented for each word. `times_correct` incremented only for correct answers.
- [ ] Student has no class (no `class_code`). Plays a game. `word_stats` table has ZERO new rows for this student.

#### Post-Session Progress
- [ ] Complete a quiz with 7/10 correct answers.
- [ ] Open Supabase → `assignment_progress`. A row exists for this student + this assignment.
- [ ] `words_mastered` is 7. `total_words` matches the assignment's `word_count`.
- [ ] `is_completed` is false (7 < 10).
- [ ] Return to HomeScreen WITHOUT pulling to refresh.
- [ ] The assignment card's progress bar shows 7/10 immediately (no reload needed).

#### Completion
- [ ] Play until `words_mastered >= total_words`.
- [ ] Supabase `assignment_progress.is_completed` is `true`.

#### XP Still Awarded
- [ ] Complete an assignment game session.
- [ ] Student's XP increases normally (same as personal mode).
- [ ] `profileProvider` state is updated.

### Phase 4 Check
- [ ] Teacher taps a collection in the Library tab.
- [ ] `TeacherUnitListScreen` opens with the same slide transition as all other screens.
- [ ] Navigate back. Navigate forward again. No crash or blank screen.

### Phase 5 Check
- [ ] `lib/screens/app_shell.dart` is deleted.
- [ ] `flutter analyze` shows no missing imports or reference errors.
- [ ] Log in as student → student shell (5 student tabs).
- [ ] Log in as teacher → teacher shell (5 teacher tabs).
- [ ] Log out as teacher → log in as student → still student shell (no lingering teacher state).

### Phase 6 Check
- [ ] Teacher assigns Unit 3 to class. Navigate away. Navigate back to Library → that collection.
- [ ] Unit 3 shows "Assigned ✓" immediately — no flash of "Assign to Class" first.
- [ ] Student joins class immediately after teacher creates it. Student opens app.
- [ ] Student's rank reveal dialog does NOT show the teacher in the class leaderboard.
- [ ] Student's Rival Card on HomeScreen does NOT show the teacher as a rival.

---

*End of Document. Every bug is here. Every line is exact. Implement in order.*
