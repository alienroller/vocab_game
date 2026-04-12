# Complete Technical Explanation — Student & Teacher Sections
## VocabGame — Flutter App

---

## Overview

VocabGame is a **Flutter** mobile app (Dart) for Uzbek students learning English vocabulary. It uses:
- **Supabase** (PostgreSQL) as the backend/database
- **Hive** for local/offline storage
- **Riverpod** (StateNotifierProvider) for state management
- **GoRouter** for navigation
- **share_plus**, **connectivity_plus**, **uuid**, **google_fonts**, **intl** packages

The app has TWO completely separate user experiences based on the `isTeacher` boolean flag on the user's profile:
- **Student** — learns vocabulary, plays games, earns XP, competes on leaderboards
- **Teacher** — creates a class, assigns vocabulary units, monitors student progress

Both roles share the **same `profiles` table** in Supabase and the **same `UserProfile` model** locally. The only difference is the `isTeacher` field.

---

## PART 1: ONBOARDING FLOW (How a user becomes a Student or Teacher)

### Step 1: Welcome Screen (`lib/screens/onboarding/welcome_screen.dart`)

First screen on fresh install. Two buttons:
- **"Get Started"** → navigates to `/onboarding/username`
- **"I Have an Account"** → navigates to `/recovery` (account recovery with username + PIN)

### Step 2: Username Screen (`lib/screens/onboarding/username_screen.dart`)

The user picks a username. Key details:
- Username must be 3–20 characters, alphanumeric + underscores only (`^[a-zA-Z0-9_]+$`)
- **Real-time uniqueness check**: debounced 600ms, calls `SyncService.isUsernameTaken()` which queries Supabase `profiles` table
- **Teacher toggle**: There is a toggle switch labeled "I am a teacher" with a `🎓` emoji. This sets `_isTeacher = true` locally.

**On submit:**
1. Generates a UUID v4 as the user's permanent ID
2. Inserts a row into Supabase `profiles` table FIRST (authoritative uniqueness check). If unique_violation error (code 23505), shows "username was just taken"
3. Only after Supabase confirms → creates local Hive profile via `profileProvider.createProfile(id, username, isTeacher: _isTeacher)`
4. The `createProfile()` method writes all fields to Hive box `'userProfile'` and sets provider state
5. Requests notification permission
6. Navigates to `/onboarding/pin` and passes `_isTeacher` as the `extra` parameter

### Step 3: PIN Setup Screen (`lib/screens/onboarding/pin_setup_screen.dart`)

- Takes `isTeacher` as a constructor parameter
- User creates a 6-digit recovery PIN (not 000000, 123456, or 111111)
- PIN is saved via `AccountRecoveryService.savePin()` to a separate Supabase table (not the profiles table)

**After saving PIN:**
- If `isTeacher == true` → navigates to `/onboarding/teacher-class-setup`
- If `isTeacher == false` → navigates to `/onboarding/join-class`

### Step 4A (STUDENT path): Join Class Screen (`lib/screens/onboarding/join_class_screen.dart`)

- Student enters a 6-character class code from their teacher
- The code is uppercased and verified against the `classes` table in Supabase
- If valid: updates the student's `profiles` row with `class_code`, updates local Hive via `profileProvider.setClassCode(code)`
- Shows a **Rank Reveal Dialog**: fetches the class leaderboard from profiles table (excluding teachers via `is_teacher == false`), finds the student's rank, shows an animated dialog: "You're #X in [className]" with the rival name
- Then sets `hasOnboarded = true` in Hive and navigates to `/home`
- **Can be skipped** — "Skip for now" sets `hasOnboarded = true` and goes to `/home` without a class code

### Step 4B (TEACHER path): Teacher Class Setup Screen (`lib/screens/onboarding/teacher_class_setup_screen.dart`)

- Teacher enters a class name (min 3 chars, max 50)
- On submit, calls `ClassService.createClass(teacherId, teacherUsername, className)`:
  - Generates a random 6-character code from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no ambiguous chars like O/0, I/1)
  - Inserts into Supabase `classes` table: `{code, teacher_id, teacher_username, class_name}`
  - Returns the code
- Updates profile `classCode` via `profileProvider.setClassCode(classCode)`
- Sets `hasOnboarded = true`
- Navigates to `/onboarding/class-code-reveal`

### Step 5B (TEACHER path): Class Code Reveal Screen (`lib/screens/onboarding/class_code_reveal_screen.dart`)

