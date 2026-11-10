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
- **Accounts, roles and verifiable guardian consent**: a minor's data stays on
  their device until their guardian authorises it, through a link the guardian
  opens without an account of their own. The gate is enforced in the security
  rules, not on a screen.
- **Sign-up asks who you are**: name, exact birth date and country, in short
  steps. The terms are accepted on the way in, and the version each person
  accepted is kept — changing the text never rewrites what somebody accepted.
  When the age says minor, the app asks for the guardian's email and explains
  what it is for.
- **One visual system**: colour, type, spacing and the repeated components live
  in one place, light and dark, with measured contrast.
- **The HUB and the two journeys**: five destinations — `Generar`, `Ver Plan`,
  `Home`, `Análisis`, `Ajustes` — the same bar for the coach and the swimmer
  with different content inside, and a portada that answers "how am I doing".
- **Each person governs their own account**: in `Ajustes` they see and correct
  their data, read the version of the terms they accepted, change their
  password through their verified email, and exercise the three rights Ley 1581
  grants them — to know what is stored, to take it, and to have it erased.

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
│   └── hub/      Which content each role gets, in each destination.
├── datos/        Firestore, in-memory, bundled assets and export.
└── ui/
    ├── hub/      The bar, the two Homes, and the wiring to screens.
    ├── ajustes/  Where a person governs their own account.
    └── …         The rest of the screens.

firebase/         Security rules, emulator config and their tests.
docs/metodologia/ Normative source of the domain.
specs/            Specification, plan and tasks for each feature.
tool/             Utilities: Library extraction, Excel reading, checks.
```

A test watches that `lib/dominio/` imports neither Flutter nor Firebase. That is
principle II of the constitution, turned into something the system verifies
instead of something somebody has to remember.

## Running against the emulators

```bash
firebase emulators:start --project demo-natacion
```

```bash
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

On the Android emulator, launch the device first (`flutter emulators --launch Pixel_7`) and
run with the same define.

**This did not work until feature 007**, and it is worth knowing why: only Firestore was ever
pointed at the emulator. The identity was not, so signing in went to the real project with
the emulator's dummy options and failed with `api-key-not-valid` every time. Since accounts
exist — feature 004 — anything involving a session had to be verified by deploying.

Three things make it work, and each is a trap on its own:

- **The host depends on where the app runs.** On the Android emulator, `localhost` is the
  emulated phone itself; the machine running the emulators is `10.0.2.2`. `hostEmulador` in
  `lib/datos/firestore/configuracion.dart` decides it. On a real phone over cable neither
  works: put the laptop's address on the local network.
- **The emulators listen on `0.0.0.0`** (`firebase.json`), or the emulated phone cannot reach
  them. They are reachable on the local network while they run; the data is a fake project's,
  but do not leave them up on somebody else's network.
- **Android has blocked cleartext HTTP since Android 9**, and the emulators speak HTTP. It is
  allowed in `android/app/src/debug/AndroidManifest.xml` only, so the build that reaches a
  swimmer still blocks it.

## The HUB and the two journeys

Five destinations, in this order, with `Home` in the centre: `Generar`,
`Ver Plan`, `Home`, `Análisis`, `Ajustes`. **The bar is the same for both
roles.** What changes is what is inside.

Which content each role gets is **not decided in a screen**. It is a total
function in `lib/dominio/hub/destino.dart`:

```dart
QueHay reparto(Destino destino, Rol rol)  // Contiene(…) or TodaviaNo(…)
```

That is why "no content of the other role shows up in a journey" is something a
pure-Dart test proves without painting anything, and why only the journey of
whoever signed in is ever built. What came before was two parallel lists walked
with one shared index, carrying its own warning in a comment: that is how you
end up showing the editor when somebody taps «Mi progreso».

### Adding a destination's content

1. Add the identifier to `Contenido`, in the domain.
2. Give it to a role in `reparto`. The function is total: every destination and
   every role returns either content or an explicit `TodaviaNo`.
3. Map the identifier to a widget in `lib/ui/hub/contenidos.dart`. **That is the
   only place in the project where a content becomes a screen.**
4. Add the screen to `test/ui/tema/ayuda_pantallas.dart`, with realistic
   content.

A destination whose content arrives in a later feature says so in one sentence
and has **no tappable control** — not even a disabled one as a hint of what is
coming.

### The bar on a narrow phone

