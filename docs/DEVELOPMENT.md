# Development

Swimming training-plan app built on the coach's methodology, documented in
[`docs/metodologia/`](metodologia/).

The app does not interpret the methodology: **it verifies it**. A plan that
breaks the no-invention rule, the per-category volumes or the ATR distributions
cannot be approved.

> The methodology documents and the feature documents under `specs/` are in
> Spanish, and stay that way: they quote the coach's normative document, and
> translating them would break traceability to it. See the language note in
> [`CONTRIBUTING.md`](../CONTRIBUTING.md).

## What is built

- **Deterministic microcycle generator**: the coach declares category, ATR phase,
  target stroke, the week's accentuated component, days and pool length, and the
  app returns the whole week already squared — volume within the category range,
  the phase's zone distribution, technical percentage, stroke split, and only
  exercises from the official Library. Same inputs, same plan. Offline and free:
  the composition comes from coded rules, not from a language model.
- **If the data is insufficient or contradictory, it generates nothing**: it
  explains what is missing or why it is impossible, with concrete numbers, and
  leaves nothing half-built.
- **Session editor with hybrid input**: the coach writes in his usual notation
  (`4x100 AL SNK PN / 2'`) and the app immediately shows what it understood in
  editable fields. What he corrects by hand wins over the automatic reading.
- **Notation parser** that never throws: when it does not understand something it
  returns partial results and flags the fragment with its exact position.
- **Audit engine** with the eleven criteria of section 16 — four blocking, seven
  justifiable.
- **Plan lifecycle**: `borrador` → `aprobado` → `publicado`. Approving stamps the
  methodology version; an approved plan is immutable.
- **Swimmer profiles** and plan assignment.
- **The swimmer consumes the plan**: they open the app at the poolside, see
  today's session, mark it done, record their RPE and observations, and report
  discomfort in a field of its own. The coach reads all of it next to the
  session that produced it, with external load and internal load side by side
  and never merged into one number.
- **It works with no signal.** Reading the plan, today's session and your own
  progress never waits for the network. Writing offline is kept on the device,
  the app says so, and it goes out on its own when the connection returns.

## Working offline

The split is deliberate, and documented in
[`specs/003-consumo-del-nadador/research.md`](../specs/003-consumo-del-nadador/research.md):

| | Mechanism |
|---|---|
| **Reading** plans and sessions | Firestore's cache. Reimplementing a read cache would be wasted work |
| **Writing** the swimmer's records | An **outbox of our own**, in the domain |

Writing is not delegated to Firestore's offline queue for three reasons: it could
not be tested without testing Firebase, it gives no control over the idempotency
FR-020 needs, and it would make "pending" a reflection of a database detail
instead of a domain concept.

One thing worth knowing rather than discovering later: **offline reading only
covers what was downloaded at least once.** A swimmer who never opened the app
with a connection has nothing to read. The promise the feature keeps is that
once the plan has been obtained, consulting it never needs the network again —
which is why the UI shows when it last synced.

To verify it:

```bash
flutter test test/dominio/sincronizacion/bandeja_salida_test.dart
```

Those are the eight guarantees of the synchronisation contract, in pure Dart with
the network and the clock faked. The swimmer's journey with the network down is
in `test/ui/nadador/`.

**Neither replaces checking it by hand on a real device in flight mode.** A
network emulator is not a swimming pool.

## Requirements

All verified on the development machine:

| Tool | Version |
|---|---|
| Flutter | 3.44+ |
| Dart | 3.12+ |
| Node | 20+ (rules tests only) |
| Firebase CLI | 15+ (rules tests only) |
| Java | 17+ (required by the Firestore emulator) |

## Getting started

Install dependencies:

```bash
flutter pub get
```

Run the app in the browser:

```bash
flutter run -d chrome
```

With local emulators, in two terminals:

```bash
firebase emulators:start --project demo-natacion
```

```bash
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

`demo-natacion` is a dummy project id. The emulators accept it without anything
existing in the cloud, so there is no risk of carelessly writing into a real
project. The flag defaults to false on purpose.

That one command starts all of them: Firestore on 8080, Authentication on 9099,
Functions on 5001, and the emulator UI on 4000. Accounts and the consent gate
need all three — Authentication because the rules read the role from the token,
and Functions because the server is what signs that role and dates a consent.

Server dependencies install separately, since the functions have their own
package:

```bash
npm --prefix firebase/functions install
```

### The first coach

Nobody can grant themselves the coach role. Every account is created as a
swimmer, and `entrenador` is only ever set by an administrative call that the
app cannot make. To promote the first one, with the emulators running:

```bash
npm --prefix firebase/functions run asignar-rol -- <uid> entrenador
```

Against a real project the same script needs credentials that are never stored
in this repository. This is deliberate friction: the role that approves and
publishes training for minors should not be a checkbox on a sign-up form.

## Tests

Domain, UI and the architecture boundary:

```bash
flutter test
```

Static analysis, which must come out clean:

```bash
flutter analyze
```

Firestore security rules, with their negative cases:

```bash
npm --prefix firebase test
```

The server, against the Authentication and Firestore emulators:

```bash
npm --prefix firebase/functions test
```

Normative document checksums — fails if one changed without bumping the
manifest version:

```bash
dart run tool/verificar_metodologia.dart
```

## Layout

```text
lib/
├── dominio/      Pure Dart. No Flutter, no Firebase. All the rules.
├── datos/        Firestore, in-memory, bundled assets and export.
└── ui/           Screens.

