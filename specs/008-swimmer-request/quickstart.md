# Quickstart: The swimmer's request

How to check that this feature works. Cases C1 to C12 are walked in the app; the gates are
commands. The lesson of features 006 and 007 is that **the running app finds what no test can**
— eight defects in 007, four of them only visible on a phone — so the walked cases are not
optional.

## Prerequisites

```bash
firebase emulators:start --project demo-natacion
```

```bash
npm --prefix firebase/functions run sembrar-emulador
```

The seed gives a coach (`entrenador.verifica@ejemplo.test`) and a swimmer
(`nadadora.verifica@ejemplo.test`), both with `clave-de-prueba-007`, plus Ana's record,
assignment and one answered session. For this feature the seed also needs a swimmer **without
valid consent** and a swimmer in a category **without ATR**; that is a task in `tasks.md`.

```bash
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

---

## C1 — The swimmer's `Generar` stops saying "todavía no"

Sign in as the swimmer and open `Generar`.

**Expected**: the list of six questions, with the stroke and event already filled in from the
record. Not an empty state, and not a spinner that never ends.

## C2 — The list is answerable by tapping

Answer all six without touching the keyboard.

**Expected**: it can be done. If any answer needs typing, P3 is broken.

## C3 — «No lo sé» about the competition

Answer the date with «No lo sé» and send.

**Expected**: it sends. The request arrives. No draft is generated, and the coach's queue shows
the phase as pending.

## C4 — The request arrives and no plan does

Send a complete request. Then walk every one of the swimmer's five destinations.

**Expected**: the request shows as «Esperando a tu entrenador», and **no new plan and no new
session appear anywhere**. Check `Home`, `Ver Plan` and `Análisis`, not just the one you expect.

## C5 — One at a time

With a request waiting, go back to `Generar`.

**Expected**: the app says there is already one waiting and does not offer the list again. Then
try it against the rules:

```bash
npm --prefix firebase test
```

**Expected**: the negative control for P12 fails the write, not just the screen.

## C6 — The coach sees it, and the draft appears when he opens it

Sign in as the coach, open `Generar`, open the request.

**Expected**: who asked, when, the six answers, the discomfort with its dates, and the draft.
The draft did not exist until this moment — check the emulator before and after: before, there
is no plan document for it.

## C7 — The derived phase, with its reason

Look at the draft of a request with a competition date.

**Expected**: the phase and why, in days. For a date 24 days out, Transformación. Change it in
one tap and check the draft changes with it.

## C8 — The boundaries

Send three requests with competition dates at 15, 16 and 44 days out (the seed can place them).

**Expected**: Realización, Transformación, Acumulación. These are the days the derivation has
to get right; everything between them follows.

## C9 — No phase where the engine forbids one

Open a request from a swimmer in Iniciación or Tecnificación.

**Expected**: the draft carries no phase and says so. If a phase appears, the engine would have
rejected the request and the generation is going around its own validation.

## C10 — Rejecting without a reason

Try to reject a request leaving the reason empty.

**Expected**: it cannot be done. Then reject with a reason, sign back in as the swimmer, and
read it as it was written.

## C11 — Approving signs, it does not deliver

Approve a request whose draft passes the audit.

**Expected**: the request reads «Aprobada» and the plan is `aprobado`. The swimmer still has no
new session: delivering is the separate act in `Ver Plan`. Check the swimmer's `Home`.

## C12 — The minor's gate, and the discomfort that is not copied

With the swimmer who has no valid consent, answer the list and send.

**Expected**: nothing reaches the server — check the emulator, not the screen — and the app says
the guardian's authorisation is missing. Then grant consent and check it leaves without being
retyped.

Then, with a swimmer whose recent sessions hold a discomfort, open the request as the coach and
check the emulator:

**Expected**: the request document holds **no discomfort field at all**. What the coach saw came
from `registros`.

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

**Expected**: all green, and the Dart count does not go down. Any test from an earlier feature
that fails means this feature changed a behaviour it had no business changing: fix this
feature, not that test.

---

## Suggested order

1. The gates first, so a red test is not blamed on the app.
2. C1 to C5 as the swimmer.
3. C6 to C11 as the coach.
4. **C12 last and carefully**: it is the one that protects a minor, and it is the one that has
   to be checked against the server rather than the screen.
5. C8 again at the end, because a boundary is the first thing a refactor moves.

---

## What the walk actually found

Written down because the walk is the task, and a task whose result is not
recorded is a task nobody can learn from. Five defects came out of C1 to C12,
and **four of them were invisible precisely because the app kept working**.

| # | What was wrong | Why no test saw it |
|---|---|---|
| 1 | Nobody wrote the request's `estado` or `enviadaEn` | The reader defaults an absent state to `esperando` and an absent date to now. The queue would have shown "now" for a request sent three days ago |
| 2 | The queue did not reload after answering | The screen held the same list object the fake returned, so the test saw the change without a reload |
| 3 | Approving did nothing and said nothing | The draft was generated in memory and never saved, so `planId` was null and the server refused. The error went nowhere |
| 4 | A swimmer with no consent was told "Le llegó" | The fake reported "held" from the first load, so the assertion passed through the initial state rather than the send |
| 5 | `reintentarLoRetenido` was written, tested, and called by nobody | Unit tests cover the class; nothing covered that somebody calls it |

**Two of those tests were passing for the wrong reason**, and both started
failing as soon as the fake behaved like the real thing: returning a snapshot
instead of a live list, and holding only after a send instead of always.

That is the pattern worth carrying to feature 009: a fake that is more
convenient than the real collaborator does not make the test easier, it makes
it dishonest.

### And one more, which only the phone could say

C12 on the Pixel 7 found a sixth: **what was held did not leave, and could not
be made to.**

The gate reads consent from Firestore's local cache — by design, so it can
answer with no connection — so a guardian authorising on another device does
not change what the phone believes. On the web this was invisible, because
reloading the page rebuilds everything and the cache comes back fresh. On a
phone there is no reload: switching destinations keeps the screen alive in the
`IndexedStack`, and **even a full restart of the app did not release it**.

Meanwhile the notice promised «En cuanto autorice, sale sola», which was not
true.

So the retained notice now carries a button — «Ya autorizó mi acudiente» — and
the wording says to use it. The button is not a convenience: without it the
promise cannot be kept, and the person waiting is a minor whose request is
sitting in a phone.
