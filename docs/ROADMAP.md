# Roadmap

Principle VII of the constitution says the four product areas — plans, progress,
video, community — are **not** built in parallel, and that "the order is declared in
the roadmap and respected". This file is that declaration.

It exists because the order was once agreed in conversation and nowhere else, and it
was lost. A roadmap that lives in a chat is not a roadmap.

## The order

| Feature | What it delivers | Status |
|---|---|---|
| **001** Plan editor and audit engine | Hybrid notation input, the eleven audit criteria, the `borrador → aprobado → publicado` lifecycle | Merged |
| **002** Deterministic microcycle generator | Eleven inputs in, a squared week out; same inputs, same plan; no language model | Merged |
| **003** The swimmer consumes the plan | Today's session offline, marked done, RPE, observations, discomfort apart, and the coach reads it | Merged |
| **004** Accounts, roles and verifiable guardian consent | Identity, the two roles, the consent gate that keeps a minor's data on the device until a guardian authorises | Merged |
| **005** Visual theme and component system | One place for colour, type, spacing and the repeated components; light and dark; measured contrast | Merged |
| **006** Account sign-up and consent at registration | Name, exact age and country in short steps; T&C accepted on the way in; the minor's guardian is asked for consent | Merged |
| **007** The HUB and the two journeys | Five tabs — `Generar`, `Ver Plan`, `Home`, `Análisis`, `Ajustes` — arranged per role, plus Home and the settings screen where a person governs their own account | Merged |
| **008** The swimmer's request | A checklist that becomes a draft, the draft reaches the coach's queue, and nothing leaves without his signature | Merged |
| **009** Ver Plan and progression | The macrocycle, confirmed once and delivered whole; the swimmer annotates it as they go, and a readjustment versions what changed | Merged |
| **010** Análisis | The detailed journey, and asking the coach for feedback | Merged |
| **011** Repairs to the swimmer's journey | The send that retries by itself, and the four defects the walks recorded | Next |
| **012** The coach → swimmer relation | Each coach reads only his own swimmers, which is the door into the community area | Planned |
| **013** Video | Uploading, watching and retention, on the consent scope modelled since 004 | Planned |

## What each of the later ones is waiting on

**009 turned out to be smaller than it looked, for one reason.** It was written
here as needing both `Macrociclo` and `Mesociclo`, since the domain had
`Microciclo` and nothing above it. Reading the code found that **a `Plan` is
already a mesocycle** — one ATR phase, several microcycles, its own lifecycle,
audit, version lineage and methodology stamp. The project had been building
mesocycles since feature 001 and calling them plans, so only the level above was
new.

The progressive reveal was dropped, and by the coach's own decision: the swimmer
gets the whole macrocycle from day one, because seeing the whole road is worth
more than the suspense of unlocking it. Section 18's staged construction was
revisited at the same time and the constitution was amended to v2.0.0 — what it
requires is the decision point, not the number of phases, and a deterministic
engine does not degrade over a long output the way a language model does. So one
confirmation remains, on the structure, and the rest derives.

**007 left something unfinished and 010 finished it.**
Records have been written to Firestore since feature 003 and, until 007, nothing
ever read them back: `RegistrosLocales` reads the device's own store, so the
coach only ever saw what his own phone had written. Feature 007 built
`RegistrosFirestore` because a Home number needed it.

Feature 009 closed the swimmer's half of that, because walking it on a phone
made the gap impossible to ignore: her screen read the device alone, so changing
phone or reinstalling set her count back to zero under a sentence promising the
opposite. `RegistrosDeLasDosPartes` now reads both sides, local winning, and
writing still never waits on the network. **What was left for 010 was the
coach's side**: his full reading of what his swimmers answer, which is the
`Análisis`.

**010 answered the video question, and shaped it rather than building it.** The
coach's decision on Q1 was to have everything ready now even though uploading is
not required yet: the request carries a `video` field, the server carries the
gate in front of it, and neither is reachable. The constructor refuses a non-null
video, the rule refuses a create that carries the key, and the interface never
mentions it — a test over every file in `lib/ui` keeps it that way. The reason is
the comment feature 004 left beside the consent scopes: discovering later that
video needs a scope of its own would mean asking every family again. That later
feature is 013: it removes two refusals and nothing else has to change.

