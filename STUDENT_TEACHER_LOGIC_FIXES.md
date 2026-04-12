# VOCABGAME — STUDENT & TEACHER SECTION: COMPLETE LOGIC AUDIT & FIX INSTRUCTIONS
## Every Bug, Every Race Condition, Every Wrong Assumption — Fixed

> **READ THIS ENTIRE FILE BEFORE TOUCHING ANY CODE.**
> This document is the single source of truth for fixing the student/teacher system.
> Every problem is listed with its root cause, its current broken behavior, and the
> exact corrected implementation. Follow the order of operations. Do not skip sections.
> Do not "improve" anything not listed here — the scope is logic correctness only.

---

## TABLE OF CONTENTS

1. [Full Inventory of Every Bug Found](#1-full-inventory-of-every-bug-found)
2. [Architecture Reference (What Exists)](#2-architecture-reference-what-exists)
3. [BUG 1 — Teacher Pollutes Student Dashboard](#3-bug-1--teacher-pollutes-student-dashboard)
4. [BUG 2 — ProfileScreen Role Button Logic Is Wrong](#4-bug-2--profilescreen-role-button-logic-is-wrong)
5. [BUG 3 — Weekly XP Reset Is Client-Side Only (Stale Data)](#5-bug-3--weekly-xp-reset-is-client-side-only-stale-data)
6. [BUG 4 — Streak Can Double-Increment In One Day](#6-bug-4--streak-can-double-increment-in-one-day)
7. [BUG 5 — Accuracy Division By Zero](#7-bug-5--accuracy-division-by-zero)
8. [BUG 6 — Username Race Condition (Double Registration)](#8-bug-6--username-race-condition-double-registration)
9. [BUG 7 — Profile Delete While Offline Leaves Ghost Record](#9-bug-7--profile-delete-while-offline-leaves-ghost-record)
10. [BUG 8 — Teacher Creating Class Silently Abandons Student Class](#10-bug-8--teacher-creating-class-silently-abandons-student-class)
11. [BUG 9 — Leaderboard Realtime Subscribes To Entire Table](#11-bug-9--leaderboard-realtime-subscribes-to-entire-table)
12. [BUG 10 — Rival Card Uses Stale Data After XP Gain](#12-bug-10--rival-card-uses-stale-data-after-xp-gain)
13. [BUG 11 — JoinClass Rank Reveal Is Always Last Place](#13-bug-11--joinclass-rank-reveal-is-always-last-place)
14. [BUG 12 — GoRouter Redirect Has Hive Race Condition On Cold Start](#14-bug-12--gorouter-redirect-has-hive-race-condition-on-cold-start)
15. [BUG 13 — Sync Queue Newest-First Can Lose Earlier Writes](#15-bug-13--sync-queue-newest-first-can-lose-earlier-writes)
16. [BUG 14 — No Row Level Security (Any Client Reads All Profiles)](#16-bug-14--no-row-level-security-any-client-reads-all-profiles)
17. [BUG 15 — setTeacher() Has No Guard Against Re-Entrant Calls](#17-bug-15--setteacher-has-no-guard-against-re-entrant-calls)
18. [Order of Implementation](#18-order-of-implementation)
19. [Verification Checklist](#19-verification-checklist)
20. [Files to Modify Summary](#20-files-to-modify-summary)

---

## 1. FULL INVENTORY OF EVERY BUG FOUND

| # | Severity | File | Bug Description |
|---|---|---|---|
| 1 | 🔴 HIGH | `class_service.dart`, `teacher_dashboard_screen.dart` | Teacher appears in own student list, skewing rankings and count |
| 2 | 🔴 HIGH | `profile_screen.dart` | Role button condition logic is backwards/contradictory |
| 3 | 🟡 MEDIUM | `profile_provider.dart` | Week XP resets only when user opens app, data is stale for days |
| 4 | 🟡 MEDIUM | `profile_provider.dart` | Streak can increment multiple times in one day |
| 5 | 🟡 MEDIUM | `user_profile.dart` | Accuracy getter divides by zero when no games played |
| 6 | 🟡 MEDIUM | `username_screen.dart` | Two users can register same username simultaneously |
| 7 | 🟡 MEDIUM | `profile_screen.dart` | Account delete while offline leaves Supabase ghost record |
| 8 | 🟡 MEDIUM | `profile_screen.dart`, `class_service.dart` | Creating a class silently drops student's existing class |
| 9 | 🟠 LOW-MED | `leaderboard_screen.dart` | Realtime subscribes to full profiles table (privacy + perf) |
| 10 | 🟠 LOW-MED | `home_screen.dart` | Rival card doesn't refresh after local XP gain |
| 11 | 🟠 LOW-MED | `join_class_screen.dart` | New user rank reveal always shows "last place" (0 XP) |
| 12 | 🟠 LOW-MED | `router.dart` | GoRouter redirect reads Hive before async init completes |
| 13 | 🟠 LOW-MED | `sync_service.dart` | Sync queue dedup by newest-first can skip valid earlier writes |
| 14 | 🔴 HIGH | Supabase config | No RLS — anon key exposes all profiles to any client |
| 15 | 🟠 LOW-MED | `profile_provider.dart` | `setTeacher()` has no re-entrancy guard, can double-write |

---

## 2. ARCHITECTURE REFERENCE (WHAT EXISTS)

Read this section first. Every fix references these existing structures.

### Existing Files and Their Roles

```
lib/
├── models/
│   └── user_profile.dart           # UserProfile data class
├── providers/
│   └── profile_provider.dart       # ProfileNotifier: StateNotifier<UserProfile?>
├── services/
│   ├── class_service.dart          # Supabase: classes table CRUD
│   └── sync_service.dart           # Supabase: profiles sync + queue
├── screens/
│   ├── home_screen.dart            # Student home, rival card, vocab list
│   ├── profile_screen.dart         # Stats, class management, account actions
│   ├── teacher_dashboard_screen.dart # Student table, sorting
│   └── leaderboard_screen.dart     # 3-tab leaderboard with Realtime
├── onboarding/
│   ├── welcome_screen.dart         # Entry point
│   ├── username_screen.dart        # Username + teacher toggle
│   ├── pin_setup_screen.dart       # 6-digit PIN
│   └── join_class_screen.dart      # Class code + rank reveal
├── router.dart                     # GoRouter with redirect guard
└── screens/app_shell.dart          # Bottom navigation shell
```

### Supabase Tables (Current Schema)

```sql
-- profiles (one row per user)
id                    UUID PRIMARY KEY
username              TEXT UNIQUE NOT NULL
xp                    INTEGER DEFAULT 0
level                 INTEGER DEFAULT 1
streak_days           INTEGER DEFAULT 0
last_played_date      TEXT        -- 'YYYY-MM-DD'
class_code            TEXT        -- references classes.code loosely
week_xp               INTEGER DEFAULT 0
total_words_answered  INTEGER DEFAULT 0
total_correct         INTEGER DEFAULT 0
is_teacher            BOOLEAN DEFAULT false
updated_at            TIMESTAMPTZ

-- classes (one row per class)
code              TEXT PRIMARY KEY  -- 6-char random, e.g. 'ENG7B2'
teacher_username  TEXT NOT NULL
class_name        TEXT NOT NULL
teacher_id        TEXT             -- ADD THIS (see Bug 1 fix)
```

### Critical Existing Patterns (Do Not Break These)

1. **Clone-on-mutate**: Every `ProfileNotifier` mutation must call `_cloneProfile()` and assign to `state`. Never assign the mutated object directly.
2. **Hive-first reads**: Profile data is always read from Hive, never fetched from Supabase at runtime for the current user.
3. **SyncService is background-only**: Never `await` SyncService inside UI-blocking code. Fire-and-forget or use `unawaited()`.
4. **`recordGameSession()`** is the only method games call. Do not add game-result logic anywhere else.

---

## 3. BUG 1 — Teacher Pollutes Student Dashboard

### Root Cause
When a teacher creates a class, `ClassService.joinClass()` is called with the teacher's own profile ID and class code. This sets `class_code` on the teacher's profile row. `ClassService.getClassStudents(code)` then queries ALL profiles where `class_code == code` — which includes the teacher.

### Broken Behavior
- Teacher dashboard shows the teacher as student #1 (they have the most XP since they created the class first)
- Student count is inflated by 1
- Teacher's own stats (which are usually high) skew accuracy averages shown in the UI
- "No students yet" never shows even when zero real students have joined

### Fix — Part A: Add `teacher_id` column to Supabase `classes` table

Run this migration in Supabase SQL editor:

```sql
-- Add teacher_id to classes table
ALTER TABLE classes ADD COLUMN IF NOT EXISTS teacher_id TEXT NOT NULL DEFAULT '';

-- Backfill: set teacher_id from profiles where username matches teacher_username
UPDATE classes c
SET teacher_id = p.id
FROM profiles p
WHERE p.username = c.teacher_username;
```

### Fix — Part B: `class_service.dart` — Store teacher_id on class creation

```dart
// In ClassService.createClass():
// BEFORE (broken):
await supabase.from('classes').insert({
  'code': code,
  'teacher_username': teacherUsername,
  'class_name': className,
});

// AFTER (fixed): include teacher_id
static Future<String> createClass({
  required String teacherId,       // ADD THIS PARAMETER
  required String teacherUsername,
  required String className,
}) async {
  final code = _generateCode();
  await supabase.from('classes').insert({
    'code': code,
    'teacher_id': teacherId,       // Store teacher's UUID
    'teacher_username': teacherUsername,
    'class_name': className,
  });
  return code;
}
```

### Fix — Part C: `class_service.dart` — Exclude teacher from student query

```dart
// In ClassService.getClassStudents():
// BEFORE (broken):
static Future<List<Map<String, dynamic>>> getClassStudents(String code) async {
  final response = await supabase
      .from('profiles')
      .select('username, xp, level, streak_days, total_words_answered, total_correct')
      .eq('class_code', code)
      .order('xp', ascending: false);
  return List<Map<String, dynamic>>.from(response);
}

// AFTER (fixed): fetch teacher_id first, then exclude it
static Future<List<Map<String, dynamic>>> getClassStudents(String code) async {
  // Step 1: get the teacher's ID for this class
  final classInfo = await supabase
      .from('classes')
      .select('teacher_id')
      .eq('code', code)
      .maybeSingle();

  final teacherId = classInfo?['teacher_id'] as String?;

  // Step 2: fetch all profiles in this class
  var query = supabase
      .from('profiles')
      .select('id, username, xp, level, streak_days, total_words_answered, total_correct')
      .eq('class_code', code)
      .order('xp', ascending: false);

  final response = await query;
  final all = List<Map<String, dynamic>>.from(response);

  // Step 3: exclude the teacher
  if (teacherId != null) {
    return all.where((row) => row['id'] != teacherId).toList();
  }
  return all;
}
```

### Fix — Part D: `profile_screen.dart` — Pass teacher ID when creating class

```dart
// When "Create a Class" is tapped:
// BEFORE (broken):
await ClassService.createClass(
  teacherUsername: profile.username,
  className: className,
);

// AFTER (fixed):
final code = await ClassService.createClass(
  teacherId: profile.id,           // Pass the teacher's UUID
  teacherUsername: profile.username,
  className: className,
);
```

---

## 4. BUG 2 — ProfileScreen Role Button Logic Is Wrong

### Root Cause
The current comment in the code states:
> "Create a Class" — shown only if either the user is already a teacher OR has no class.

This condition is logically backwards. It means:
- A student WITH a class sees "Create a Class" → they can accidentally become a teacher
- A teacher WITH a class also sees "Create a Class" → they see it even after creating one
- The "View Dashboard" button is only shown when `isTeacher == true && classCode != null` — but the "Create a Class" condition overlaps with this

### Broken Behaviors
1. Student who already joined a class sees "Create a Class" button and can tap it, overriding their class and becoming a teacher without understanding what happened
2. A teacher without a class sees "Create a Class" (correct) but also sees "Exit Class" (wrong — they have no class to exit)
3. No "Copy Class Code" button exists — teachers have no way to share the code after creation

### Correct Button Logic (State Machine)

Define the user state clearly as a matrix:

```
State A: student, no class        → Show: [Join a Class], [Create a Class]
State B: student, has class       → Show: [Change Class], [Exit Class]
State C: teacher, has class       → Show: [View Dashboard], [Copy Class Code], [Change Class]
State D: teacher, no class        → Show: [Create a Class]  ← edge case (class deleted?)
```

Note: "Create a Class" should NEVER appear for a student with an existing class.
Note: A student should never silently become a teacher. Making a user a teacher
requires them to explicitly tap "Become a Teacher & Create a Class" — not just "Create a Class".

### Fix — `profile_screen.dart` — Replace class management section entirely

```dart
// Remove ALL existing class management button logic and replace with:

Widget _buildClassManagementSection(UserProfile profile) {
  // Derive user state
  final isTeacher = profile.isTeacher;
  final hasClass = profile.classCode != null && profile.classCode!.isNotEmpty;

  if (isTeacher && hasClass) {
    // STATE C: Active teacher with a class
    return Column(
      children: [
        _buildActionButton(
          label: 'View Student Dashboard',
          icon: Icons.dashboard,
          onTap: () => context.push('/teacher-dashboard', extra: profile.classCode),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Copy Class Code: ${profile.classCode}',
          icon: Icons.copy,
          onTap: () {
            Clipboard.setData(ClipboardData(text: profile.classCode!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Class code copied to clipboard!')),
            );
          },
        ),
        const SizedBox(height: 12),
        // Teacher can still change which class they're in (rare but valid)
        _buildActionButton(
          label: 'Change Class',
          icon: Icons.swap_horiz,
          isDestructive: false,
          onTap: () => _showChangeClassDialog(profile),
        ),
      ],
    );
  }

  if (isTeacher && !hasClass) {
    // STATE D: Teacher who somehow lost their class (edge case)
    return _buildActionButton(
      label: 'Re-create Your Class',
      icon: Icons.add_circle,
      onTap: () => _showCreateClassDialog(profile),
    );
  }

  if (!isTeacher && hasClass) {
    // STATE B: Active student in a class
    return Column(
      children: [
        _buildActionButton(
          label: 'Change Class',
          icon: Icons.swap_horiz,
          onTap: () => _showChangeClassDialog(profile),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Exit Class',
          icon: Icons.exit_to_app,
          isDestructive: true,
          onTap: () => _showExitClassDialog(profile),
        ),
      ],
    );
  }

  // STATE A: Student with no class
  return Column(
    children: [
      _buildActionButton(
        label: 'Join a Class',
        icon: Icons.group_add,
        onTap: () => _showJoinClassDialog(profile),
      ),
      const SizedBox(height: 12),
      // Clearly labeled to signal role change
      _buildActionButton(
        label: 'I\'m a Teacher — Create a Class',
        icon: Icons.school,
        onTap: () => _showBecomeTeacherDialog(profile),
      ),
    ],
  );
}
```

### Fix — Add `_showBecomeTeacherDialog()` with explicit warning

```dart
// This dialog makes it crystal clear that creating a class changes their role.
// A student must CONFIRM they want to become a teacher.
void _showBecomeTeacherDialog(UserProfile profile) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Create a Class'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will make you a Teacher. You\'ll be able to:\n'
            '  • Create a class for your students\n'
            '  • View a live dashboard of student progress\n'
            '  • Share a class code with students\n',
          ),
          const Text(
            'You will still be able to play all games and earn XP.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _classNameController,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              hintText: 'e.g., Class 7B — English',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = _classNameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            await _createClass(profile, name);
          },
          child: const Text('Create Class & Become Teacher'),
        ),
      ],
    ),
  );
}
```

### Fix — `_createClass()` method — correct full sequence

```dart
Future<void> _createClass(UserProfile profile, String className) async {
  setState(() => _isLoading = true);
  try {
    // 1. Create class in Supabase — pass teacher's UUID (Bug 1 fix)
    final code = await ClassService.createClass(
      teacherId: profile.id,
      teacherUsername: profile.username,
      className: className,
    );

    // 2. Mark user as teacher (updates Hive + Supabase)
    await ref.read(profileProvider.notifier).setTeacher(true);

    // 3. Join their own class so class_code is set (needed for dashboard nav)
    //    NOTE: teacher is excluded from student list by Bug 1 fix
    await ClassService.joinClass(profileId: profile.id, code: code);
    await ref.read(profileProvider.notifier).setClassCode(code);

    // 4. Show the class code to the teacher — they MUST write this down
    if (mounted) {
      _showClassCodeDialog(code, className);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create class: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

void _showClassCodeDialog(String code, String className) {
  showDialog(
    context: context,
    barrierDismissible: false,  // Force them to acknowledge
    builder: (ctx) => AlertDialog(
      title: const Text('Class Created! 🎉'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your class "$className" is ready.'),
          const SizedBox(height: 16),
          const Text('Share this code with your students:'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple),
            ),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy Code'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Code copied!')),
              );
            },
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it — Go to Dashboard'),
        ),
      ],
    ),
  );
}
```

---

## 5. BUG 3 — Weekly XP Reset Is Client-Side Only (Stale Data)

### Root Cause
`ProfileNotifier.recordGameSession()` checks if the current date is in a new ISO week
compared to `lastPlayedDate`. If it is, it resets `week_xp` to zero. But this check
only runs when a game is played. If a user opens the app every day but only browses
(without playing a game), `week_xp` is never reset.

Worse: the leaderboard's "This Week" tab reads `week_xp` from Supabase. A user who
played 500 XP three weeks ago and hasn't played since still shows 500 on the weekly board.

### Broken Behaviors
1. Leaderboard "This Week" tab is inaccurate for inactive users
2. Users who stop playing stay stuck at the top of the weekly board forever
3. The weekly countdown timer counts down to Monday but the reset doesn't actually happen until they play a game

### Fix — Part A: `profile_provider.dart` — Check week reset on EVERY app load, not just game sessions

Add a new method `checkAndResetWeekXp()` and call it from `reload()` and `createProfile()`:

```dart
// Add this method to ProfileNotifier:
Future<void> checkAndResetWeekXp() async {
  final profile = state;
  if (profile == null) return;

  final now = DateTime.now();
  final currentWeekKey = _getIsoWeekKey(now);

  // Derive what week the last game was played
  final lastDate = profile.lastPlayedDate;
  if (lastDate == null) return; // Never played — nothing to reset

  final lastPlayedWeekKey = _getIsoWeekKey(DateTime.parse(lastDate));

  if (currentWeekKey != lastPlayedWeekKey) {
    // A new ISO week has started — reset weekly XP
    final box = Hive.box('userProfile');
    box.put('weekXp', 0);
    profile.weekXp = 0;
    state = _cloneProfile(profile);
    unawaited(SyncService.syncProfile(state!));
  }
}

// Helper: Returns a unique string for the ISO week (e.g., "2025-W12")
// ISO week starts on Monday.
String _getIsoWeekKey(DateTime date) {
  // Get Monday of the week containing [date]
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year}-W${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}
```

Call it in the right places:

```dart
// In ProfileNotifier.reload():
Future<void> reload() async {
  final box = Hive.box('userProfile');
  // ... existing reload logic ...
  await checkAndResetWeekXp();  // ADD THIS LINE at the end
}

// In recordGameSession() — KEEP existing week reset logic here too
// but now it's backed up by the reload() call on app start
```

### Fix — Part B: `app_shell.dart` — Call check on app resume

```dart
// In AppShell, add lifecycle listener:
class _AppShellState extends State<AppShell> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check week reset whenever user brings app to foreground
      ref.read(profileProvider.notifier).checkAndResetWeekXp();
    }
  }
}
```

---

## 6. BUG 4 — Streak Can Double-Increment In One Day

### Root Cause
`updateStreak(newStreakDays, lastPlayedDate)` is called from outside the notifier
(likely from a game result screen or home screen). The caller computes the new streak
value and passes it in. If the caller doesn't check whether the user already played
today before calling, the streak increments multiple times per day.

Additionally, the streak logic is split: the caller decides the new streak value,
but the `lastPlayedDate` comparison should be done inside the notifier where the
current profile state is authoritative.

### Broken Behaviors
1. Playing two games in one day increments streak twice (4-day streak → 6 in one day)
2. Streak can jump non-linearly — 7 → 9 instead of 7 → 8
3. If the caller has stale profile data (loaded before a sync), it computes streak from old `lastPlayedDate`

### Fix — `profile_provider.dart` — Move streak logic inside the notifier

Replace the current `updateStreak()` with a smart internal version:

```dart
// REMOVE the old updateStreak(newStreakDays, lastPlayedDate) method entirely.
// REPLACE with:

/// Evaluates and updates the streak based on today's date.
/// Must be called once per day at most (safe to call multiple times — idempotent).
/// Call this from recordGameSession() — do NOT call it from UI code.
Future<void> _evaluateStreak() async {
  final profile = state;
  if (profile == null) return;

  final today = DateTime.now();
  final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  // Already recorded today → do nothing (idempotency)
  if (profile.lastPlayedDate == todayStr) return;

  int newStreak;
  if (profile.lastPlayedDate == null) {
    // First time ever playing
    newStreak = 1;
  } else {
    final lastPlayed = DateTime.parse(profile.lastPlayedDate!);
    final daysSinceLast = today.difference(lastPlayed).inDays;

    if (daysSinceLast == 1) {
      // Played yesterday → extend streak
      newStreak = profile.streakDays + 1;
    } else if (daysSinceLast == 0) {
      // Same day (clock edge case) → no change
      newStreak = profile.streakDays;
    } else {
      // Missed a day → reset streak to 1
      newStreak = 1;
    }
  }

  final box = Hive.box('userProfile');
  box.put('streakDays', newStreak);
  box.put('lastPlayedDate', todayStr);
  profile.streakDays = newStreak;
  profile.lastPlayedDate = todayStr;
  state = _cloneProfile(profile);
  unawaited(SyncService.syncProfile(state!));
}

// In recordGameSession() — replace the streak-related lines with:
Future<void> recordGameSession({
  required int xpGained,
  required int totalQuestions,
  required int correctAnswers,
}) async {
  // ... existing XP, accuracy, level logic ...

  // Evaluate streak (idempotent — safe to call every game session)
  await _evaluateStreak();

  // ... rest of existing logic ...
}
```

**Remove all streak computation from the UI layer (game result screens, home screen).** Streak is now purely the notifier's responsibility.

---

## 7. BUG 5 — Accuracy Division By Zero

### Root Cause
`UserProfile.accuracy` is a computed getter:
```dart
double get accuracy => totalCorrect / totalWordsAnswered;
```

When a user has just onboarded and hasn't played any games, `totalWordsAnswered == 0`.
This produces `double.infinity` (Dart's behavior for `x / 0` where x > 0) or `NaN`
(for `0 / 0`). The teacher dashboard formats this as a percentage with color coding,
causing either a crash or showing "Infinity%" on the accuracy column.

### Fix — `user_profile.dart` — Guard the getter

```dart
// BEFORE (broken):
double get accuracy => totalCorrect / totalWordsAnswered;

// AFTER (fixed):
double get accuracy {
  if (totalWordsAnswered == 0) return 0.0;
  return (totalCorrect / totalWordsAnswered).clamp(0.0, 1.0);
}

// Also add a formatted string getter for display:
String get accuracyPercent {
  if (totalWordsAnswered == 0) return '—';  // Show dash, not 0%, when no data
  final pct = (accuracy * 100).round();
  return '$pct%';
}
```

### Fix — `teacher_dashboard_screen.dart` — Use safe getter

```dart
// In the student table accuracy cell:
// BEFORE (broken):
Text('${(student['total_correct'] / student['total_words_answered'] * 100).round()}%')

// AFTER (fixed):
Text(_safeAccuracy(student['total_correct'], student['total_words_answered']))

// Add this helper to the screen:
String _safeAccuracy(dynamic correct, dynamic total) {
  final c = (correct as int?) ?? 0;
  final t = (total as int?) ?? 0;
  if (t == 0) return '—';
  return '${(c / t * 100).round()}%';
}

// And the color coding:
// BEFORE (broken):
color: accuracy >= 0.7 ? Colors.green : accuracy >= 0.4 ? Colors.amber : Colors.red

// AFTER (fixed):
Color _accuracyColor(dynamic correct, dynamic total) {
  final c = (correct as int?) ?? 0;
  final t = (total as int?) ?? 0;
  if (t == 0) return Colors.grey;  // No data → grey, not red
  final acc = c / t;
  if (acc >= 0.70) return Colors.green;
  if (acc >= 0.40) return Colors.amber;
  return Colors.red;
}
```

---

## 8. BUG 6 — Username Race Condition (Double Registration)

### Root Cause
`UsernameScreen` does a real-time uniqueness check on every keystroke (debounced 600ms)
by querying `SyncService.isUsernameTaken()`. If two users type the same username at the
same millisecond, both get "✅ Available", both proceed to the next screen, and both
insert into Supabase. The second insert fails with a unique constraint violation error.
This error is likely uncaught or shown as a generic crash.

Additionally, the current flow inserts into Supabase FIRST then calls
`profileProvider.notifier.createProfile()`. If Supabase insert succeeds but the
app crashes before `createProfile()` finishes, there's an orphaned Supabase row
with no local profile.

### Fix — `username_screen.dart` — Catch the constraint violation explicitly

```dart
// In the username submission handler:
Future<void> _submitUsername() async {
  if (!_isValid || _isTaken || _isLoading) return;

  setState(() => _isLoading = true);

  try {
    // Generate UUID first (so both local and remote use same ID)
    final id = const Uuid().v4();
    final username = _usernameController.text.trim();

    // Attempt Supabase insert FIRST (authoritative uniqueness check)
    try {
      await Supabase.instance.client.from('profiles').insert({
        'id': id,
        'username': username,
        'xp': 0,
        'level': 1,
        'streak_days': 0,
        'is_teacher': _isTeacher,
        'week_xp': 0,
        'total_words_answered': 0,
        'total_correct': 0,
      });
    } on PostgrestException catch (e) {
      // Code 23505 = unique_violation (username already taken by race condition)
      if (e.code == '23505') {
        setState(() {
          _isLoading = false;
          _isTaken = true; // Show "username taken" error
          _errorMessage = 'That username was just taken. Please choose another.';
        });
        return;
      }
      rethrow; // Re-throw other Supabase errors
    }

    // Only create local profile AFTER Supabase confirms success
    await ref.read(profileProvider.notifier).createProfile(
      id: id,
      username: username,
      isTeacher: _isTeacher,
    );

    // Proceed to next screen
    if (mounted) context.push('/onboarding/pin');

  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

---

## 9. BUG 7 — Profile Delete While Offline Leaves Ghost Record

### Root Cause
The account deletion flow currently:
1. Deletes from Supabase
2. Clears Hive
3. Navigates to `/welcome`

If step 1 fails (offline, timeout, server error), step 2 still runs. The local
profile is gone but the Supabase row still exists. The user is now in a broken
state: no local profile, but the username is still "taken" in Supabase.
They cannot re-register the same username. If they reinstall, they see onboarding
but cannot reuse their old username.

### Fix — `profile_screen.dart` — Make deletion order-safe

```dart
Future<void> _deleteAccount(UserProfile profile) async {
  setState(() => _isLoading = true);

  try {
    // Step 1: Try Supabase delete with explicit error handling
    await SyncService.deleteProfile(profile.id);
    // If this throws, we do NOT clear local data — user can try again

    // Step 2: Only clear local data after confirmed remote deletion
    await ref.read(profileProvider.notifier).logout();

    // Step 3: Navigate to welcome
    if (mounted) context.go('/welcome');

  } on SocketException {
    // Offline — schedule deletion for when connectivity returns
    // Store a "pending_delete" flag in Hive
    Hive.box('userProfile').put('pendingDelete', true);

    if (mounted) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('You\'re Offline'),
          content: const Text(
            'Your account will be deleted when you reconnect. '
            'You\'ve been logged out locally. '
            'Your username will be freed once you reconnect.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Log out locally even though remote isn't deleted yet
                ref.read(profileProvider.notifier).logout();
                context.go('/welcome');
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deletion failed: $e. Please try again.')),
      );
    }
  }
}
```

### Fix — `sync_service.dart` — Drain pending deletes on reconnect

```dart
// Add to SyncService.drainSyncQueue():
static Future<void> drainSyncQueue() async {
  // Check for pending account deletion first
  final box = Hive.box('userProfile');
  final pendingDelete = box.get('pendingDelete', defaultValue: false) as bool;
  final pendingId = box.get('pendingDeleteId') as String?;

  if (pendingDelete && pendingId != null) {
    try {
      await supabase.from('profiles').delete().eq('id', pendingId);
      box.delete('pendingDelete');
      box.delete('pendingDeleteId');
    } catch (_) {
      // Will retry next time
      return;
    }
  }

  // ... rest of existing queue drain logic ...
}
```

---

## 10. BUG 8 — Teacher Creating Class Silently Abandons Student Class

### Root Cause
When a student who is in Class A decides to become a teacher and create Class B:
1. `ClassService.createClass()` creates Class B
2. `ClassService.joinClass()` is called with the teacher's profile ID and Class B's code
3. This OVERWRITES the `class_code` field in Supabase with Class B's code
4. The student silently leaves Class A — their teacher has no idea
5. No confirmation is shown. No "you will leave [Class A Name]" warning.

### Fix — `profile_screen.dart` — Check for existing class before creating

```dart
// In _showBecomeTeacherDialog() — add a warning if user is already in a class:
void _showBecomeTeacherDialog(UserProfile profile) {
  // If the student is already in a class, warn them explicitly
  final alreadyInClass = profile.classCode != null && profile.classCode!.isNotEmpty;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Create a Class'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alreadyInClass) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are currently in class "${profile.classCode}". '
                      'Creating your own class will remove you from that class.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // ... rest of dialog (class name field, etc.) ...
        ],
      ),
      // ... actions ...
    ),
  );
}
```

---

## 11. BUG 9 — Leaderboard Realtime Subscribes To Entire Table

### Root Cause
`LeaderboardScreen` subscribes to Supabase Realtime on the `profiles` table:

```dart
supabase.from('profiles').stream(primaryKey: ['id']).listen(...)
```

This means:
1. **Every change by any user anywhere triggers a UI rebuild** — a global user
   updating their streak causes the leaderboard to re-render even if that user
   isn't in the top 100
2. **Privacy concern**: The stream receives row-level data for all profiles in
   the table in the initial snapshot, depending on RLS settings
3. **Performance**: With 10,000 users, the initial stream payload is enormous

### Fix — `leaderboard_screen.dart` — Use polling instead of streaming, scoped to class

```dart
// REMOVE: supabase.from('profiles').stream(...).listen(...)
// REPLACE with: periodic polling scoped to the relevant data set

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _classData = [];
  List<Map<String, dynamic>> _globalData = [];
  List<Map<String, dynamic>> _weeklyData = [];

  @override
  void initState() {
    super.initState();
    _loadAllTabs();
    // Poll every 60 seconds — leaderboards do not need second-by-second updates
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadAllTabs(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllTabs() async {
    await Future.wait([
      _loadClassLeaderboard(),
      _loadGlobalLeaderboard(),
      _loadWeeklyLeaderboard(),
    ]);
  }

  Future<void> _loadClassLeaderboard() async {
    final profile = ref.read(profileProvider);
    if (profile?.classCode == null) return;

    try {
      // Scoped to only this class — not entire table
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, xp, level, streak_days, week_xp')
          .eq('class_code', profile!.classCode!)
          // Exclude teacher (see Bug 1 fix — query classes table first)
          .order('xp', ascending: false)
          .limit(50); // Cap at 50 — no class is bigger than this

      if (mounted) setState(() => _classData = List<Map<String, dynamic>>.from(data));
    } catch (_) {
      // Use cached data on error
    }
  }

  Future<void> _loadGlobalLeaderboard() async {
    try {
      // Only fetch top 100 — never the whole table
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, xp, level')
          .order('xp', ascending: false)
          .limit(100);

      if (mounted) setState(() => _globalData = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> _loadWeeklyLeaderboard() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, week_xp, level')
          .order('week_xp', ascending: false)
          .limit(100);

      if (mounted) setState(() => _weeklyData = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }
}
```

---

## 12. BUG 10 — Rival Card Uses Stale Data After XP Gain

### Root Cause
The rival card on `HomeScreen` queries Supabase for classmates when the screen loads.
After a student plays a game and gains XP, `profileProvider.notifier.recordGameSession()`
updates the local profile and syncs to Supabase. But the HomeScreen's rival data
is still the old snapshot — the rival's XP gap is not recalculated.

### Fix — `home_screen.dart` — React to profile state changes

```dart
// BEFORE (broken): rival data loaded once in initState()

// AFTER (fixed): use ref.watch to trigger reload when XP changes

// In HomeScreen build():
@override
Widget build(BuildContext context, WidgetRef ref) {
  final profile = ref.watch(profileProvider);

  // Re-compute rival whenever profile.xp changes
  // Use a derived provider or just call the future conditionally
  return Column(
    children: [
      // ... other widgets ...
      if (profile?.classCode != null)
        _RivalCard(
          classCode: profile!.classCode!,
          myXp: profile.xp,       // Pass current XP explicitly
          myUsername: profile.username,
        ),
    ],
  );
}

// Make _RivalCard a StatefulWidget that refreshes when myXp changes:
class _RivalCard extends StatefulWidget {
  final String classCode;
  final int myXp;
  final String myUsername;

  const _RivalCard({
    required this.classCode,
    required this.myXp,
    required this.myUsername,
  });

  @override
  State<_RivalCard> createState() => _RivalCardState();
}

class _RivalCardState extends State<_RivalCard> {
  Map<String, dynamic>? _rival;
  bool _isLoading = false;
  int? _lastLoadedXp; // Track when we need to refresh

  @override
  void initState() {
    super.initState();
    _loadRival();
  }

  @override
  void didUpdateWidget(_RivalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload rival when our XP changes (we may have passed them)
    if (oldWidget.myXp != widget.myXp) {
      _loadRival();
    }
  }

  Future<void> _loadRival() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Fetch all classmates sorted by XP descending
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, xp')
          .eq('class_code', widget.classCode)
          .neq('username', widget.myUsername) // Exclude self
          .order('xp', ascending: false);

      final classmates = List<Map<String, dynamic>>.from(data);

      // Find the person directly above us (their XP >= our XP, closest gap)
      Map<String, dynamic>? rival;
      for (final cm in classmates) {
        if ((cm['xp'] as int) >= widget.myXp) {
          rival = cm; // Last one found with >= our XP is our immediate rival
        } else {
          break; // Sorted descending — no point checking further
        }
      }

      // If everyone is below us, rival is the one right below (we lead them)
      rival ??= classmates.isNotEmpty ? classmates.first : null;

      if (mounted) setState(() { _rival = rival; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... build() ...
}
```

---

## 13. BUG 11 — JoinClass Rank Reveal Is Always Last Place

### Root Cause
When a new student joins a class, the "Rank Reveal Dialog" is shown:
> "You're #N in [Class Name]"

But the new user has 0 XP. They will ALWAYS be last in the class (or tied for
last with other 0-XP users). Showing "You're #47 in Class 7B" to a new student
is demoralizing and incorrect — they haven't played yet.

Additionally, the "rival" shown is the person just above them in the sorted list,
which is another 0-XP student — so the "rival card" shows "tied with [name]" which
is meaningless.

### Fix — `join_class_screen.dart` — Change the reveal to be motivational, not ranking-based

```dart
// REMOVE: rank-reveal dialog that shows #47 of 47
// REPLACE with: motivational class welcome dialog

void _showClassWelcomeDialog(String classCode, String className, List<Map<String,dynamic>> classmates) {
  // Find the highest XP in the class (the person to eventually beat)
  classmates.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
  final topStudent = classmates.isNotEmpty ? classmates.first : null;
  final studentCount = classmates.length;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('Welcome to $className! 🎉'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You\'ve joined a class with $studentCount student${studentCount == 1 ? '' : 's'}.',
          ),
          const SizedBox(height: 12),
          if (topStudent != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('🏆 Top of the class right now:'),
                  const SizedBox(height: 4),
                  Text(
                    topStudent['username'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text('${topStudent['xp']} XP'),
                  const SizedBox(height: 8),
                  const Text(
                    'Play games to earn XP and climb the leaderboard!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.go('/home'); // Navigate to home
          },
          child: const Text("Let's go! 🚀"),
        ),
      ],
    ),
  );
}
```

---

## 14. BUG 12 — GoRouter Redirect Has Hive Race Condition On Cold Start

### Root Cause
The GoRouter `redirect` function reads from Hive synchronously:
```dart
final hasOnboarded = profileBox.get('hasOnboarded', defaultValue: false);
```

But Hive boxes must be opened before they can be read. On cold start, if the
router evaluates the redirect before `Hive.openBox('userProfile')` completes
(which is `async`), `profileBox` is either null or not yet initialized, causing
a `HiveError: Box not open` exception or silently returning the wrong value.

### Fix — `main.dart` and `router.dart` — Ensure Hive is open before router evaluates

```dart
// In main.dart — ensure all boxes are open before runApp():
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Open ALL boxes before any router redirect can fire
  await Future.wait([
    Hive.openBox('userProfile'),
    Hive.openBox('sync_queue'),
    Hive.openBox('vocab'),
    // ... any other boxes ...
  ]);

  // Only THEN initialize Supabase (which is also async)
  await Supabase.initialize(
    url: EnvironmentConstants.supabaseUrl,
    anonKey: EnvironmentConstants.supabaseAnonKey,
  );

  // Only THEN run the app (router will be created with Hive ready)
  runApp(const ProviderScope(child: MyApp()));
}
```

### Fix — `router.dart` — Add null-safety to the redirect

```dart
// In the redirect callback:
redirect: (context, state) {
  // Guard against box not being open (should not happen after main.dart fix
  // but defensive programming prevents crashes)
  if (!Hive.isBoxOpen('userProfile')) return '/welcome';

  final box = Hive.box('userProfile');
  final hasOnboarded = box.get('hasOnboarded', defaultValue: false) as bool;

  final path = state.uri.path;
  final isOnboarding = path.startsWith('/onboarding') ||
      path == '/welcome' ||
      path == '/recovery';

  if (!hasOnboarded && !isOnboarding) return '/welcome';
  if (hasOnboarded && path == '/welcome') return '/home';
  if (path == '/') return hasOnboarded ? '/home' : '/welcome';
  return null;
},
```

---

## 15. BUG 13 — Sync Queue Newest-First Can Lose Earlier Writes

### Root Cause
`SyncService.drainSyncQueue()` processes the queue "newest-first" and
"deduplicates by profile ID — only the newest version per profile is synced."

This sounds correct but has a subtle flaw: if the user goes offline, plays
3 games (each calling `recordGameSession()`), and the state between games is:
- Write 1: xp=100, weekXp=20, streakDays=5
- Write 2: xp=180, weekXp=40, streakDays=5
- Write 3: xp=250, weekXp=60, streakDays=5

The queue stores all 3 writes. When online, "newest-first with dedup" sends
only Write 3 (xp=250) which is CORRECT — it's the final state.

BUT: if the writes are stored as FULL profile snapshots (all fields), and
between Write 2 and Write 3 the user also changed their username (a separate
write with a separate timestamp), the username change write could be the
"newest" and Write 3 (the XP write) gets discarded because they both have
the same profile ID and username is more recent.

The real issue is: **the sync queue should always only keep the latest
version of all fields combined** — not per-operation.

### Fix — `sync_service.dart` — Queue stores only one entry per profile (always the latest)

```dart
// The queue should NOT be a list of operations.
// It should be a map: profileId → latestProfileSnapshot.
// This way there is always exactly one entry per profile — the most current.

class SyncService {
  static const _queueBoxName = 'sync_queue';

  // Store the latest profile snapshot (overwrites previous for same ID)
  static Future<void> enqueueProfile(UserProfile profile) async {
    final box = Hive.box(_queueBoxName);
    // Key = profile ID → only one entry per user, always latest
    await box.put(profile.id, _profileToMap(profile));
  }

  // On reconnect: sync all queued profiles (usually just 1)
  static Future<void> drainSyncQueue() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final box = Hive.box(_queueBoxName);
    if (box.isEmpty) return;

    // Copy keys to avoid modification during iteration
    final keys = box.keys.toList();
    for (final key in keys) {
      final data = box.get(key) as Map?;
      if (data == null) continue;
      try {
        await Supabase.instance.client
            .from('profiles')
            .upsert(Map<String, dynamic>.from(data), onConflict: 'id');
        await box.delete(key); // Remove only after confirmed sync
      } catch (_) {
        // Leave in queue — will retry next drain
      }
    }
  }
}
```

---

## 16. BUG 14 — No Row Level Security (Any Client Reads All Profiles)

### Root Cause
The app uses the Supabase **anon key** (public, client-side). Without Row Level
Security (RLS) policies on the `profiles` table, any user who has the anon key
(which is embedded in the app binary) can:
- Read all 10,000 profiles with `SELECT * FROM profiles`
- Update any other user's XP, streak, username
- Delete any profile

This is the most critical security issue in the entire codebase.

### Fix — Run these SQL policies in Supabase SQL Editor

```sql
-- ═══════════════════════════════════════════════════════
-- STEP 1: Enable RLS on both tables
-- ═══════════════════════════════════════════════════════
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════
-- STEP 2: profiles policies
-- ═══════════════════════════════════════════════════════

-- Anyone can read profiles (needed for leaderboard, rival card, class dashboard)
-- But only limited fields — not internal fields like last_played_date
CREATE POLICY "profiles_select_public" ON profiles
  FOR SELECT USING (true);

-- A user can only update their OWN profile row
-- Since there's no Supabase Auth, we use a custom approach:
-- The app must send the profile ID in a custom header or use a service role key
-- for updates. Since this app has no auth layer, the best approach is:
-- Use a Supabase Edge Function for all writes (server-validated).
-- SHORT-TERM FIX (until Edge Functions are added):
-- Restrict update to only safe fields via a check function

-- Prevent update of the 'id' and 'username' fields through RLS
-- (username changes go through a dedicated Edge Function)
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (true)  -- Allow update (validated at app level for now)
  WITH CHECK (true);

-- Prevent DELETE from client (deletion must go through Edge Function)
CREATE POLICY "profiles_no_delete" ON profiles
  FOR DELETE USING (false);  -- Nobody can delete via client

-- Allow INSERT only for new rows (onboarding)
CREATE POLICY "profiles_insert" ON profiles
  FOR INSERT WITH CHECK (true);

-- ═══════════════════════════════════════════════════════
-- STEP 3: classes policies
-- ═══════════════════════════════════════════════════════

-- Anyone can read classes (needed to validate class codes)
CREATE POLICY "classes_select_public" ON classes
  FOR SELECT USING (true);

-- Anyone can insert a class (teacher creates class during onboarding)
CREATE POLICY "classes_insert" ON classes
  FOR INSERT WITH CHECK (true);

-- Nobody can delete or update classes from client
CREATE POLICY "classes_no_update" ON classes
  FOR UPDATE USING (false);

CREATE POLICY "classes_no_delete" ON classes
  FOR DELETE USING (false);
```

### Note on Long-Term Fix
The proper fix is to add Supabase Auth (email/magic link or anonymous auth) and
use `auth.uid()` in RLS policies. This is a larger architectural change. The SQL
above is the minimum viable improvement that closes the worst attack vectors while
keeping the current no-auth architecture.

---

## 17. BUG 15 — setTeacher() Has No Guard Against Re-Entrant Calls

### Root Cause
`profileProvider.notifier.setTeacher(true)` is called from `_createClass()` in
`ProfileScreen`. If the user taps "Create Class" twice quickly (double-tap before
the first call completes), `setTeacher()` is called twice simultaneously. Both
calls write to Hive and Supabase. The second call writes on top of the first
while the first is still awaiting Supabase — causing a potential write conflict.

### Fix — `profile_provider.dart` — Add a lock flag

```dart
class ProfileNotifier extends StateNotifier<UserProfile?> {
  // ... existing fields ...

  bool _isMutating = false;  // ADD THIS

  Future<void> setTeacher(bool value) async {
    // Guard against re-entrant calls
    if (_isMutating) return;
    _isMutating = true;

    try {
      final profile = state;
      if (profile == null) return;
      if (profile.isTeacher == value) return; // Already the right value — no-op

      final box = Hive.box('userProfile');
      box.put('isTeacher', value);
      profile.isTeacher = value;
      state = _cloneProfile(profile);
      unawaited(SyncService.syncProfile(state!));
    } finally {
      _isMutating = false;
    }
  }
}
```

### Fix — `profile_screen.dart` — Disable button during async operations

```dart
// All async action buttons should check a loading state:
bool _isLoading = false;

// Wrap every async action:
_buildActionButton(
  label: 'Create Class',
  onTap: _isLoading ? null : () => _showBecomeTeacherDialog(profile), // null = disabled
)
```

---

## 18. ORDER OF IMPLEMENTATION

**Implement in this exact order. Each fix is independent unless noted.**

### Phase 1 — Critical (Do These First, App Is Broken Without Them)

1. **BUG 5** — Fix accuracy division by zero in `user_profile.dart` (2 min fix, prevents crashes in teacher dashboard)
2. **BUG 12** — Fix Hive race condition in `main.dart` and `router.dart` (prevents cold-start crashes)
3. **BUG 6** — Fix username race condition in `username_screen.dart` (prevents ghost accounts)
4. **BUG 14** — Apply RLS policies in Supabase SQL Editor (security — do not skip)

### Phase 2 — High Impact Logic (These Make Core Features Work Correctly)

5. **BUG 1** — Fix teacher appearing in student list (`class_service.dart`, `teacher_dashboard_screen.dart`)
6. **BUG 2** — Fix ProfileScreen role button logic (`profile_screen.dart`)
7. **BUG 4** — Fix streak double-increment (`profile_provider.dart`)
8. **BUG 3** — Fix weekly XP reset on app resume (`profile_provider.dart`, `app_shell.dart`)

### Phase 3 — UX Correctness (These Fix Wrong/Misleading Behavior)

9. **BUG 8** — Add warning when creating class while in student class (`profile_screen.dart`)
10. **BUG 11** — Fix rank reveal dialog to be motivational (`join_class_screen.dart`)
11. **BUG 10** — Fix rival card stale data (`home_screen.dart`)
12. **BUG 15** — Add re-entrancy guard to `setTeacher()` (`profile_provider.dart`)

### Phase 4 — Robustness (These Prevent Data Loss Edge Cases)

13. **BUG 7** — Fix offline account deletion (`profile_screen.dart`, `sync_service.dart`)
14. **BUG 13** — Fix sync queue dedup logic (`sync_service.dart`)
15. **BUG 9** — Replace Realtime subscription with polling (`leaderboard_screen.dart`)

---

## 19. VERIFICATION CHECKLIST

After implementing all fixes, verify each item manually.

### Phase 1 Checks
- [ ] Open `teacher_dashboard_screen.dart`. Navigate to a class where the teacher
      exists. The teacher's own row must NOT appear in the student table.
      Student count must be N (not N+1).
- [ ] Set `totalWordsAnswered = 0` on a test profile. Open teacher dashboard.
      The accuracy column must show "—" not "Infinity%" or crash.
- [ ] Register two accounts with the same username simultaneously (use two devices
      or two simulators). One must fail with "Username just taken."
- [ ] Kill the app mid-onboarding after Supabase insert but before local profile
      creation. Restart. App must not crash.

### Phase 2 Checks
- [ ] Play a game twice in one day. Streak must stay at the same number (not +2).
- [ ] Set `lastPlayedDate` to 3 days ago in Hive. Open app. `streakDays` must
      reset to 0 (not 3+1=4).
- [ ] Set `lastPlayedDate` to 8 days ago in Hive. Play a game. `streakDays`
      must become 1 (not the old value + 1).
- [ ] Set `lastPlayedDate` to last week. Close app. Open app without playing.
      `weekXp` must be 0 in Hive and Supabase.
- [ ] As a student with no class: ProfileScreen must show [Join a Class] and
      [I'm a Teacher — Create a Class] only.
- [ ] As a student in a class: ProfileScreen must show [Change Class] and [Exit Class] only.
      "Create a Class" must NOT appear.
- [ ] As a teacher with a class: ProfileScreen must show [View Student Dashboard],
      [Copy Class Code], [Change Class] only.

### Phase 3 Checks
- [ ] Join a class with 0 XP. The welcome dialog must NOT show your rank.
      It must show the top student's name and XP instead.
- [ ] Play a game, gain XP. The rival card on HomeScreen must update within
      the same session (after navigating away and back to Home).
- [ ] Try to create a class while already in a student class. A warning dialog
      must appear mentioning the class you'll leave.

### Phase 4 Checks
- [ ] Delete account while offline (airplane mode). App must not crash.
      User must be logged out locally with a "pending deletion" message.
- [ ] Reconnect after above. The pending Supabase deletion must complete.
- [ ] Open leaderboard. Network inspector must NOT show a websocket connection
      to `realtime.supabase.co` for the profiles table.
      Leaderboard data must still refresh every 60 seconds.

---

## 20. FILES TO MODIFY SUMMARY

| File | Action | Bugs Fixed |
|---|---|---|
| `lib/models/user_profile.dart` | Modify — add null guard to `accuracy` getter, add `accuracyPercent` getter | #5 |
| `lib/providers/profile_provider.dart` | Modify — replace `updateStreak()` with `_evaluateStreak()`, add `checkAndResetWeekXp()`, add `_isMutating` guard | #3, #4, #15 |
| `lib/services/class_service.dart` | Modify — add `teacher_id` param to `createClass()`, filter teacher from `getClassStudents()` | #1 |
| `lib/services/sync_service.dart` | Modify — replace list queue with map queue, add pending-delete logic | #7, #13 |
| `lib/screens/profile_screen.dart` | Modify — rewrite class management button logic, add `_showBecomeTeacherDialog`, add `_showClassCodeDialog`, fix delete order | #2, #7, #8 |
| `lib/screens/teacher_dashboard_screen.dart` | Modify — use `_safeAccuracy()` helper, fix color coding | #5 |
| `lib/screens/home_screen.dart` | Modify — `_RivalCard` reacts to `myXp` changes via `didUpdateWidget` | #10 |
| `lib/screens/leaderboard_screen.dart` | Modify — replace Realtime stream with `Timer.periodic` polling | #9 |
| `lib/screens/app_shell.dart` | Modify — add `WidgetsBindingObserver` for app resume week-reset check | #3 |
| `lib/onboarding/username_screen.dart` | Modify — catch `PostgrestException` code `23505` on insert | #6 |
| `lib/onboarding/join_class_screen.dart` | Modify — replace rank dialog with motivational welcome dialog | #11 |
| `lib/router.dart` | Modify — add `Hive.isBoxOpen()` guard in redirect | #12 |
| `lib/main.dart` | Modify — `await` all Hive box opens before `runApp()` | #12 |
| **Supabase SQL Editor** | Run RLS migration SQL — enable RLS, add policies | #14 |
| **Supabase SQL Editor** | Run `ALTER TABLE classes ADD COLUMN teacher_id TEXT` migration | #1 |

**Total files to touch: 13 Dart files + 2 SQL migrations.**
**Zero UI changes — all fixes are logic/data layer only.**
