# VocabGame Hardening — Walkthrough for Remaining Work

This walks through what still needs **your** attention after the code changes in this branch land. Everything here is either (a) a server/console task that can't be done from Flutter code, (b) a local one-time install step, or (c) a verification test.

If you skip the **Ship-blockers** the app is still cheatable in ways that make leaderboards, XP, and duels meaningless. Please do them before any real users.

---

## 0. First thing: install new dependencies and run tests

From the project root:

```bash
flutter pub get
flutter analyze      # should run clean under the new stricter lints
flutter test         # new unit tests for XP/date logic
```

If `flutter pub get` fails on `flutter_secure_storage` on Windows, add the Windows build prerequisites per https://pub.dev/packages/flutter_secure_storage.

> `flutter analyze` will report ~250 **info/warning** items (no errors) in files I didn't touch — that's expected. The linter is now stricter (empty catches, unawaited futures, raw-type checks, prefer const/final, strict-inference). They're the debt the audit flagged (items A3/A6 in particular). `strict-casts` is intentionally left off because turning it on promotes pre-existing `dynamic → T` reads from untyped Hive/Supabase calls into hard errors across ~40 call sites; that's a separate cleanup pass, not a one-line flip. See the note at the top of `analysis_options.yaml`.

---

## 1. SHIP-BLOCKERS (required before any real user data)

### 1a. Rotate the committed Firebase key (S6)

The Firebase API key `AIzaSyAi41G12BfeT1AIMd2biBTeLJ_E1lZ4Oxc` is checked in at:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase.json`

**Do:**

1. Firebase Console → Project Settings → **General** → under "Your apps" delete the compromised Android and iOS app entries.
2. Re-add them (same package ids) to get new `google-services.json` / `GoogleService-Info.plist`.
3. Replace the files in the repo.
4. In the Google Cloud Console for the same project, go to **APIs & Services → Credentials** and apply **Application restrictions** to the new keys (Android: SHA-1 fingerprint; iOS: bundle id).
5. Commit the new config files. (They will still be checked in — that's fine once the keys are restricted.)

### 1b. Turn on Supabase Anonymous Auth (S1)

Right now anyone who knows the anon key can write to any profile because user identity is a client-generated UUID. Fix by making every request carry a real `auth.uid()`.

**Do:**

1. Supabase Dashboard → **Authentication → Providers → Anonymous sign-ins** → **Enable**.
2. In the client, sign the user in anonymously on first launch (where we currently just generate a UUID). Example patch in your onboarding flow:

   ```dart
   // Where you currently do `final id = const Uuid().v4();`
   final supa = Supabase.instance.client;
   final response = await supa.auth.signInAnonymously();
   final id = response.user!.id;     // <-- use THIS as the profile id
   ```

3. In `lib/services/sync_service.dart`, make every write also assert `'id': supabase.auth.currentUser!.id` instead of trusting the caller.
4. Existing users already have UUIDs in Hive. Add a one-time migration on startup that reads the legacy id, calls `signInAnonymously()`, and upserts a row keyed to `supabase.auth.currentUser!.id`. I left a comment hook in `ProfileNotifier._loadProfile` — wire this when you're ready.

### 1c. Add Row-Level Security to every table (S2, S5)

**Do:** Run this SQL in Supabase → **SQL Editor**. Edit table/column names if yours differ.

```sql
-- =========================================================================
-- Enable RLS on every table
-- =========================================================================
alter table public.profiles            enable row level security;
alter table public.duels               enable row level security;
alter table public.classes             enable row level security;
alter table public.assignments         enable row level security;
alter table public.assignment_progress enable row level security;
alter table public.word_stats          enable row level security;

-- =========================================================================
-- profiles: each user can only read/write THEIR OWN row.
-- Leaderboard reads are allowed only for rows sharing the caller's class_code.
-- =========================================================================
create policy "profiles_self_read"
  on public.profiles for select
  using (id = auth.uid());

create policy "profiles_classmates_read"
  on public.profiles for select
  using (
    class_code is not null
    and class_code = (
      select class_code from public.profiles where id = auth.uid()
    )
  );

create policy "profiles_self_write"
  on public.profiles for update
  using  (id = auth.uid())
  with check (id = auth.uid());

create policy "profiles_self_insert"
  on public.profiles for insert
  with check (id = auth.uid());

-- XP/level/streak fields should only be writable via the trusted RPC
-- (see 1d). Block direct column writes:
create policy "profiles_no_direct_xp_writes"
  on public.profiles for update
  using  (id = auth.uid())
  with check (
    id = auth.uid()
    and xp           is not distinct from (select xp           from public.profiles where id = auth.uid())
    and level        is not distinct from (select level        from public.profiles where id = auth.uid())
    and streak_days  is not distinct from (select streak_days  from public.profiles where id = auth.uid())
    and week_xp      is not distinct from (select week_xp      from public.profiles where id = auth.uid())
  );

