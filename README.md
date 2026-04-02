# VocabGame — English ↔ Uzbek Vocabulary Learning App

A competitive Flutter app for students to practice English and Uzbek vocabulary through 5 different game modes, with XP, streaks, class leaderboards, and head-to-head duels.

## Game Modes

| Mode | Description |
|---|---|
| **Quiz** | Multiple-choice — translate the word |
| **Flashcards** | Flip cards to reveal translations |
| **Matching** | Pair English words with Uzbek translations |
| **Memory** | Classic card-flip pairs |
| **Fill in the Blank** | Type the missing translation |

## Competitive Features

- ⚡ **XP System** — earn points with speed bonuses
- 🔥 **Streaks** — consecutive daily play tracked with milestone celebrations
- 🏆 **Leaderboard** — class-based rankings with rival tracking
- ⚔️ **Duels** — challenge classmates in real-time vocabulary battles
- 📚 **Library** — curated ESL vocabulary units with difficulty levels
- 👨‍🏫 **Teacher Dashboard** — manage classes, monitor student progress

## Tech Stack

- **Framework:** Flutter + Dart (SDK ^3.7.2)
- **State Management:** Riverpod
- **Local Storage:** Hive (typed objects)
- **Backend:** Supabase (auth-free, profile sync, leaderboards)
- **Notifications:** flutter_local_notifications (streak warnings, duel alerts)
- **Typography:** Google Fonts (Inter)
- **Routing:** go_router

## Setup

1. Install Flutter SDK 3.7.2 or higher
2. Clone the repo
3. Copy `lib/config/supabase_config.dart.example` to `lib/config/supabase_config.dart` and add your Supabase keys
4. Run dependencies:
   ```bash
   flutter pub get
   ```
5. Generate Hive type adapters:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
6. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── config/          # Environment & Supabase configuration
├── games/           # 5 game mode widgets + shared streak mixin
├── models/          # Vocab, UserProfile data models
├── providers/       # Riverpod state (profile, vocab, leaderboard, duel)
├── screens/         # UI screens (home, onboarding, profile, duels, library)
├── services/        # Business logic (XP, sync, streak, storage, notifications)
├── widgets/         # Reusable UI components
├── router.dart      # go_router route definitions
└── main.dart        # App entry point
```

## License

Private repository — all rights reserved.