- Displays the generated class code in large monospace text
- Two buttons: "Copy Code" (clipboard) and "Share Code" (share_plus)
- User MUST copy or share before continuing (soft gate — shows a SnackBar if they haven't)
- "Continue to Dashboard →" navigates to `/teacher/dashboard` via `context.go()` (replaces stack)

---

## PART 2: ROUTING & NAVIGATION ARCHITECTURE (`lib/router.dart`)

### Role-based redirect logic

The `GoRouter` has a global `redirect` function:

```
1. If Hive box 'userProfile' is not open → redirect to /welcome
2. If !hasOnboarded and not on an onboarding route → redirect to /welcome
3. If hasOnboarded and on /welcome → redirect to /home
4. If path == '/' → redirect to /teacher/dashboard (if teacher) or /home (if student)
5. If isTeacher and trying to access student routes (/home, /library, /profile, /duels, /speaking) → redirect to /teacher/dashboard
6. If !isTeacher and trying to access /teacher/* → redirect to /home
```

### Two StatefulShellRoutes

There are TWO separate `StatefulShellRoute.indexedStack` in the router:

**Student Shell** (5 tabs):
1. `/home` → HomeScreen (with sub-routes: hall-of-fame, leaderboard, games)
2. `/library` → LibraryScreen
3. `/speaking` → SpeakingHomeScreen
4. `/duels` → DuelLobbyScreen
5. `/profile` → ProfileScreen

**Teacher Shell** (5 tabs):
1. `/teacher/dashboard` → TeacherDashboardScreen
2. `/teacher/classes` → TeacherMyClassesScreen
3. `/teacher/library` → TeacherLibraryScreen
4. `/teacher/analytics` → TeacherAnalyticsScreen
5. `/teacher/profile` → TeacherProfileScreen

**Additional teacher routes (full-screen overlay, no bottom nav):**
- `/teacher/student-detail` → TeacherStudentDetailScreen (receives `ClassStudent` as `extra`)

### AppShell (`lib/screens/app_shell.dart`)

Both shells share a single `AppShell` widget that reads `profileProvider.isTeacher` and renders either `TeacherNavShell` or `StudentNavShell`.

```dart
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTeacher = ref.watch(profileProvider)?.isTeacher ?? false;
    if (isTeacher) return TeacherNavShell(navigationShell: navigationShell);
    else return StudentNavShell(navigationShell: navigationShell);
  }
}
```

### Student Nav Shell (`lib/screens/student_nav_shell.dart`)

- 5 tabs: Home, Library, Speaking, Duels, Profile
- Has a `WidgetsBindingObserver` that calls `profileProvider.checkAndResetWeekXp()` when app is resumed
- Shows a badge count on the Duels tab for pending duel invitations
- Back button: if not on Home tab → switches to Home tab. If on Home tab → double-tap within 2 seconds to exit via `SystemNavigator.pop()`

### Teacher Nav Shell (`lib/screens/teacher_nav_shell.dart`)

- 5 tabs: Dashboard, My Classes, Library, Analytics, Profile
- Same double-tap-back-to-exit behavior as student shell
- No badge counts
- Back button: if not on Dashboard → switch to Dashboard. If on Dashboard → double-tap to exit

---

## PART 3: DATA MODELS

### UserProfile (`lib/models/user_profile.dart`)

The single model for BOTH students and teachers. Stored in Hive box `'userProfile'` as individual key-value pairs (NOT as a HiveObject).

```dart
class UserProfile {
  late String id;            // UUID v4, generated during onboarding
  late String username;       // unique across all users
  int xp = 0;                // total XP (never resets)
  int level = 1;             // derived from XP
  int streakDays = 0;        // consecutive days played
  String? lastPlayedDate;    // "YYYY-MM-DD" or null
  String? classCode;         // 6-char code or null
  int weekXp = 0;            // resets every Monday
  int totalWordsAnswered = 0;
  int totalCorrect = 0;
  bool hasOnboarded = false;
  bool isTeacher = false;     // <-- THIS IS THE ROLE FLAG
  List<String> unlockedBadges = [];

  double get accuracy => totalWordsAnswered == 0 ? 0.0 : (totalCorrect / totalWordsAnswered).clamp(0.0, 1.0);
  String get accuracyPercent => totalWordsAnswered == 0 ? '—' : '${(accuracy * 100).round()}%';
}
```

### ClassStudent (`lib/models/class_student.dart`)

Used by teacher screens to represent a student in their class. Created from Supabase query results.

```dart
class ClassStudent {
  final String id;
  final String username;
  final int xp;
  final int level;
  final int streakDays;
  final int totalWordsAnswered;
  final int totalCorrect;
  final String? lastPlayedDate;
  final String? classCode;

  // Computed:
  double get accuracy => totalWordsAnswered == 0 ? 0.0 : totalCorrect / totalWordsAnswered;
  String get accuracyDisplay => totalWordsAnswered == 0 ? '—' : '${(accuracy * 100).round()}%';
  bool get isAtRisk => lastPlayedDate == null || DateTime.now().difference(DateTime.parse(lastPlayedDate!)).inDays >= 3;
  int? get daysSinceActive => lastPlayedDate == null ? null : daysDifference;

  factory ClassStudent.fromMap(Map<String, dynamic> map) // maps Supabase snake_case columns
}
```

### ClassHealthScore (`lib/models/class_health_score.dart`)

Computed LOCALLY (no Supabase call) from a list of `ClassStudent` objects.

```dart
class ClassHealthScore {
  final double score;           // 0-100
  final double avgAccuracy;     // 0.0-1.0
  final double engagementRate;  // 0.0-1.0
  final int totalStudents;
  final int activeStudentsThisWeek;
  final int atRiskCount;

  String get label => score >= 80 ? 'Excellent' : score >= 60 ? 'Good' : score >= 40 ? 'Fair' : 'Needs Attention';
  String get colorTier => score >= 80 ? 'green' : score >= 60 ? 'amber' : score >= 40 ? 'orange' : 'red';
}
```

**Health score formula**: `(avgAccuracy × 0.5 + engagementRate × 0.5) × 100`

### Assignment (`lib/models/assignment.dart`)

Represents a teacher-assigned vocabulary unit for a class.

```dart
class Assignment {
  final String id;           // UUID from Supabase
  final String classCode;
  final String teacherId;
  final String bookId;       // collection UUID
  final String bookTitle;
  final String unitId;       // unit UUID
  final String unitTitle;
  final String? dueDate;     // 'YYYY-MM-DD' or null
  final int wordCount;
  final DateTime createdAt;
  final bool isActive;       // soft-delete flag

  bool get isOverdue => dueDate != null && DateTime.now().isAfter(DateTime.parse(dueDate!));
  int? get daysRemaining => dueDate == null ? null : due.difference(today).inDays;

  factory Assignment.fromMap(Map<String, dynamic> map) // maps Supabase columns
  Map<String, dynamic> toMap() // for insertion (excludes id and created_at)
}
```

### AssignmentProgress (`lib/models/assignment_progress.dart`)

Tracks a student's progress on a specific assignment.

```dart
class AssignmentProgress {
  final String id;
  final String assignmentId;
  final String studentId;
  final String classCode;
  final int wordsMastered;
  final int totalWords;
  final bool isCompleted;
  final DateTime? lastPracticedAt;

  double get progressRatio => totalWords == 0 ? 0.0 : wordsMastered / totalWords;
  String get progressLabel => '$wordsMastered / $totalWords words';
}
```

### TeacherMessage (`lib/models/teacher_message.dart`)

A pinned message from teacher to class.

```dart
class TeacherMessage {
  final String classCode;
  final String message;
  final DateTime updatedAt;

  factory TeacherMessage.fromMap(Map<String, dynamic> map)
}
```

### WordStat (`lib/models/word_stat.dart`)

Aggregated word difficulty data across all students in a class.

```dart
class WordStat {
  final String wordEnglish;
  final String wordUzbek;
  final int timesShown;
  final int timesCorrect;

  double get accuracy => timesShown == 0 ? 0.0 : timesCorrect / timesShown;
  String get difficultyTier => accuracy < 0.40 ? 'hard' : accuracy < 0.70 ? 'medium' : 'easy';
}
```

---

## PART 4: SUPABASE TABLE SCHEMAS (Inferred from code)

### `profiles` table
```sql
id                  UUID PRIMARY KEY
username            TEXT UNIQUE NOT NULL
xp                  INTEGER DEFAULT 0
level               INTEGER DEFAULT 1
streak_days         INTEGER DEFAULT 0
last_played_date    TEXT          -- 'YYYY-MM-DD' or null
class_code          TEXT          -- FK to classes.code, nullable
week_xp             INTEGER DEFAULT 0
total_words_answered INTEGER DEFAULT 0
total_correct       INTEGER DEFAULT 0
is_teacher          BOOLEAN DEFAULT false
updated_at          TIMESTAMPTZ   -- updated on each sync
```

### `classes` table
```sql
code                TEXT PRIMARY KEY  -- 6-char code like 'ENG7B'
teacher_id          UUID NOT NULL     -- FK to profiles.id
teacher_username    TEXT NOT NULL
class_name          TEXT NOT NULL
```

### `teacher_messages` table
```sql
class_code          TEXT UNIQUE NOT NULL  -- one message per class
teacher_id          UUID NOT NULL
message             TEXT NOT NULL
updated_at          TIMESTAMPTZ
```
- UNIQUE constraint on `class_code` — upsert uses `onConflict: 'class_code'`

### `collections` table (vocabulary collections/books)
```sql
id                  UUID PRIMARY KEY
short_title         TEXT
description         TEXT
category            TEXT   -- 'esl', 'fiction', 'academic'
difficulty          TEXT   -- 'A1', 'A2', 'B1', etc. (CEFR)
cover_emoji         TEXT
cover_color         TEXT   -- hex color like '#4F46E5'
total_units         INTEGER
is_published        BOOLEAN
```

### `units` table (word units within a collection)
```sql
id                  UUID PRIMARY KEY
collection_id       UUID NOT NULL  -- FK to collections.id
title               TEXT
unit_number         INTEGER
word_count          INTEGER
```

### `assignments` table
```sql
id                  UUID PRIMARY KEY DEFAULT gen_random_uuid()
class_code          TEXT NOT NULL
teacher_id          UUID NOT NULL
book_id             UUID NOT NULL
book_title          TEXT NOT NULL
unit_id             UUID NOT NULL
unit_title          TEXT NOT NULL
due_date            TEXT          -- nullable, 'YYYY-MM-DD'
word_count          INTEGER NOT NULL
is_active           BOOLEAN DEFAULT true
created_at          TIMESTAMPTZ DEFAULT now()
```

### `assignment_progress` table
```sql
id                  UUID PRIMARY KEY DEFAULT gen_random_uuid()
assignment_id       UUID NOT NULL    -- FK to assignments.id
student_id          UUID NOT NULL    -- FK to profiles.id
class_code          TEXT NOT NULL    -- denormalized for analytics
words_mastered      INTEGER DEFAULT 0
total_words         INTEGER NOT NULL
is_completed        BOOLEAN DEFAULT false
last_practiced_at   TIMESTAMPTZ
```

### `word_stats` table
```sql
word_english        TEXT NOT NULL
word_uzbek          TEXT NOT NULL
times_shown         INTEGER NOT NULL
times_correct       INTEGER NOT NULL
class_code          TEXT NOT NULL    -- which class this stat belongs to
-- (implied: also has student_id or some per-student granularity based on the aggregation logic in AnalyticsService)
```

### `account_recovery` table (inferred)
```sql
profile_id          UUID PRIMARY KEY
pin_hash            TEXT NOT NULL    -- hashed 6-digit PIN
```

---

## PART 5: STATE MANAGEMENT (Riverpod Providers)

### profileProvider (`lib/providers/profile_provider.dart`)

```dart
final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile?>((ref) => ProfileNotifier());
```

This is the SINGLE source of truth for the current user. Loads from Hive on init. Key methods:

- `createProfile({id, username, isTeacher})` — onboarding: writes all fields to Hive, sets state
- `reload()` — re-reads from Hive, checks week reset
- `recordGameSession({xpGained, totalQuestions, correctAnswers})` — post-game: adds XP, updates accuracy, evaluates streak, saves to Hive, syncs to Supabase
- `setClassCode(String? code)` — join/leave class
- `updateUsername(String)` — updates in Supabase first, then Hive
- `setTeacher(bool)` — has re-entrancy guard (`_isMutating` flag)
- `awardBadge(String)` — adds to `unlockedBadges` list
- `logout()` — clears Hive, sets state to null
- `sync()` — manual sync to Supabase
- `checkAndResetWeekXp()` — resets `weekXp` to 0 if current ISO week differs from last played week

**Streak logic** (`_evaluateStreak`):
- If never played before → streak = 1
- If played yesterday → streak + 1
- If played today already → no change (idempotent)
- If missed one or more days → streak = 1

**Week XP reset** (`_checkWeekReset`):
- Uses Monday-based weeks
- Compares current Monday date string with stored `weekXpResetDate`

### classStudentsProvider (`lib/providers/class_students_provider.dart`)

```dart
final classStudentsProvider = StateNotifierProvider<ClassStudentsNotifier, ClassStudentsState>((ref) => ...);
```

State: `{students: List<ClassStudent>, healthScore: ClassHealthScore?, isLoading, error}`

- `load({classCode, teacherId})` → calls `AnalyticsService.getClassStudents()` then `computeHealthScore()`

### assignmentProvider (`lib/providers/assignment_provider.dart`)

```dart
final assignmentProvider = StateNotifierProvider<AssignmentNotifier, AssignmentState>((ref) => ...);
```

State: `{assignments: List<Assignment>, progressMap: Map<String, AssignmentProgress>, isLoading, error}`

Two loading methods:
- `loadStudentAssignments({classCode, studentId})` — fetches assignments + student's progress map
- `loadTeacherAssignments({classCode, teacherId})` — fetches only assignments (empty progress map)

Other methods:
- `updateLocalProgress(AssignmentProgress)` — optimistic local update after student plays
- `removeAssignment(String id)` — removes from local list (after teacher deactivates)

### wordStatsProvider (`lib/providers/word_stats_provider.dart`)

```dart
final wordStatsProvider = StateNotifierProvider<WordStatsNotifier, WordStatsState>((ref) => ...);
```

State: `{stats: List<WordStat>, isLoading, error}`

- `load(String classCode)` → calls `AnalyticsService.getClassWordStats()`

---

## PART 6: SERVICES

### ClassService (`lib/services/class_service.dart`)

Static methods:
- `createClass({teacherId, teacherUsername, className})` → inserts into `classes` table, returns 6-char code
- `joinClass({profileId, code})` → verifies code exists in `classes`, updates `profiles.class_code`, returns class data or null
- `getClassInfo(String code)` → queries `classes` table, returns map or null

### AssignmentService (`lib/services/assignment_service.dart`)

**Teacher methods:**
- `createAssignment({classCode, teacherId, bookId, bookTitle, unitId, unitTitle, wordCount, dueDate?})` → inserts into `assignments` table, returns `Assignment`
- `deactivateAssignment(String id)` → sets `is_active = false` (soft delete)
- `getTeacherAssignments({classCode, teacherId})` → queries `assignments` where `is_active = true`, ordered by `created_at DESC`
- `getAssignmentCompletionSummary({assignmentId, classCode})` → counts total students in class (excluding teachers) and completed progress rows. Returns `{completed: int, total: int}`
- `getAssignmentStudentProgress({assignmentId})` → joins `assignment_progress` with `profiles` to get per-student detail

**Student methods:**
- `getStudentAssignments({classCode})` → all active assignments for the class
- `getStudentProgressMap({studentId})` → all progress rows for this student, returned as `Map<assignmentId, AssignmentProgress>`
- `updateAssignmentProgress({assignmentId, studentId, classCode, wordsMasteredDelta, totalWords})`:
  - Checks if progress row exists for this student+assignment
  - If not: creates new row with `words_mastered = delta.clamp(0, total)`
  - If exists: increments `words_mastered`, capped at `totalWords`
  - Sets `is_completed = words_mastered >= totalWords`
  - Updates `last_practiced_at`

### AnalyticsService (`lib/services/analytics_service.dart`)

- `getClassStudents({classCode, teacherId})` → queries `profiles` where `class_code = classCode AND is_teacher = false AND id != teacherId`, ordered by `xp DESC`. Returns `List<ClassStudent>`.
- `computeHealthScore(List<ClassStudent>)` → pure computation, no Supabase call:
  - avgAccuracy: average accuracy of students who have answered at least 1 question
  - engagementRate: fraction of students active in last 7 days
  - atRiskCount: students with `isAtRisk == true` (no activity for 3+ days)
  - score = `(avgAccuracy * 0.5 + engagementRate * 0.5) * 100`
- `getClassWordStats({classCode})` → fetches all `word_stats` rows for the class, aggregates by `word_english` (sums `times_shown` and `times_correct`), sorts by accuracy ascending (hardest words first)

### TeacherMessageService (`lib/services/teacher_message_service.dart`)

- `setMessage({classCode, teacherId, message})` → upserts into `teacher_messages` (one message per class, uses `onConflict: 'class_code'`)
- `deleteMessage(String classCode)` → deletes the row
- `getMessage(String classCode)` → fetches with `maybeSingle()`, returns `TeacherMessage?`

### SyncService (`lib/services/sync_service.dart`)

- `syncProfile(UserProfile)` → upserts to `profiles` table. If offline, enqueues in Hive box `'sync_queue'` keyed by profile ID (so only the latest snapshot is kept per user)
- `drainSyncQueue()` → on app start, iterates all queued items and attempts to sync. Handles both `profile_sync` and `pending_delete` types
- `fetchProfile(String userId)` → fetches from Supabase by ID (used for account recovery)
- `isUsernameTaken(String)` → checks if username exists in `profiles`
- `deleteProfile(String userId)`:
  - If ONLINE: deletes from Supabase first, then clears local Hive
  - If OFFLINE: queues a `pending_delete` in sync_queue, clears local Hive immediately (user gets immediate feedback)

---

## PART 7: TEACHER SCREENS IN DETAIL

### Teacher Dashboard (`lib/screens/teacher/teacher_dashboard_screen.dart`)

**What it shows:**
1. **AppBar title**: Class name (fetched from `ClassService.getClassInfo()`) or fallback "Class {code}" or "Dashboard"
2. **Share button** in AppBar: shares "Join my class on VocabGame! Code: {code}" via share_plus
3. **Class Health Card** (tappable → navigates to Analytics):
   - Large health score number (e.g. "72") with color based on tier (green/amber/orange/red)
   - Label (Excellent/Good/Fair/Needs Attention)
   - Avg Accuracy percentage
   - Active students this week (e.g. "8/12")
4. **Teacher Message Card** (tappable → opens edit modal):
   - Shows pinned message or "📌 Pin a message for students" placeholder
   - Edit modal: TextField (max 200 chars), "Clear" button (red, deletes message), "Save" button
5. **At-Risk Section**:
   - Header: "⚠️ At Risk — X students" in orange
   - If atRiskCount == 0: shows "✅ All students practiced recently"
   - If atRiskCount > 0: shows up to 5 at-risk students as ListTiles with red dot, username, last active date
   - If atRiskCount > 5: "View all →" link to Analytics
   - Tapping a student → navigates to `/teacher/student-detail` with `ClassStudent` as extra

**On init:**
- Calls `classStudentsProvider.load({classCode, teacherId})` to fetch all students
- Fetches class name from `ClassService.getClassInfo()`
- Fetches pinned message from `TeacherMessageService.getMessage()`

**Pull-to-refresh** reloads all data.

### Teacher My Classes Screen (`lib/screens/teacher/teacher_classes_screen.dart`)

**What it shows:**
1. **Class Info Card**: class code in large text, "X students enrolled", Share button, Copy button
2. **Sort Controls**: horizontal chip row — XP, Level, Streak, Accuracy, Name. Toggle ascending/descending. Default: XP descending.
3. **Student List**: sorted ListView with:
   - XP-based rank (🥇🥈🥉 for top 3, then numbers)
   - Avatar (first letter of username)
   - Red dot on avatar if student `isAtRisk`
   - Username, "Lvl X • Y XP"
   - Streak fire icon + count (if > 0)
   - Accuracy percentage (color-coded: green ≥70%, orange ≥40%, red <40%, grey if no answers)
   - Tapping → navigates to student detail

**On init:** loads students from `classStudentsProvider` if not already loaded.

**Error state:** shows error message with Retry button.

### Teacher Library Screen (`lib/screens/teacher/teacher_library_screen.dart`)

**What it shows:**
1. **Filter bar**: All, ESL, Fiction, Academic category chips
2. **Collection grid** (2-column GridView):
   - Each card: colored background, emoji, title, difficulty badge (A1/A2/B1 etc.), unit count
   - Tapping → navigates to `TeacherUnitListScreen` (inline screen in same file)

**TeacherUnitListScreen** (pushed via `Navigator.push`, NOT GoRouter):
1. Lists all units in the collection from Supabase `units` table
2. Each unit row shows: unit number, title, word count
3. **"Assign to Class" button** per unit:
   - Calls `AssignmentService.createAssignment()` with all the metadata
   - Shows loading spinner during request
   - After success: reloads teacher assignments, shows "Assigned successfully!" SnackBar
   - If already assigned (checks `assignmentState.assignments`): button shows "Assigned ✓" and is disabled
   - Has a re-entrancy guard: `_assigningUnitId` prevents double-taps

**On init:**
- Loads collections from Supabase `collections` table (where `is_published = true`)
- Loads teacher assignments to check which units are already assigned

### Teacher Analytics Screen (`lib/screens/teacher/teacher_analytics_screen.dart`)

**What it shows:**
1. **Assigned Units section**:
   - Lists all active assignments
   - Each card shows: unit title, book title, progress bar (completed/total students), "X/Y" count
   - **Swipe to dismiss**: confirm dialog "Remove Assignment?" → calls `AssignmentService.deactivateAssignment()` (soft delete) and removes from provider
   - Completion summary fetched per assignment via `AssignmentService.getAssignmentCompletionSummary()` and cached in `_completionCache`
2. **Class Struggling Words section**:
   - Title: "Words students answer incorrectly most often"
   - Lists up to 20 `WordStat` entries sorted by accuracy ascending (hardest first)
   - Each row: English word, Uzbek translation, accuracy % (color-coded), attempt count

**On init:**
- Loads teacher assignments
- Loads class word stats
- Fetches completion summary for each assignment

**Pull-to-refresh** reloads all data.

### Teacher Student Detail Screen (`lib/screens/teacher/teacher_student_detail_screen.dart`)

Receives a `ClassStudent` object via `extra`.

**What it shows:**
1. **Summary Card**: Level (star icon), XP (bolt icon), Streak (fire icon), Accuracy (check icon)
2. **Detail Stats**: Total Words Answered, Total Correct Answers, Last Active (relative date)
3. **Assignments Progress**:
   - Fetches student's progress via `AssignmentService.getStudentProgressMap(studentId)`
   - Fetches active assignments via `AssignmentService.getStudentAssignments(classCode)`
   - Shows each assignment with: title, book, progress bar, mastered/total count, completion checkmark

### Teacher Profile Screen (`lib/screens/teacher/teacher_profile_screen.dart`)

**What it shows:**
1. Avatar (first letter), username, "Teacher" badge
2. **Class Code card**: large monospace code, Copy + Share buttons
3. **Account section**:
   - Change Username → dialog with TextField, min 3 chars, updates via `profileProvider.updateUsername()`
   - Recovery PIN → navigates to `/onboarding/pin` with `extra: true` (isTeacher=true)
   - Logout → confirm dialog → `profileProvider.logout()` → `context.go('/welcome')`
   - Delete Account → confirm dialog → `profileProvider.logout()` → `context.go('/welcome')`

**⚠️ BUG: Delete Account for teachers does NOT actually call `SyncService.deleteProfile()`. It only calls `profileProvider.logout()`, which clears local Hive but leaves the Supabase row intact. Compare with the student ProfileScreen which properly calls `SyncService.deleteProfile(profile.id)`.**

---

## PART 8: STUDENT SCREENS (relevant to teacher interaction)

### Student Home Screen (`lib/screens/home_screen.dart`)

**Class-related features on the student home screen:**

1. **Assignments carousel** (horizontal ScrollView):
   - Shows if `assignmentState.assignments.isNotEmpty`
   - Each card: unit title, book title, progress bar (mastered/total), due date if set
   - Tapping is currently a **TODO** — should launch AssignmentModeGame (Phase 7)
   - Loaded via `assignmentProvider.loadStudentAssignments({classCode, studentId})` on init

2. **Teacher Message card**:
   - Shows if `_teacherMessage != null`
   - Displays: 📌 icon, "Class Announcement" header, message text
   - Fetched via `TeacherMessageService.getMessage(classCode)` on init

3. **Rival card**:
   - Fetches classmates from Supabase `profiles` (excluding self and teachers via `is_teacher = false`)
   - Finds the person directly above in XP as the "rival"
   - Shows: "Your rival: {name} — X XP ahead" or "you lead by X XP 🔥"
   - Gap is computed LIVE using `_rivalXp - profile.xp` so it updates instantly

### Student Profile Screen (`lib/screens/profile_screen.dart`)

**Class management section** (`_ClassManagementSection`):

- **State A (no class)**: Shows "Join a Class" button → dialog with 6-char code input → calls `ClassService.joinClass()` and `profileProvider.setClassCode()`
- **State B (has class)**: Shows two buttons:
  - "Change Class" → confirm dialog → clears class code → shows join dialog
  - "Exit Class" → confirm dialog → clears class code

**Account management:**
- Logout: clears Hive, goes to `/welcome`
- Delete Account: requires typing "DELETE" to confirm → calls `SyncService.deleteProfile(profile.id)` → clears Hive → goes to `/welcome`

---

## PART 9: KNOWN BUGS AND ISSUES

### BUG 1: Teacher Dashboard `_editMessage` — Missing try-catch and closure bracket

In `teacher_dashboard_screen.dart` lines 106-124, the Save button's `onPressed` handler has a syntax issue. The `try` block at line 107 is never closed with a `catch`. The code is:

```dart
onPressed: () async {
  try {
    if (controller.text.trim().isNotEmpty) {
      await TeacherMessageService.setMessage(...);
      final newMsg = await TeacherMessageService.getMessage(classCode);
      setState(() => _message = newMsg);
    }
    if (context.mounted) Navigator.pop(context);
  },     // <-- ERROR: `try` without `catch` or `finally`
```

This should be `} catch (e) { ... }` or `} finally { ... }` to close the try block properly. **This will cause a compile error.**

### BUG 2: Teacher Profile — Delete Account doesn't delete from Supabase

In `teacher_profile_screen.dart` lines 158-163, the delete handler just calls `profileProvider.logout()` without calling `SyncService.deleteProfile()`. The Supabase `profiles` row is **never deleted**. Compare with the student `ProfileScreen` which properly calls `SyncService.deleteProfile(profile.id)`.

### BUG 3: AppShell uses same builder for both StatefulShellRoutes

In `router.dart`, both the student `StatefulShellRoute` (line 182) and the teacher `StatefulShellRoute` (line 399) use the same `AppShell` widget:
```dart
builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
```

This works because `AppShell` internally checks `profileProvider.isTeacher` to decide which nav shell to render. However, this means the teacher's route tree uses the same `AppShell` dispatcher — if a teacher's `isTeacher` flag somehow gets set to false while on a teacher route, it would render the StudentNavShell with teacher route indices, potentially causing index mismatch issues.

### BUG 4: classStudentsProvider health score null-safety in Dashboard

In `teacher_dashboard_screen.dart` line 270:
```dart
Text('⚠️ At Risk — ${classesState.healthScore!.atRiskCount} students', ...)
```

This uses `healthScore!` (force-unwrap) but it's inside `if (classesState.students.isNotEmpty)` — the health score could still be null if loading failed but students were cached from a previous load. It should check `classesState.healthScore != null` instead.

### BUG 5: Assignment game tapping is unimplemented (TODO)

In `home_screen.dart` line 337-339, tapping an assignment card has a `// TODO: Launch AssignmentModeGame (Phase 7)` comment. Students can see their assignments but cannot actually play them through the assignment cards.

### BUG 6: Teacher Library uses `Navigator.push` instead of GoRouter

In `teacher_library_screen.dart` line 151:
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherUnitListScreen(collection: c)));
```

This uses Flutter's native Navigator instead of GoRouter. This means the TeacherUnitListScreen doesn't have a proper route path, can't be deep-linked, and doesn't get the fade+slide transition that all other routes get via `_buildPage()`.

### BUG 7: Student Rank Reveal and Rival exclude teacher incorrectly

The rank reveal in `join_class_screen.dart` line 104 and the rival fetch in `home_screen.dart` line 111 both filter by `is_teacher = false`. This relies on the teacher having `is_teacher = true` in their Supabase profile. If the teacher's profile wasn't synced yet when they created the class (e.g., offline), they might appear in the student leaderboard.

### BUG 8: WeekXp ISO week key generation is non-standard

In `profile_provider.dart` line 228:
```dart
String _getIsoWeekKey(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year}-W${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}
```

This uses `monday.month-monday.day` as the week key instead of the actual ISO week number. This works for distinguishing unique weeks but is not a standard ISO week representation. The format `2026-W04-12` doesn't match ISO 8601 week format `2026-W15`. It still works correctly for the purpose of detecting week changes.

### BUG 9: TeacherUnitListScreen assignment check is insufficient

In `teacher_library_screen.dart` line 319:
```dart
final isAssigned = assignmentState.assignments.any((a) => a.unitId == unitId && a.isActive);
```

The `isActive` check is redundant because `getTeacherAssignments()` already filters for `is_active = true`. But more importantly, if the provider hasn't loaded yet (first load), `assignmentState.assignments` will be empty and all units will show "Assign to Class" even if they're already assigned. The `initState` calls `loadTeacherAssignments()` in `addPostFrameCallback` but there's a race condition where the UI builds before the data loads.

### BUG 10: Multiple classes not supported for teachers

The current architecture assumes one teacher has one class. `UserProfile.classCode` stores a single class code. If a teacher created multiple classes (e.g., "English 7A" and "English 7B"), only the most recent class code would be stored. The `ClassService.createClass()` overwrites the teacher's `classCode` each time.

---

## PART 10: HIVE BOXES USED

1. **`'userProfile'`** — stores all UserProfile fields as individual key-value pairs (NOT a serialized object). Keys match UserProfile field names (e.g., `'id'`, `'username'`, `'xp'`, `'isTeacher'`, `'classCode'`, etc.). Also stores `'weekXpResetDate'` and `'lastStreakMilestone'`.

2. **`'sync_queue'`** — stores pending sync operations. Keys are `'profile_{userId}'` for profile syncs and `'pending_delete_{userId}'` for account deletions. Each value is a map with `{type, data, timestamp}`.

3. **`'vocabWords'`** — the student's personal vocabulary list (not related to teacher/class system).

4. **`'dictionary_cache'`** — cached dictionary lookups for offline use.

---

## PART 11: COMPLETE DATA FLOW EXAMPLES

### Example: Teacher creates a class and assigns a unit

1. Teacher picks username → creates Supabase profile with `is_teacher: true`
2. Teacher sets up PIN → navigates to `TeacherClassSetupScreen`
3. Teacher enters class name "English 7B"
4. `ClassService.createClass()` generates code "ENG7B2", inserts into `classes` table
5. `profileProvider.setClassCode("ENG7B2")` → saves to Hive + syncs to Supabase `profiles`
6. Teacher is shown the code → shares it → redirected to Dashboard
7. Dashboard loads students via `classStudentsProvider.load()` (empty initially)
8. Teacher taps Library tab → `TeacherLibraryScreen` loads published collections from `collections` table
9. Teacher taps a collection → sees units from `units` table
10. Teacher taps "Assign to Class" → `AssignmentService.createAssignment()` inserts into `assignments` table
11. Provider reloads → button changes to "Assigned ✓"

### Example: Student joins a class and sees assignments

1. Student creates account (isTeacher=false) → PIN → JoinClassScreen
2. Student enters "ENG7B2" → `ClassService.joinClass()` verifies code, updates `profiles.class_code`
3. `profileProvider.setClassCode("ENG7B2")` → saves locally
4. Student sees rank reveal dialog
5. On HomeScreen load: `assignmentProvider.loadStudentAssignments({classCode, studentId})`
6. This calls `AssignmentService.getStudentAssignments({classCode})` → gets all active assignments
7. Also calls `AssignmentService.getStudentProgressMap({studentId})` → gets progress for each
8. Assignments appear as horizontal cards showing progress
9. Teacher message appears via `TeacherMessageService.getMessage(classCode)`

### Example: Teacher views a student's detail

1. On Dashboard or My Classes, teacher taps a student
2. GoRouter navigates to `/teacher/student-detail` with `ClassStudent` as `extra`
3. `TeacherStudentDetailScreen` shows the student's stats from the `ClassStudent` object
4. Fetches assignment progress via `AssignmentService.getStudentProgressMap(studentId)`
5. Fetches active assignments via `AssignmentService.getStudentAssignments(classCode)` — note: uses student's `classCode` which comes from the `ClassStudent` model
6. Displays per-assignment progress

---

## PART 12: FILE LIST (Every file relevant to Student/Teacher sections)

### Screens
- `lib/screens/app_shell.dart` — role-based shell switcher
- `lib/screens/student_nav_shell.dart` — student bottom nav (5 tabs)
- `lib/screens/teacher_nav_shell.dart` — teacher bottom nav (5 tabs)
- `lib/screens/home_screen.dart` — student home (assignments, teacher message, rival)
- `lib/screens/profile_screen.dart` — student profile (class join/change/exit)
- `lib/screens/teacher/teacher_dashboard_screen.dart` — class health, message, at-risk students
- `lib/screens/teacher/teacher_classes_screen.dart` — student roster with sorting
- `lib/screens/teacher/teacher_library_screen.dart` — collections + assign to class
- `lib/screens/teacher/teacher_analytics_screen.dart` — assignment completion + struggling words
- `lib/screens/teacher/teacher_profile_screen.dart` — teacher profile + class code
- `lib/screens/teacher/teacher_student_detail_screen.dart` — individual student stats
- `lib/screens/onboarding/welcome_screen.dart` — first screen
- `lib/screens/onboarding/username_screen.dart` — username + teacher toggle
- `lib/screens/onboarding/pin_setup_screen.dart` — 6-digit recovery PIN
- `lib/screens/onboarding/join_class_screen.dart` — student joins a class
- `lib/screens/onboarding/teacher_class_setup_screen.dart` — teacher creates a class
- `lib/screens/onboarding/class_code_reveal_screen.dart` — shows generated class code

### Providers
- `lib/providers/profile_provider.dart` — user profile state + sync
- `lib/providers/class_students_provider.dart` — teacher's student list + health score
- `lib/providers/assignment_provider.dart` — assignments + progress
- `lib/providers/word_stats_provider.dart` — class-level word difficulty stats

### Models
- `lib/models/user_profile.dart` — local user profile (shared by student + teacher)
- `lib/models/class_student.dart` — student data as seen by teacher
- `lib/models/class_health_score.dart` — computed class health metrics
- `lib/models/assignment.dart` — assigned vocabulary unit
- `lib/models/assignment_progress.dart` — student's progress on an assignment
- `lib/models/teacher_message.dart` — pinned class message
- `lib/models/word_stat.dart` — per-word accuracy stats

### Services
- `lib/services/class_service.dart` — create/join class
- `lib/services/assignment_service.dart` — CRUD for assignments + progress
- `lib/services/analytics_service.dart` — class students + health score + word stats
- `lib/services/teacher_message_service.dart` — CRUD for teacher messages
- `lib/services/sync_service.dart` — Supabase sync + offline queue + profile deletion

### Config
- `lib/router.dart` — all routes + role-based redirect logic