-- =========================================================================
-- duels: only the two participants can read or write their duel row.
-- Score updates must come from the player who owns that score column.
-- =========================================================================
create policy "duels_participants_read"
  on public.duels for select
  using (challenger_id = auth.uid() or opponent_id = auth.uid());

create policy "duels_challenger_creates"
  on public.duels for insert
  with check (challenger_id = auth.uid());

create policy "duels_participant_updates"
  on public.duels for update
  using  (challenger_id = auth.uid() or opponent_id = auth.uid())
  with check (challenger_id = auth.uid() or opponent_id = auth.uid());

-- =========================================================================
-- classes: teachers own their classes.
-- =========================================================================
create policy "classes_teacher_manage"
  on public.classes for all
  using  (teacher_id = auth.uid())
  with check (teacher_id = auth.uid());

create policy "classes_students_read"
  on public.classes for select
  using (
    class_code in (
      select class_code from public.profiles where id = auth.uid()
    )
  );

-- =========================================================================
-- assignments: only the teacher that owns the class can insert/update.
-- =========================================================================
create policy "assignments_teacher_write"
  on public.assignments for all
  using  (teacher_id = auth.uid())
  with check (teacher_id = auth.uid());

create policy "assignments_class_read"
  on public.assignments for select
  using (
    class_code in (
      select class_code from public.profiles where id = auth.uid()
    )
  );

-- =========================================================================
-- assignment_progress: each student sees & writes their own row; teacher
-- for that class can read all rows for that class.
-- =========================================================================
create policy "progress_self_rw"
  on public.assignment_progress for all
  using  (student_id = auth.uid())
  with check (student_id = auth.uid());

create policy "progress_class_teacher_read"
  on public.assignment_progress for select
  using (
    class_code in (
      select class_code from public.classes where teacher_id = auth.uid()
    )
  );
