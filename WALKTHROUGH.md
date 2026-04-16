# VocabGame Hardening — Walkthrough

Do the steps in order. Don't skip §1.

---

## 0. Build check

```bash
cd .claude/worktrees/suspicious-euclid
flutter pub get
flutter analyze
flutter test
```

Expect: `0 errors`, `15/15 All tests passed!`.

---

## 1. SHIP-BLOCKERS

### 1a. Rotate Firebase key

1. https://console.firebase.google.com → your project → **⚙ Project Settings** → **General**.
2. Under **Your apps**: click each app → **⋮** → **Remove this app**.
3. Click **Add app** → Android → same package id → **Download `google-services.json`**.
4. Click **Add app** → iOS → same bundle id → **Download `GoogleService-Info.plist`**.
5. Replace these two files in the repo:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
6. https://console.cloud.google.com/apis/credentials (same project):
   - Click the new Android key → **Application restrictions** → **Android apps** → **Add** → enter package id + SHA-1 → **Save**.
   - Click the new iOS key → **Application restrictions** → **iOS apps** → **Add** → enter bundle id → **Save**.
7. Commit the two replaced files.

### 1b. Enable Supabase Anonymous Auth

1. https://app.supabase.com → your project → **Authentication** → **Providers** → **Anonymous sign-ins** → toggle **ON** → **Save**.

2. Open your onboarding file (search the repo for `Uuid().v4()`). Replace:

   ```dart
   final id = const Uuid().v4();
   ```

   with:

   ```dart
   final supa = Supabase.instance.client;
   final response = await supa.auth.signInAnonymously();
   final id = response.user!.id;
   ```

3. In `lib/services/sync_service.dart`, find every `.upsert({...})` and `.update({...})` call on `profiles`. Add this line right before the payload map:

   ```dart
   assert(profile.id == Supabase.instance.client.auth.currentUser!.id);
   ```

4. In `lib/providers/profile_provider.dart` at the top of `_loadProfile()`, paste:

   ```dart
   final supa = Supabase.instance.client;
   if (supa.auth.currentUser == null) {
     final legacyId = Hive.box('userProfile').get('id') as String?;
     final resp = await supa.auth.signInAnonymously();
     final newId = resp.user!.id;
     if (legacyId != null && legacyId != newId) {
       await Hive.box('userProfile').put('id', newId);
       await Supabase.instance.client.from('profiles')
         .update({'id': newId}).eq('id', legacyId);
     }
   }
   ```

### 1c. Paste this SQL in Supabase

https://app.supabase.com → your project → **SQL Editor** → **New query** → paste → **Run**:

