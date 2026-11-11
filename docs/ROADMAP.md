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
| **010** Análisis | The detailed journey, and asking the coach for feedback | Planned |

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

**010 touches video**, which is out of scope today and carries its own consent
scope (`Alcance.video`, modelled in 004 precisely for this). Whether the feedback
request includes video, or stops at the request, is a decision for its spec.

**010 still has to finish something 007 started, but less of it than before.**
Records have been written to Firestore since feature 003 and, until 007, nothing
ever read them back: `RegistrosLocales` reads the device's own store, so the
coach only ever saw what his own phone had written. Feature 007 built
`RegistrosFirestore` because a Home number needed it.

Feature 009 closed the swimmer's half of that, because walking it on a phone
made the gap impossible to ignore: her screen read the device alone, so changing
phone or reinstalling set her count back to zero under a sentence promising the
opposite. `RegistrosDeLasDosPartes` now reads both sides, local winning, and
writing still never waits on the network. **What is left for 010 is the coach's
side**: his full reading of what his swimmers answer, which is the `Análisis`,
and it should start from that same reader.

**The deferred manual checks** — T088 and T089 of feature 004, and C1/C2 of
feature 003 — close after 010. They need a real device and the coach's own eyes.

## Changing this file

The order is the coach's to change. Moving a feature changes what later specs can
assume, so the change belongs in a commit of its own, not inside a feature's work.
