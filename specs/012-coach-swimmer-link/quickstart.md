# Quickstart — The coach → swimmer relation

How to see this feature work, and how to see it **refuse**, which is the half that
matters.

---

## Prerequisites

```bash
flutter pub get
```

```bash
firebase emulators:start --project demo-natacion --export-on-exit
```

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node firebase/functions/tools/sembrar-emulador.js
```

The seed needs a second coach and a second swimmer who belongs to nobody. Without them,
every "he cannot see her" check passes for the wrong reason.

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

**The rules number must go up a lot.** This feature is a boundary; if the rules suite
barely moves, the boundary is not being tested.

---

## V0 — The seed builds a product somebody belongs to

**There is no migration to rehearse.** The coach confirmed there is nobody to link, so
nothing has to happen in a particular order at deploy time. What is left is the seed.

1. Confirm `sembrar-emulador.js` creates a community for the seeded coach.
2. Confirm the seeded swimmers are in it, and that at least one is **not**, so every
   "he cannot see her" check below has something real to fail against.
3. Confirm a second coach exists with his own community.

**Fails if** everybody in the seed belongs to everybody, because then V5 passes without
proving anything.

---

## V1 — He names it, she is offered it

1. As the coach, open settings and set the community name.
2. Create a swimmer account from scratch.
3. Confirm the joining step offers that name.
4. Rename it as the coach; confirm a new swimmer is offered the new name and that nobody's
   membership changed.

**Fails if** the name has to be typed by the swimmer, or if renaming moves anybody.

---

## V2 — She asks while signing up, and can decline to

1. Create an account and choose to join. Confirm the request is waiting for the coach.
2. Create another and skip it. Confirm the account works and she can ask later.
3. With no community named at all, confirm she is told so and can still finish.

**Fails if** skipping blocks her, or if a missing community leaves her on a dead end.

---

## V3 — While she waits, she is told where she stands

1. With her request waiting, sign in as her.
2. Confirm she can move through the app.
3. On the screen where her plan would be, confirm it says she is waiting for the coach —
   **not** that she has no plan, and not an empty screen.
4. As the swimmer who never asked, confirm that same screen tells her how to ask instead.

**Fails if** the two cases look the same to her. They are different facts and feature 011
spent itself on exactly this distinction.

---

## V4 — He accepts, and only then does he read her

1. As the coach, find the request where things already wait for him.
2. **Before accepting**, confirm nothing of hers is readable: not her answers, not her
   discomfort, not her feedback requests.
3. Accept.
4. Confirm she appears among his swimmers and that what she wrote **before** he accepted
   is now readable.

**Fails if** anything of hers was readable at step 2 — that is the feature not existing.

---

## V5 — The second coach, which is the whole point

The scenario feature 010 could not meet and declared instead.

1. Sign in as a second coach, belonging to his own community.
2. Run **every** query the app makes about swimmers: the list, the records, the
   macrocycles, the plans, the assignments, the feedback requests.
3. Confirm each returns nothing of the first coach's swimmer.

**Fails if** any of them returns her — and **also fails if** any of them returns nothing
because the client filtered it. The query itself must be refused or scoped; filtering
after reading is not a boundary.

**This is the check that replaces** the test in `reglas_analisis.test.js` which today
asserts the opposite and says in its own text that it is waiting for this day.

---

## V6 — The queries that used to read everything

Each of the five, confirmed to still work for the coach **and** to be scoped:

| Query | Before | Now |
|---|---|---|
| who has answered | all of `registros` | his swimmers only |
| the swimmer list | all of `nadadores` | his community only |
| which macrocycle each has | all of `macrociclos` | his swimmers only |
| the plan requests | all of `peticiones` | his swimmers only |
| the assignments | all of `asignaciones` | his swimmers only |

**And record the number of queries** "who has answered" now costs with the seeded group.
Feature 007 made it one on purpose; this feature makes it a few, and the number goes here
rather than in anyone's memory.

---

## V7 — Leaving, and being let go

1. As the swimmer, leave the community. Confirm the coach stops reading her on his next
   query, and that her own history is untouched.
2. As the coach, remove the other swimmer. Confirm she is told, and the same two things
   hold.
3. Confirm either of them can then ask to join somewhere else.

**Fails if** anything she wrote disappears. Leaving is not deleting.

---

## V8 — The consent gate is still there

1. With a minor who has no valid consent, confirm her data still does not leave the
   device — **even though she now belongs to a community**.
2. With consent and no membership, confirm no coach reads her.

**Fails if** either gate alone is enough. They compose; neither replaces the other.

---

## V9 — The negative control, re-run

The requirement that is really a warning (FR-018).

1. Point the rules suite at a collection with **no rule at all**, as feature 010 did.
2. Record how many tests pass anyway, and which.
3. Compare with the old measurement: **5 of 10, all five failures being `assertSucceeds`**.

**What to look for**: the second-coach test used to be one of those five. After inverting
it, the suite has one fewer assertion that can notice the rules are missing entirely. If
the number of "passes against no rule" has gone up, add the `assertSucceeds` this feature
can honestly make — a coach reading **his own** swimmer — and record that it was needed.

**A suite that only asserts refusals passes for free when nothing is enforced.** That is
the whole reason this check exists.

---

## What is NOT closed here

The deferred device checks — C1 and C2 of feature 003, C7 and C8 of feature 004, tasks
T071, T088 and T089 — are still walked together after feature 013, by the coach's
decision. Nothing in this feature closes them, and C7 (two siblings on one phone) now has
one more thing to look at: whether signing out leaves a membership behind on the device.