Five Spanish labels need about 500 px: «Ver Plan» alone wants 100 px at the
13 px label, which is the floor feature 005 declared because some of the people
reading this are nine years old. Phones are 320 to 430 px wide.

So below 500 px **the bar gives up its labels, not the words**: it shows icons,
and the name of the current destination is the screen's title, in full and at
reading size. `test/ui/hub/etiquetas_caben_test.dart` measures it by comparing
what each label is painted at against what it would need unconstrained — which
is the only way to catch a label that ellipsises silently.

## The swimmer's request

A swimmer answers six questions and the coach gets a draft he did not type.
Added by feature 008; the whole shape of it comes from one finding.

### Why the list is six questions and not eleven

Section 5 of `PROMPT_MAESTRO_V3.4` lists eleven inputs that must exist before
anything is generated, and `PeticionGeneracion` asks for the same ones. Cross
them with who actually knows each:

| Input | Where it comes from |
|---|---|
| Category | The swimmer's record. The coach assigns it |
| Target stroke, target event | The record, and the swimmer confirms or changes them |
| Technical diagnosis | The record. These are errors the coach observed |
| ATR phase, accentuated component | **Derived.** Nobody can ask a swimmer for these |
| Days, session duration, pool length | The swimmer |
| Competition date | The swimmer. A fact, not a judgement |
| Dates with no service | The club |
| Injuries or discomfort | **Their recent sessions**, never a new question |

So the swimmer answers five and confirms two. Asking for the rest would be
asking them to have an opinion on what is not theirs, which is principle IV in
its most direct form: here the request comes from below.

### Where the draft is generated, and why it matters

**On the coach's device, when he opens the request.** Not on the swimmer's, and
not on the server.

Not on the swimmer's, because FR-013 says they must not see the draft before
the signature. If their phone generated it, the plan would be sitting in their
storage and "cannot see it" would be a property of which screen is shown.

Not on the server, because that would mean reimplementing the generator, and
the generator *is* the methodology. Two copies of it are two methodologies.

A consequence worth knowing: a request nobody opens leaves no draft anywhere.
That is also the honest state of affairs.

### The phase derivation

`lib/dominio/peticiones/fase_por_fecha.dart`. Counting back from the
competition date, using the block durations section 12 of the methodology cites
(Issurin 2010):

| Days until the competition | Phase |
|---|---|
| 1 to 15 | Realización |
| 16 to 43 | Transformación |
| 44 or more | Acumulación |
| 0, past, or none | **No phase.** The coach sets it |

The boundaries are the **upper** bound of each published window. With lower
bounds, a swimmer ten days out would land in Transformación, inside the
published taper window, which is the error that costs a competition. Confirmed
by the coach on 2026-11-02.

The derived phase travels into the draft **with its reason written out**
("Transformación, porque la competencia es en 24 días") and the coach changes
it with one tap. A derived phase that could not be seen or corrected would be
judgement delegated through the back door.

### `peticionesDePlan`, deliberately not `solicitudes`

`solicitudes` already exists: it holds the **consent requests** of feature 004,
the ones a guardian redeems with a token. Two different things under one name
in the same database is how a rule gets written against the wrong collection,
and these rules guard a minor's data.

The document id **is the swimmer id**. That is what makes "one open request at
a time" a rule the server enforces: with a random id, no Firestore rule could
count the open ones and the limit would live only in the screen. A closed
request is overwritten by the next one, and the server archives the old one to
`historial` first.

Two things that caught us out, both worth remembering:

- A `set()` over an existing document is an **update**, not a create. The
  one-at-a-time rule has to cover both.
- **Deleting a document does not delete its subcollections.** A request's
  `historial` outlives the request. It is why `suprimirDatosDe` deletes the
  history explicitly before the request itself.

### Discomfort is read, never copied

`LectorDeMolestias` has no write method, and that is the point. The coach sees
what the swimmer already reported in their sessions, read where it already
lives, inside a four-week window: a number the coach chose and the methodology
does not fix. The request stores nothing about it.

When the window holds none, the queue says so out loud. A blank space reads as
"nothing hurts", and that is an assertion this app cannot make.

## The macrocycle and the mesocycle

**A `Plan` is a mesocycle.** Read that first, because the code has been saying
it since feature 001 without using the word: one `faseAtr`, several
`microciclos`, their sessions, start and end dates, the `borrador → aprobado →
publicado` lifecycle, `versionAnteriorId` with `crearVersionDesde`, the
section 16 audit, and the methodology stamp. A plan with one ATR phase and
several microcycles **is** a mesocycle.