```

Verify by running as anon key in a separate HTTP client:

```bash
# Should now be rejected with 401 / PGRST policy violation:
curl -X PATCH "$SUPABASE_URL/rest/v1/profiles?id=eq.<someone-else>" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"xp": 999999}'
```

### 1d. Move XP/duel mutations behind Edge Functions (S3, S4)

Clients still send final XP values from games. Even with RLS, a client can inflate XP by posting a fake session. Fix by computing XP server-side.

**Do:**

1. Create a trusted `increment_xp` SQL function (replacing the current one):

   ```sql
   create or replace function public.increment_xp(
     profile_id uuid,
     amount     integer
   )
   returns void
   language plpgsql
   security definer
   as $$
   begin
     -- Only the owner (or the service role) can drive this.
     if profile_id <> auth.uid() and auth.role() <> 'service_role' then
       raise exception 'not authorised';
     end if;
     if amount < 0 or amount > 1000 then
       raise exception 'xp delta out of range';
     end if;
     update public.profiles
        set xp           = coalesce(xp, 0) + amount,
            week_xp      = coalesce(week_xp, 0) + amount,
            updated_at   = now()
      where id = profile_id;
   end;
   $$;

   revoke all on function public.increment_xp(uuid, integer) from public;
   grant execute on function public.increment_xp(uuid, integer) to authenticated;
   ```

2. Create an **Edge Function** `record-session` that receives `{questions, correct, secondsLeft[], streakDays}` and re-runs the same XP math that lives in `lib/services/xp_service.dart`. Reject mismatched values. From the client, call it via `supabase.functions.invoke('record-session', …)` instead of writing `profiles.xp` directly.

3. Create an Edge Function `finish-duel` that takes the duel id and recomputes the winner from the server-side stored scores (not the client's claim). The rollback logic I added in `DuelService.finishDuel` is still useful — it's the client's cooperative protocol while you migrate.

4. Once both are in place, delete the direct `profiles.xp` writes from `sync_service.dart` and call the Edge Function from `ProfileNotifier.recordGameSession` instead.

---

## 2. PRE-PRODUCTION HARDENING

### 2a. Verify Hive encryption (S9)

Done in code: `StorageService.openSecurityBox()` now opens an AES-encrypted `secureBox` whose key lives in Android Keystore / iOS Keychain via `flutter_secure_storage`. The PIN hash is migrated into it automatically on first run of the new build.

**You should verify:**

- Install a fresh debug build, onboard, set a PIN.
- `adb shell run-as com.example.vocab_game ls -la app_flutter/hive/` — the `secureBox` files exist but aren't human-readable.
- Uninstall and reinstall: the security box is re-created from scratch (the Keystore key was lost) and the PIN hash will be re-fetched from Supabase on next recovery — confirm that still works.

### 2b. Verify PIN brute-force resistance (S7)

Done in code: the PIN rate-limit counter and escalation level now persist in `secureBox`, so killing the app no longer resets the counter. Each re-trigger doubles the lockout (60s → 2m → 4m … capped at 24h).

**You should verify:**

1. Enter a wrong PIN 3× — you're locked out for 60s.
2. Force-kill the app and reopen — still locked out (the timer survives).
3. After the lockout expires, enter wrong PIN 3× again — this time locked out for **2 minutes**, not 60s.
4. A correct PIN clears the escalation level so legitimate users aren't punished long-term.

### 2c. Remove Firebase Analytics collection of PII (S11)

**Do:**

1. Firebase Console → Project → **Analytics → Events**.
2. Audit any custom events your app fires. Make sure none contain `username`, `class_code`, or other identifying strings as parameters.
3. If you don't actually use Analytics, disable it: Firebase Console → Project Settings → **Integrations** → Google Analytics → **Disable**. Your FCM (push) still works after this.

---

## 3. Quality & test coverage (recommended)

### 3a. Run the new tests

```bash
flutter test
```

You should see tests in:

- `test/services/xp_service_test.dart` — XP math (streak tiers, speed bonus, level curve).
- `test/services/date_utils_test.dart` — ISO-week boundaries (DST, year edges, leap years).
- `test/widget_test.dart` — the existing smoke test.

### 3b. Known items still pending (not blocking)

| Item | What's left | Why I left it |
|------|-------------|--------------|
| A1 ProfileNotifier god class | Split into `streakProvider`, `weekXpProvider`, `syncStatusProvider` | Mechanical refactor; best done alongside consumer updates |
| A3 Games bypass the provider | Have games go through `ProfileNotifier` for `classCode`/`id` reads instead of `Hive.box('userProfile').get(...)` | Touches every game file — wanted to get the correctness fixes in first |
| A5 Routing role-based access | Add a teacher→student deep-link guard in `lib/router.dart` | Needs a user role reloading strategy; pair with 1b migration |
| A6 Game-mode duplication | Extract a `BaseGameNotifier` | Best after A3 lands so the abstraction has a single seam |
| P3 Polling backoff | Exponential backoff in `home_screen.dart`, `leaderboard_screen.dart`, `duel_lobby_screen.dart` timers | Small, but needed on every poller |
| P9 Accessibility | Add `Semantics` wrappers for game buttons, leaderboard rows | Audit pass with TalkBack/VoiceOver |

---

## 4. Verification checklist

After deploying the SQL + Edge Functions:

- [ ] `curl -X PATCH …profiles?id=eq.<other-user>` with anon key fails (RLS).
- [ ] Kill-and-retry after 3 wrong PIN attempts still shows lockout (persisted counter).
- [ ] `flutter analyze` runs clean.
- [ ] `flutter test` — new unit tests green.
- [ ] In Supabase dashboard → **Realtime**, after hot-restarting the app, the number of active connections per user is exactly 1 (no channel leak).
- [ ] Run two duels concurrently from one device (e.g. via emulator pair). XP totals match the sum of session results, i.e. no lost updates from the A2 race.
- [ ] Force a network failure during `finishDuel` (e.g. airplane mode mid-duel). The duel row lands back on `status = 'active'` instead of being stranded in `settling`.

---

## 5. What changed in code (summary)

| Finding | Fix | Files |
|---------|-----|-------|
| A8 | Strict analysis options | `analysis_options.yaml` |
| A10 | Game/duel constants centralised | `lib/services/game_constants.dart` + game files |
| P1 | Duel realtime channel now tracked & unsubscribable | `lib/main.dart` |
| P6 | ISO-week based reset replaces local Monday math | `lib/services/date_utils.dart`, `lib/main.dart`, `lib/providers/profile_provider.dart` |
| A4 | Every `catch (_) {}` now logs | `lib/games/*.dart`, `lib/services/sync_service.dart`, `lib/services/firebase_service.dart`, `lib/services/dictionary_service.dart`, `lib/speaking/services/eval_cache_service.dart`, `lib/screens/home_screen.dart`, `lib/screens/teacher/teacher_dashboard_screen.dart`, `lib/providers/profile_provider.dart` |
| A2 | `recordGameSession` serialised under a write lock | `lib/providers/profile_provider.dart` |
| A7 | Fire-and-forget `unawaited(...)` syncs now logged | `lib/providers/profile_provider.dart`, `lib/main.dart` |
| S7 | PIN rate limit persists in encrypted box + escalating lockouts | `lib/services/account_recovery_service.dart`, `lib/services/game_constants.dart` |
| S9 | Hive security box encrypted with keystore-backed AES key | `lib/services/secure_storage_service.dart`, `lib/services/storage_service.dart`, `pubspec.yaml` |
| P4 | `finishDuel` stages through `settling` state, rolls back on partial failure | `lib/services/duel_service.dart` |
| T1 | Unit tests for XP math + ISO-week logic | `test/services/xp_service_test.dart`, `test/services/date_utils_test.dart` |

**Not changed (blocked on server):** S1, S2, S3, S4, S5, S6, S11. See section 1.