firebase/         Security rules, emulator config and their tests.
docs/metodologia/ Normative source of the domain.
specs/            Specification, plan and tasks for each feature.
tool/             Utilities: Library extraction, Excel reading, checks.
```

A test watches that `lib/dominio/` imports neither Flutter nor Firebase. That is
principle II of the constitution, turned into something the system verifies
instead of something somebody has to remember.

## Regenerating the exercise Library

The Library is extracted from section 19 of the normative document:

```bash
dart run tool/extraer_biblioteca.dart
```

The result **must be reviewed by the coach** before it is taken as valid: a
mistranscribed exercise is a misapplied rule.

## The coach's diagnosis vocabulary

When the coach declares a technical fault, the generator picks the corrective
exercise through the **term index** in
[`assets/biblioteca/terminos_diagnostico.json`](../assets/biblioteca/terminos_diagnostico.json):
every way he names a fault, and the exercises that correspond to it in his order
of priority. He confirmed each correspondence one by one; the record is in
[`docs/metodologia/correspondencia_diagnostico.md`](metodologia/correspondencia_diagnostico.md).

The entries are in Spanish because they are his own words, exactly as he writes
them at the poolside.

What the index tolerates and what it does not:

- `patada desde rodillas` and `patada desde las rodillas` are the same thing.
  Articles, accents and capitals decide nothing.
- `no gira la cadera` and `gira la cadera` are **not** the same thing. The
  negation is never discarded: they are opposite faults.
- `patada` on its own is not enough. It is too generic to pick a corrective, and
  it is reported as a gap.
- **There is no letter-similarity matching.** That tolerance would match
  `patada` with `brazada` before it matched `dosiflexión` with `dorsiflexión`.
  Both spellings of that word are declared as entries of their own.

A phrase that is not in the index is reported as a Library gap. The session's
technical block is then filled from the section 15 progression — a session
cannot be left without technique — but **never** with an exercise picked by eye
for that fault.

The index does **not** modify section 19. The prose of the «error que corrige»
field stays untouched, so the methodology version does not change and approved
plans keep their traceability.

To check what the app finds for any phrase:

```bash
dart run tool/probar_diagnostico.dart "codo bajo" "dosiflexion"
```

To see the full catalogue with its fault field:

```bash
dart run tool/probar_diagnostico.dart --vocabulario
```

## Deploying

**Not done yet, and it cannot be until a Firebase project exists for this
app.** What follows is everything needed, in order.

### 1. A project of its own

This app has no Firebase project. Deploying it into one that belongs to a
different product would, among other things, overwrite that product's
Firestore security rules — so it needs its own:

```bash
firebase projects:create
```

Cloud Functions require the Blaze plan. That is a billing decision, not a
technical one, and it belongs to whoever owns the account.

### 2. Point the repository at it

```bash
firebase use --add
```

This writes `firebase/.firebaserc`, which records the project id. The id is
not a secret.

### 3. Give the app its configuration

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart`. Without it the web app has no way
to reach the project, which is exactly the failure fixed in PR #5: it boots
and says it is in local mode, because there is nobody to authenticate against.

The file holds a web API key. That key is **not** a credential — it identifies
the project to Google and is visible in any Firebase web app. What protects the
data is the security rules in `firestore.rules`, which is why they are tested
the way they are.

### 4. Deploy, rules and server first

```bash
npm --prefix firebase/functions ci
flutter build web --release
firebase deploy --project swimming-app-ab45f --only firestore:rules,functions,hosting
```

Rules and functions before hosting, deliberately: the gate has to be in place
before there is an app that can write through it.

### 5. The first coach

Every account is created as a swimmer. Promote the coach's own account once,
as described under "The first coach" above, this time against the real project
rather than the emulators.

### 6. Verify on a real device

Two scenarios cannot be checked in a desktop browser, and both involve
children: siblings sharing a phone, and a session expiring at the poolside
with no signal. They are C7 and C8 of
[the feature 004 quickstart](../specs/004-cuentas-y-consentimiento/quickstart.md),
plus C1 and C2 of
[the feature 003 one](../specs/003-consumo-del-nadador/quickstart.md), which
have been waiting for somewhere to deploy to.

### Before any real swimmer uses it

The informative consent text in `assets/consentimiento/texto_v1.md` says in its
own first lines that it has not been reviewed by a lawyer. It should be, along
with the declaration the guardian signs and the record that the minor was
heard, before a single family sees it.

## Governance

The project is governed by
[`.specify/memory/constitution.md`](../.specify/memory/constitution.md). Every
feature follows the Spec Kit flow: `/speckit-specify` → `/speckit-plan` →
`/speckit-tasks` → `/speckit-implement`.

How work lands in this repository, and the language split: see
[`CONTRIBUTING.md`](../CONTRIBUTING.md).
