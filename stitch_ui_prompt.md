# Context for UI Generation AI ("Stitch")
## VocabGame — Mobile Vocabulary Learning App

---

## 📱 What is VocabGame?
VocabGame is an English-to-Uzbek vocabulary learning and gamification mobile app built in **Flutter**. It acts as a comprehensive language learning ecosystem with a built-in offline/online dictionary, gamified quizzes, multiplayer duels, and progressive learning tracks based on CEFR levels (A1, A2, B1, etc.).

We have the entire backend and logic fully built and functional. **Our current goal is to completely redesign and upgrade the UI/UX to make it feel like a modern, premium, highly gamified app (similar to Duolingo or Quizlet).**

---

## 🛠️ Tech Stack & Architecture (Do not change)
- **Frontend Framework:** Flutter (Dart)
- **Backend / Database:** Supabase (PostgreSQL, Auth, Leaderboards)
- **Local Cache / Offline Storage:** Hive & IndexedDB
- **Theme/Styling:** Currently using standard Material 3 with a primary `violet` color scheme (`AppTheme.violet`).

---

## 🗺️ Current App Structure & Screens

The app uses standard bottom navigation containing the following primary flows:

### 1. Home Screen (Dashboard)
- Displays user's daily progress, current Experience Points (XP), and current Streak.
- Has a gamified "Streak Calendar" or daily tracker.
- Shows quick-start buttons to jump into the latest vocabulary level.
- **Current UI Flaws:** Very basic Material cards. Needs a more engaging, game-like dashboard.

### 2. Library Screen
- A grid/list of vocabulary "Books" or Collections categorized by difficulty (e.g., *Navigate A1*, *Round Up*, *Top 5000 Common Words*).
- Each book contains "Units" (25-30 words each).
- Users can select a unit to practice via Flashcards or Quiz mode.
- **Current UI Flaws:** Looks too much like a standard file directory. Needs a beautiful, visually distinct layout for books.

### 3. Games & Duels (Learning Mode)
- **Quiz Mode:** Multiple choice questions (English to Uzbek or vice versa). Correct answers grant XP.
- **Duel Mode:** Synchronized, high-stakes multiplayer quiz against a bot or another player. Features a 3-second countdown start, sudden death mechanics, and point penalties for incorrect answers.
- **Current UI Flaws:** The quiz cards are basic text boxes. We need premium animations, vibrant correct/incorrect feedback states, and a much more intense "gameplay" feel.

### 4. Search / Dictionary Screen
- A highly sophisticated 4-tier lookup system (App Bundle -> Local Hive Cache -> Supabase DB -> Google Translate API Fallback).
- Contains a dictionary of 4,897 curated Oxford words.
- Displays: English word, Uzbek translation, Part of Speech, Definition, Example sentences (italicized).
- **Recent Addition:** Color-coded CEFR Level Badges (Green for A1/A2, Yellow for B1/B2, Red for C1/C2) next to the word.
- **Current UI Flaws:** Highly functional but text-heavy. Needs to feel like a sleek, modern dictionary card.

### 5. Profile Screen
- Shows User Avatar, Name, Rank, and total XP.
- Contains an "Offline Dictionary" section where users can download the 4,897-word pack into their local Hive storage for offline use.
- Displays a progress bar during download.
- **Current UI Flaws:** Looks like a generic "Settings" page. Needs to feel like a Gamer Profile or Achievement showcase.

---

## 🎨 UI/UX Redesign Goals (What we need you to generate)

When generating the new UI for these screens, please adhere to the following principles:

1. **Gamified & Premium Feel:** We want to move away from standard flat "Material" elements. Use glassmorphism, subtle gradients, soft drop shadows, and rounded corners (border-radius: 16-24px).
2. **Color Palette:** The brand's primary color is Violet/Purple. Think deep purples for backgrounds, bright energetic neons (cyan/magenta/yellow) for game elements, streaks, and XP points.
3. **Micro-interactions & States:** Define clear, vibrant visual states for *Correct* (Bright Green) and *Incorrect* (Vibrant Red) during quizzes.
4. **Typography:** Needs a modern, rounded, highly legible font (like *Nunito*, *Quicksand*, or *Inter*) to give it a friendly, educational vibe.
5. **Data Integration:** Ensure the UI components you design have obvious placeholders for our existing data models (e.g., `cefrLevel`, `example_sentence`, `xp_amount`, `streak_days`).

### Your Task
Please generate new Flutter UI code (or UI design guidelines/markup) for these screens that drastically improves their aesthetic quality while keeping our current feature set intact. Focus on visual hierarchy, gamification, and premium aesthetics.
