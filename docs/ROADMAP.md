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
video needs a scope of its own would mean asking every family again. A later
feature removes two refusals and nothing else has to change.

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

Closing it is a feature of its own, and it belongs with whatever first needs more
than one coach — the community area of principle VII. It is recorded here the way
feature 003's identity gap was recorded until 004 closed it.


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

Left for next, diagnosed in `specs/010-analysis-and-feedback/tasks.md`: the
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
not have fired anyway. Wiring it is a change with a decision inside it, so it is
recorded in `specs/010-analysis-and-feedback/tasks.md` rather than bolted on
here. T089 of feature 004 — siblings on one phone, a session expiring poolside —
is still open and needs its own setup.

## Changing this file

The order is the coach's to change. Moving a feature changes what later specs can
assume, so the change belongs in a commit of its own, not inside a feature's work.
