# Quickstart: Ver Plan and progression

How to check that this feature works. C1 to C13 are walked in the app; the gates are commands.

Feature 008 found six defects by walking, five of them invisible because the app kept working,
and the sixth only visible on a phone. So the walk is not optional here either, and C12 and C13
are the two that would not announce themselves.

## Prerequisites

```bash
firebase emulators:start --project demo-natacion
```

```bash
npm --prefix firebase/functions run sembrar-emulador
```

The seed gives a coach and swimmers with consent. This feature also needs a swimmer with a
**complete record and a competition far enough away** for a three-phase skeleton, and one in a
category **without ATR**; both are tasks in `tasks.md`.

```bash
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

---

## C1 — The skeleton is proposed, with its reason

As the coach, start a macrocycle for a swimmer whose competition is 14 weeks away.

**Expected**: three blocks — Acumulación, Transformación, Realización — each saying why, in
weeks until the competition. Not a blank form, and not a finished plan.

## C2 — And it is editable

Change the number of blocks, then a phase, then a length.

**Expected**: all three change. If any part is fixed, M3 is broken and the proposal is a
decision.

## C3 — The models are his, and pre-filled only from his own record

Look at the event model and the swimmer model.

**Expected**: whatever the coach already wrote on that swimmer's record is offered back —
technical diagnosis, target event, marks. **Nothing else is filled in.** If fatigue tolerance
or motivation arrives pre-written, the app derived what the constitution reserves to him.

## C4 — Nothing exists yet

Before confirming, check the emulator.

**Expected**: no macrocycle document, no plans, no sessions. This is C10's cheap half; the
locked half is a test over the repositories.

## C5 — One confirmation, everything derived

Confirm.

**Expected**: mesocycles, microcycles and sessions appear at once, and **nothing else is
asked**. If a second confirmation appears between levels, the constitution amendment was
misread.

## C6 — A category without ATR

Start a macrocycle for the Iniciación swimmer.

**Expected**: one block with no phase, and the app says why rather than leaving it blank.

## C7 — A phase outside the published range

Set a Realización of four weeks.

**Expected**: a warning, and it still generates. Section 12 says swimming uses longer phases
than the general literature.

## C8 — Signing and delivering

Approve, then deliver.

**Expected**: approving is one act however many mesocycles there are, and the swimmer has
nothing new until delivery. Then check the emulator: either every mesocycle is delivered or
none is.

## C9 — The whole path, from day one

Sign in as the swimmer and open `Ver Plan`.

**Expected**: the structure unfolded, today's position visible, and the view **already scrolled
to today**. Expand a session six weeks out: it opens. Nothing is hidden.

## C10 — Marking, the two halves

Try to mark tomorrow's session. Then skip Tuesday and mark Thursday.

**Expected**: tomorrow cannot be marked and the app says why. Thursday is marked, and the app
says Tuesday is outstanding. Then mark Tuesday: it still works.

## C11 — What the coach sees

As the coach, look at adherence.

**Expected**: Thursday done, Tuesday as a skip. Not as missing data — the difference is what
his readjustment will be reading.

## C12 — The readjustment does not eat the swimmer's history

**This is the one that would not announce itself.** With sessions already marked inside a
mesocycle, readjust it.

**Expected**: the records are still **reachable** afterwards — check against the emulator, not
the screen. If session ids changed with the version, the swimmer's history is orphaned and
nothing failed to tell you.

## C13 — One act, one notice

Readjust something that moves three mesocycles.

**Expected**: one act for the coach, and the swimmer is told **once** rather than three times.

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

```bash
npm --prefix firebase/functions test
```

**Expected**: all green, and the Dart count does not go down. A test from an earlier feature
that fails means this feature changed a behaviour it had no business changing.

---

## Suggested order

1. The gates first, so a red test is not blamed on the app.
2. C1 to C8 as the coach.
3. C9 to C11 as the swimmer.
4. **C12 and C13 last and carefully**: they are the two the walk exists for.
5. C9 again on the Android emulator. Feature 008's sixth defect was only visible on a phone,
   and this feature's folding controls are exactly the kind of thing a browser flatters.