**010 delivered the coach's side of the reading.** `Análisis` had carried a
`TodaviaNo(feature: '010')` since feature 007 — a bounded promise with the number
of the feature that would keep it written inside — and there is now no `todavía
no` left anywhere in the HUB. He reads what his swimmers answered beside the
session that produced it, from `registrosParaElEntrenador`, which is the server
reader and deliberately **not** `RegistrosDeLasDosPartes`: his device never wrote
her answers, so "local wins" has nothing to win with, and if it had something it
would be his own test records from feature 003 mixed into hers.

**What 010 declared missing, and did not invent: the coach → swimmer link.**
FR-024 originally said a coach reads only his own swimmers. There is no such
relation in the product — `Nadador` has no owner and the rule says
`esEntrenador()`, full stop — and the constitution describes a community led by
*a* coach, singular, so the rule is right for what exists. The requirement could
not be met, so it was amended with the reason recorded next to it, and
`firebase/test/reglas_analisis.test.js` carries a test that asserts a **second**
coach account reads the first coach's swimmer and **succeeds**, saying in its own
text why. The day a second coach exists, that test is the first thing that fails.

Closing it is a feature of its own — 012 — and it belongs with whatever first
needs more than one coach, the community area of principle VII. It was recorded
here the way feature 003's identity gap was recorded until 004 closed it.


**What the 010 walk found, and what it cost.** The walk on the Pixel 7 found
five defects before C1 was through, and none of them was reachable from a Dart
test — the same lesson feature 009 paid for. Three were 010's own and are fixed;
two belonged to earlier features.

The one worth repeating here, because it is the shape this project keeps
meeting: **every record that had reached the server was unreadable**.
`FieldValue.serverTimestamp()` writes `recibidoEn` as a `Timestamp` and the
deserialiser read it as a string, so the exception escaped up through
`registrosDelLinaje` and the swimmer's screen kept saying "0 de 39" with her
answer already in Firestore. The coach's `Análisis` reads through the same
repository, so it would have broken the moment anyone answered for real. The app
had already named this defect, mirrored, in `molestias_firestore.dart`.

The second: the HUB picked a swimmer's plan as **the last of her published
assignments**, which meant "the plan she was given" until feature 009 made every
mesocycle an assigned plan. It then became whichever the query returned last —
arbitrary, not merely wrong. Fixed with `elPlanDeAhora`: the plan that contains
today, then the next to start, then the last to have ended.

Left for 011, diagnosed in `specs/010-analysis-and-feedback/tasks.md`: the
pending list counts a session the swimmer answered with "I did not do it".
`ProgresoEnElMacrociclo.pendientes` excludes only `hechas`, and the class's own
documentation forbids exactly that conflation.

**The deferred manual checks, and what walking them cost.** C1 and C2 of feature
003 had been waiting since there was nowhere to deploy. Walking them found three
more defects, all one shape — **the Firestore SDK does not throw when there is
no network, it leaves the Future open**, and a `catch` cannot catch a Future
that never completes. Offline, `Ver Plan` spun forever with the plan sitting in
the device's own cache; marking a session spun forever with the record already
saved; and once the screen stopped waiting, two overlapping syncs sent the same
record twice.

So the rule, said whole: **what hangs on the network gets a deadline.** Reads
fall back to the device's cache on timeout and only on timeout — a
`permission-denied` still rises, because the cache does not go through the rules
and covering a refusal with it would turn a bad rule into a screen that works.
A short memory of a server that did not answer keeps a screen's chained reads
from each paying the wait. And the outbox's send has a deadline too, which makes
possible the probe `estado_de_red.dart` described from the beginning: "a write
is attempted and one sees whether it arrives".

