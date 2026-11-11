# Quickstart: Análisis and feedback

**Feature**: 010 · **Date**: 2026-11-11

The walk that proves this feature works. **It runs on the Pixel 7 against the emulators,
not in a browser.** Feature 009's walk found seven defects in eight days and not one was
reachable from a Dart test; six had the same shape — the in-memory double is kinder than
Firestore, so the screen passed everything and failed on the phone.

## Before you start

```bash
npx firebase emulators:start --project demo-natacion --export-on-exit <dir>
```

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 node firebase/functions/tools/sembrar-emulador.js
```

```bash
flutter build apk --debug --dart-define=USAR_EMULADORES=true
```

**Four things wipe this walk and each one looks like an app bug.** They cost a day in
feature 009:

1. The rules suites call `clearFirestore()` per test against the same `demo-natacion`
   emulator the app uses. Running them mid-walk empties every collection.
2. `adb shell pm clear` drops the Dart code `flutter run` leaves in the app's data
   directory, so the app silently falls back to whatever APK is installed.
3. An APK built without `--dart-define=USAR_EMULADORES=true` talks to the **real project**,
   and signing in fails with "El correo o la contraseña no coinciden".
4. The emulators persist nothing without `--export-on-exit`.

Accounts: all share `clave-de-prueba-007`; coach `entrenador.verifica@ejemplo.test`,
swimmer `nadadora.verifica@ejemplo.test`.

---

## C1 — The coach reads what she answered, from his own device

1. As the coach, create and deliver a macrocycle for Ana.
2. Sign in as Ana **on the phone** and mark two sessions, one with an effort score and an
   observation.
3. Sign back in as the coach and open `Análisis`.

**Expected**: her two answers, each beside the session that produced it. He has never
used her device.

**Check in the emulator, not on the screen**: the records exist under her id and the plan
she was on. A screen that shows the right thing from the wrong source is the defect this
walk exists to catch.

---

## C2 — A swimmer who has answered nothing

Open a swimmer with no records.

**Expected**: a sentence saying she has not answered yet. **Not** an empty frame, and not
a spinner that never resolves.

---

## C3 — Discomfort stands apart

1. As Ana, mark a session and report a discomfort.
2. As the coach, open `Análisis` **without opening her yet**.

**Expected**: he can tell from the swimmer list that she reported something. Opening her,
the session is distinguishable before he expands it, and what he reads proposes nothing:
no severity, no suggested change, no next step.

**The failure this looks for**: a pain report sitting in the stream of observations. That
is the exact mistake principle VIII names twice.

---

## C4 — Internal and external, never merged

Open one session in the coach's reading.

**Expected**: the programmed work and her answer, each named. Scan the screen for any
third number derived from the two. There must be none.

---

## C5 — An answer survives a readjustment

1. With Ana's answers in place, readjust block 1 as the coach and deliver it.
2. Open her analysis again.

**Expected**: her answers are still there, attached to the sessions she swam.

**Why this one matters**: feature 009 found this twice on the swimmer's side — once
because the screen never called the lineage reader, and once because reading the lineage
needed a plan that was no longer hers. The coach's side reads the same lineage and can
read every version, so it should be simpler. Confirm that rather than assume it.

---

## C6 — She asks for feedback, offline

1. As Ana, turn on airplane mode.
2. Ask for feedback on a session she already swam.

**Expected**: the app accepts it and says so. Nothing waits on the network.

3. Turn the connection back on.

**Check in the emulator**: the request arrived, with her words, under the right session.

---

## C7 — She cannot ask about a session that has not happened

Open a session whose day has not arrived.

**Expected**: asking for feedback is not offered. Not offered and disabled — **not
offered at all**. A control that leads nowhere has been forbidden since feature 007.

---

## C8 — He sees it, and she can tell

1. As the coach, open her analysis and mark the request as seen.
2. As Ana, open that session.

**Expected**: she can tell he saw it, with no written answer arriving. That is the whole
of what the app promises here (Q2).

**Check in the emulator**: `vistaEn` is set and `pregunta` is byte-for-byte what she
wrote. If marking seen changed her question, the rule that restricts the update is not
doing its job.

---

## C9 — Nothing about video, anywhere

Walk the whole feature as both roles.

**Expected**: the interface never mentions video, never offers it, never hints it is
coming. The field exists in the model and the gate exists in the rules; neither is
visible, and that is deliberate — a control the app cannot honour is a promise it should
not make.

---

## C10 — The boundaries, checked on the server

Not on the phone. These run as rules tests, and each must fail when its rule is removed.

- She reads her own request; she cannot read another swimmer's.
- She queries hers filtering by swimmer **and** plan; filtering by plan alone is refused.
- The coach reads hers and cannot write her question.
- He sets `vistaEn`; setting `vistaEn` together with `pregunta` is refused.
- With consent revoked, she cannot create a request.
- A request carrying `video` is refused.
- Nobody deletes one.

**And one that states a limit instead of enforcing it**: a second coach account reads the
first coach's swimmer and **succeeds**. There is no coach→swimmer link in the product and
this feature does not invent one. The test asserts the current truth so that the day a
second coach exists, it is the first thing that fails.

---

## The four gates

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

CI runs all four plus the domain-boundary test, the methodology checksums and a web
build. Give the checks a moment to register before reading their status — reading too
early shows zero passing and zero failing, which is not the same as no CI.