So feature 009 added the level **above** it, not the level inside it.
`Macrociclo` holds references — plan ids, in order — plus the structure the
coach confirmed. The sessions live in its mesocycles. `Plan` gained two
nullable fields, `macrocicloId` and `ordenEnElMacrociclo`, and nothing else.

That matters beyond vocabulary. FR-031 says the mesocycle is the unit that
receives a new version when the coach readjusts, and that lands on the type
which already has versioning, tested since feature 001. Building a parallel
`Mesociclo` would have meant rebuilding a lifecycle, an audit, an assignment
path, an immutability rule and a version lineage for the exact unit that
already had all five.

### The single confirmation

Constitution v2.0.0 restated principle IV: what it requires is the decision
point, not the number of phases. Section 18's six confirmations exist because
a language model's accuracy degrades over a long output, and a deterministic
engine does not degrade.

So there is **one** confirmation, and it is in
[`lib/ui/macrociclo/estructura.dart`](../lib/ui/macrociclo/estructura.dart). The
coach supplies the two things no formula derives — the event model and the
swimmer model, steps 2 and 3 of section 4 — over a temporal skeleton the app
proposes. Below that, `derivarMacrociclo` drives the feature 002 engine once
per microcycle and nothing else is asked.

Two rules guard it, and both would break silently:

- **Nothing is stored before he confirms.** The lock looks at the
  repositories, not at the screen
  (`test/dominio/macrociclo/nada_se_guarda_antes_test.dart`). A convenient
  preview that cached a draft would break it with nothing failing.
- **The two models are never derived.** No file in
  `lib/dominio/macrociclo/` may even name them; what the app offers back comes
  from `lib/ui/macrociclo/sugerencias.dart`, which reads only the swimmer's
  own record — technical diagnosis, target event, marks — and nothing else.

### Marking what was done

The rule is about the date, not the order
([`puede_marcarse.dart`](../lib/dominio/macrociclo/puede_marcarse.dart)). A
session whose day has not arrived cannot be marked; one that has passed can
always be marked, whatever happened before it, and what is outstanding is
**shown, not enforced**.

The reason is section 4's step 8. Readjustment runs on adherence data, so a
rule that stopped a swimmer recording a session they actually swam would make
the app lie, and the readjustment would be modelling a fiction.

The lock lives where the record is built, not in a widget: "by any path" means
the record of a future session never comes into existence. There is a server
backstop on `registros` as well, which does not opine when the session document
carries no readable date.

And "no la hice" is not the same absence as "no contesté". The first is data —
the swimmer was there and said what happened. The second is the lack of it, and
can mean they forgot, had no signal, or stopped opening the app.
`ProgresoEnElMacrociclo` keeps them apart because that difference is what the
coach's readjustment reads.

### Readjustment

Each mesocycle the coach marks gets a new version through the existing lineage,
in one act, with one notice to the swimmer however many moved. The new versions
are born as drafts: they pass the audit and carry his signature before they
reach anyone.

**The macrocycle is not signed again.** Putting a delivered macrocycle back
through signing returns it to `aprobado`, which is going backwards in the
lifecycle, and the rules refuse it — what he signed then is still signed. What
gets signed is the new mesocycle versions, by
[`firmarYEntregarElReajuste`](../lib/dominio/macrociclo/reajuste.dart).

What the swimmer already recorded is never touched, copied or renamed.
`registrosDelLinaje` finds it by reading backwards along `versionAnteriorId`.
Copying the records forward would duplicate what they wrote and the coach would
read adherence over the double; rewriting them is what FR-035 forbids outright.

### One trap worth knowing

`copiarCon` resolves every field as `nuevo ?? this.campo`, so passing null means
"leave it alone", not "clear it". A line like `sesion.copiarCon(id: null)`
**looks** like it strips the identifier and does not. That reading cost feature
009 a wrong diagnosis: the plan recorded that `crearVersionDesde` renamed every
session and orphaned the swimmer's records, and it never did. It is pinned now
in `test/dominio/entidades/plan_mesociclo_test.dart`.

## The visual system

Everything the app looks like is decided in `lib/ui/tema/` and nowhere else.