C1 passes now. C2 passes through step 4. Step 5 — "restore the network and wait
without touching anything" — does not: the record arrives and the notice goes,
but only when the app is next opened. `Sincronizador.alVolverLaRed` exists, is
tested, and **nothing in `lib/` listens to it**; and the probe behind it could
not have fired anyway. Wiring it is a change with a decision inside it, so it
was recorded rather than bolted on, and **it is now feature 011**. T089 of
feature 004 — siblings on one phone, a session expiring poolside — is still open
and needs its own setup; it is 011's natural companion, since both are the
swimmer's journey on a real device.

## What 011, 012 and 013 carry

**They are three and not one, and that is principle VII, not taste.** Video and
community are two of the four product areas, and the principle forbids opening
them in parallel — for the reason it states itself: one person holds this up,
and four open fronts is the surest way to finish none. Closing the network
trigger is repair work on an area already built; the relation and the video each
open an area. So they go in that order, declared here.

### 011 — Repairs to the swimmer's journey

Everything the two walks found and left written down, and nothing else. No new
product surface: at the end of it the app does what it already promises.

**The network trigger, which is the one that matters.** The sync contract names
three triggers — on save, on network return, on app open — and the second was
never wired. `Sincronizador.alVolverLaRed` exists and is tested, and **nothing
in `lib/` listens to it**; it could not have fired anyway, because the probe
behind it is `sondear: () async => datos != null`, which asks "did Firestore
initialise?" and is true with the airplane on. So C2 of feature 003 stops at
step 5: the record does arrive and the notice does go, but only when the app is
next opened.

It was left for its own feature because it has a decision inside it — what to
probe, how often, and what that costs — and because `estado_de_red.dart` has
said from the beginning what the probe should be: "a write is attempted and one
sees whether it arrives". With the send bounded, that is finally possible.

And the three smaller ones:

- `ProgresoEnElMacrociclo.pendientes` counts a session the swimmer answered
  with "I did not do it". It excludes only `hechas`, and that class's own
  documentation forbids the conflation.
- `Mi progreso` says "Todavía no tienes un plan asignado" for the twenty
  seconds its plan takes to load offline — an empty state shown before the data
  has had its chance, and false while it says it.
- The pending notice can outlive the send. Firestore's own queue delivers the
  write our deadline stopped waiting for, so the server holds the record while
  the outbox still counts it pending. Nothing is lost or duplicated, the id is
  deterministic, but the sentence stays on screen after it stops being true.

Closing this closes **T071 of feature 003 and T088 of feature 004**, which have
been open since there was nowhere to deploy. T089 of feature 004 — siblings on
one phone, a session expiring poolside — is the natural companion of 011's walk,
since both are the swimmer's journey on a real device.

### 012 — The coach → swimmer relation

Feature 010 declared this missing rather than inventing it. FR-024 said a coach
reads only his own swimmers; there is no such relation in the product — a
`Nadador` has no owner and the rule says `esEntrenador()`, full stop — so the
requirement was amended with the reason recorded beside it, and
`firebase/test/reglas_analisis.test.js` carries a test asserting that a **second**
coach account reads the first coach's swimmer and **succeeds**, saying in its own
text why. That test is this feature's starting point: the day the relation
exists, it is the first thing that has to be rewritten, and until then it is an
honest description of what the product does.

It is the door into the community area of principle VII, which is why it comes
before video rather than after: a video belongs to a swimmer, and who may watch
it is a question with no answer until this exists.

### 013 — Video

Feature 010 shaped it and refused to build it, by the coach's decision on Q1:
the request already carries a `video` field, the server carries the gate in
front of it, and neither is reachable. The constructor refuses a non-null video,
the rule refuses a create that carries the key, and the interface never mentions
it — a test over every file in `lib/ui` keeps it that way.

`Alcance.video` has been modelled since feature 004 and used nowhere. That was
the point: the comment feature 004 left beside the consent scopes says that
discovering later that video needs a scope of its own would mean asking every
family again. This feature removes two refusals and activates a scope that is
already consented; it does not go back to the families.

What it still has to decide, and has not: where the files live, who pays for
them, how long a minor's video is kept and what deleting it means — which is
principle V's territory and the reason this is a feature and not a flag.

## Changing this file

The order is the coach's to change. Moving a feature changes what later specs can
assume, so the change belongs in a commit of its own, not inside a feature's work.