```sql
alter table public.profiles            enable row level security;
alter table public.duels               enable row level security;
alter table public.classes             enable row level security;
alter table public.assignments         enable row level security;
alter table public.assignment_progress enable row level security;
alter table public.word_stats          enable row level security;

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

Then verify in a terminal (fill in `$SUPABASE_URL`, `$ANON_KEY`, and a different user's id):

```bash
curl -X PATCH "$SUPABASE_URL/rest/v1/profiles?id=eq.<someone-else>" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"xp": 999999}'
```

Must return `401` or a policy-violation error.

### 1d. Paste this SQL in Supabase (XP function)

Same SQL Editor → **New query** → paste → **Run**:

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

### 1e. Create Edge Function `record-session`

1. Supabase Dashboard → **Edge Functions** → **Create a new function** → name it `record-session` → **Create**.
2. Paste this into the function editor:

   ```typescript
   import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
   import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

   serve(async (req) => {
     const authHeader = req.headers.get('Authorization')!;
     const supabase = createClient(
       Deno.env.get('SUPABASE_URL')!,
       Deno.env.get('SUPABASE_ANON_KEY')!,
       { global: { headers: { Authorization: authHeader } } }
     );
     const { data: userData } = await supabase.auth.getUser();
     const userId = userData.user?.id;
     if (!userId) return new Response('unauthorised', { status: 401 });

     const { questions, correct, secondsLeft, streakDays } = await req.json();
     if (questions > 50 || correct > questions) {
       return new Response('invalid payload', { status: 400 });
     }

     // Mirror of lib/services/xp_service.dart
     const multiplier = streakDays >= 30 ? 4 : streakDays >= 14 ? 3 : streakDays >= 7 ? 2 : 1;
     let xp = 0;
     for (let i = 0; i < correct; i++) {
       const base = 10;
       const speedBonus = Math.round(10 * (secondsLeft[i] ?? 0) / 20);
       xp += (base + speedBonus) * multiplier;
     }
     if (xp > 1000) return new Response('xp out of range', { status: 400 });

     const { error } = await supabase.rpc('increment_xp', {
       profile_id: userId,
       amount: xp,
     });
     if (error) return new Response(error.message, { status: 500 });
     return new Response(JSON.stringify({ xp }), {
       headers: { 'Content-Type': 'application/json' },
     });
   });
   ```

3. Click **Deploy**.

4. In `lib/providers/profile_provider.dart`, find this block inside `recordGameSession`:

   ```dart
   try {
     await SyncService.syncProfile(state!);
   } catch (e, s) {
     debugPrint('recordGameSession sync failed (queued): $e\n$s');
   }
   ```

   Replace with:

   ```dart
   try {
     await Supabase.instance.client.functions.invoke('record-session', body: {
       'questions': totalQuestions,
       'correct': correctAnswers,
       'secondsLeft': secondsLeftList, // pass from the game
       'streakDays': profile.streakDays,
     });
     await SyncService.syncProfile(state!);
   } catch (e, s) {
     debugPrint('record-session failed (queued): $e\n$s');
   }
   ```

5. In every game file (`quiz_game.dart`, `fill_blank_game.dart`, etc.), collect `secondsLeft` per question and pass it to `recordGameSession`.

### 1f. Create Edge Function `finish-duel`

1. Supabase Dashboard → **Edge Functions** → **Create a new function** → name `finish-duel` → **Create**.
2. Paste:

   ```typescript
   import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
   import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

   serve(async (req) => {
     const authHeader = req.headers.get('Authorization')!;
     const supabase = createClient(
       Deno.env.get('SUPABASE_URL')!,
       Deno.env.get('SUPABASE_ANON_KEY')!,
       { global: { headers: { Authorization: authHeader } } }
     );
     const { data: userData } = await supabase.auth.getUser();
     const userId = userData.user?.id;
     if (!userId) return new Response('unauthorised', { status: 401 });

     const { duelId } = await req.json();

     const { data: duel, error: dErr } = await supabase
       .from('duels').select('*').eq('id', duelId).single();
     if (dErr || !duel) return new Response('duel not found', { status: 404 });
     if (duel.status !== 'active' && duel.status !== 'settling') {
       return new Response('duel already finished', { status: 409 });
     }
     if (duel.challenger_id !== userId && duel.opponent_id !== userId) {
       return new Response('not a participant', { status: 403 });
     }

     const cs = duel.challenger_score ?? 0;
     const os = duel.opponent_score ?? 0;
     let challengerXp = 30, opponentXp = 30;
     if (cs > os)       { challengerXp = 50; opponentXp = 20; }
     else if (os > cs)  { challengerXp = 20; opponentXp = 50; }

     await supabase.rpc('increment_xp', { profile_id: duel.challenger_id, amount: challengerXp });
     await supabase.rpc('increment_xp', { profile_id: duel.opponent_id,   amount: opponentXp });

     await supabase.from('duels').update({
       status: 'finished',
       finished_at: new Date().toISOString(),
     }).eq('id', duelId);

     return new Response(JSON.stringify({ challengerXp, opponentXp }), {
       headers: { 'Content-Type': 'application/json' },
     });
   });
   ```

3. Click **Deploy**.

4. In `lib/services/duel_service.dart`, replace the entire body of `finishDuel(...)` with:

   ```dart
   Future<void> finishDuel({required String duelId}) async {
     await Supabase.instance.client.functions.invoke('finish-duel', body: {
       'duelId': duelId,
     });
   }
   ```

   Delete the old three-phase logic below it.

---

## 2. PRE-PRODUCTION VERIFY

### 2a. Hive encryption

Install a fresh debug build → onboard → set PIN. Then:

```bash
adb shell run-as com.example.vocab_game ls -la app_flutter/hive/
```

Must show `secureBox.hive` as unreadable bytes.

Uninstall → reinstall → recover account with PIN → confirm it still works.

### 2b. PIN lockout

1. Enter wrong PIN 3× → locked out 60s.
2. Force-kill app → reopen → still locked out.
3. After lockout expires → wrong PIN 3× → locked out **2 min**.
4. Correct PIN → escalation resets.

### 2c. Analytics PII

1. Firebase Console → **Analytics** → **Events** → audit every custom event. Remove any that send `username`, `class_code`, or student names.
2. Or disable Analytics: Project Settings → **Integrations** → **Google Analytics** → **Disable**.

---

## 3. Deferred work (not blocking)

| Item | What's left |
|------|-------------|
| A1 | Split `ProfileNotifier` into `streakProvider`, `weekXpProvider`, `syncStatusProvider` |
| A3 | Route game reads through `ProfileNotifier` instead of `Hive.box('userProfile').get(...)` |
| A5 | Add teacher→student deep-link guard in `lib/router.dart` |
| A6 | Extract `BaseGameNotifier` |
| P3 | Exponential backoff in `home_screen.dart`, `leaderboard_screen.dart`, `duel_lobby_screen.dart` timers |
| P9 | `Semantics` wrappers on game buttons + leaderboard rows |

---

## 4. Final checklist

- [ ] `curl -X PATCH …profiles?id=eq.<other>` returns 401.
- [ ] Force-kill after wrong PIN still shows lockout.
- [ ] `flutter analyze` = 0 errors.
- [ ] `flutter test` = 15/15 pass.
- [ ] Supabase **Realtime** tab shows 1 active connection per user after hot restart.
- [ ] Two concurrent game completions sum correctly in `profiles.xp`.
- [ ] Airplane mode during `finishDuel` → duel returns to `status='active'`.

---

## 5. What I changed (for reference)

| Finding | Fix | Files |
|---------|-----|-------|
| A8 | Strict analysis options | `analysis_options.yaml` |
| A10 | Game/duel constants | `lib/services/game_constants.dart` |
| P1 | Duel channel unsubscribable | `lib/main.dart` |
| P6 | ISO-week reset | `lib/services/date_utils.dart`, `lib/main.dart`, `lib/providers/profile_provider.dart` |
| A4 | Logged catches | `lib/games/*.dart`, `lib/services/sync_service.dart`, `lib/services/firebase_service.dart`, `lib/services/dictionary_service.dart`, `lib/speaking/services/eval_cache_service.dart`, `lib/screens/home_screen.dart`, `lib/screens/teacher/teacher_dashboard_screen.dart`, `lib/providers/profile_provider.dart` |
| A2 | `recordGameSession` write lock | `lib/providers/profile_provider.dart` |
| A7 | Logged `unawaited(...)` | `lib/providers/profile_provider.dart`, `lib/main.dart` |
| S7 | PIN lockout persisted + escalating | `lib/services/account_recovery_service.dart`, `lib/services/game_constants.dart` |
| S9 | Hive AES cipher | `lib/services/secure_storage_service.dart`, `lib/services/storage_service.dart`, `pubspec.yaml` |
| P4 | `finishDuel` three-phase + rollback | `lib/services/duel_service.dart` |
| T1 | Unit tests | `test/services/xp_service_test.dart`, `test/services/date_utils_test.dart` |