```text
lib/ui/tema/
├── paleta.dart        The raw colours. Light and dark.
├── tipografia.dart    The type scale, on the system font.
├── espaciado.dart     Spacings, radii, tap target and icon sizes.
├── avisos.dart        The four notice tones, as a ThemeExtension.
├── tema.dart          Builds both ThemeData from the tokens above.
└── dominio/           Where the methodology meets the screen:
    ├── escala_de_zonas.dart    the seven intensity zones
    └── estados_de_plan.dart    draft, approved, published

lib/ui/componentes/    The repeated pieces, decided once.
```

### Three rules the tests enforce

**`paleta.dart` is the only file in the project allowed a colour literal.**
`test/ui/tema/frontera_tema_test.dart` reads the source of `lib/` and fails,
naming file and line, on any `Color(0x…)` or `Colors.whatever` outside it. The
same test does it for font sizes outside `tipografia.dart`.

This is not purism. A colour written into a screen is a colour that does not
adapt to dark mode, that nobody checks for contrast, and that you have to go
hunting for to change. With one place, changing the app's identity is changing
one file — and dark mode came out right by construction, with no screen touched.

**The error colour belongs to two screens only.** Sign-in and consent
confirmation. `test/ui/tema/avisos_test.dart` enforces it. Before this system
the app had 34 uses of the error family out of 54 semantic colour uses: it
painted everything that asked for attention red, and a red that always shows up
stops meaning anything. Anything that needs attention without something having
broken takes the **care** tone; anything that only informs takes **informative**.

What that test forbids is **applying** the colour. Saying `TonoDeAviso.error` on
a notice is allowed anywhere, because that is the sanctioned way to report a
failure and the colour for it is still applied in `lib/ui/tema/`. Feature 007
had to make that distinction explicit: as written, no new screen could report a
failure at all. And it is a failure that earns the tone — the delete button in
`Ajustes` is deliberately not red, because asking for an erasure is not a
failure.

**A component takes its measurements, it does not decide them.**
`test/ui/tema/componentes_test.dart` fails on a literal measurement inside
`lib/ui/componentes/`. If a component needs a value that is not in the tokens,
**the token is what is missing** — add it to `espaciado.dart`, not to the
component.

### Writing a screen

Read colours from `Theme.of(context)`, or from `context.colores` for the ones
Material does not have (the four tones, the seven zones, the three plan states).
Reach for `lib/ui/componentes/` before writing a card, a field, a button, a
notice, a section header or an empty state.

Two measurements run against every screen and will fail your change if you
break them: the whole app is opened at 200% text scale on a 360×640 phone and
must not overflow (`tamano_de_letra_test.dart`), and every tappable area must
reach 48×48 (`area_pulsable_test.dart`). Both read their list of screens from
`test/ui/tema/ayuda_pantallas.dart` — **add yours there**, with realistic
content. A bench only measures the paths it builds.

## Who is a minor

One place decides it: `lib/dominio/cuentas/edad.dart`. Everything else asks.

That sounds like tidiness and is not. Two things could answer the question —
the birth date, which feature 006 introduced, and the declaration feature 004
stored — and two answers eventually disagree. Disagreeing here means **not
asking for a consent that was needed**, which a family pays for, not us.

The order is: birth date if there is one, declaration if there is not, and
**minor if there is neither**. That last step is not decoration. The mistake of
asking for a consent that was not needed can be undone; the other one cannot.

A boundary test (`test/dominio/cuentas/un_solo_sitio_test.dart`) fails if any
other file calculates it, and a second one
(`test/dominio/frontera_edad_test.dart`) fails if age reaches
`dominio/generacion/`, `metodologia/`, `auditoria/` or `calculo/` at all.
**The category is declared by skills, never by age** (methodology section 11.1):
a nine-year-old and an adult can both train in Iniciación, and the app is not
there to contradict that.

### The guardian's path

A guardian has no account and is not going to make one to say yes. So:

- the server emails a link carrying a single-use token;
- `/consentimiento?t=…` opens the consent form **without a session** —
  `tokenDelEnlace` reads it before anything else in `main.dart`;
- the form calls `canjear`, which records the consent.

Two refusals are deliberate. Without a server, the page says so instead of
showing a form that would do nothing. Without the informative text, it refuses
too: authorising without reading what you authorise is not informed consent.

**Never log the notice body.** It carries the token, which is the credential
that authorises processing a minor's data. Writing only its hash to Firestore
protects the database; logging the plaintext hands it back.

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
