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
| **008** The swimmer's request | A checklist that becomes a draft, the draft reaches the coach's queue, and nothing leaves without his signature | Planned |
| **009** Ver Plan and progression | Macrocycle and mesocycle, revealed as the swimmer completes sessions | Planned |
| **010** Análisis | The detailed journey, and asking the coach for feedback | Planned |

## What each of the later ones is waiting on

**009 is larger than it looks.** The domain has `Microciclo` and nothing above it:
neither `Macrociclo` nor `Mesociclo` exists. Section 18 of the methodology also
requires staged construction with the coach's confirmation between stages, so the
progressive reveal fits the methodology — but it has to be designed, not assumed.

**010 touches video**, which is out of scope today and carries its own consent
scope (`Alcance.video`, modelled in 004 precisely for this). Whether the feedback
request includes video, or stops at the request, is a decision for its spec.

**010 also has to finish something 007 started.** Records have been written to
Firestore since feature 003 and, until 007, nothing ever read them back:
`RegistrosLocales` reads the device's own store, so the coach only ever saw what
his own phone had written. The promise — "the coach reads it next to the session
that produced it" — held only when coach and swimmer shared a device, which is
exactly how it was tested. Feature 007 built `RegistrosFirestore` because a Home
number needed it; the coach's full reading of what his swimmers answer is the
`Análisis` that 010 brings, and it should start from that reader.

**The deferred manual checks** — T088 and T089 of feature 004, and C1/C2 of
feature 003 — close after 010. They need a real device and the coach's own eyes.

## Changing this file

The order is the coach's to change. Moving a feature changes what later specs can
assume, so the change belongs in a commit of its own, not inside a feature's work.
