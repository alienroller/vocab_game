# VocabGame — Detailed Project Overview

> **Platform:** Flutter (Dart 3.7+)  
> **Backend:** Supabase (PostgreSQL + Realtime + Edge Functions)  
> **State Management:** Riverpod  
> **Version:** 1.0.3+3  
> **Target Platforms:** Android, iOS, Web, Windows, macOS, Linux

---

## Table of Contents

1. [What Is VocabGame?](#1-what-is-vocabgame)
2. [Who Is It For?](#2-who-is-it-for)
3. [Project Structure](#3-project-structure)
4. [Screens & Navigation](#4-screens--navigation)
5. [Game Modes](#5-game-modes)
6. [Data Models](#6-data-models)
7. [Services (Business Logic)](#7-services-business-logic)
8. [State Management — Riverpod Providers](#8-state-management--riverpod-providers)
9. [Database Schema (Supabase)](#9-database-schema-supabase)
10. [Edge Functions (Serverless)](#10-edge-functions-serverless)
11. [Local Storage — Hive (Offline-First)](#11-local-storage--hive-offline-first)
12. [Speaking Module](#12-speaking-module)
13. [Teacher System](#13-teacher-system)
14. [Duel System](#14-duel-system)
15. [Exam System](#15-exam-system)
16. [XP, Levels & Streaks](#16-xp-levels--streaks)
17. [Design System & Theme](#17-design-system--theme)
18. [Key Widgets](#18-key-widgets)
19. [Dependencies & What They Do](#19-dependencies--what-they-do)
20. [Configuration & Environment](#20-configuration--environment)
21. [Architectural Patterns](#21-architectural-patterns)
22. [Summary Statistics](#22-summary-statistics)

---

## 1. What Is VocabGame?

VocabGame is a **competitive, gamified English–Uzbek vocabulary learning app** built with Flutter. It is designed for ESL (English as a Second Language) learners in Uzbekistan studying from textbook series such as Navigate, Round Up, and similar EFL curricula.

The app turns routine vocabulary memorization into an engaging experience through:

- **5 distinct game modes** (multiple-choice quiz, flashcards, matching, memory pairs, fill-in-the-blank)
- **Real-time head-to-head duels** between classmates
- **Teacher-led live exam sessions** with synchronized questions
- **Scenario-based speaking practice** with offline speech recognition and pronunciation scoring
- **XP, levels, streaks, and leaderboards** providing competitive motivation
- **Offline-first architecture** — students can play and sync when back online

The entire app runs without requiring an account login. Users are identified by a locally-generated UUID stored in encrypted Hive storage. A PIN system allows account recovery if the app is uninstalled.

---

## 2. Who Is It For?

| User Type | Role in App | Key Features Used |
|-----------|-------------|-------------------|
| **Students** | Learn, compete, practice | Games, duels, library, speaking, XP/streaks, leaderboard |
| **Teachers** | Manage, assign, examine | Class management, exam creation, assignment tracking, analytics |

- **Students** get a 5-tab navigation shell (Home, Library, Speaking, Duels, Profile).
- **Teachers** get a 6-tab navigation shell (Dashboard, Classes, Library, Exams, Analytics, Profile).

The same app binary serves both roles. The `isTeacher` flag on the user's profile determines which navigation shell and routes are displayed at startup.

---

## 3. Project Structure

```
vocab_game/
├── lib/                            # All Dart source code
│   ├── main.dart                   # App entry point, Supabase init, GoRouter setup
│   ├── config/                     # Environment config & Firebase options
│   ├── theme/                      # App-wide design system (colors, gradients, typography)
│   ├── models/                     # 10 data model classes (PODOs)
│   ├── services/                   # 23 service classes (business logic)
│   ├── providers/                  # 9 Riverpod state providers
│   ├── screens/                    # 25+ UI screen files
│   ├── games/                      # 5 game mode implementations
│   ├── widgets/                    # 7 reusable UI widget files
│   └── features/speaking/          # Clean-architecture speaking module
│       ├── domain/                 # Scenario entities & scoring interfaces
│       ├── data/                   # Speech recognition, TTS, Sherpa ONNX
│       └── presentation/           # Screens, widgets, exercise widgets
│
├── supabase/
│   ├── config.toml                 # Supabase project configuration
│   ├── migrations/                 # 5 SQL schema migration files
│   └── functions/                  # 4 Deno Edge Functions
│       ├── create-exam/
│       ├── start-exam/
│       ├── join-exam/
│       └── submit-answer/
│
├── assets/
│   └── top5000_bundle.json         # ~1.1 MB bundled English–Uzbek dictionary
│
├── tools/                          # Python scripts & SQL for seeding vocabulary data
│   ├── generate_navigate_a1_seed.py
│   ├── generate_navigate_a2_seed.py
│   ├── generate_round_up_seed.py
│   ├── generate_irregular_verbs_seed.py
│   ├── seed_content.sql
│   ├── seed_navigate_a1.sql
│   ├── seed_navigate_a2.sql
│   ├── seed_round_up.sql
│   └── seed_irregular_verbs.sql
│
├── test/                           # Widget & unit tests
├── android/                        # Android native project
├── ios/                            # iOS native project
├── web/                            # Web platform support
├── windows/                        # Windows platform support
├── linux/                          # Linux platform support
├── macos/                          # macOS platform support
├── pubspec.yaml                    # All dependencies & app metadata
└── analysis_options.yaml           # Dart lint rules
```

---

## 4. Screens & Navigation

### App-Level Routing (GoRouter)

The app uses `go_router` for declarative, deep-link-capable navigation. On startup, `main.dart` determines the initial route:

- First launch → `/welcome` (onboarding)
- Returning teacher → `/teacher/dashboard`
- Returning student → `/home`

---

### Onboarding Flow (One-time, not in bottom nav)

| Screen | File | What It Does |
|--------|------|--------------|
| **Welcome** | `onboarding/welcome_screen.dart` | First screen; user taps "Student" or "Teacher" to choose role |
| **Username** | `onboarding/username_screen.dart` | Enter a unique username; validated against Supabase `profiles` table |
| **PIN Setup** | `onboarding/pin_setup_screen.dart` | Create a 4-digit PIN stored encrypted in the device keystore |
| **Join Class** | `onboarding/join_class_screen.dart` | Student enters a 6-character class code from their teacher |
| **Teacher Class Setup** | `onboarding/teacher_class_setup_screen.dart` | Teacher creates their first class and class name |
| **Class Code Reveal** | `onboarding/class_code_reveal_screen.dart` | Shows the generated class code teachers share with students |
| **Recovery** | `onboarding/recovery_screen.dart` | Recover account using saved username + PIN after reinstall |
| **Update** | `update.dart` | Shown when the app version is below the minimum required version |

---

### Student Navigation (5 Tabs — `StudentNavShell`)

#### Tab 1 — Home (`home_screen.dart`)
The main hub for a student. Shows:
- Current XP, level, and streak
- Weekly leaderboard position
- Pinned teacher message/announcement
- "Rival" — the student just above them on the leaderboard
- Upcoming or active exam banner
- Quick-access button to start games

Sub-routes from Home:
- `/home/games` → **Game Selection Screen** — pick which game mode to play with the current vocabulary set
- `/home/leaderboard` → **Leaderboard Screen** — full weekly XP ranking for the class
- `/home/hall-of-fame` → **Hall of Fame Screen** — all-time XP leaders

#### Tab 2 — Library (`library/library_screen.dart`)
Displays curated vocabulary collections grouped by:
- Book (Navigate A1, Navigate A2, Round Up, Irregular Verbs, etc.)
- Unit number
- Difficulty level (A1, A2, B1, etc.)

Students tap a collection to browse words or launch a game session from that unit. Teachers can also assign units directly from the Library tab.

#### Tab 3 — Speaking (`features/speaking/presentation/screens/scenario_list_screen.dart`)
Scenario-based pronunciation practice (Falou-style). Lists all available scenarios by category (e.g., "At the Hotel", "Shopping", "Introducing Yourself"). Tapping a scenario shows its intro, then launches a lesson runner with exercises.

#### Tab 4 — Duels (`duel/duel_lobby_screen.dart`)
- View a list of classmates to challenge
- See incoming duel challenges (real-time)
- View duel history with past match results

#### Tab 5 — Profile (`profile_screen.dart`)
- Username, avatar initial, total XP, level badge
- Accuracy percentage and lifetime correct answers
- Current streak count and longest streak
- Class information and class code
- Account recovery settings (view/reset PIN)

---

### Teacher Navigation (6 Tabs — `TeacherNavShell`)

#### Tab 1 — Dashboard (`teacher/teacher_dashboard_screen.dart`)
- Quick stats: total students, class average accuracy, average streak
- Pinned message editor (broadcast to all class students)
- Student roster with individual accuracy + XP shown inline
- Quick links to create exams or view analytics

#### Tab 2 — Classes (`teacher/teacher_classes_screen.dart`)
- List all classes the teacher manages (a teacher can have multiple classes)
- Add new classes, view class codes, manage class membership

#### Tab 3 — Library (`teacher/teacher_library_screen.dart`)
- Same collections as the student library
- Additional ability to assign a unit to a class with a due date
- View assignment completion progress per unit

#### Tab 4 — Exams (`teacher/teacher_exams_screen.dart`)
- List all exam sessions created by this teacher
- Status indicators: Lobby, In Progress, Completed, Cancelled
- Tap any exam to open its results

Sub-routes:
- `/teacher/create-exam` → **Create Exam Screen** — select vocabulary units, set question count, time per question, and total time limit; generates the exam session and moves to lobby
- `/teacher/exam-lobby/:id` → **Exam Lobby Screen** — live waiting room showing which students have joined; teacher taps "Start" when ready
- `/teacher/exam-results/:id` → **Exam Results Screen** — detailed breakdown: per-student scores, accuracy, which words caused the most errors (word heatmap)

#### Tab 5 — Analytics (`teacher/teacher_analytics_screen.dart`)
- Class-wide word difficulty heatmap (most missed words shown prominently)
- Student performance trends over time
- Average accuracy and streak graphs

Sub-routes:
- `/teacher/student-detail/:id` → **Student Detail Screen** — individual student's accuracy per unit, missed words, streak history, total games played

#### Tab 6 — Profile (`teacher/teacher_profile_screen.dart`)
- Teacher account settings
- Manage class codes (regenerate if needed)
- Sign out / data export options

---

## 5. Game Modes

All game modes are launched from the **Game Selection Screen** (`game_selection_screen.dart`) or directly from a library unit. After any game, the player is taken to the **Result Screen** (`result_screen.dart`).

### Quiz (`games/quiz_game.dart`)
**What it does:** Presents an English word; student taps the correct Uzbek translation from 4 options.

- 4 multiple-choice options per question; 3 distractors drawn from same unit/book
- Timer bar per question (configurable via `GameConstants`)
- Correct answer flashes green; wrong answer reveals correct one in red
- Speed bonus: faster correct answers award more XP
- Session size: configurable (default from `GameConstants.defaultSessionSize`)

### Flashcard (`games/flashcard_game.dart`)
**What it does:** Shows a card with the English word; student taps to flip and reveal the Uzbek translation.

- Swipe left to mark as "needs more practice", swipe right for "got it"
- Cards marked as difficult are shown again at the end of the session
- No scoring pressure; good for first-pass study

### Matching (`games/matching_game.dart`)
**What it does:** Shows a grid of English words on the left and Uzbek words on the right; student draws lines connecting matching pairs.

- Maximum 6 pairs per round to avoid visual overload
- Matched pairs turn green and lock in place
- Incorrect attempts flash red and reset the selection
- No timer; accuracy-focused

### Memory (`games/memory_game.dart`)
**What it does:** Classic concentration/memory card flip game with English–Uzbek pairs.

- Cards laid face-down in a grid; tap any two to flip
- Matched pairs stay face-up; unmatched cards flip back after a short delay
- Tracks number of attempts for a star rating at the end

### Fill-in-the-Blank (`games/fill_blank_game.dart`)
**What it does:** Shows a sentence or prompt with a blank; student types the Uzbek translation.

- Text input keyboard; case-insensitive comparison
- Minor typos accepted if edit distance ≤ 1 (Levenshtein tolerance)
- Hardest mode — no hints, tests active recall

### Result Screen (`result_screen.dart`)
**What it shows after every game:**
- Score (questions correct / total)
- Accuracy percentage
- XP earned (base + speed bonus)
- Streak status (maintained / broken / milestone)
- Animated "+XP" float animation
- "Play Again" and "Change Mode" buttons

---

## 6. Data Models

All models live in `lib/models/`. The core ones use Hive for offline persistence; others are plain Dart classes mapped to/from Supabase JSON.

### `Vocab` (`models/vocab.dart`)
```
id        String   Unique identifier
english   String   English word or phrase
uzbek     String   Uzbek translation
```
- Persisted in Hive with `typeId: 0`; auto-generated adapter in `vocab.g.dart`
- Used by all game modes as the fundamental learning unit

### `UserProfile` (`models/user_profile.dart`)
```
id                    String   UUID generated on first launch
username              String   Unique display name
xp                    int      Total XP earned lifetime
level                 int      Derived from XP (from XpService)
streakDays            int      Consecutive days with at least one game
lastPlayedDate        String   ISO date of last game (for streak logic)
classCode             String   Class the student belongs to
weekXp                int      XP earned this ISO calendar week
totalWordsAnswered    int      All-time questions answered
totalCorrect          int      All-time correct answers
isTeacher             bool     Determines which navigation shell to show
unlockedBadges        List     Badge IDs earned
```
- Stored in Hive box `'userProfile'` (encrypted)
- Synced to Supabase `profiles` table after every game session
- Source of truth is local; Supabase is the backup

### `ExamSession` (`models/exam_session.dart`)
```
id                String   UUID (Supabase primary key)
teacherId         String   Creator's user ID
classCode         String   Which class this exam is for
title             String   Display name shown to students
bookIds           List     Which books' words to draw from
unitIds           List     Specific units to include
questionCount     int      Total questions in the exam
perQuestionSeconds int     Seconds per question
totalSeconds      int      Hard time limit for the whole exam
status            String   'lobby' | 'in_progress' | 'completed' | 'cancelled'
createdAt         DateTime
startedAt         DateTime?
endedAt           DateTime?
```

### `ExamParticipant` (`models/exam_participant.dart`)
```
sessionId      String   Links to ExamSession.id
studentId      String   Student's UUID
status         String   'invited' | 'joined' | 'in_progress' | 'completed' | 'absent' | 'timed_out'
shuffleSeed    int      Per-student random seed to shuffle question order
joinedAt       DateTime?
completedAt    DateTime?
score          int      Questions answered correctly
accuracy       double   score / total questions
```

### `Assignment` (`models/assignment.dart`)
```
id          String   UUID
classCode   String   Target class
teacherId   String   Creator
bookId      String   Vocabulary book reference
bookTitle   String
unitId      String   Specific unit
unitTitle   String
dueDate     DateTime
wordCount   int      Words in the assigned unit
createdAt   DateTime
isActive    bool

Computed getters:
  isOverdue        → dueDate is before today
  daysRemaining    → days until dueDate
```

### `AssignmentProgress` (`models/assignment_progress.dart`)
```
assignmentId     String   Links to Assignment.id
studentId        String   Student's UUID
completedGames   int      Number of games finished for this assignment
accuracy         double   Average accuracy across games
progress         double   0.0–1.0 completion percentage
```

### `WordStat` (`models/word_stat.dart`)
```
wordEnglish    String   English word
wordUzbek      String   Uzbek translation
timesShown     int      How many times shown class-wide
timesCorrect   int      How many times answered correctly class-wide
```
Used to build the teacher analytics heatmap showing the hardest words for the class.

### `ClassStudent` (`models/class_student.dart`)
```
classCode        String   Links to class
studentId        String
studentUsername  String
joinedAt         DateTime
score            int      Lifetime XP
weekXp           int      This week's XP
```

### `ClassHealthScore` (`models/class_health_score.dart`)
```
classCode       String
avgAccuracy     double   Class average accuracy
totalStudents   int
avgStreak       double   Average streak days across students
```

### `TeacherMessage` (`models/teacher_message.dart`)
```
id           String
classCode    String
teacherId    String
message      String   The announcement text
pinnedAt     DateTime
```

---

## 7. Services (Business Logic)

Services are plain Dart classes (no `ChangeNotifier`). They contain all business logic, database calls, and local storage operations. Providers compose services to expose reactive state to the UI.

### `StorageService` (`services/storage_service.dart`)
**Purpose:** Manages all Hive boxes — the app's primary local database.

- Opens and encrypts Hive boxes on startup
- Registers the `VocabAdapter` type adapter (typeId: 0)
- Provides typed CRUD operations for vocabulary words
- Handles migration from an older, unencrypted box format on first run after encryption was added

### `SecureStorageService` (`services/secure_storage_service.dart`)
**Purpose:** Manages secrets using the platform keystore.

- On Android, uses the Android Keystore; on iOS, uses the Secure Enclave/Keychain
- Generates and stores a random 32-byte AES key for encrypting the Hive security box
- Stores a PBKDF2 hash of the user's 4-digit PIN for account recovery verification
- `verifyPin(pin)` hashes the input and compares it to the stored hash — the raw PIN is never stored

### `ExamService` (`services/exam_service.dart`)
**Purpose:** Manages the full lifecycle of teacher-led exam sessions.

- `fetchWordsForUnits(unitIds)` — queries Supabase `words` table for vocabulary in the selected units
- `createExam(session)` — calls the `create-exam` Edge Function, which pre-generates shuffled questions and inserts them into `exam_questions`
- `startExam(sessionId)` — calls `start-exam` Edge Function; transitions status to `in_progress` and timestamps `started_at`
- `joinExam(sessionId, studentId)` — calls `join-exam` Edge Function; creates an `exam_participants` row with a random shuffle seed
- `submitAnswer(sessionId, studentId, questionId, answer)` — calls `submit-answer` Edge Function; returns whether the answer was correct and updates the participant's running score
- `getExamSession(id)` — fetches current session status (used for real-time polling)
- `getParticipantScore(sessionId, studentId)` — fetches the student's current score mid-exam

### `DuelService` (`services/duel_service.dart`)
**Purpose:** Manages real-time head-to-head vocabulary duels.

- `createDuel(challengerId, opponentId, wordSet)` — inserts a `duels` row with status `pending` and a shared word set (both players get the same questions)
- `acceptDuel(duelId)` / `declineDuel(duelId)` — opponent updates the duel status
- `updateScore(duelId, userId, score)` — called after each question; updates the player's running score in Supabase
- `finishDuel(duelId)` — transitions status to `finished`, records final scores
- `getDuelHistory(userId)` — fetches past duels for the profile history view
- Uses Supabase Realtime to subscribe to score changes on the opponent's row so both players see live updates

### `AssignmentService` (`services/assignment_service.dart`)
**Purpose:** CRUD for teacher-created assignments and student progress tracking.

- `createAssignment(assignment)` — teacher creates an assignment targeting a class + unit
- `loadStudentAssignments(classCode)` — student fetches all active assignments for their class
- `getAssignmentProgress(assignmentId, studentId)` — returns a student's current progress
- `submitAssignmentGame(assignmentId, studentId, accuracy)` — called after each game; increments `completedGames` and recalculates accuracy
- `markAssignmentComplete(assignmentId, studentId)` — sets progress to 100%

### `ClassService` (`services/class_service.dart`)
**Purpose:** Manages classroom membership and aggregate statistics.

- `createClass(teacherId, className)` — generates a unique 6-character alphanumeric class code and inserts a `classes` row
- `joinClass(studentId, classCode)` — adds the student to `class_students`; validates the class code exists
- `getClassStudents(classCode)` — returns all students in the class with their XP and streak data
- `getClassInfo(classCode)` — returns class name and teacher ID
- `getClassHealth(classCode)` — computes and returns a `ClassHealthScore` aggregate

### `WordStatsService` (`services/word_stats_service.dart`)
**Purpose:** Tracks per-word accuracy data for spaced repetition and analytics.

- `recordWordAttempt(classCode, word, wasCorrect)` — upserts a row in `word_stats`, incrementing `times_shown` and optionally `times_correct`
- `getWordStats(classCode)` — returns all word stats for a class, used by the teacher analytics heatmap
- `getClassWordStats(classCode)` — alias returning the hardest words (lowest accuracy ratio) sorted by difficulty

### `XpService` (`services/xp_service.dart`)
**Purpose:** Pure calculation logic for the XP and level system.

- `levelFromXp(xp)` — computes current level from total XP (exponential curve)
- `xpNeededForNextLevel(level)` — threshold XP for the next level
- `levelProgressPercent(xp)` — 0.0–1.0 progress within the current level (for the XP bar)
- `calculateXpGain(baseXp, answeredInSeconds, totalSeconds)` — applies a speed multiplier: answering quickly awards up to 2× base XP

### `StreakService` (`services/streak_service.dart`)
**Purpose:** Manages the daily streak system.

- `checkStreakOnAppOpen(profile)` — compares `lastPlayedDate` to today; resets streak to 0 if more than 1 day has elapsed
- `handleGameCompletion(profile)` — called after finishing a game; updates `lastPlayedDate` and increments `streakDays` if this is the first game of the day
- `resetStreakIfMissed(profile)` — helper used by `checkStreakOnAppOpen` to produce a new `UserProfile` with streak reset

### `SyncService` (`services/sync_service.dart`)
**Purpose:** Keeps local Hive data in sync with Supabase, tolerating offline conditions.

- `syncProfile(profile)` — upserts the full `UserProfile` to Supabase `profiles`; if it fails (network error), enqueues the update to the Hive `sync_queue` box
- `drainSyncQueue()` — called on app start and after each successful sync; replays any queued updates in order
- Ensures eventual consistency without blocking the UI on network latency

### `NotificationService` (`services/notification_service.dart`)
**Purpose:** Manages local push notifications.

- `initialize()` — sets up `flutter_local_notifications` plugin with Android/iOS channel config
- `requestPermission()` — requests notification permission from the OS
- `showStreakWarning()` — fires a local notification in the evening if the user hasn't played today (streak at risk)
- `notifyDuelChallenge(opponentName)` — fires a notification when another student challenges this user to a duel

### `TeacherMessageService` (`services/teacher_message_service.dart`)
**Purpose:** Teacher-to-class broadcast announcements.

- `getMessage(classCode)` — fetches the most recently pinned message for a class; shown on the student Home screen
- `pinMessage(classCode, teacherId, message)` — inserts or replaces the pinned message for the class

### `AccountRecoveryService` (`services/account_recovery_service.dart`)
**Purpose:** Allows users to recover their account after reinstalling the app.

- `initiateRecovery(username)` — looks up the profile in Supabase by username to verify it exists
- `verifyPin(pin)` — cross-checks the entered PIN against the stored hash via `SecureStorageService`
- `restoreProfile(username)` — downloads the profile from Supabase and restores it to the local Hive box

### `VersionService` (`services/version_service.dart`)
**Purpose:** Enforces minimum app version policy.

- `checkForUpdate()` — fetches the minimum required version from a Supabase config table and compares it to `package_info_plus` version
- Returns `true` if the installed version is below the minimum, triggering the `update.dart` screen

### `DictionaryService` (`services/dictionary_service.dart`)
**Purpose:** Seeds the local Hive database with the bundled vocabulary dictionary.

- `loadBundledDictionary()` — reads `assets/top5000_bundle.json` on first launch
- Parses the 5 000-word English–Uzbek dictionary into `Vocab` objects
- Writes them to the Hive `vocabTypedBox`
- Sets a flag so this import only runs once

---

## 8. State Management — Riverpod Providers

The app uses `flutter_riverpod` for reactive state. All providers are defined in `lib/providers/`.

### `profileProvider` (`providers/profile_provider.dart`)
- **Type:** `StateNotifierProvider<ProfileNotifier, UserProfile?>`
- **State:** The logged-in user's complete profile
- **What it does:** The single source of truth for user state. `ProfileNotifier` exposes `updateXp()`, `updateStreak()`, `setClassCode()`, and similar mutation methods. Each mutation:
  1. Updates the in-memory state
  2. Writes to local Hive
  3. Calls `SyncService.syncProfile()` asynchronously
- A `_withWriteLock()` re-entrancy guard prevents concurrent mutations from losing updates (e.g., if two games finish simultaneously)

### `vocabProvider` (`providers/vocab_provider.dart`)
- **Type:** `FutureProvider<List<Vocab>>`
- **State:** All vocabulary words loaded from Hive
- **What it does:** Loads vocab from the `vocabTypedBox` Hive box. If empty, triggers `DictionaryService.loadBundledDictionary()` first. Words are sorted alphabetically for the Library display.

### `assignmentProvider` (`providers/assignment_provider.dart`)
- **Type:** `StateNotifierProvider<AssignmentNotifier, List<Assignment>>`
- **State:** All active assignments for the current student's class
- **What it does:** Calls `AssignmentService.loadStudentAssignments()` on initialization. `AssignmentNotifier` exposes `refresh()` to reload from Supabase and `markProgress()` to update a specific assignment's progress locally before syncing.

### `examProvider` (`providers/exam_provider.dart`)
- **Type:** `StateNotifierProvider`
- **State:** All exam sessions created by this teacher
- **What it does:** Used exclusively in the teacher view. Fetches exams filtered by `teacherId` from Supabase. Exposes `createExam()` and `cancelExam()` mutations.

### `studentExamProvider` (`providers/student_exam_provider.dart`)
- **Type:** `StateNotifierProvider`
- **State:** The student's current exam participation state
- **What it does:** Handles joining an exam session, receiving questions (via `ExamService.joinExam()`), and submitting answers. Tracks the student's local score and syncs it via the `submit-answer` Edge Function.

### `duelProvider` (`providers/duel_provider.dart`)
- **Type:** `StateNotifierProvider`
- **State:** Active duel and duel history list
- **What it does:** Manages the full duel lifecycle. Sets up a Supabase Realtime subscription on the `duels` table filtered to this user's ID to receive incoming challenges and live score updates.

### `leaderboardProvider` (`providers/leaderboard_provider.dart`)
- **Type:** `FutureProvider`
- **State:** Ranked list of users by XP
- **What it does:** Fetches from Supabase `profiles` ordered by `week_xp` DESC (weekly) or `xp` DESC (all-time). Returns top 100 results.

### `wordStatsProvider` (`providers/word_stats_provider.dart`)
- **Type:** `FutureProvider`
- **State:** Word statistics for the current class
- **What it does:** Fetches `word_stats` rows for the teacher's class. Used to render the analytics heatmap.

### `classStudentsProvider` (`providers/class_students_provider.dart`)
- **Type:** `StateNotifierProvider`
- **State:** Student roster with live stats
- **What it does:** Calls `ClassService.getClassStudents()`. Used on the teacher dashboard to render the student list. Exposes `refresh()` for pull-to-refresh.

---

## 9. Database Schema (Supabase)

The database is PostgreSQL hosted on Supabase. Schema is managed through 5 migration files.

### Core Tables

#### `profiles`
```sql
id               TEXT PRIMARY KEY  -- User UUID (client-generated)
username         TEXT UNIQUE
xp               INT DEFAULT 0
level            INT DEFAULT 1
streak_days      INT DEFAULT 0
last_played_date TEXT              -- ISO date string
class_code       TEXT
week_xp          INT DEFAULT 0
total_words_answered INT DEFAULT 0
total_correct    INT DEFAULT 0
is_teacher       BOOLEAN DEFAULT FALSE
updated_at       TIMESTAMPTZ
```

#### `classes`
```sql
class_code   TEXT PRIMARY KEY  -- 6-char alphanumeric (e.g., "XK9F2T")
teacher_id   TEXT              -- References profiles.id
class_name   TEXT
created_at   TIMESTAMPTZ
```

#### `words` (Vocabulary Master Data)
```sql
id               TEXT PRIMARY KEY
unit_id          TEXT
book_id          TEXT
word             TEXT  -- English
translation      TEXT  -- Uzbek
part_of_speech   TEXT
difficulty       TEXT  -- A1 / A2 / B1 / B2
```

#### `units`
```sql
id           TEXT PRIMARY KEY
book_id      TEXT
unit_title   TEXT
unit_number  INT
```

#### `collections` (Library Curated Sets)
```sql
id            TEXT PRIMARY KEY
short_title   TEXT
category      TEXT
difficulty    TEXT
is_published  BOOLEAN
cover_emoji   TEXT
```

#### `exam_sessions`
```sql
id                  UUID PRIMARY KEY DEFAULT gen_random_uuid()
teacher_id          TEXT
class_code          TEXT
title               TEXT
book_ids            TEXT[]
unit_ids            TEXT[]
question_count      INT
per_question_seconds INT
total_seconds       INT
status              TEXT  -- 'lobby' | 'in_progress' | 'completed' | 'cancelled'
created_at          TIMESTAMPTZ
started_at          TIMESTAMPTZ
ended_at            TIMESTAMPTZ
```

#### `exam_questions`
```sql
id              UUID PRIMARY KEY
session_id      UUID  -- References exam_sessions.id
order_index     INT
word_id         TEXT
prompt          TEXT  -- The English word shown
correct_answer  TEXT  -- The correct Uzbek translation
options         JSONB -- Array of 4 choices (shuffled)
```

#### `exam_participants`
```sql
session_id    UUID  -- References exam_sessions.id
student_id    TEXT  -- References profiles.id
status        TEXT  -- 'invited' | 'joined' | 'in_progress' | 'completed' | 'absent' | 'timed_out'
shuffle_seed  INT
joined_at     TIMESTAMPTZ
completed_at  TIMESTAMPTZ
score         INT DEFAULT 0
accuracy      DOUBLE PRECISION DEFAULT 0
PRIMARY KEY (session_id, student_id)
```

#### `duels`
```sql
id                   UUID PRIMARY KEY DEFAULT gen_random_uuid()
challenger_id        TEXT
challenger_username  TEXT
opponent_id          TEXT
opponent_username    TEXT
status               TEXT  -- 'pending' | 'active' | 'finished'
word_set             JSONB -- Shared vocabulary for this duel
started_at           TIMESTAMPTZ
ended_at             TIMESTAMPTZ
challenger_score     INT DEFAULT 0
opponent_score       INT DEFAULT 0
```

#### `assignments`
```sql
id           UUID PRIMARY KEY
class_code   TEXT
teacher_id   TEXT
book_id      TEXT
book_title   TEXT
unit_id      TEXT
unit_title   TEXT
due_date     DATE
word_count   INT
created_at   TIMESTAMPTZ
is_active    BOOLEAN DEFAULT TRUE
```

#### `assignment_progress`
```sql
assignment_id    UUID  -- References assignments.id
student_id       TEXT
completed_games  INT DEFAULT 0
accuracy         DOUBLE PRECISION DEFAULT 0
progress         DOUBLE PRECISION DEFAULT 0
PRIMARY KEY (assignment_id, student_id)
```

#### `word_stats`
```sql
id             UUID PRIMARY KEY
class_code     TEXT
word_english   TEXT
word_uzbek     TEXT
times_shown    INT DEFAULT 0
times_correct  INT DEFAULT 0
```

#### `class_health_scores`
```sql
class_code      TEXT PRIMARY KEY
avg_accuracy    DOUBLE PRECISION
total_students  INT
avg_streak      DOUBLE PRECISION
```

#### `teacher_messages`
```sql
id           UUID PRIMARY KEY
class_code   TEXT
teacher_id   TEXT
message      TEXT
pinned_at    TIMESTAMPTZ
```

### Row-Level Security (RLS)

All tables have RLS enabled. Key policies:

| Table | Who can READ | Who can WRITE |
|-------|-------------|---------------|
| `profiles` | Anyone (needed for leaderboard) | Own row only |
| `exam_sessions` | Any student (to join) | Teacher (own rows) |
| `exam_questions` | Any participant | Teacher via Edge Function |
| `exam_participants` | Own row | Own row (status updates) |
| `duels` | Both challenger & opponent | Both players |
| `assignments` | Class members | Teacher only |
| `word_stats` | Class members | Class members |

---

## 10. Edge Functions (Serverless)

Edge Functions are TypeScript/Deno functions deployed to Supabase's global edge network. They run server-side logic that should not be trusted to the client.

### `create-exam`
**When called:** Teacher taps "Create Exam" after selecting units and settings.

**What it does:**
1. Receives `teacherId`, `classCode`, `title`, `unitIds`, `questionCount`, `perQuestionSeconds`, `totalSeconds`
2. Queries the `words` table for all vocabulary in the selected units
3. Randomly samples `questionCount` words
4. For each word, generates 3 distractor options from other words in the set
5. Inserts a new `exam_sessions` row with status `'lobby'`
6. Inserts all generated questions into `exam_questions`
7. Returns the new `sessionId` to the client

**Why server-side:** Ensures all students get identical questions; prevents the teacher's client from cheating or manipulating the question set.

### `start-exam`
**When called:** Teacher taps "Start" in the exam lobby.

**What it does:**
1. Receives `sessionId` and `teacherId`
2. Verifies the teacher owns this session
3. Updates `exam_sessions.status` to `'in_progress'`
4. Sets `started_at` to the current timestamp
5. Returns the updated session

**Why server-side:** Ensures the start time is authoritative; prevents students from starting early by manipulating the client.

### `join-exam`
**When called:** Student taps "Join" on the exam banner.

**What it does:**
1. Receives `sessionId` and `studentId`
2. Verifies the session exists and is in `'lobby'` or `'in_progress'` status
3. Verifies the student is in the correct class
4. Generates a random `shuffleSeed` for this student (determines their question order)
5. Inserts an `exam_participants` row with status `'joined'`
6. Returns the participant row and all questions (ordered by the student's shuffle)

### `submit-answer`
**When called:** Student answers a question during an exam.

**What it does:**
1. Receives `sessionId`, `studentId`, `questionId`, `answer`
2. Looks up the correct answer from `exam_questions`
3. Returns `{ correct: true/false, correctAnswer: "..." }`
4. Updates `exam_participants.score` (increments if correct)
5. Recalculates and updates `accuracy`
6. If this was the last question, marks participant status as `'completed'` and sets `completed_at`

**Why server-side:** Prevents cheating by hiding the correct answers from the client until after submission.

---

## 11. Local Storage — Hive (Offline-First)

The app uses Hive, a fast key-value database for Flutter, as its primary data store. Supabase is the sync target, not the primary source.

### Hive Boxes

| Box Name | Type | Contents | Encrypted? |
|----------|------|----------|------------|
| `vocabTypedBox` | `Box<Vocab>` | All vocabulary words (from bundled JSON) | No (public data) |
| `userProfile` | `Box<dynamic>` | `UserProfile` fields as a map | Yes (AES-256) |
| `secureBox` | `Box<dynamic>` | PIN hash, Hive encryption key | Yes (AES-256, keystore-backed) |
| `sync_queue` | `Box<dynamic>` | Failed sync operations pending retry | Yes |

### Encryption
- The AES key for `userProfile` and `secureBox` is generated once, stored in the platform keystore (Android Keystore / iOS Keychain), and never leaves the device.
- The PIN is stored as a PBKDF2 hash — the raw PIN is discarded after hashing.

### First-Launch Flow
1. App opens → `SecureStorageService.getOrCreateHiveKey()` generates or retrieves the AES key
2. Hive initializes with the encrypted key
3. `DictionaryService.loadBundledDictionary()` checks if `vocabTypedBox` is empty
4. If empty, reads `assets/top5000_bundle.json`, parses 5 000 word pairs, writes them to Hive
5. Sets a `SharedPreferences` flag so this only runs once

---

## 12. Speaking Module

The speaking module lives in `lib/features/speaking/` using a clean architecture pattern (Domain → Data → Presentation).

### Purpose
Scenario-based pronunciation practice modeled after apps like Falou. Students practice English phrases in realistic contexts (hotel check-in, shopping, introductions, etc.) with immediate pronunciation feedback.

### Architecture Layers

#### Domain (`features/speaking/domain/`)
- `scenario.dart` — Entity defining a scenario: title, description, category, list of exercises
- `exercise.dart` — Entity for a single exercise (exercise type, target phrase, hints)
- `pronunciation_scorer.dart` — Abstract interface for scoring a recorded audio against a target phrase

#### Data (`features/speaking/data/`)
- `falou_scenarios.dart` — Hardcoded scenario definitions (the content library)
- `sherpa_onnx_service.dart` — Integration with the Sherpa-ONNX offline speech recognition engine; loads Zipformer ONNX model files, runs ASR on recorded WAV audio, returns transcript
- `tts_service.dart` — Text-to-speech using `flutter_tts`; plays example pronunciations for students to hear before repeating
- `gemini_scorer.dart` — When `GEMINI_API_KEY` is configured, sends the ASR transcript to Gemini for phonetic scoring and feedback; falls back to basic string-match scoring otherwise

#### Presentation (`features/speaking/presentation/`)
**Screens:**
- `scenario_list_screen.dart` — Grid of available scenarios with category filter
- `scenario_intro_screen.dart` — Scenario overview: context description, difficulty, example dialogue
- `lesson_runner_screen.dart` — Main exercise runner; sequences through exercises, shows hearts/lives, handles recording
- `scenario_complete_screen.dart` — Completion summary with accuracy score, XP earned, and badge unlock

**Exercise Widgets** (different exercise types rendered inside `lesson_runner_screen.dart`):
- `listen_repeat_widget.dart` — Plays TTS pronunciation → student records → ASR scores the recording → shows match percentage
- `listen_widget.dart` — Listen-only comprehension; no recording required
- `recall_widget.dart` — Student speaks the translation without hearing it first (harder mode)
- `word_breakdown_widget.dart` — Focuses on individual words within a phrase; plays each word separately

**Support Widgets:**
- `hearts_indicator.dart` — Shows remaining lives (3 hearts, lose one per failed attempt)
- `mic_button.dart` — Large microphone button with pulsing waveform animation during recording
- `phrase_card.dart` — Displays the target English phrase with a speaker icon to play TTS

### Offline Speech Recognition (Sherpa-ONNX)
The app bundles the `sherpa_onnx` Flutter package which uses ONNX Runtime to run a Zipformer speech recognition model entirely on-device. This means:
- No audio is sent to any server
- Works without internet connection
- Model files are downloaded and extracted from a ZIP archive on first use

### Scoring
1. Student records audio using the `record` package (outputs WAV)
2. WAV is passed to `SherpaOnnxService.transcribe()` → returns text transcript
3. If Gemini API key is available: transcript + target phrase sent to Gemini, which returns a 0–100 phonetic score and specific feedback
4. If no Gemini key: falls back to normalized edit-distance scoring (Levenshtein) between transcript and target phrase
5. Score ≥ 80 counts as a pass; < 80 deducts a heart

---

## 13. Teacher System

Teachers use the same app binary as students. The `isTeacher: true` flag on their `UserProfile` routes them to the teacher navigation shell.

### Teacher Capabilities

#### Class Management
- Create multiple classes, each with an auto-generated 6-character code
- Share the code verbally or on screen for students to join
- View full student roster with real-time XP and streak data
- See class health metrics (average accuracy, average streak, total active students)

#### Assignment System
- Browse the Library and assign any vocabulary unit to their class
- Set a due date for the assignment
- Monitor per-student and per-assignment completion from the analytics screen
- Students see their due assignments on the Home screen with a countdown

#### Live Exam System
- Create an exam session by selecting units and configuring question count + time limits
- An exam lobby is created; students who are online see a banner and can join
- Teacher taps "Start" to synchronize the exam start for all joined students
- During the exam, the teacher sees a live participant count and completion status
- After the exam, the teacher sees a detailed results screen with:
  - Per-student scores and accuracy
  - Question-level analysis (which words most students missed)
  - Time taken per student

#### Analytics
- Word difficulty heatmap: shows the Uzbek translations students most frequently get wrong class-wide
- Built from `word_stats` table which is updated after every game session by all students in the class

#### Messaging
- Pin a single broadcast message to the class
- Shown prominently on every student's Home screen until the teacher updates or removes it

---

## 14. Duel System

The duel system enables real-time head-to-head vocabulary competitions between two classmates.

### Flow

1. **Challenge:** Student A opens the Duels tab, selects Student B from their classmates list, and taps "Challenge"
2. **Notification:** Student B receives a local notification ("Student A challenged you to a duel!")
3. **Accept/Decline:** Student B opens the app, sees the pending challenge, and accepts or declines
4. **Play:** Both students simultaneously answer the same vocabulary questions (same word set, same order via shared seed)
5. **Live Scores:** After each answer, both players' scores update in real time via Supabase Realtime
6. **Result:** When both finish (or time out), the Results screen shows winner, final scores, and XP awarded

### Word Set
The duel word set is drawn from the vocabulary both students have in common (based on their class assignments or the global top-5000 bundle). It's embedded in the `duels.word_set` JSONB column at challenge creation time, ensuring both players see the same questions even if the database changes mid-duel.

### Supabase Realtime
- Each client subscribes to `channel: 'duel-{duelId}'`
- Score updates trigger Postgres changes → broadcast to both subscribers
- No polling required; latency is typically under 200ms on a good connection

---

## 15. Exam System

The exam system is the most complex feature, providing teacher-synchronized assessment for classroom settings.

### Key Design Decisions

**Questions are generated server-side (Edge Function).** This prevents the client from seeing correct answers before submission and ensures all students get identical questions with consistent randomization.

**Per-student shuffle seed.** Each student gets a unique random seed, so their question order is different from classmates (prevents copying), but the same questions appear for everyone.

**Answers are validated server-side.** The `submit-answer` Edge Function holds the ground truth. The client never receives the correct answer until after submission.

**Status machine:**
```
lobby → in_progress → completed
         ↓
      cancelled
```

### Student Exam Flow
1. Student sees the exam banner on Home screen (real-time polling detects when teacher creates an exam)
2. Student taps "Join" → `join-exam` Edge Function creates their participant row
3. Student waits in the lobby until the teacher starts
4. When teacher starts, all students' screens transition to the first question simultaneously
5. Per-question countdown timer shows remaining time; auto-advances when time runs out
6. After all questions, shows a brief "waiting for results" screen
7. Once the teacher views results, students can also see the full breakdown

---

## 16. XP, Levels & Streaks

### XP System (`services/xp_service.dart`)
XP (Experience Points) is the primary reward currency.

**Sources of XP:**
| Action | Base XP | Speed Bonus |
|--------|---------|-------------|
| Correct answer in any game | 10 XP | Up to 2× if answered quickly |
| Completing a game session | 20 XP | — |
| Winning a duel | 50 XP | — |
| Completing an exam | 30 XP | Accuracy bonus |
| Completing a speaking lesson | 25 XP | — |

**Level Curve:** Exponential — each level requires progressively more XP. Level 1 → 2 requires 100 XP; Level 10 → 11 requires ~1 000 XP. This is calculated by `XpService.levelFromXp()`.

**Week XP:** A separate `weekXp` counter resets every Monday (ISO week). Used for the weekly leaderboard to keep it competitive — high-level users don't permanently dominate new players.

### Streak System (`services/streak_service.dart`)
A streak counts consecutive calendar days on which the student completed at least one game.

- **Increment:** On the first game completion of a calendar day, `streakDays` increments
- **Reset:** If `lastPlayedDate` is more than 1 day before today when the app opens, `streakDays` resets to 0
- **Warning:** `NotificationService.showStreakWarning()` fires a local notification at ~8 PM if the user hasn't played yet that day
- **Milestones:** The Streak Widget shows special animations at 7, 30, 100-day milestones

### Leaderboard (`providers/leaderboard_provider.dart`)
- **Weekly:** Top students by `week_xp` — resets every Monday
- **All-time (Hall of Fame):** Top students by total `xp`
- Both are class-wide (not global) to keep competition relevant to peers

---

## 17. Design System & Theme

All design tokens are defined in `lib/theme/app_theme.dart`.

### Design Language
- **Dark-first** with a light variant
- Glassmorphism cards with subtle blur and border glow
- Gradient-heavy — backgrounds, buttons, badges all use multi-stop gradients
- Micro-animations on XP gains, streak milestones, and correct answers

### Color Palette

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| Background | `#0F1123` | `#F5F6FA` |
| Surface | `#1A1D3A` | `#FFFFFF` |
| Card | `#1E2140` | `#F0F2FF` |
| Primary (Violet) | `#7C4DFF` | `#5C2FE0` |
| Primary Light | `#A47AFF` | `#7C4DFF` |
| Accent (Gold/XP) | `#FFB300` | `#FF8F00` |
| Fire (Streak) | `#FF6D00` | `#FF3D00` |
| Success | `#00E676` | `#00C853` |
| Error | `#FF5252` | `#D50000` |

### Gradients
- `darkBgGradient` / `lightBgGradient` — full-screen background sweep
- `primaryGradient` — violet gradient for primary action buttons
- `xpGradient` — gold–amber for XP and level badge backgrounds
- `fireGradient` — orange–red for streak indicators
- `successGradient` — green for correct answer feedback

### Typography
- **Font:** Google Fonts Inter (loaded via `google_fonts` package)
- **Weights used:** Regular (400), Medium (500), SemiBold (600), Bold (700), ExtraBold (800)
- **Scale:** caption 12sp → body 14–16sp → title 20sp → heading 24sp → display 32sp

---

## 18. Key Widgets

### `XpBarWidget` (`widgets/xp_bar_widget.dart`)
Displays the user's current level and XP progress.
- Shows: Level badge (number in gradient circle) + progress bar from 0 to next level threshold
- Animated: bar fills smoothly on XP gain using `AnimatedContainer`
- Rendered on: Home screen header, Profile tab, Result screen

### `StreakWidget` (`widgets/streak_widget.dart`)
Displays the current streak count with fire animation.
- Shows: Flame icon + day count + "day streak" label
- At milestones (7, 30, 100 days): emits a particle burst animation
- Color: `fireGradient` — orange-to-red
- Rendered on: Home screen, Profile tab, Result screen

### `LeaderboardRowWidget` (`widgets/leaderboard_row_widget.dart`)
Single row in the leaderboard list.
- Shows: Rank number (with gold/silver/bronze for top 3), avatar initial in colored circle, username, XP
- Current user's row has a highlighted background tint
- Rendered on: Leaderboard screen, Hall of Fame screen

### `VocabTile` (`widgets/vocab_tile.dart`)
Card displaying a vocabulary word pair.
- Shows: English word (large) + Uzbek translation (smaller)
- State variants: default / answered-correct (green glow) / answered-wrong (red glow)
- Tappable for the Library browse view
- Rendered on: Library screen, student detail missed-words list

### `ExamBannerWidget` (`widgets/exam_banner_widget.dart`)
Floating notification banner for active or upcoming exams.
- Shows: Exam title, teacher name, time remaining to join
- Has a "Join Now" button that calls the `join-exam` Edge Function
- Animates in from the top when an exam enters `lobby` or `in_progress` status
- Rendered on: Home screen

### `CustomButton` (`widgets/custom_button.dart`)
Reusable button component with multiple variants.
- Variants: `primary` (gradient fill), `secondary` (outline), `destructive` (red)
- Loading state: shows `CircularProgressIndicator` and disables interaction
- Used throughout the app for consistency

### `XpFloatWidget` (`widgets/xp_float_widget.dart`)
Animated "+XP" toast that floats upward and fades out after a correct answer.
- Shows: "+10 XP" (or whatever the gain was) in the accent gold color
- Triggered by: correct answer in any game, game completion, duel win
- Rendered as an overlay on the game screens

---

## 19. Dependencies & What They Do

### Core Framework

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter` | SDK | Core Flutter framework — widget toolkit, rendering engine, platform channels |
| `flutter_riverpod` | ^2.6.1 | Reactive state management; replaces Provider; compile-safe dependency injection |

### Local Storage

| Package | Version | Purpose |
|---------|---------|---------|
| `hive` | ^2.2.3 | Fast, lightweight NoSQL key-value database; primary offline data store |
| `hive_flutter` | ^1.1.0 | Flutter-specific Hive initialization and `path_provider` integration |
| `path_provider` | ^2.1.4 | Gets platform-specific storage paths (documents, app support, temp) |
| `flutter_secure_storage` | ^9.2.2 | Stores secrets in Android Keystore / iOS Keychain; used for the Hive AES key and PIN hash |
| `shared_preferences` | ^2.3.3 | Simple key-value flags (e.g., "has loaded dictionary"); secondary to Hive |

### Backend (Supabase)

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.8.4 | Official Supabase Flutter SDK; handles PostgreSQL queries, Realtime subscriptions, and Edge Function calls |
| `http` | ^1.6.0 | Low-level HTTP client; used directly for Edge Function invocations with custom headers |

### Navigation

| Package | Version | Purpose |
|---------|---------|---------|
| `go_router` | ^14.6.3 | Declarative URL-based routing with nested shell routes for bottom nav tabs; supports deep linking |

### UI & Typography

| Package | Version | Purpose |
|---------|---------|---------|
| `google_fonts` | ^6.2.1 | Loads Google Fonts (Inter) at runtime; used for all text in the app |
| `cupertino_icons` | ^1.0.8 | iOS-style icon set (supplementary to Material icons) |
| `intl` | ^0.19.0 | Internationalization — date/number formatting, locale handling |

### Notifications & Communication

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_local_notifications` | ^18.0.1 | Schedules and displays local notifications (streak warnings, duel challenges) |
| `firebase_core` | ^4.6.0 | Firebase SDK initialization; required by `firebase_messaging` |
| `firebase_messaging` | ^16.1.3 | Firebase Cloud Messaging for server-sent push notifications (used for duel challenges when app is closed) |
| `connectivity_plus` | ^6.1.0 | Detects network state changes; triggers `SyncService.drainSyncQueue()` when connectivity is restored |
| `timezone` | ^0.10.0 | Timezone database; required for scheduling notifications at specific local times |

### Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| `uuid` | ^4.5.1 | Generates RFC 4122 UUID v4 for user IDs and session IDs |
| `crypto` | ^3.0.6 | PBKDF2 and SHA-256 hashing for the PIN security system |
| `package_info_plus` | ^9.0.0 | Reads the app version from pubspec.yaml at runtime; used by `VersionService` |
| `url_launcher` | ^6.3.2 | Opens URLs in the system browser (terms of service, privacy policy) |
| `share_plus` | ^10.1.4 | Invokes the system share sheet (share class code with students) |
| `path` | ^1.9.1 | Platform-independent path string manipulation |
| `archive` | ^3.6.1 | Extracts ZIP archives; used to unpack the Sherpa-ONNX speech model files |

### Speaking Module — Speech & Audio

| Package | Version | Purpose |
|---------|---------|---------|
| `sherpa_onnx` | ^1.12.39 | On-device offline speech recognition using Zipformer ONNX models (no network required) |
| `speech_to_text` | ^7.0.0 | Cloud-based ASR fallback via OS speech recognition APIs; used when Sherpa models are unavailable |
| `flutter_tts` | ^4.2.0 | Text-to-speech; plays example English phrases for students to hear before repeating |
| `record` | ^6.2.0 | Records microphone audio to WAV files; provides waveform amplitude data for the mic animation |
| `permission_handler` | ^11.3.0 | Cross-platform microphone and notification permission requests |

### Build / Dev Only

| Package | Version | Purpose |
|---------|---------|---------|
| `build_runner` | ^2.4.13 | Runs code generators at build time |
| `hive_generator` | ^2.0.1 | Generates Hive type adapter code (`vocab.g.dart`) from `@HiveType`/`@HiveField` annotations |
| `flutter_lints` | ^5.0.0 | Official Flutter lint rules; enforces code quality |
| `flutter_test` | SDK | Flutter test framework for unit and widget tests |

---

## 20. Configuration & Environment

### Build-Time Variables

The app uses `--dart-define` compile-time variables for secrets, keeping them out of source code:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJh... \
  --dart-define=GEMINI_API_KEY=AIza...   # optional — enables Gemini-powered speech scoring
```

These are read in `lib/config/environment_constants.dart`:
```dart
static const supabaseUrl    = String.fromEnvironment('SUPABASE_URL');
static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
static const geminiApiKey   = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
```

If `SUPABASE_URL` or `SUPABASE_ANON_KEY` are missing, the app throws a clear error at startup rather than crashing silently.

### Firebase Configuration

`lib/config/firebase_options.dart` is auto-generated by the FlutterFire CLI. It contains:
- Firebase project ID, API keys, and app IDs per platform (Android, iOS, Web)
- Used only by `firebase_core` (init) and `firebase_messaging` (push notifications)
- **Not** committed in plain text to public repos — replaced with environment-specific values in CI

### Vocabulary Seeding Tools (`tools/`)

The `tools/` directory contains Python scripts and generated SQL for seeding the Supabase `words` and `units` tables with real vocabulary content:

| Script | What It Seeds |
|--------|--------------|
| `generate_navigate_a1_seed.py` | Navigate A1 textbook vocabulary |
| `generate_navigate_a2_seed.py` | Navigate A2 textbook vocabulary |
| `generate_round_up_seed.py` | Round Up grammar series vocabulary |
| `generate_irregular_verbs_seed.py` | Common English irregular verb forms |

The scripts output SQL `INSERT` statements into the corresponding `.sql` files in `tools/`, which are then run against the Supabase database via the Supabase CLI or dashboard SQL editor.

---

## 21. Architectural Patterns

### Trust-the-Client Identity Model
The app does not use Supabase Auth (no email/password, no OAuth). Instead:
- A UUID is generated on first launch and stored in encrypted Hive
- This UUID is passed as a field in all Supabase queries and Edge Function calls
- Edge Functions do server-side authorization by checking class membership and ownership

**Why:** Reduces friction significantly — students never need to remember an email or password. The PIN system provides recovery. For an educational app used by children, this is a common pattern.

### Offline-First with Sync Queue
1. All game results are written to Hive immediately (no network dependency)
2. `SyncService.syncProfile()` attempts to push changes to Supabase
3. If the network call fails, the update is serialized to a `sync_queue` Hive box
4. On next app open (or when `connectivity_plus` detects reconnection), `drainSyncQueue()` replays all queued updates in order

**Why:** Students in Uzbekistan may have intermittent connectivity. They should never lose XP or streaks due to network issues.

### Re-entrancy Guard on Profile Mutations
`ProfileNotifier` uses a `_withWriteLock()` pattern:
- An `_isMutating` flag is set before any async mutation begins
- If another mutation arrives while `_isMutating` is true, it waits using a `Completer` queue
- This prevents lost updates from two game sessions completing simultaneously (e.g., user rapidly taps in two different screens)

### Clean Architecture in the Speaking Module
The speaking feature uses a distinct three-layer architecture:
- **Domain** — pure Dart entities and abstract interfaces; no Flutter, no Supabase, no packages
- **Data** — concrete implementations of domain interfaces (Sherpa ONNX, Gemini API, flutter_tts)
- **Presentation** — Riverpod-connected screens and widgets

**Why:** The speaking module is the most complex and independently evolving feature. Clean architecture makes it easier to swap the ASR engine or scoring API without changing the UI layer.

### Single Binary, Dual Role
There is one app binary. Teachers and students are separated by:
1. The `isTeacher` boolean in `UserProfile`
2. Two separate `GoRouter` shell routes with different `StatefulShellRoute` navigators
3. A redirect guard in the router that checks `isTeacher` on startup

**Why:** Simplifies distribution — the same APK is shared to everyone. Teachers self-identify during onboarding.

---

## 22. Summary Statistics

| Metric | Count |
|--------|-------|
| Screens (total) | 25+ |
| Game Modes | 5 |
| Speaking Exercise Types | 4 |
| Data Models | 10 |
| Services | 23 |
| Riverpod Providers | 9 |
| Reusable Widgets | 7 (+4 speaking) |
| Supabase Tables | 13 |
| Schema Migrations | 5 |
| Edge Functions | 4 |
| Hive Boxes | 4 |
| Direct Dependencies | 36 |
| Asset Files | 1 (top5000_bundle.json, ~1.1 MB) |
| Platform Targets | 6 (Android, iOS, Web, Windows, macOS, Linux) |

---

*Generated: 2026-04-23*  
*App Version: 1.0.3+3*
