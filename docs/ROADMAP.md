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
| **011** Repairs to the swimmer's journey | The send that retries by itself, and the four defects the walks recorded | Merged |
| **012** The coach → swimmer relation | Each coach reads only his own swimmers, which is the door into the community area | Next |
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
was recorded rather than bolted on, and **it is now feature 011**. The checks
themselves — T071 here, T088 and T089 of feature 004 — stay open until after
feature 013, by the coach's decision: they are walked together, on a real device,
once there is more to walk in one trip.

## What 011, 012 and 013 carry

**They are three and not one, and that is principle VII, not taste.** Video and
community are two of the four product areas, and the principle forbids opening
them in parallel — for the reason it states itself: one person holds this up,
and four open fronts is the surest way to finish none. Closing the network
trigger is repair work on an area already built; the relation and the video each
open an area. So they go in that order, declared here.

### 011 — Repairs to the swimmer's journey

**Built, and the headline is the shape, not the fix.** Two of the four defects were the
same mistake: something correct, built, tested, and **never connected**.
`Sincronizador.alVolverLaRed` had a test and no listener, for seven features.
`ProgresoEnElMacrociclo.sinContestar` had the exact rule the pending list needed, had
tests asserting that done, refused and unanswered partition the past sessions, and
nothing in `lib/` ever called it. A green suite says nothing about whether a part is
fitted.

**The approach: the attempt is the probe.** Nothing is asked about the network any more.
The outbox keeps trying what is queued, and the result of trying is the only true answer
— it tests the whole path to the server rather than the first hop out of the phone. That
is what `estado_de_red.dart` had said the detection should be since feature 003, written
directly above a line that did the opposite: `sondear: () async => datos != null`, which
asks whether Firestore initialised and is true with the airplane on. The value never
changed, so the stream never emitted, so the trigger could never fire — and nothing
listened to it anyway. Two independent failures, either one sufficient.

Nothing is probed while the queue is empty, because there is nothing to attempt. The
cost, which the spec required as a number: **66 attempts in the first hour** with one
record queued and no network — six quick ones while the wait grows, then one a minute —
zero reads, zero billable operations, and zero of everything with an empty queue.

**No new dependency.** "Detect connectivity" is the sentence that ends in a connectivity
package, and the one it would answer is the wrong question: the OS knows whether an
interface exists, and a pool with wifi that does not reach the internet is the normal
case here. The refusal is checked by a gate, not remembered: `git diff` on the pubspec
must be empty.

**What the work found that the planning did not.** `EnvioPendiente`'s retry wait
**overflowed**: `1 << 64` is zero, so past about sixty-four attempts the wait became zero
seconds — the tight loop that code exists to prevent. It had been unreachable since
feature 003 precisely because nothing retried without the swimmer opening the app, and
the first simulated hour of this feature found it by hanging the suite. The gate in front
of the send also had to go rather than be rewired: with the attempt as the probe, a gate
that consults the probe before attempting deadlocks.

**Four existing tests encoded the defects and were inverted**, each with the reason
written where it happened. One of them justified itself with a comment contradicting the
documentation three lines above it in the production file. Another asserted that the
**consent gate is skipped** when there is no network; it now asserts the opposite, and
principle V is stronger for it.

**It removes the causes; it closes no scenario.** C1 and C2 of feature 003 and C7 and C8
of feature 004 — T071, T088 and T089 — are walked together after feature 013, by the
coach's decision. What a phone adds to C2 is the part no test reaches: a real radio, a
real airplane mode, and a real walk out of a building.

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

#### What was built

**Membership lives in one place**: `comunidadId` on the swimmer's own profile,
written only by the server. No `membresias` collection, no copy on records,
plans or requests — because the copy is the thing that cannot be unmade when a
membership ends, and ending one has to cut the reading immediately.

The relation is born in three steps the coach controls. He names his community
in Settings; she asks while creating her account, from a list that shows his
name; the request waits in the queue feature 008 already built, and **nothing
happens without his signature**. Meanwhile she uses the app normally and the
screen where her plan would be tells her where she stands.

**The boundary is the point.** The rule that said `esEntrenador()` now asks
whose swimmer this is, across six collections, and the test that asserted a
second coach could read the first coach's swimmer has been inverted — the
second time this product closes something it had declared rather than hidden.
The rules suite grew from 174 tests to 223.

**What the five rewritten queries cost.** Every query the coach makes used to
read a whole collection, which worked because any coach could read anyone.
Rules do not filter: a query is proved by its filters or refused entire. So all
five — his swimmer list, who has answered, who has a macrocycle, the request
queue, the assignments — now carry the list of his swimmers in their filters.
A sixth was found during the work, in `molestias_firestore.dart`, and it was
the worst of them: it swallowed its own failure, so with the boundary in place
it would have answered "nobody reported a discomfort" for ever, silently.

The cost is one query for "who are mine" plus one per batch of thirty, with no
caching — **two queries where feature 007's decision D10 bought one**, and a
full refresh makes eight where it made four. D10 existed to avoid N; this is
not N, and at this scale the trade is the same one the consent gate accepted in
feature 004.

**What is not closed**: `planes`. A plan carries no owner — only
`nadadoresIds`, empty in a draft, and a draft is exactly what its author must
be able to read — so the rule has nothing to ask, and giving plans an owner
means migrating documents that already exist. What leaks is the coach's
training design, not a fact about a swimmer: who was given which plan lives in
`asignaciones`, and that is closed. Her boundary is complete; his is half, and
the limitation is asserted in a test rather than left unsaid.

### 013 — Video

**What 012 hands it.** "Who may watch a swimmer's video" was a question with no
place to get an answer; now it has one. A video belongs to a swimmer, a swimmer
belongs to at most one community, and `esDeMiComunidad()` in
`firebase/firestore.rules` is the single predicate that answers it — the same
one the six tightened collections already use, so video does not invent a
seventh way of asking.

Three things 012 settled that video would otherwise have had to settle itself:
**membership lives in one place**, so revoking it cuts access to the video in
the next query rather than requiring a sweep; **a query is proved by its
filters**, so the listing of a swimmer's videos has to carry her id, the way
the other six now do; and **the consent gate composes rather than being
replaced** — `Alcance.video` still decides whether the file may exist at all,
and membership decides only who may watch one that may.

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
