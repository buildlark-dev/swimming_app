# Quickstart — Repairs to the swimmer's journey

How to see this feature work, and — just as important — **what cannot be closed here**.

Four of the scenarios below are walked on a phone. They are not walked in this feature:
the coach decided to walk C1 and C2 of feature 003 and C7 and C8 of feature 004 together
after feature 013. What this feature owes them is everything provable without a device,
plus an honest list of what is left. That list is at the bottom.

---

## Prerequisites

```bash
flutter pub get
```

For the scenarios that need a server, the emulators, as always:

```bash
firebase emulators:start --project demo-natacion --export-on-exit
```

Seeding, from the project root:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node firebase/functions/tools/sembrar-emulador.js
```

---

## The gates

```bash
flutter analyze
```

```bash
flutter test
```

```bash
npm --prefix firebase test
```

**The rules suites must end on the same number they started on.** This feature adds no
rule and touches no document. If that number moves, something grew that was not meant to,
and it is worth finding out what before going further.

---

## V1 — Nothing is attempted while nothing is waiting

The cheapest check and the one most likely to regress, because every later change wants
to add "just one more poll".

1. Run the outbox suite with an empty queue.
2. Confirm **no wake-up is scheduled**, and that none has been scheduled at any point.

**Fails if** a timer exists, a socket is opened, or the transport is touched at all with
nothing queued. A swimmer with nothing to send must cost nothing.

---

## V2 — What she wrote leaves by itself

In pure Dart with simulated time:

1. Queue a record with a transport that refuses.
2. Advance the clock. Confirm the retries space out — 1, 2, 4, 8 seconds — and that the
   spacing **stops growing at one minute**.
3. Make the transport answer.
4. Confirm the record is sent on the next wake-up, **without anything calling
   `sincronizar()` from outside**.

**Fails if** the record waits more than a minute after the transport starts answering, or
if sending it required a trigger the swimmer would have had to cause.

---

## V3 — One record's success releases the rest of the queue

This is what FR-005 means once the attempt is the probe. A single record has no separate
"the network came back" to wait for — its own next attempt *is* the discovery, and the
one-minute cap is what keeps that inside SC-001. The cut-short is **between** records.

1. Queue two records, A and B, and let both fail enough times to reach long delays.
2. Make the transport answer.
3. When A's next attempt succeeds, confirm **B is tried at once**, without serving out
   the rest of its own delay.

**Why this one exists**: the delay protects a server that is not answering. A's success
is proof that it is answering now, so B's protection has nothing left to protect. Without
this, a swimmer who annotated five sessions offline watches them trickle out one slow
delay at a time, with every mechanism in place.

---

## V4 — The deadline, and the success that arrives late

With a transport that **accepts and never answers** — the shape the real SDK has, and the
shape a double that throws will hide:

1. Queue a record. Confirm `sincronizar()` **returns**, that the record stays queued, and
   that the attempt counted as a failure.
2. Now let that same abandoned attempt complete.
3. Confirm the record becomes sent and the notice clears.

**Fails if** anything hangs, or if the record stays queued after its write actually
landed. This is the defect where the server had the record and the app kept saying it
would be sent when she had internet.

---

## V5 — The notice means it arrived

1. With a record queued and no transport answering, confirm the notice is on screen with
   its sentence **exactly** as FR-017 requires: «Guardado el progreso, se enviará cuando
   tengas acceso a internet».
2. Let the record be sent. Confirm the notice goes.
3. Put a record in a state the server holds but the queue still counts waiting, and
   confirm the notice goes on the next sync.

**Fails if** the notice ever clears for a record the server does not hold. Clearing it
means *it arrived*, never *we stopped looking*.

---

## V6 — Nothing about the network reaches the swimmer

A test over every file that draws her screens.

**Fails if** any of them can show a network error, a status code, a number of attempts,
or a control that says retry. The retrying is the app's work, and someone wet at the edge
of a pool is not there to diagnose connectivity.

---

## V7 — A session she said she did not do

1. Answer a past session with «no pude hacerla».
2. Confirm it is **not** among the sessions she has left to mark.
3. Confirm a past session with no answer at all **is**.
4. Confirm today's, unanswered, is not — the day has not finished.
5. Confirm one with no date is not — there is no day it was missed on.
6. Confirm the coach reads the same count she does.

---

## V8 — No screen claims an absence it has not established

1. With a reading still in flight, confirm the screen says it is loading and **does not**
   say she has no plan.
2. With the reading finished and nothing there, confirm the existing empty state appears,
   with its existing words.
3. With the reading failed, confirm she is told it could not be read — not that there is
   nothing to read.

Both of her screens, not one: the same sentence lives in `Mi progreso` and in the day's
session.

---

## V9 — The doubles must hang where the server hangs

Not a scenario so much as a rule for every double written in this feature, and the reason
three defects got past a green suite.

Any double standing in for the server must be able to **accept and never answer** — a
future that does not complete — and the tests that matter must use that shape. A double
that throws is kinder than the thing it stands for, and kindness is what hid all of this.

Every lock wraps its call in a deadline with a failing message, so a regression fails the
test instead of stopping the suite.

---

## What is NOT closed here

Deliberately, and by the coach's decision — walked after feature 013, all together:

- **C1 of feature 003** — the day's session with no signal, after closing the app
  completely. Its cause was fixed in feature 010's walk; the check itself is still owed.
- **C2 of feature 003** — annotating with no signal and the record arriving by itself.
  **This feature is the repair C2 step 5 was waiting for**, and everything above proves it
  in simulated time. What a phone adds is the part no test reaches: a real radio, a real
  airplane mode, and a real walk out of a building.
- **C7 and C8 of feature 004** — two siblings on one phone, and a session expiring at the
  poolside.

These are tasks T071 of feature 003 and T088 and T089 of feature 004. They stay open.
A scenario is closed by someone standing at a pool with airplane mode on, not by the
commit that should make it pass.
