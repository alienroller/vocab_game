# VocabGame — Duel Session Real-Time Bug: Analyze & Fix

## Your Role
You are a senior Flutter + Supabase engineer. Your job is to:
1. **Diagnose** why the duel session is not updating in real-time on both screens
2. **Propose** the best solution with clear reasoning
3. **Implement** the fix without breaking any other part of the project

---

## Project Context
- **App:** VocabGame — a Flutter vocabulary learning app for Uzbek English learners
- **Backend:** Supabase (PostgreSQL + Realtime + Edge Functions)
- **Duel feature:** Two students compete live — answering vocabulary questions, seeing each other's XP/score update in real-time
- **Problem:** Screen state does not update instantly during a live duel session. Notifications and UI changes on both sides are delayed or not firing at all.

---

## Step 1 — Read the Codebase First

Before writing a single line of code, read and understand:
- `lib/features/duel/` — all files
- `lib/services/` or `lib/core/` — any realtime, supabase, or notification service
- `supabase/functions/` — any edge functions related to duel
- The Supabase `duels` table schema (check migrations or existing queries)

Do NOT guess. Read actual code.

---

## Step 2 — Diagnose: Answer These Questions

After reading the code, answer each question explicitly:

### Supabase Realtime
- Is `supabase.channel()` being subscribed correctly for the duel room?
- Is the subscription using `.on('postgres_changes', ...)` or `.on('broadcast', ...)`? Which is appropriate here?
- Is the channel being subscribed **after** the duel is created, or before?
- Is the channel being **disposed/unsubscribed** properly on screen exit? Could this be causing a ghost subscription?
- Is RLS (Row Level Security) blocking realtime events from reaching the subscriber?

### State Management
- What state management is used (Provider, Riverpod, Bloc, setState)?
- When Supabase fires an event, does it correctly call `setState` or `notifyListeners`?
- Is the screen widget still mounted when the callback fires? (classic `if (!mounted) return` issue)

### Notifications
- Are duel-related notifications local or push?
- Is there a race condition between the duel starting and the notification listener being registered?

### Both Users
- Is there a single shared channel both users subscribe to, or are they on separate channels?
- Could one user's subscription be silently failing?

---

## Step 3 — Root Cause Statement

Write a clear, specific root cause statement in this format:

> "The real-time updates are failing because [X]. This causes [Y] on the UI side. The notification issue is caused by [Z]."

No vague language. Be specific about which file and which line or function is the problem.

---

## Step 4 — Propose the Best Solution

Pick the best approach from these options and justify your choice:

| Option | Description | When to use |
|--------|-------------|-------------|
| **Postgres Changes** | Subscribe to DB row changes | Simple state sync, no latency requirements |
| **Broadcast** | Send custom events via Supabase channel | Low-latency, high-frequency updates (scores changing every second) |
| **Presence** | Track who is online in a channel | Knowing if opponent is still connected |
| **Hybrid** | Broadcast for score updates + Postgres Changes for final state | Best of both worlds for duels |

For a live duel with score updates every answer → **Broadcast is almost certainly the right choice.**

Explain your reasoning clearly before implementing.

---

## Step 5 — Implement the Fix

### Rules
- Do NOT rewrite files that are unrelated to the duel feature
- Do NOT change the database schema unless absolutely necessary — if you must, write a migration file
- Preserve all existing navigation, auth, and assignment logic
- Add comments where the fix differs from the original code

### Required Implementation Checklist
- [ ] Correct channel subscription in the duel screen's `initState`
- [ ] Proper cleanup in `dispose()` — `channel.unsubscribe()`
- [ ] State update triggers `setState` / notifier correctly and checks `mounted`
- [ ] Both players subscribe to the same named channel (e.g. `duel:${duelId}`)
- [ ] Score/XP broadcast sent immediately on answer submission
- [ ] Opponent's score reflected on screen within <500ms
- [ ] Notification (if applicable) fires correctly when duel ends or opponent takes the lead

### Code Pattern to Follow (Broadcast approach)
```dart
// SUBSCRIBE
final channel = supabase.channel('duel:$duelId')
  ..onBroadcast(
    event: 'score_update',
    callback: (payload) {
      if (!mounted) return;
      setState(() {
        opponentScore = payload['score'];
      });
    },
  )
  ..subscribe();

// SEND (on answer submit)
await supabase.channel('duel:$duelId').sendBroadcast(
  event: 'score_update',
  payload: {'userId': currentUserId, 'score': newScore},
);

// DISPOSE
@override
void dispose() {
  supabase.removeChannel(channel);
  super.dispose();
}
```

---

## Step 6 — Test Plan

After implementing, describe exactly how to verify the fix:
1. Open the app on two physical devices (or two simulators)
2. Start a duel session from both accounts
3. Answer a question on Device A — Device B should update within 500ms
4. Answer a question on Device B — Device A should update within 500ms
5. Complete the duel — both screens should show results simultaneously
6. Background one device — confirm notification fires correctly

---

## Output Format

Deliver in this order:
1. **Diagnosis** — answers to all Step 2 questions
2. **Root Cause** — one clear statement
3. **Solution Choice** — which approach and why
4. **Code Changes** — only modified/new files, with file paths
5. **Test Plan** — how to verify it works

Do not output anything until you have read the full codebase.
