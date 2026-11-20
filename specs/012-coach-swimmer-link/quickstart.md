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

### Walked on 2026-11-19, against the emulators, in the app

All five work, and the numbers are these.

Every one of them is expressed in terms of «his swimmers», so one piece answers that once:
`lib/datos/firestore/mis_nadadores.dart`, a single query filtered by `comunidadId`, **with
no memory on purpose**. Remembering the list for a few seconds would save three queries per
HUB refresh and would let a coach who has just accepted somebody refresh and not see her —
a bad trade on the one fact this feature makes change by hand.

| | queries |
|---|---|
| each scoped call | **1** (who are mine) **+ 1 per batch of 30** (`whereIn` takes 30) |
| who has answered, with the seeded group | **2** |
| the same with 30 swimmers | 2 |
| the same with 60 | 3 |
| a full HUB refresh (4 such calls) | 8, where it used to be 4 |

Feature 007's decision D10 bought «one query» to avoid **N**. This is not N, and that is
the whole argument.

**What the app showed.** Signed in as `entrenador.verifica@ejemplo.test`: HOME counts 4
plans and 1 «en uso», which is exactly what the seed says it should be; `Análisis` lists
his seven swimmers and no one else's; `Solicitudes` holds the three border requests;
`Ver Plan` shows the four plans with their deliveries. Signed in as
`entrenador.otro@ejemplo.test`: **`Análisis` lists exactly one swimmer, Camila Ríos, his
own** — none of the other coach's seven, and not because a screen hid them. Signed in as
`nadadora.verifica@ejemplo.test`: her session, her 2 of 3, her last note, unchanged. No
console errors anywhere in the walk.

One thing the rules forced on the way: the queue over `peticionesDePlan` filters by the
`nadadorId` **field**, not the document id, because in a `list` the path wildcard is not
bound and the rule died with «Null value error» over the whole queue. `firestore.rules`
splits `get` from `list` there for that reason, and says so.

**And the seed had to be told.** `sembrarParaPeticiones` creates five more swimmers
(`n-sin-permiso`, `n-inicia` and the three borders) and none of them carried a
`comunidadId`, because until today nothing asked. Without it the coach's screens showed
two swimmers instead of seven and scenarios C8, C9 and C12 had no subject. The boundary
does not distinguish a test swimmer from another coach's.

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

### Run on 2026-11-19

| Suite | Against no rule at all | Failures |
|---|---|---|
| `reglas_analisis.test.js`, before this feature | 5 of 10 passed | 5, every one an `assertSucceeds` |
| the same, after | **7 of 11 passed** | 4, every one an `assertSucceeds` |
| `reglas_frontera.test.js` (new) | **11 of 18 passed** | 7, every one an `assertSucceeds` |

The analysis suite got worse at noticing a missing rule, and by two, not one: this feature
inverted *two* of those five — the second coach reading another's swimmer, and the
whole-collection read the boundary makes impossible. So the compensating assertion was
needed and is in place: «y el suyo SI la lee: la frontera no es que no funcione nada»,
which says what the suite could not say before — that membership **lets him read**, not
only that it stops others. Without it the suite would be down to three.

The boundary suite was measured against copies of the collections with no rules
(`nadadores_sin_regla` and the rest, deleted afterwards), before the four later
collections took it to 26 tests.

---

## The walk, done on 2026-11-19

Against the emulators, in the app, V1 through V8. What each one showed:

| | What it showed |
|---|---|
| **V1** | Settings has «Mi comunidad» with «Club Acuático del Valle», 23/60. The second coach's says «Escuela de Natación Ribera». |
| **V2** | Sign-up step 6 of 6, «¿Con quién entrenas?», both communities **by name**, and «Todavía no» selected by default. Skippable, as FR-005 says. |
| **V3** | Signed in as her while waiting: «Esperando que el entrenador acepte tu ingreso». Settings: «Pediste entrar en Club Acuático del Valle y todavía no te han contestado», with «Retirar mi solicitud». |
| **V4** | His queue: «Valentina Ocampo · Lo pidió el 19/11/2026», with Aceptar and Ahora no. After accepting, Firestore holds **both writes**: `comunidadId` + `miembroDesde` on her profile and `estado: aceptada` + `resueltaEn` on the request. |
| **V5** | Signed in as the second coach: `Análisis` lists **one** swimmer, Camila Ríos, his own. None of the first coach's eight. |
| **V6** | His own `Análisis` lists his eight, «Contó una molestia» on Ana (so the sixth query works too), and HOME counts 4 plans / 1 «en uso», exactly what the seed says. |
| **V7** | She leaves from Settings. The dialog says what she loses and what she does not. After it: her profile keeps name, marks and diagnosis, **her 2 records are untouched**, `comunidadId` and `miembroDesde` are gone, `pertenenciaTerminadaEn` is stamped — and the coach's `Análisis` no longer lists her. |
| **V8** | The consent gate: seeding a minor with no consent still blocks her writes, with the membership in place. Locked in `reglas_frontera.test.js` rather than walked. |

### What the walk found that the tests did not

Four things, and every one of them was a screen telling somebody something false:

1. **A fourth screen said «todavía no tienes un plan».** The swimmer's HOME —
   `home_del_nadador.dart` — carried its own copy of the sentence with slightly different
   words. It is the **first screen she sees**, and with the waiting notice already wired
   into the two screens the spec names, it was the one telling her to wait for a plan from
   a coach who was not hers yet. The locks for US4 mounted the two screens I knew about.
2. **His queue said «Alguien que todavía no tiene perfil».** F3 and FR-009 collide: he may
   not read her profile before accepting, and he must see who asked. Both are only true if
   **the request carries her name**, which it now does. Without the walk this would have
   shipped asking him to decide about a stranger.
3. **The sign-up promised a door that did not exist.** Its last step says «puedes pedirlo
   más adelante desde Ajustes», and Settings had nothing for somebody who skipped the step
   or was turned down — so FR-005 and FR-012 had no path after sign-up.
4. **Two screens did not notice their own changes.** `Análisis` caches its roster in
   `initState`, so a swimmer he had just accepted did not appear until the app restarted;
   and the HUB did not rebuild when `dondeEsta` changed, so after she left, Settings kept
   saying she belonged. Both now repaint.

**None of them was a boundary bug.** The rules and the queries were right; what was wrong
was what the screens said about them, which is exactly what a walk catches and a suite
does not.

---

## What is NOT closed here

The deferred device checks — C1 and C2 of feature 003, C7 and C8 of feature 004, tasks
T071, T088 and T089 — are still walked together after feature 013, by the coach's
decision. Nothing in this feature closes them, and C7 (two siblings on one phone) now has
one more thing to look at: whether signing out leaves a membership behind on the device.
