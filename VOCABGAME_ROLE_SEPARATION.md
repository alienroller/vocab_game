# VOCABGAME — COMPLETE ROLE SEPARATION ARCHITECTURE
## Teacher and Student as Two Parallel Experiences

> **READ THIS ENTIRE DOCUMENT BEFORE WRITING A SINGLE LINE OF CODE.**
> This document defines every data model, every service method, every screen, every provider,
> and every navigation route required to make Teacher and Student truly separate roles.
> Every decision is explained. Every field is named. Every method signature is given.
> Do not invent anything not listed here. Do not skip any section.
> Implement in the exact order given in Section 14.

---

## TABLE OF CONTENTS

1. [The Mental Model — What Changes and Why](#1-the-mental-model)
2. [Database Schema — New and Modified Tables](#2-database-schema)
3. [Dart Data Models — New Classes](#3-dart-data-models)
4. [Services — New and Modified Methods](#4-services)
5. [Providers — New and Modified](#5-providers)
6. [Navigation Architecture — Two Shells](#6-navigation-architecture)
7. [Teacher Screens — All 5 Tabs](#7-teacher-screens)
8. [Student Screens — Modified](#8-student-screens)
9. [Library Assignment Integration](#9-library-assignment-integration)
10. [Onboarding — Split by Role](#10-onboarding-split)
11. [Class Health Score — Formula and Display](#11-class-health-score)
12. [At-Risk Detection — Logic](#12-at-risk-detection)
13. [Word Analytics — Tracking and Display](#13-word-analytics)
14. [Order of Implementation](#14-order-of-implementation)
15. [Verification Checklist](#15-verification-checklist)
16. [Complete File List](#16-complete-file-list)

---

## 1. THE MENTAL MODEL

### Why the Current Architecture Is Wrong

Right now `isTeacher` is a boolean flag that shows/hides a few buttons inside shared screens.
A teacher still lands on the student home screen (vocab list, XP bar, rival card, play button).
A teacher still has a streak counter, a weekly XP tracker, and appears on the leaderboard.
The teacher dashboard is buried inside the Profile tab — the least discoverable location.

This is not role separation. This is feature flagging on top of a single-role app.

### The Correct Mental Model

```
VocabGame
├── Shared Infrastructure (never changes)
│   ├── UUID-based identity (no Supabase Auth)
│   ├── Hive local storage
│   ├── SyncService (profiles sync)
│   ├── AccountRecoveryService (PIN)
│   └── Library content (books + units — read-only for both roles)
│
├── Student Experience
│   ├── Goal: improve personally, compete with peers
│   ├── Home: vocab list, XP bar, streak, rival card, assignment card
│   ├── Library: browse books/units, see assigned badge, study mode
│   ├── Speaking: speaking practice exercises
│   ├── Duels: real-time battles with classmates
│   └── Profile: personal stats, class membership, account
│
└── Teacher Experience
    ├── Goal: monitor students, assign content, identify who needs help
    ├── Dashboard: class health score, at-risk list, teacher message
    ├── My Classes: class code, student table, copy/share code
    ├── Library: browse books/units, ASSIGN units to class (no personal study)
    ├── Analytics: word difficulty heatmap, assignment completion, per-student drill-down
    └── Profile: class info only, account settings — NO XP, NO streak, NO level
```

### Hard Rules That Cannot Be Broken

1. **Teachers do NOT appear on any leaderboard.** Filter them out at query level.
2. **Teachers do NOT appear in any student's rival card calculation.** Filter at query level.
3. **Teachers cannot be challenged to Duels.** Filter at lobby level.
4. **Teachers see ZERO gamification UI.** No XP bar, no streak widget, no level badge, no accuracy stats on their profile.
5. **The teacher's `classCode` in `UserProfile` is the class they OWN.** They created it. They manage it. They do not "participate" in it as a learner.
6. **`AppShell` renders a completely different widget tree based on `isTeacher`.** No `if (isTeacher)` blocks scattered inside shared screen files.
7. **All `if (isTeacher)` blocks in existing screens must be removed** and replaced with role-specific screen files.

---

## 2. DATABASE SCHEMA

### 2A. Existing Tables — Required Modifications

#### `profiles` table — add one column

```sql
-- No new columns needed on profiles.
-- IMPORTANT: The existing is_teacher and class_code columns are used as-is.
-- For teachers: class_code = the class they OWN (not joined as student).
-- For students: class_code = the class they JOINED.
-- There is no ambiguity because a teacher never joins a class they don't own.
```

#### `classes` table — ensure teacher_id exists (from previous fixes doc)

```sql
-- Already added in previous fix document:
ALTER TABLE classes ADD COLUMN IF NOT EXISTS teacher_id TEXT NOT NULL DEFAULT '';
```

### 2B. New Table: `assignments`

One row per assignment. A teacher assigns a specific library unit to their class.

```sql
CREATE TABLE assignments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_code    TEXT NOT NULL,
  teacher_id    TEXT NOT NULL,
  book_id       TEXT NOT NULL,
  book_title    TEXT NOT NULL,
  unit_id       TEXT NOT NULL,
  unit_title    TEXT NOT NULL,
  due_date      TEXT,               -- 'YYYY-MM-DD' ISO string, NULL means no deadline
  word_count    INTEGER NOT NULL,   -- total words in the unit at time of assignment
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  is_active     BOOLEAN DEFAULT true
);

-- Index for fast student queries:
CREATE INDEX idx_assignments_class_code ON assignments(class_code);

-- Index for fast teacher queries:
CREATE INDEX idx_assignments_teacher_id ON assignments(teacher_id);
```

**Rules:**
- One class can have multiple active assignments simultaneously.
- A teacher deactivating an assignment (`is_active = false`) hides it from students.
- Deleting an assignment cascades to `assignment_progress`.

### 2C. New Table: `assignment_progress`

One row per (assignment, student) pair. Tracks how far each student is on each assignment.

```sql
CREATE TABLE assignment_progress (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id     UUID NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
  student_id        TEXT NOT NULL,
  class_code        TEXT NOT NULL,
  words_mastered    INTEGER DEFAULT 0,
  total_words       INTEGER NOT NULL,
  is_completed      BOOLEAN DEFAULT false,
  last_practiced_at TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(assignment_id, student_id)
);

-- Index for teacher analytics queries:
CREATE INDEX idx_asgn_progress_assignment ON assignment_progress(assignment_id);
CREATE INDEX idx_asgn_progress_student ON assignment_progress(student_id);
CREATE INDEX idx_asgn_progress_class ON assignment_progress(class_code);
```

**Rules:**
- A row is created the first time a student starts practicing an assigned unit.
- `words_mastered` is updated every time `recordGameSession()` is called in Assignment Mode.
- `is_completed` becomes `true` when `words_mastered >= total_words`.
- `last_practiced_at` is updated on every practice session.

### 2D. New Table: `word_stats`

Tracks per-student accuracy for each vocabulary word. Used by teacher analytics to identify hard words.

```sql
CREATE TABLE word_stats (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    TEXT NOT NULL,
  class_code    TEXT NOT NULL,
  word_english  TEXT NOT NULL,
  word_uzbek    TEXT NOT NULL,
  times_shown   INTEGER DEFAULT 0,
  times_correct INTEGER DEFAULT 0,
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, word_english)
);

-- Index for teacher analytics: get all word stats for a class:
CREATE INDEX idx_word_stats_class ON word_stats(class_code);

-- Index for per-student queries:
CREATE INDEX idx_word_stats_student ON word_stats(student_id);
```

**Rules:**
- Updated every time a student answers a question in any game mode (personal or assignment).
- Used ONLY for teacher analytics. Students never see this table directly.
- Upsert on conflict: increment `times_shown` and `times_correct` (if correct).

### 2E. New Table: `teacher_messages`

A teacher can pin a short message visible to all students on their home screen.

```sql
CREATE TABLE teacher_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_code  TEXT NOT NULL UNIQUE,  -- one active message per class
  teacher_id  TEXT NOT NULL,
  message     TEXT NOT NULL,         -- max 200 characters, enforced in Dart
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
```

**Rules:**
- `UNIQUE` on `class_code` means there is exactly one row per class.
- Teacher updates their message with an upsert (conflict on `class_code`).
- Deleting the row = no message shown to students.
- Students fetch this once on home screen load. Cached in Hive for offline.

### 2F. RLS Policies for New Tables

Run in Supabase SQL Editor after creating the tables:

```sql
-- Enable RLS on all new tables
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignment_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_messages ENABLE ROW LEVEL SECURITY;

-- assignments: teacher can read/write their own class. Students can read their class.
CREATE POLICY "assignments_teacher_all" ON assignments
  FOR ALL USING (teacher_id = current_setting('app.user_id', true));

CREATE POLICY "assignments_student_read" ON assignments
  FOR SELECT USING (
    class_code IN (
      SELECT class_code FROM profiles
      WHERE id = current_setting('app.user_id', true)
    )
  );

-- assignment_progress: student can read/write own rows. Teacher can read all in their class.
CREATE POLICY "progress_student_own" ON assignment_progress
  FOR ALL USING (student_id = current_setting('app.user_id', true));

CREATE POLICY "progress_teacher_read" ON assignment_progress
  FOR SELECT USING (
    class_code IN (
      SELECT class_code FROM profiles
      WHERE id = current_setting('app.user_id', true) AND is_teacher = true
    )
  );

-- word_stats: student writes own. Teacher reads all in their class.
CREATE POLICY "word_stats_student_own" ON word_stats
  FOR ALL USING (student_id = current_setting('app.user_id', true));

CREATE POLICY "word_stats_teacher_read" ON word_stats
  FOR SELECT USING (
    class_code IN (
      SELECT class_code FROM profiles
      WHERE id = current_setting('app.user_id', true) AND is_teacher = true
    )
  );

-- teacher_messages: teacher writes own. Students in same class can read.
CREATE POLICY "msg_teacher_write" ON teacher_messages
  FOR ALL USING (teacher_id = current_setting('app.user_id', true));

CREATE POLICY "msg_student_read" ON teacher_messages
  FOR SELECT USING (
    class_code IN (
      SELECT class_code FROM profiles
      WHERE id = current_setting('app.user_id', true)
    )
  );
```

---

## 3. DART DATA MODELS

All new model files go in `lib/models/`.

### 3A. `Assignment` model — `lib/models/assignment.dart`

```dart
class Assignment {
  final String id;           // UUID from Supabase
  final String classCode;
  final String teacherId;
  final String bookId;
  final String bookTitle;
  final String unitId;
  final String unitTitle;
  final String? dueDate;     // 'YYYY-MM-DD' or null
  final int wordCount;
  final DateTime createdAt;
  final bool isActive;

  const Assignment({
    required this.id,
    required this.classCode,
    required this.teacherId,
    required this.bookId,
    required this.bookTitle,
    required this.unitId,
    required this.unitTitle,
    this.dueDate,
    required this.wordCount,
    required this.createdAt,
    required this.isActive,
  });

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] as String,
      classCode: map['class_code'] as String,
      teacherId: map['teacher_id'] as String,
      bookId: map['book_id'] as String,
      bookTitle: map['book_title'] as String,
      unitId: map['unit_id'] as String,
      unitTitle: map['unit_title'] as String,
      dueDate: map['due_date'] as String?,
      wordCount: map['word_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      isActive: map['is_active'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'class_code': classCode,
      'teacher_id': teacherId,
      'book_id': bookId,
      'book_title': bookTitle,
      'unit_id': unitId,
      'unit_title': unitTitle,
      'due_date': dueDate,
      'word_count': wordCount,
      'is_active': isActive,
      // id and created_at are generated by Supabase — do NOT include on insert
    };
  }

  // Returns true if the due date is today or in the past
  bool get isOverdue {
    if (dueDate == null) return false;
    final due = DateTime.parse(dueDate!);
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day)
        .isAfter(DateTime(due.year, due.month, due.day));
  }

  // Days remaining until due date. Returns null if no due date.
  int? get daysRemaining {
    if (dueDate == null) return null;
    final due = DateTime.parse(dueDate!);
    final today = DateTime.now();
    return due.difference(DateTime(today.year, today.month, today.day)).inDays;
  }
}
```

### 3B. `AssignmentProgress` model — `lib/models/assignment_progress.dart`

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

  const AssignmentProgress({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.classCode,
    required this.wordsMastered,
    required this.totalWords,
    required this.isCompleted,
    this.lastPracticedAt,
  });

  factory AssignmentProgress.fromMap(Map<String, dynamic> map) {
    return AssignmentProgress(
      id: map['id'] as String,
      assignmentId: map['assignment_id'] as String,
      studentId: map['student_id'] as String,
      classCode: map['class_code'] as String,
      wordsMastered: map['words_mastered'] as int,
      totalWords: map['total_words'] as int,
      isCompleted: map['is_completed'] as bool,
      lastPracticedAt: map['last_practiced_at'] != null
          ? DateTime.parse(map['last_practiced_at'] as String)
          : null,
    );
  }

  // Progress as a value between 0.0 and 1.0
  double get progressRatio =>
      totalWords == 0 ? 0.0 : wordsMastered / totalWords;

  // For display: "14 / 25 words"
  String get progressLabel => '$wordsMastered / $totalWords words';
}
```

### 3C. `ClassStudent` model — `lib/models/class_student.dart`

Used by teacher analytics. Replaces the raw `Map<String, dynamic>` currently returned by `getClassStudents()`.

```dart
class ClassStudent {
  final String id;
  final String username;
  final int xp;
  final int level;
  final int streakDays;
  final int totalWordsAnswered;
  final int totalCorrect;
  final String? lastPlayedDate;   // 'YYYY-MM-DD' or null

  const ClassStudent({
    required this.id,
    required this.username,
    required this.xp,
    required this.level,
    required this.streakDays,
    required this.totalWordsAnswered,
    required this.totalCorrect,
    this.lastPlayedDate,
  });

  factory ClassStudent.fromMap(Map<String, dynamic> map) {
    return ClassStudent(
      id: map['id'] as String,
      username: map['username'] as String,
      xp: map['xp'] as int,
      level: map['level'] as int,
      streakDays: map['streak_days'] as int,
      totalWordsAnswered: map['total_words_answered'] as int,
      totalCorrect: map['total_correct'] as int,
      lastPlayedDate: map['last_played_date'] as String?,
    );
  }

  // Safe accuracy: returns 0.0 if no answers
  double get accuracy =>
      totalWordsAnswered == 0 ? 0.0 : totalCorrect / totalWordsAnswered;

  // For display: "74%" or "—"
  String get accuracyDisplay =>
      totalWordsAnswered == 0 ? '—' : '${(accuracy * 100).round()}%';

  // At-risk: hasn't played in 3 or more days
  bool get isAtRisk {
    if (lastPlayedDate == null) return true; // never played
    final last = DateTime.parse(lastPlayedDate!);
    final today = DateTime.now();
    final daysSince = DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    return daysSince >= 3;
  }

  // Days since last activity. Returns null if never played.
  int? get daysSinceActive {
    if (lastPlayedDate == null) return null;
    final last = DateTime.parse(lastPlayedDate!);
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
  }
}
```

### 3D. `WordStat` model — `lib/models/word_stat.dart`

Used for teacher analytics word heatmap.

```dart
class WordStat {
  final String wordEnglish;
  final String wordUzbek;
  final int timesShown;
  final int timesCorrect;

  const WordStat({
    required this.wordEnglish,
    required this.wordUzbek,
    required this.timesShown,
    required this.timesCorrect,
  });

  factory WordStat.fromMap(Map<String, dynamic> map) {
    return WordStat(
      wordEnglish: map['word_english'] as String,
      wordUzbek: map['word_uzbek'] as String,
      timesShown: map['times_shown'] as int,
      timesCorrect: map['times_correct'] as int,
    );
  }

  // Class-level accuracy for this word (across all students)
  double get accuracy =>
      timesShown == 0 ? 0.0 : timesCorrect / timesShown;

  String get accuracyDisplay => '${(accuracy * 100).round()}%';

  // Difficulty tier: used for heatmap color
  // 'hard'   = accuracy < 0.40
  // 'medium' = accuracy 0.40 - 0.69
  // 'easy'   = accuracy >= 0.70
  String get difficultyTier {
    if (accuracy < 0.40) return 'hard';
    if (accuracy < 0.70) return 'medium';
    return 'easy';
  }
}
```

### 3E. `TeacherMessage` model — `lib/models/teacher_message.dart`

```dart
class TeacherMessage {
  final String classCode;
  final String message;
  final DateTime updatedAt;

  const TeacherMessage({
    required this.classCode,
    required this.message,
    required this.updatedAt,
  });

  factory TeacherMessage.fromMap(Map<String, dynamic> map) {
    return TeacherMessage(
      classCode: map['class_code'] as String,
      message: map['message'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
```

### 3F. `ClassHealthScore` model — `lib/models/class_health_score.dart`

A computed value, not stored in Supabase. Calculated fresh on each teacher dashboard load.

```dart
class ClassHealthScore {
  final double score;          // 0-100
  final double avgAccuracy;    // 0.0 - 1.0
  final double engagementRate; // 0.0 - 1.0: fraction of students active this week
  final int totalStudents;
  final int activeStudentsThisWeek;
  final int atRiskCount;

  const ClassHealthScore({
    required this.score,
    required this.avgAccuracy,
    required this.engagementRate,
    required this.totalStudents,
    required this.activeStudentsThisWeek,
    required this.atRiskCount,
  });

  // Score label for display
  String get label {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Attention';
  }

  // Color tier for display (return a string key, map to Color in UI)
  // 'green' = score >= 80
  // 'amber' = score >= 60
  // 'orange' = score >= 40
  // 'red'   = score < 40
  String get colorTier {
    if (score >= 80) return 'green';
    if (score >= 60) return 'amber';
    if (score >= 40) return 'orange';
    return 'red';
  }
}
```

---

## 4. SERVICES

### 4A. New Service: `AssignmentService` — `lib/services/assignment_service.dart`

This service handles all Supabase operations for assignments and assignment progress.
It follows the same pattern as `ClassService`: static methods, no state.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment.dart';
import '../models/assignment_progress.dart';

class AssignmentService {
  static final _supabase = Supabase.instance.client;

  // ─── TEACHER METHODS ───────────────────────────────────────────────────────

  /// Creates a new assignment for a class.
  /// Returns the created Assignment with its Supabase-generated id.
  /// Throws PostgrestException on failure.
  static Future<Assignment> createAssignment({
    required String classCode,
    required String teacherId,
    required String bookId,
    required String bookTitle,
    required String unitId,
    required String unitTitle,
    required int wordCount,
    String? dueDate, // 'YYYY-MM-DD' or null
  }) async {
    final data = await _supabase
        .from('assignments')
        .insert({
          'class_code': classCode,
          'teacher_id': teacherId,
          'book_id': bookId,
          'book_title': bookTitle,
          'unit_id': unitId,
          'unit_title': unitTitle,
          'word_count': wordCount,
          'due_date': dueDate,
          'is_active': true,
        })
        .select()
        .single();
    return Assignment.fromMap(data);
  }

  /// Deactivates an assignment (soft delete — students no longer see it).
  /// Only the teacher who created it should call this (verified by RLS).
  static Future<void> deactivateAssignment(String assignmentId) async {
    await _supabase
        .from('assignments')
        .update({'is_active': false})
        .eq('id', assignmentId);
  }

  /// Gets all active assignments created by this teacher for their class.
  /// Returns newest first.
  static Future<List<Assignment>> getTeacherAssignments({
    required String classCode,
    required String teacherId,
  }) async {
    final data = await _supabase
        .from('assignments')
        .select()
        .eq('class_code', classCode)
        .eq('teacher_id', teacherId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Assignment.fromMap(e)).toList();
  }

  /// Gets the assignment completion summary for a given assignment.
  /// Returns: how many students have completed it, total students in class.
  /// Used by teacher analytics to show "11/18 students completed Unit 3".
  static Future<Map<String, int>> getAssignmentCompletionSummary({
    required String assignmentId,
    required String classCode,
  }) async {
    // Count total students in class (excluding teacher)
    final totalData = await _supabase
        .from('profiles')
        .select('id')
        .eq('class_code', classCode)
        .eq('is_teacher', false);
    final totalStudents = (totalData as List).length;

    // Count completed progress rows for this assignment
    final completedData = await _supabase
        .from('assignment_progress')
        .select('id')
        .eq('assignment_id', assignmentId)
        .eq('is_completed', true);
    final completedCount = (completedData as List).length;

    return {
      'completed': completedCount,
      'total': totalStudents,
    };
  }

  /// Gets per-student progress for a specific assignment.
  /// Returns list of maps: {student_id, username, words_mastered, total_words, is_completed}
  /// Used for individual assignment analytics.
  static Future<List<Map<String, dynamic>>> getAssignmentStudentProgress({
    required String assignmentId,
  }) async {
    // Join assignment_progress with profiles to get username
    final data = await _supabase
        .from('assignment_progress')
        .select('student_id, words_mastered, total_words, is_completed, last_practiced_at, profiles(username)')
        .eq('assignment_id', assignmentId);
    return List<Map<String, dynamic>>.from(data as List);
  }

  // ─── STUDENT METHODS ───────────────────────────────────────────────────────

  /// Gets all active assignments for the student's class.
  /// Called on student home screen load.
  static Future<List<Assignment>> getStudentAssignments({
    required String classCode,
  }) async {
    final data = await _supabase
        .from('assignments')
        .select()
        .eq('class_code', classCode)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Assignment.fromMap(e)).toList();
  }

  /// Gets this student's progress on all assignments in their class.
  /// Returns a map of assignmentId -> AssignmentProgress.
  /// If no progress row exists for an assignment, that assignment is not in the map.
  static Future<Map<String, AssignmentProgress>> getStudentProgressMap({
    required String studentId,
  }) async {
    final data = await _supabase
        .from('assignment_progress')
        .select()
        .eq('student_id', studentId);
    final list = (data as List).map((e) => AssignmentProgress.fromMap(e));
    return {for (var p in list) p.assignmentId: p};
  }

  /// Creates or updates a student's progress row for an assignment.
  /// Called from AssignmentModeGame when a session ends.
  ///
  /// Parameters:
  /// - assignmentId: the UUID of the assignment
  /// - studentId: the student's profile UUID
  /// - classCode: the student's class_code (denormalized for analytics)
  /// - wordsMasteredDelta: how many additional words were mastered this session
  /// - totalWords: total words in the assignment (needed if creating new row)
  static Future<void> updateAssignmentProgress({
    required String assignmentId,
    required String studentId,
    required String classCode,
    required int wordsMasteredDelta,
    required int totalWords,
  }) async {
    // Check if a progress row already exists
    final existing = await _supabase
        .from('assignment_progress')
        .select()
        .eq('assignment_id', assignmentId)
        .eq('student_id', studentId)
        .maybeSingle();

    if (existing == null) {
      // First time this student practices this assignment — create row
      final newMastered = wordsMasteredDelta.clamp(0, totalWords);
      await _supabase.from('assignment_progress').insert({
        'assignment_id': assignmentId,
        'student_id': studentId,
        'class_code': classCode,
        'words_mastered': newMastered,
        'total_words': totalWords,
        'is_completed': newMastered >= totalWords,
        'last_practiced_at': DateTime.now().toIso8601String(),
      });
    } else {
      // Row exists — increment words_mastered, cap at total_words
      final currentMastered = existing['words_mastered'] as int;
      final newMastered = (currentMastered + wordsMasteredDelta).clamp(0, totalWords);
      await _supabase
          .from('assignment_progress')
          .update({
            'words_mastered': newMastered,
            'is_completed': newMastered >= totalWords,
            'last_practiced_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id'] as String);
    }
  }
}
```

### 4B. New Service: `AnalyticsService` — `lib/services/analytics_service.dart`

Handles all teacher analytics queries. Called only from teacher screens.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_student.dart';
import '../models/class_health_score.dart';
import '../models/word_stat.dart';

class AnalyticsService {
  static final _supabase = Supabase.instance.client;

  /// Returns all students in a class (excluding the teacher).
  /// teacher_id is used to exclude the teacher from the list.
  /// This replaces ClassService.getClassStudents() with a typed result.
  static Future<List<ClassStudent>> getClassStudents({
    required String classCode,
    required String teacherId,
  }) async {
    final data = await _supabase
        .from('profiles')
        .select('id, username, xp, level, streak_days, total_words_answered, total_correct, last_played_date')
        .eq('class_code', classCode)
        .eq('is_teacher', false)   // exclude teacher rows
        .neq('id', teacherId)      // belt-and-suspenders: also exclude by id
        .order('xp', ascending: false);
    return (data as List).map((e) => ClassStudent.fromMap(e)).toList();
  }

  /// Computes the ClassHealthScore from student data.
  /// Call this after getClassStudents() — pass the result directly.
  /// Does not make a Supabase call — pure computation.
  static ClassHealthScore computeHealthScore(List<ClassStudent> students) {
    if (students.isEmpty) {
      return ClassHealthScore(
        score: 0,
        avgAccuracy: 0,
        engagementRate: 0,
        totalStudents: 0,
        activeStudentsThisWeek: 0,
        atRiskCount: 0,
      );
    }

    // Average accuracy across all students with at least one answer
    final studentsWithAnswers = students.where((s) => s.totalWordsAnswered > 0);
    final avgAccuracy = studentsWithAnswers.isEmpty
        ? 0.0
        : studentsWithAnswers.map((s) => s.accuracy).reduce((a, b) => a + b) /
            studentsWithAnswers.length;

    // Engagement rate: fraction of students active in last 7 days
    // A student is "active this week" if lastPlayedDate is within the last 7 days
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final activeThisWeek = students.where((s) {
      if (s.lastPlayedDate == null) return false;
      final last = DateTime.parse(s.lastPlayedDate!);
      return last.isAfter(sevenDaysAgo);
    }).length;
    final engagementRate = activeThisWeek / students.length;

    // At-risk count: students who haven't played in 3+ days
    final atRisk = students.where((s) => s.isAtRisk).length;

    // Class health score formula:
    // (avgAccuracy × 0.5 + engagementRate × 0.5) × 100
    // This means: equally weights "are they accurate?" and "are they active?"
    final score = (avgAccuracy * 0.5 + engagementRate * 0.5) * 100;

    return ClassHealthScore(
      score: score,
      avgAccuracy: avgAccuracy,
      engagementRate: engagementRate,
      totalStudents: students.length,
      activeStudentsThisWeek: activeThisWeek,
      atRiskCount: atRisk,
    );
  }

  /// Fetches word stats aggregated across all students in the class.
  /// Groups by word, sums times_shown and times_correct.
  /// Used for the word difficulty heatmap.
  /// Returns list sorted by accuracy ascending (hardest first).
  static Future<List<WordStat>> getClassWordStats({
    required String classCode,
  }) async {
    // Fetch all individual word_stats rows for the class
    final data = await _supabase
        .from('word_stats')
        .select('word_english, word_uzbek, times_shown, times_correct')
        .eq('class_code', classCode);

    final rows = data as List;
    if (rows.isEmpty) return [];

    // Aggregate: group by word_english, sum the counts
    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final row in rows) {
      final word = row['word_english'] as String;
      if (!aggregated.containsKey(word)) {
        aggregated[word] = {
          'word_english': word,
          'word_uzbek': row['word_uzbek'],
          'times_shown': 0,
          'times_correct': 0,
        };
      }
      aggregated[word]!['times_shown'] =
          (aggregated[word]!['times_shown'] as int) + (row['times_shown'] as int);
      aggregated[word]!['times_correct'] =
          (aggregated[word]!['times_correct'] as int) + (row['times_correct'] as int);
    }

    final stats = aggregated.values.map((e) => WordStat.fromMap(e)).toList();

    // Sort hardest first (lowest accuracy first)
    stats.sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return stats;
  }
}
```

### 4C. New Service: `WordStatsService` — `lib/services/word_stats_service.dart`

Called by the game engine to track per-word accuracy. Called from inside `recordGameSession()` or directly from the game screens before calling `recordGameSession()`.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class WordStatsService {
  static final _supabase = Supabase.instance.client;

  /// Records the result of answering a single vocabulary word.
  /// Call this for EVERY word answered in ANY game mode (personal or assignment).
  ///
  /// Parameters:
  /// - studentId: the student's UUID
  /// - classCode: the student's class_code (null if student has no class — skip upload)
  /// - wordEnglish: the English side of the word
  /// - wordUzbek: the Uzbek side of the word
  /// - wasCorrect: whether the student answered correctly
  static Future<void> recordWordAnswer({
    required String studentId,
    required String? classCode,
    required String wordEnglish,
    required String wordUzbek,
    required bool wasCorrect,
  }) async {
    // Only sync to Supabase if the student is in a class.
    // No class = no teacher = no analytics needed.
    if (classCode == null || classCode.isEmpty) return;

    // Upsert: if row exists, increment. If not, create.
    // We cannot use a single SQL increment upsert easily from client SDK,
    // so we use a fetch-then-update pattern with conflict handling.
    try {
      final existing = await _supabase
          .from('word_stats')
          .select('id, times_shown, times_correct')
          .eq('student_id', studentId)
          .eq('word_english', wordEnglish)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('word_stats').insert({
          'student_id': studentId,
          'class_code': classCode,
          'word_english': wordEnglish,
          'word_uzbek': wordUzbek,
          'times_shown': 1,
          'times_correct': wasCorrect ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _supabase
            .from('word_stats')
            .update({
              'times_shown': (existing['times_shown'] as int) + 1,
              'times_correct': (existing['times_correct'] as int) + (wasCorrect ? 1 : 0),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'] as String);
      }
    } catch (_) {
      // Silently fail — word stat tracking is non-critical.
      // Main game flow must not be blocked by analytics failures.
    }
  }
}
```

### 4D. New Service: `TeacherMessageService` — `lib/services/teacher_message_service.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_message.dart';

class TeacherMessageService {
  static final _supabase = Supabase.instance.client;

  /// Posts or updates the teacher's pinned message for their class.
  /// Uses upsert on class_code (there is a UNIQUE constraint on class_code).
  static Future<void> setMessage({
    required String classCode,
    required String teacherId,
    required String message,
  }) async {
    await _supabase.from('teacher_messages').upsert(
      {
        'class_code': classCode,
        'teacher_id': teacherId,
        'message': message.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'class_code',
    );
  }

  /// Removes the teacher's message (students will see no message card).
  static Future<void> deleteMessage(String classCode) async {
    await _supabase
        .from('teacher_messages')
        .delete()
        .eq('class_code', classCode);
  }

  /// Fetches the current message for a class. Returns null if none exists.
  /// Called on student home screen load and teacher dashboard load.
  static Future<TeacherMessage?> getMessage(String classCode) async {
    final data = await _supabase
        .from('teacher_messages')
        .select()
        .eq('class_code', classCode)
        .maybeSingle();
    if (data == null) return null;
    return TeacherMessage.fromMap(data);
  }
}
```

### 4E. Modified: `ClassService.getClassStudents()` — `lib/services/class_service.dart`

**REMOVE the old `getClassStudents()` method entirely.** It returned raw maps and did not exclude the teacher. Replace it with `AnalyticsService.getClassStudents()` which returns typed `ClassStudent` objects and excludes the teacher by both `is_teacher = false` and `id != teacherId`.

Any screen that currently calls `ClassService.getClassStudents()` must be updated to call `AnalyticsService.getClassStudents()` instead.

---

## 5. PROVIDERS

### 5A. New Provider: `assignmentProvider` — `lib/providers/assignment_provider.dart`

Holds assignments for the current user. Behavior differs by role.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../models/assignment_progress.dart';
import '../services/assignment_service.dart';
import 'profile_provider.dart';

// State: holds both the assignment list and the student's progress map
class AssignmentState {
  final List<Assignment> assignments;
  final Map<String, AssignmentProgress> progressMap; // assignmentId -> progress
  final bool isLoading;
  final String? error;

  const AssignmentState({
    this.assignments = const [],
    this.progressMap = const {},
    this.isLoading = false,
    this.error,
  });

  AssignmentState copyWith({
    List<Assignment>? assignments,
    Map<String, AssignmentProgress>? progressMap,
    bool? isLoading,
    String? error,
  }) {
    return AssignmentState(
      assignments: assignments ?? this.assignments,
      progressMap: progressMap ?? this.progressMap,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AssignmentNotifier extends StateNotifier<AssignmentState> {
  AssignmentNotifier() : super(const AssignmentState());

  /// Loads assignments for a STUDENT.
  /// Call this from the student's HomeScreen initState / ref.listen on profileProvider.
  Future<void> loadStudentAssignments({
    required String classCode,
    required String studentId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await AssignmentService.getStudentAssignments(
        classCode: classCode,
      );
      final progressMap = await AssignmentService.getStudentProgressMap(
        studentId: studentId,
      );
      state = state.copyWith(
        assignments: assignments,
        progressMap: progressMap,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Loads assignments created by a TEACHER.
  /// Call this from the teacher's Library screen and Analytics screen.
  Future<void> loadTeacherAssignments({
    required String classCode,
    required String teacherId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await AssignmentService.getTeacherAssignments(
        classCode: classCode,
        teacherId: teacherId,
      );
      // Teachers have no progress map — use empty map
      state = state.copyWith(
        assignments: assignments,
        progressMap: const {},
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Called after a student completes an assignment game session.
  /// Updates the progress map locally without a full reload.
  void updateLocalProgress(AssignmentProgress updatedProgress) {
    final newMap = Map<String, AssignmentProgress>.from(state.progressMap);
    newMap[updatedProgress.assignmentId] = updatedProgress;
    state = state.copyWith(progressMap: newMap);
  }

  /// Removes an assignment from the list (after teacher deactivates it).
  void removeAssignment(String assignmentId) {
    state = state.copyWith(
      assignments: state.assignments
          .where((a) => a.id != assignmentId)
          .toList(),
    );
  }
}

final assignmentProvider =
    StateNotifierProvider<AssignmentNotifier, AssignmentState>((ref) {
  return AssignmentNotifier();
});
```

### 5B. New Provider: `classStudentsProvider` — `lib/providers/class_students_provider.dart`

Holds the student list for the teacher's dashboard and analytics. Separate from `assignmentProvider`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_student.dart';
import '../models/class_health_score.dart';
import '../services/analytics_service.dart';

class ClassStudentsState {
  final List<ClassStudent> students;
  final ClassHealthScore? healthScore;
  final bool isLoading;
  final String? error;

  const ClassStudentsState({
    this.students = const [],
    this.healthScore,
    this.isLoading = false,
    this.error,
  });
}

class ClassStudentsNotifier extends StateNotifier<ClassStudentsState> {
  ClassStudentsNotifier() : super(const ClassStudentsState());

  Future<void> load({
    required String classCode,
    required String teacherId,
  }) async {
    state = const ClassStudentsState(isLoading: true);
    try {
      final students = await AnalyticsService.getClassStudents(
        classCode: classCode,
        teacherId: teacherId,
      );
      final healthScore = AnalyticsService.computeHealthScore(students);
      state = ClassStudentsState(
        students: students,
        healthScore: healthScore,
        isLoading: false,
      );
    } catch (e) {
      state = ClassStudentsState(isLoading: false, error: e.toString());
    }
  }
}

final classStudentsProvider =
    StateNotifierProvider<ClassStudentsNotifier, ClassStudentsState>((ref) {
  return ClassStudentsNotifier();
});
```

### 5C. New Provider: `wordStatsProvider` — `lib/providers/word_stats_provider.dart`

Holds the word difficulty heatmap data for the teacher's Analytics screen.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word_stat.dart';
import '../services/analytics_service.dart';

class WordStatsState {
  final List<WordStat> stats;
  final bool isLoading;
  final String? error;

  const WordStatsState({
    this.stats = const [],
    this.isLoading = false,
    this.error,
  });
}

class WordStatsNotifier extends StateNotifier<WordStatsState> {
  WordStatsNotifier() : super(const WordStatsState());

  Future<void> load(String classCode) async {
    state = const WordStatsState(isLoading: true);
    try {
      final stats = await AnalyticsService.getClassWordStats(classCode: classCode);
      state = WordStatsState(stats: stats, isLoading: false);
    } catch (e) {
      state = WordStatsState(isLoading: false, error: e.toString());
    }
  }
}

final wordStatsProvider =
    StateNotifierProvider<WordStatsNotifier, WordStatsState>((ref) {
  return WordStatsNotifier();
});
```

---

## 6. NAVIGATION ARCHITECTURE

### 6A. The Core Change

`AppShell` (`lib/screens/app_shell.dart`) currently renders one `NavigationBar` with 5 tabs for everyone.

**New behavior:** `AppShell` reads `isTeacher` from `profileProvider` and renders either `StudentNavShell` or `TeacherNavShell`. These are two separate widgets with completely different tab sets and branch routes.

### 6B. Router Changes — `lib/router.dart`

Add two new route constants. All existing student routes remain at their current paths.
New teacher-specific routes are added.

```dart
// EXISTING STUDENT ROUTES — do not change paths
// /home              → HomeScreen (student)
// /library           → LibraryScreen (student view)
// /speaking          → SpeakingHomeScreen
// /duels             → DuelLobbyScreen
// /profile           → ProfileScreen (student view)

// NEW TEACHER ROUTES — add these
// /teacher/dashboard     → TeacherDashboardScreen
// /teacher/classes       → TeacherMyClassesScreen
// /teacher/library       → TeacherLibraryScreen (same content, different behavior)
// /teacher/analytics     → TeacherAnalyticsScreen
// /teacher/profile       → TeacherProfileScreen

// SHARED ROUTES (accessible from both shells)
// /search            → DictionarySearchScreen (unchanged)
// /welcome           → WelcomeScreen (unchanged)
// /recovery          → RecoveryScreen (unchanged)
// /onboarding/*      → Onboarding screens (see Section 10)
```

**StatefulShellRoute setup:** Define one `StatefulShellRoute.indexedStack` for student branches and one for teacher branches. `AppShell` decides which shell to render based on `isTeacher`.

**Redirect rule addition:** After the existing `hasOnboarded` check, add:

```dart
// If teacher tries to access a student-only route, redirect to teacher dashboard
final isTeacher = profileBox.get('isTeacher', defaultValue: false);
if (isTeacher && (path == '/home' || path == '/duels' || path == '/speaking')) {
  return '/teacher/dashboard';
}
// If student tries to access a teacher route, redirect to student home
if (!isTeacher && path.startsWith('/teacher')) {
  return '/home';
}
```

### 6C. Student Shell — `lib/screens/student_nav_shell.dart`

This is extracted from the current `AppShell`. Contains exactly what exists today.

```
Tab 0: Home         icon: Icons.home           route: /home
Tab 1: Library      icon: Icons.auto_stories   route: /library
Tab 2: Speaking     icon: Icons.mic            route: /speaking
Tab 3: Duels        icon: Icons.sports_kabaddi route: /duels
Tab 4: Profile      icon: Icons.person         route: /profile
```

Duel invitation badge dot remains on Tab 3 (unchanged behavior).

Back button behavior: same as current (double-tap to exit, or switch to home tab).

### 6D. Teacher Shell — `lib/screens/teacher_nav_shell.dart`

**New widget.** Renders the teacher's 5-tab experience.

```
Tab 0: Dashboard    icon: Icons.dashboard      route: /teacher/dashboard
Tab 1: My Classes   icon: Icons.groups         route: /teacher/classes
Tab 2: Library      icon: Icons.auto_stories   route: /teacher/library
Tab 3: Analytics    icon: Icons.bar_chart      route: /teacher/analytics
Tab 4: Profile      icon: Icons.person         route: /teacher/profile
```

**No badge dots** on any teacher tab (teachers have no duel invitations).

Back button behavior: double-tap-to-exit from Dashboard tab. From any other tab, switch to Dashboard.

### 6E. AppShell — Updated — `lib/screens/app_shell.dart`

```dart
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final isTeacher = profile?.isTeacher ?? false;

    if (isTeacher) {
      return TeacherNavShell(navigationShell: navigationShell);
    } else {
      return StudentNavShell(navigationShell: navigationShell);
    }
  }
}
```

**Note:** The `StatefulNavigationShell` passed to `AppShell` must have branches defined that cover both student and teacher routes. Define all branches in the router; the shell just determines which `NavigationBar` is shown and which tabs respond to taps.

---

## 7. TEACHER SCREENS

All teacher screens live in `lib/screens/teacher/`.

### 7A. Teacher Dashboard Screen — `lib/screens/teacher/teacher_dashboard_screen.dart`

**Route:** `/teacher/dashboard`
**This is the teacher's home screen — the first thing they see when opening the app.**

**On screen init / pull-to-refresh:**
1. Read `profile.classCode` and `profile.id` from `ref.read(profileProvider)`.
2. Call `ref.read(classStudentsProvider.notifier).load(classCode, teacherId)`.
3. Fetch teacher message: `TeacherMessageService.getMessage(classCode)`.

**Layout (top to bottom):**

```
AppBar:
  title: class name (fetched from Supabase 'classes' table once on init, cached)
  actions: [refresh IconButton, share-code IconButton]

Body — SingleChildScrollView:
  1. ClassHealthCard widget
  2. TeacherMessageCard widget (with edit button)
  3. AtRiskSection widget
  4. RecentActivitySection widget (optional — show last 3 students who played)
```

**1. ClassHealthCard widget:**
- Displays: big score number (e.g. "78"), label (e.g. "Good"), colored background
- Color: green/amber/orange/red based on `healthScore.colorTier`
- Below the score: two sub-stats
  - "Engagement: 14/18 active this week"
  - "Avg Accuracy: 72%"
- Tap: navigates to `/teacher/analytics` (Analytics screen)

**2. TeacherMessageCard widget:**
- Shows current message text if one exists.
- If no message: shows "📌 Pin a message for students" in muted text.
- Edit icon (pencil) in top-right corner.
- Tapping edit icon: opens a bottom sheet with a `TextField` (maxLength: 200 chars).
  - Bottom sheet has two buttons: "Clear Message" (deletes) and "Save".
  - On Save: calls `TeacherMessageService.setMessage()`.
  - On Clear: calls `TeacherMessageService.deleteMessage()`.
  - Rebuild the card widget after save/clear (local state update, no full screen reload).

**3. AtRiskSection widget:**
- Header: "⚠️ At Risk — N students"
- Shows only students where `student.isAtRisk == true`.
- Each item: avatar (first letter), username, "Last active: N days ago" or "Never played"
- If zero at-risk students: shows "✅ All students practiced recently" in green.
- Limit display to first 5 at-risk students. If more: "View all in Analytics →" link.

**4. RecentActivitySection (optional, do not implement until Sections 1-3 are working):**
- Shows the last 3 students who had `last_played_date == today`.
- Each item: username, "Played today ✓"

**Pull-to-refresh:** `RefreshIndicator` wrapping the `SingleChildScrollView`. On refresh: re-runs step 1-3 from init.

---

### 7B. Teacher My Classes Screen — `lib/screens/teacher/teacher_classes_screen.dart`

**Route:** `/teacher/classes`

**On screen init:**
1. Read `profile.classCode` and `profile.id` from `ref.read(profileProvider)`.
2. If `classStudentsProvider.state.students` is already loaded (from Dashboard), use it. Otherwise load it.

**Layout:**

```
AppBar:
  title: "My Class"
  actions: [copy-code IconButton]

Body:
  1. ClassInfoCard (class name, code, student count)
  2. Sort controls row
  3. Student table
```

**1. ClassInfoCard:**
- Class name (large)
- Class code in monospace font, large, with copy-to-clipboard icon
- Student count: "N students enrolled"
- Share button: opens system share sheet with text "Join my class on VocabGame! Code: [CODE]"

**2. Sort controls row:**
- Horizontal scrollable row of sort chips: "XP" | "Level" | "Streak" | "Accuracy" | "Name"
- Active chip is highlighted.
- Tapping an active chip toggles ascending/descending order.
- Default sort: XP descending.

**3. Student table (scrollable list, not a DataTable — use ListView.builder):**
Each student row (`_StudentRow` widget) shows:
- Rank number (1, 2, 3... with 🥇🥈🥉 for top 3, plain number for rest)
- Avatar circle (first letter of username, gradient background)
- Username
- XP (compact: "1.2k" for 1200+)
- Streak (🔥 N)
- Accuracy (color-coded: green ≥70%, amber ≥40%, red <40%, "—" if no answers)
- At-risk indicator: small red dot on avatar if `student.isAtRisk`

**Tapping a student row:** navigates to `TeacherStudentDetailScreen` with `ClassStudent` passed as `extra`.

---

### 7C. Teacher Library Screen — `lib/screens/teacher/teacher_library_screen.dart`

**Route:** `/teacher/library`

**This uses the SAME library content as the student library (same books, same units).**
The difference is behavior: instead of "Add to My Words," each unit shows "Assign to Class."

**On screen init:**
1. Load library books (same source as student library — do not duplicate the data fetching logic).
2. Load teacher's active assignments: `ref.read(assignmentProvider.notifier).loadTeacherAssignments(classCode, teacherId)`.
3. Build a `Set<String>` of already-assigned unit IDs from the loaded assignments for O(1) lookup.

**Layout:**

```
AppBar:
  title: "Library"
  bottom: TabBar with level tabs (A1 | A2 | B1 | B2) — same as student library

Body:
  ListView of books → tap book → list of units → tap unit → AssignUnitBottomSheet
```

**Unit list item — differences from student version:**
- Show "📌 Assigned" badge (amber chip) if `assignedUnitIds.contains(unit.id)`.
- Bottom-right button:
  - If NOT assigned: "Assign to Class" button (outlined, primary color)
  - If already assigned: "Assigned ✓" chip (non-tappable, shows deactivate option on long-press)

**Assign to Class — Bottom Sheet (`_AssignUnitBottomSheet`):**
Opens when teacher taps "Assign to Class" on a unit.

Content:
- Unit title (large)
- Book name (subtitle)
- Word count: "N words"
- Due date picker:
  - Label: "Due Date (optional)"
  - Row with calendar icon + text field showing selected date or "No deadline"
  - Tapping opens `showDatePicker()` with `firstDate: DateTime.now()`, `lastDate: DateTime.now().add(Duration(days: 365))`
  - "Clear" button next to date to set back to no deadline
- "Assign Now" button (filled, primary color)

**On "Assign Now" tap:**
1. Show loading indicator on button (disable button).
2. Call `AssignmentService.createAssignment(...)` with all fields.
3. On success: close bottom sheet, call `ref.read(assignmentProvider.notifier).loadTeacherAssignments(...)` to refresh.
4. On error: show `SnackBar` with error message. Do NOT close bottom sheet.

**Long-press on "Assigned ✓" chip — Deactivate dialog:**
Shows `AlertDialog` with title "Remove Assignment?" and two buttons: "Cancel" and "Remove".
On "Remove": calls `AssignmentService.deactivateAssignment(assignmentId)`, then removes from local provider state via `ref.read(assignmentProvider.notifier).removeAssignment(assignmentId)`.

---

### 7D. Teacher Analytics Screen — `lib/screens/teacher/teacher_analytics_screen.dart`

**Route:** `/teacher/analytics`

**On screen init:**
1. Ensure `classStudentsProvider` is loaded (reuse if already loaded from Dashboard).
2. Load word stats: `ref.read(wordStatsProvider.notifier).load(classCode)`.
3. Load assignments: reuse `assignmentProvider` state.

**Layout — TabBar with 3 tabs:**

```
AppBar:
  title: "Analytics"
  bottom: TabBar
    Tab 0: "Overview"
    Tab 1: "Words"
    Tab 2: "Students"
```

**Tab 0 — Overview:**

Section 1: Assignment Completion Cards
- For each active assignment: one `_AssignmentCompletionCard`
- Each card shows:
  - Unit title + book name
  - Horizontal progress bar: completed/total students
  - Label: "N/M students completed" (e.g. "11/18 completed")
  - Due date if set: "Due: Fri 14 Nov" or "No deadline"
  - Overdue indicator if past due date: "⚠️ Overdue" in red
- Tapping a card: expands to show per-student progress list (see below)
- If no assignments: "No active assignments. Go to Library to assign a unit."

Section 2: Class Engagement Summary
- "Active this week: N/M students" with a small bar chart (7 days)
- Actually: just show the engagement rate number prominently — do not build a full chart unless resources allow. Keep it as text: "14 of 18 students practiced this week (78%)"

**Expanded Assignment Card — per-student progress list:**
When a card is tapped, it expands inline (using `AnimatedCrossFade` or `ExpansionTile`) to show:
- List of all students in the class
- Each item: username + progress bar showing `words_mastered / total_words`
- Completed students show green ✓
- Students with no progress row show "Not started"
- Sort: completed first, then by `words_mastered` descending

**Tab 1 — Words (Word Difficulty Heatmap):**

- Header: "Class Word Difficulty — N words tracked"
- If `wordStatsProvider.state.stats` is empty: "No word data yet. Students need to practice first."
- List of `WordStat` items, sorted hardest first.
- Each item:
  - English word (bold) — Uzbek word (muted)
  - Accuracy bar (colored: red <40%, amber 40-69%, green ≥70%)
  - Accuracy label: "34%" and "N answers"
  - Filter chips at top: "All" | "Hard (<40%)" | "Medium" | "Easy" — filter the list
- Limit initial display to 30 words. "Show more" button if more exist.

**Tab 2 — Students (Individual Drill-Down):**

- Same student list as "My Classes" screen but tappable for detail.
- Each row shows: rank, username, XP, accuracy, streak, at-risk dot.
- Tapping a student row navigates to `TeacherStudentDetailScreen`.

---

### 7E. Teacher Student Detail Screen — `lib/screens/teacher/teacher_student_detail_screen.dart`

**Route:** `/teacher/student-detail` (with `ClassStudent` passed as `extra`)

This screen is accessed from both "My Classes" tab and "Analytics → Students" tab.

**Layout:**

```
AppBar:
  title: student username
  subtitle: "Level N · Class 7B"

Body — SingleChildScrollView:
  1. Stats overview cards (4 cards in 2x2 grid)
  2. Activity status row
  3. This student's assignment progress
  4. Top 10 hardest words for this student
```

**1. Stats cards:**
- XP: number + level badge
- Streak: N days 🔥 (or "No streak")
- Accuracy: percentage (or "—")
- Words answered: total count

**2. Activity status:**
- "Last active: N days ago" or "Active today ✓" or "Never played"
- At-risk warning if `student.isAtRisk`: red banner "⚠️ This student hasn't practiced in N days"

**3. Assignment progress:**
- For each active assignment: progress bar + "N/M words"
- If student hasn't started an assignment: "Not started"

**4. Hardest words for this student:**
- Fetch from `word_stats` table: `student_id = student.id`, sort by accuracy ascending, limit 10.
- This requires one additional Supabase query on screen init.
- Show as a simple list: word (English / Uzbek) + accuracy percentage.
- If no data: "No word data yet."

---

### 7F. Teacher Profile Screen — `lib/screens/teacher/teacher_profile_screen.dart`

**Route:** `/teacher/profile`

**This screen is completely different from the student profile screen.**
There is NO XP bar. NO level display. NO streak. NO accuracy stats. NO badge gallery.

**Layout:**

```
AppBar:
  title: "Profile"

Body:
  1. Teacher identity card (username, avatar)
  2. Class info card
  3. Account section
```

**1. Teacher identity card:**
- Large avatar circle (first letter, gradient)
- Username (large)
- "Teacher" label/badge

**2. Class info card:**
- Class name
- Class code (monospace, large, with copy button)
- Student count: "N students enrolled"
- Class health score: "Class Health: N% (Good)" in colored chip
- Buttons:
  - "Copy Class Code" → copies to clipboard, shows SnackBar "Copied!"
  - "Share Class Code" → system share sheet
  - "View Dashboard" → navigates to `/teacher/dashboard`

**3. Account section:**
- "Change Username" → dialog with text field (validates uniqueness via SyncService)
- "Recovery PIN" → navigates to PIN setup screen
- "Logout" → confirms, clears Hive, navigates to `/welcome`
- "Delete Account" → confirms with "DELETE" typing requirement, deletes from Supabase + Hive

**There are NO class management operations on the teacher profile.**
Creating a class happens during onboarding. The teacher cannot delete their class from the profile screen (this would orphan student data — if needed in future, add a separate "Manage Class" screen with appropriate warnings).

---

## 8. STUDENT SCREENS

### 8A. Student Home Screen — Modified — `lib/screens/home_screen.dart`

**Remove all `if (isTeacher)` blocks.** This screen is now student-only.

**Add at the TOP of the scrollable content (above the vocab list), ONLY if student has a classCode:**

**Assignment Cards section:**
- Watch `assignmentProvider.state`
- For each active assignment, render `_AssignmentCard` widget
- Each `_AssignmentCard` shows:
  - 📚 icon + unit title
  - Book name (subtitle)
  - Progress bar: if student has progress, show `wordsMastered / totalWords`; if no progress yet, show empty bar
  - Progress label: "14/25 words" or "Not started"
  - Due date chip if set: "Due Friday" (amber) or "Overdue" (red)
  - "Practice Now" button → navigates to Assignment Mode game with this assignment's word set
- If `assignmentProvider.state.isLoading`: show shimmer placeholder cards
- If no assignments: show nothing (do not show empty state — just omit the section)

**Teacher Message Card:**
- Below assignment cards, above quick links
- Shown only if a `TeacherMessage` was fetched and is non-empty
- Styled as: 📌 icon + message text + teacher name
- Read-only. Dismiss is NOT possible (teacher controls visibility).
- Fetched once on init via `TeacherMessageService.getMessage(classCode)`
- Cached in a local `useState` or `StateProvider` — does not need to be in Hive

**On HomeScreen init:**
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final profile = ref.read(profileProvider);
    if (profile?.classCode != null && !(profile?.isTeacher ?? false)) {
      ref.read(assignmentProvider.notifier).loadStudentAssignments(
        classCode: profile!.classCode!,
        studentId: profile.id,
      );
    }
  });
}
```

**Rival Card fix:** Filter out teachers when computing rival. The rival query in `HomeScreen` currently fetches classmates by XP. Add `.eq('is_teacher', false)` to the Supabase query that fetches classmates.

### 8B. Student Library Screen — Modified — `lib/screens/library_screen.dart`

Add "📌 Assigned" badge to units that are in the student's active assignments.

On screen init: check `assignmentProvider.state.assignments` (already loaded from home screen). Build a `Set<String>` of assigned `unitId`s.

For each unit in the library:
- If `assignedUnitIds.contains(unit.id)`: show "📌 Assigned" chip below the unit title.
- Tapping an assigned unit: navigates to the unit detail screen which shows both "Study" (personal) and "Practice Assignment" (assignment mode) options.

### 8C. Student Profile Screen — `lib/screens/profile_screen.dart`

**Remove all teacher-related buttons and `if (isTeacher)` blocks.**

This screen now always shows the student experience:
- Stats cards (XP, level, accuracy, streak)
- Class management (Join / Change / Exit class)
- Account section (logout, delete)

The "Create a Class" button must be **completely removed** from this screen.
The path to becoming a teacher is ONLY through onboarding (see Section 10).

---

## 9. LIBRARY ASSIGNMENT INTEGRATION

### 9A. What "Assignment Mode" Means

When a student taps "Practice Now" on an assignment card, the game launches in **Assignment Mode**. This changes the word source: instead of the student's personal vocabulary list, the game uses the library unit's word list.

**Assignment Mode parameters (passed as `extra` to the game route):**
```dart
class AssignmentModeParams {
  final String assignmentId;
  final String unitId;
  final String unitTitle;
  final List<VocabWord> words; // pulled from library before navigation
  final int wordsMasteredSoFar; // from AssignmentProgress, 0 if new

  const AssignmentModeParams({
    required this.assignmentId,
    required this.unitId,
    required this.unitTitle,
    required this.words,
    required this.wordsMasteredSoFar,
  });
}
```

**Before navigating to the game:** fetch the unit's word list from the library (same method used by the library screen to show unit words). Pass the words in `AssignmentModeParams.words`.

### 9B. How Games Detect Assignment Mode

Every game screen checks `extra` on its GoRouter route. If `extra` is an `AssignmentModeParams`:
- Word source = `params.words` (not personal vocab list)
- After session ends: call `AssignmentService.updateAssignmentProgress()` in addition to (not instead of) `profileProvider.notifier.recordGameSession()`
- XP is still awarded normally — assignment mode does not disable XP

### 9C. Word Stats Tracking in Games

In every game mode, when a player answers a question, call:
```dart
// Fire-and-forget — do not await, do not block UI
unawaited(WordStatsService.recordWordAnswer(
  studentId: profile.id,
  classCode: profile.classCode,    // null-safe: service handles null
  wordEnglish: answeredWord.english,
  wordUzbek: answeredWord.uzbek,
  wasCorrect: isCorrect,
));
```

This must be called for EVERY word answered, in BOTH personal mode and assignment mode.
It must be called inside the game's answer-handling logic, not in `recordGameSession()` (which is called once per session, not per word).

### 9D. Library Data Model (Assumed Structure)

The library already exists in the app. This document assumes the following structure exists. If the actual structure differs, adapt the field names but the logic is identical.

```dart
// Assumed existing models
class LibraryBook {
  final String id;         // unique book identifier
  final String title;
  final String level;      // 'A1', 'A2', 'B1', 'B2'
  final List<LibraryUnit> units;
}

class LibraryUnit {
  final String id;         // unique unit identifier (use this as unit_id in assignments)
  final String title;
  final List<VocabWord> words;

  int get wordCount => words.length;
}
```

When a teacher assigns a unit:
- `bookId` = `LibraryBook.id`
- `bookTitle` = `LibraryBook.title`
- `unitId` = `LibraryUnit.id`
- `unitTitle` = `LibraryUnit.title`
- `wordCount` = `LibraryUnit.wordCount`

---

## 10. ONBOARDING SPLIT

### 10A. Current Flow (Both Roles — Identical)
```
WelcomeScreen → UsernameScreen → PinSetupScreen → JoinClassScreen → /home
```

### 10B. New Flow

The split happens at `UsernameScreen` when the teacher toggle is switched ON.

**Student Flow (unchanged):**
```
WelcomeScreen → UsernameScreen (toggle OFF) → PinSetupScreen → JoinClassScreen → /student/home
```

**Teacher Flow (new):**
```
WelcomeScreen → UsernameScreen (toggle ON) → PinSetupScreen → TeacherClassSetupScreen → /teacher/dashboard
```

### 10C. UsernameScreen — Modified — `lib/onboarding/username_screen.dart`

When user taps "Continue":
1. Validate username (existing logic).
2. Check uniqueness (existing logic).
3. Insert into Supabase `profiles` with `is_teacher: _isTeacher` (existing logic).
4. Create local profile via `profileProvider.notifier.createProfile()`.
5. Navigate to `PinSetupScreen` (unchanged).
6. **Store `_isTeacher` in a way that `PinSetupScreen` can pass it forward.**
   - Recommended: pass `isTeacher` as a `GoRouter` extra to `PinSetupScreen`, then forward it to the next screen.
   - Do NOT store `_isTeacher` in Hive during onboarding before it's confirmed. It's already set on the profile via `createProfile()`.

### 10D. PinSetupScreen — Modified — `lib/onboarding/pin_setup_screen.dart`

Receives `isTeacher` as extra from `UsernameScreen`.
After PIN save, navigates to:
- If `isTeacher == true`: `/onboarding/teacher-class-setup`
- If `isTeacher == false`: `/onboarding/join-class` (existing screen, unchanged)

### 10E. New Screen: TeacherClassSetupScreen — `lib/onboarding/teacher_class_setup_screen.dart`

**Route:** `/onboarding/teacher-class-setup`

This is the teacher's equivalent of `JoinClassScreen`. It creates their first class.

**Layout:**

```
Top: Progress indicator (step 4 of 4)
Large icon: 🏫
Title: "Set up your class"
Subtitle: "Give your class a name. Students will see this when they join."

TextField:
  hint: "e.g. Class 7B — English"
  maxLength: 50
  validation: must be 3+ characters

Button: "Create My Class →" (enabled when field is valid)
```

**On "Create My Class" tap:**
1. Show loading indicator on button.
2. Call `ClassService.createClass(teacherUsername: profile.username, className: enteredName, teacherId: profile.id)`.
3. On success (returns a class code):
   a. Update profile's `classCode` locally and in Supabase: `profileProvider.notifier.setClassCode(code)`.
   b. Set `hasOnboarded = true` in Hive: `box.put('hasOnboarded', true)`.
   c. Navigate to **Class Code Reveal Screen** (see below).
4. On error: show `SnackBar`, re-enable button.

### 10F. New Screen: ClassCodeRevealScreen — `lib/onboarding/class_code_reveal_screen.dart`

**Route:** `/onboarding/class-code-reveal` (receives class code and class name as extra)

This screen is shown ONCE after the teacher creates their class. It is celebratory and ensures the teacher copies their code before proceeding.

**Layout:**

```
🎉 large emoji at top

Title: "Your class is ready!"
Subtitle: "Share this code with your students"

Large code display:
  [  E N G 7 B 2  ]   ← monospace, very large font, letter-spaced
  "Class: [Class Name]"

Two action buttons:
  [📋 Copy Code]   ← copies to clipboard, shows "Copied!" feedback
  [📤 Share Code]  ← opens system share sheet with text: "Join my class on VocabGame! Code: ENG7B2"

Bottom:
  "Continue to Dashboard →" button
  This button CANNOT be tapped until the teacher has either copied or shared the code.
  (Track with a boolean _hasSharedCode = false, set to true on either copy or share action)
  If teacher tries to tap before sharing: show a gentle tooltip "Share your code first so students can join!"
```

**On "Continue to Dashboard" tap:**
- Navigate to `/teacher/dashboard` using `context.go('/teacher/dashboard')`.
- Do NOT use `context.push()` — this replaces the navigation stack so teacher cannot go back to onboarding.

---

## 11. CLASS HEALTH SCORE

The Class Health Score is computed by `AnalyticsService.computeHealthScore()` (defined in Section 4B).

### Formula
```
health_score = (avg_accuracy × 0.5 + engagement_rate × 0.5) × 100
```

Where:
- `avg_accuracy` = average of `totalCorrect / totalWordsAnswered` across all students with at least one answer. Range: 0.0 to 1.0.
- `engagement_rate` = fraction of students who have `lastPlayedDate` within the last 7 days. Range: 0.0 to 1.0.
- If no students have any answers, `avg_accuracy` = 0.
- If the class has zero students, the score is 0.

### Display Tiers
| Score | Label | Color |
|---|---|---|
| ≥ 80 | Excellent | Green |
| 60–79 | Good | Amber |
| 40–59 | Fair | Orange |
| < 40 | Needs Attention | Red |

### Where It Appears
1. Teacher Dashboard → `ClassHealthCard` (large, prominent)
2. Teacher Profile screen → small chip under class name
3. Teacher My Classes screen → inside `ClassInfoCard`

### When It Is Computed
- Every time `classStudentsProvider.load()` is called.
- It is NOT stored in Supabase. It is always computed fresh from student data.
- It is NOT shown to students anywhere.

---

## 12. AT-RISK DETECTION

### Definition
A student is "at risk" if:
- `lastPlayedDate` is null (they have never played), OR
- The number of days between today and `lastPlayedDate` is ≥ 3

### Implementation
`ClassStudent.isAtRisk` (getter defined in Section 3C) handles this calculation.

### Where At-Risk Students Appear
1. **Teacher Dashboard → AtRiskSection:** list of at-risk students (max 5, "View all" link)
2. **Teacher My Classes → student rows:** red dot on avatar
3. **Teacher Analytics → Students tab:** red dot on avatar
4. **Teacher Student Detail Screen:** red banner at top

### Logic Rules
- At-risk status is recalculated on every `classStudentsProvider.load()` call.
- It is NOT stored in Supabase. It is computed from `lastPlayedDate`.
- A student who plays today immediately drops off the at-risk list on next teacher refresh.

---

## 13. WORD ANALYTICS

### How Word Stats Are Collected

1. Every game screen calls `WordStatsService.recordWordAnswer()` once per word, per answer.
2. This upserts a row in the `word_stats` table.
3. Rows are keyed by `(student_id, word_english)` — UNIQUE constraint.
4. `times_shown` always increments. `times_correct` increments only on correct answers.

### How Teacher Sees Word Analytics

`AnalyticsService.getClassWordStats(classCode)` (Section 4B):
1. Fetches all `word_stats` rows for the class.
2. Aggregates by `word_english`: sums `times_shown` and `times_correct` across all students.
3. Returns a list of `WordStat` objects sorted by accuracy ascending (hardest first).

### Display in Teacher Analytics Screen — Tab 1 (Words)

Each `WordStat` rendered as a list tile:
- Left: word (English bold, Uzbek muted)
- Right: accuracy bar + percentage label
- Bar color: red (<40%), amber (40–69%), green (≥70%)
- Tap: opens a dialog showing "N students attempted this word" (uses `times_shown` as a proxy)

### Important Limitations
- Word stats only accumulate from the moment this feature is deployed. Historical game sessions are not backfilled.
- Words in personal vocabulary lists are tracked only when the student is in a class (`classCode != null`). Students without a class produce no word stats (the service returns early).

---

## 14. ORDER OF IMPLEMENTATION

**Do not skip steps. Do not reorder steps. Each step builds on the previous.**

### Phase 0 — Database (Do Before Any Code)
1. Run SQL migration: `ALTER TABLE classes ADD COLUMN teacher_id TEXT` (if not done from previous fix doc)
2. Run SQL: Create `assignments` table (Section 2B)
3. Run SQL: Create `assignment_progress` table (Section 2C)
4. Run SQL: Create `word_stats` table (Section 2D)
5. Run SQL: Create `teacher_messages` table (Section 2E)
6. Run SQL: Apply all RLS policies for new tables (Section 2F)

### Phase 1 — Data Models (No UI yet)
7. Create `lib/models/assignment.dart` (Section 3A)
8. Create `lib/models/assignment_progress.dart` (Section 3B)
9. Create `lib/models/class_student.dart` (Section 3C)
10. Create `lib/models/word_stat.dart` (Section 3D)
11. Create `lib/models/teacher_message.dart` (Section 3E)
12. Create `lib/models/class_health_score.dart` (Section 3F)

### Phase 2 — Services (No UI yet)
13. Create `lib/services/assignment_service.dart` (Section 4A)
14. Create `lib/services/analytics_service.dart` (Section 4B)
15. Create `lib/services/word_stats_service.dart` (Section 4C)
16. Create `lib/services/teacher_message_service.dart` (Section 4D)
17. Modify `lib/services/class_service.dart`: Remove `getClassStudents()` (Section 4E)

### Phase 3 — Providers (No UI yet)
18. Create `lib/providers/assignment_provider.dart` (Section 5A)
19. Create `lib/providers/class_students_provider.dart` (Section 5B)
20. Create `lib/providers/word_stats_provider.dart` (Section 5C)

### Phase 4 — Navigation Architecture
21. Create `lib/screens/student_nav_shell.dart` — extract from current `AppShell` (Section 6C)
22. Create `lib/screens/teacher_nav_shell.dart` — new teacher shell (Section 6D)
23. Modify `lib/screens/app_shell.dart` — read isTeacher, render correct shell (Section 6E)
24. Modify `lib/router.dart` — add teacher routes, add redirect rules (Section 6B)
25. **Test:** Run app as student → sees student shell. Run app as teacher → sees teacher shell. ✓

### Phase 5 — Teacher Screens (Implement in this order)
26. Create `lib/screens/teacher/teacher_profile_screen.dart` (Section 7F) — do this first, it's simplest
27. Create `lib/screens/teacher/teacher_classes_screen.dart` (Section 7B)
28. Create `lib/screens/teacher/teacher_dashboard_screen.dart` (Section 7A)
29. Create `lib/screens/teacher/teacher_library_screen.dart` (Section 7C) — requires assignment_service
30. Create `lib/screens/teacher/teacher_analytics_screen.dart` (Section 7D)
31. Create `lib/screens/teacher/teacher_student_detail_screen.dart` (Section 7E)

### Phase 6 — Student Screen Modifications
32. Modify `lib/screens/home_screen.dart` — add assignment cards, teacher message, fix rival query (Section 8A)
33. Modify `lib/screens/library_screen.dart` — add assigned badges (Section 8B)
34. Modify `lib/screens/profile_screen.dart` — remove all teacher blocks, remove "Create a Class" (Section 8C)

### Phase 7 — Word Stats in Games
35. Add `WordStatsService.recordWordAnswer()` call inside every game mode's answer-handling logic (Section 9C)
36. Verify: after playing a game as a student with a class, check `word_stats` table in Supabase for new rows. ✓

### Phase 8 — Onboarding Split
37. Modify `lib/onboarding/pin_setup_screen.dart` — receive and forward `isTeacher` (Section 10D)
38. Create `lib/onboarding/teacher_class_setup_screen.dart` (Section 10E)
39. Create `lib/onboarding/class_code_reveal_screen.dart` (Section 10F)
40. Modify `lib/router.dart` — add new onboarding routes (Section 10B)
41. **Test full onboarding flows:** Student flow end-to-end ✓. Teacher flow end-to-end ✓.

### Phase 9 — Cleanup and Verification
42. Search entire codebase for `if (isTeacher)` and `if (profile.isTeacher)` — every remaining instance should be only inside `AppShell`. If found anywhere else: refactor to role-specific screen.
43. Search for `getClassStudents()` calls — should be zero (all replaced with `AnalyticsService.getClassStudents()`).
44. Run verification checklist (Section 15).

---

## 15. VERIFICATION CHECKLIST

Run these checks manually after completing all implementation phases.

### Navigation and Routing
- [ ] Fresh install → `WelcomeScreen` appears.
- [ ] Onboard as student (toggle OFF) → student shell appears with 5 student tabs.
- [ ] Onboard as teacher (toggle ON) → teacher class setup screen appears → class code reveal screen appears → teacher shell appears with 5 teacher tabs.
- [ ] Hardcoded URL `/duels` as a teacher → redirected to `/teacher/dashboard`.
- [ ] Hardcoded URL `/teacher/dashboard` as a student → redirected to `/home`.

### Teacher Dashboard
- [ ] Teacher with 0 students → ClassHealthCard shows 0%, AtRiskSection shows empty state "✅ All students practiced recently."
- [ ] Add a student to class → dashboard refresh shows 1 student, health score updates.
- [ ] Student who hasn't played in 3+ days → appears in AtRiskSection with red indicator.
- [ ] Teacher posts a message → message appears in TeacherMessageCard. Teacher clears message → card shows "no message" state.
- [ ] Teacher pulls down to refresh → student list and health score update.

### Teacher My Classes
- [ ] Teacher's own row does NOT appear in the student table.
- [ ] Student count shows only real student count (not teacher + students).
- [ ] Tapping a student row navigates to student detail screen.
- [ ] Sort by accuracy works. Sort by streak works. Toggle ascending/descending works.
- [ ] "Copy Class Code" button copies to clipboard.

### Teacher Library and Assignments
- [ ] Teacher opens Library tab → sees books and units.
- [ ] Teacher assigns a unit → "Assign Now" in bottom sheet → "Assigned ✓" badge appears on unit.
- [ ] Teacher assigns same unit twice → second tap shows "Assigned ✓" (not a second assignment button).
- [ ] Teacher long-presses "Assigned ✓" → deactivate dialog appears → on confirm, badge disappears.
- [ ] Assigned unit with a due date shows the due date on the assignment card in Analytics.

### Student Home Screen — Assignments
- [ ] Student with no class → no assignment cards section (section is completely absent from the screen).
- [ ] Student in a class with active assignments → assignment cards appear above vocab list.
- [ ] Student taps "Practice Now" → game launches with unit words (not personal vocab).
- [ ] Student completes assignment session → progress bar in assignment card updates.
- [ ] Teacher deactivates assignment → on next student load, assignment card disappears.

### Teacher Message on Student Home
- [ ] Teacher posts message → student (in same class) sees message card on home screen after reload.
- [ ] Teacher deletes message → student sees no message card after reload.
- [ ] Student with no class → no message card ever appears.

### Teacher Analytics
- [ ] Overview tab: shows assignment cards with correct completion ratios.
- [ ] Expanding an assignment card: shows per-student progress list.
- [ ] Words tab: shows words sorted hardest first. Filter chips work.
- [ ] Students tab: same list as My Classes, at-risk dots visible.

### Teacher Profile
- [ ] No XP bar, no level, no streak, no accuracy stat anywhere on teacher profile screen.
- [ ] Class code displayed prominently.
- [ ] "Copy Class Code" and "Share Class Code" work.
- [ ] Logout works.

### Word Stats Collection
- [ ] Student plays a quiz game → after session, `word_stats` table in Supabase has new/updated rows for played words.
- [ ] Student with no class plays a game → `word_stats` table has NO new rows (service returns early).

### Rival Card
- [ ] Student's rival card never shows a teacher's username (teacher is filtered from rival query).

### Leaderboard
- [ ] Class leaderboard tab does NOT show the teacher (teacher filtered by `is_teacher = false`).
- [ ] Global leaderboard does NOT show any teacher profiles.

### Old Teacher Dashboard (TeacherDashboardScreen)
- [ ] The old `/teacher-dashboard` route (if it existed) is either removed or redirects to `/teacher/classes`.

---

## 16. COMPLETE FILE LIST

### New Files to Create

| File Path | Purpose |
|---|---|
| `lib/models/assignment.dart` | Assignment data model |
| `lib/models/assignment_progress.dart` | AssignmentProgress data model |
| `lib/models/class_student.dart` | ClassStudent data model (replaces raw maps) |
| `lib/models/word_stat.dart` | WordStat data model |
| `lib/models/teacher_message.dart` | TeacherMessage data model |
| `lib/models/class_health_score.dart` | ClassHealthScore computed model |
| `lib/services/assignment_service.dart` | All assignment Supabase ops |
| `lib/services/analytics_service.dart` | Teacher analytics queries |
| `lib/services/word_stats_service.dart` | Per-word answer tracking |
| `lib/services/teacher_message_service.dart` | Teacher message CRUD |
| `lib/providers/assignment_provider.dart` | Assignment state for student + teacher |
| `lib/providers/class_students_provider.dart` | Student list + health score for teacher |
| `lib/providers/word_stats_provider.dart` | Word difficulty data for teacher |
| `lib/screens/student_nav_shell.dart` | Student 5-tab navigation shell |
| `lib/screens/teacher_nav_shell.dart` | Teacher 5-tab navigation shell |
| `lib/screens/teacher/teacher_dashboard_screen.dart` | Teacher home screen |
| `lib/screens/teacher/teacher_classes_screen.dart` | Class + student table |
| `lib/screens/teacher/teacher_library_screen.dart` | Library with assign capability |
| `lib/screens/teacher/teacher_analytics_screen.dart` | 3-tab analytics |
| `lib/screens/teacher/teacher_student_detail_screen.dart` | Per-student drill-down |
| `lib/screens/teacher/teacher_profile_screen.dart` | Teacher profile (no gamification) |
| `lib/onboarding/teacher_class_setup_screen.dart` | Teacher onboarding step 4 |
| `lib/onboarding/class_code_reveal_screen.dart` | Class code reveal after creation |

### Files to Modify

| File Path | Change |
|---|---|
| `lib/screens/app_shell.dart` | Read isTeacher, render correct shell |
| `lib/screens/home_screen.dart` | Add assignment cards, teacher message, fix rival query |
| `lib/screens/library_screen.dart` | Add assigned badges |
| `lib/screens/profile_screen.dart` | Remove all teacher blocks, remove "Create Class" |
| `lib/services/class_service.dart` | Remove getClassStudents() |
| `lib/onboarding/pin_setup_screen.dart` | Forward isTeacher param to correct next screen |
| `lib/router.dart` | Add teacher routes + redirect rules |
| All game mode screens | Add WordStatsService.recordWordAnswer() per word |

### Files to Delete (or Archive)

| File Path | Reason |
|---|---|
| `lib/screens/teacher_dashboard_screen.dart` | Replaced by `teacher_classes_screen.dart` |

### SQL Migrations (Run in Supabase SQL Editor)

| Order | Description |
|---|---|
| 1 | Add `teacher_id` to `classes` table (if not done) |
| 2 | Create `assignments` table |
| 3 | Create `assignment_progress` table |
| 4 | Create `word_stats` table |
| 5 | Create `teacher_messages` table |
| 6 | Enable RLS + add policies for all 4 new tables |

**Total: 24 new Dart files + 8 modified Dart files + 1 deleted Dart file + 6 SQL migrations.**

---

*End of Document. Every decision is here. Every field is named. Implement in order.*
