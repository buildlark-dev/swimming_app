# Feature Specification: Análisis and feedback

**Feature Branch**: `010-analysis-and-feedback`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "Análisis. El entrenador lee lo que sus nadadores respondieron, junto a la sesión que lo produjo: esfuerzo percibido, observaciones y las molestias aparte, y cómo va su adherencia. Hoy esa lectura no existe: la pestaña está en el HUB desde la 007 y los registros se escriben en Firestore desde la 003, pero durante mucho tiempo nadie los leyó de vuelta. La 009 cerró la mitad del nadador con RegistrosDeLasDosPartes —su teléfono y el servidor, ganando lo local— y falta la del entrenador, que debe partir de ese mismo lector y no de los registros del dispositivo. El nadador, por su parte, puede pedirle feedback sobre una sesión concreta, y el entrenador lo ve donde ya mira. El vídeo queda fuera del alcance: su consentimiento está modelado desde la 004 (Alcance.video) y no se usa todavía, así que esta spec decide si la petición de feedback lo contempla o se queda en la petición. Lo que se muestra son datos de menores: cada entrenador ve solo a sus nadadores, y ni nombres ni marcas salen en registros ni en analítica. La adherencia y el progreso ya se calculan en el dominio desde la 009 y no se vuelven a calcular aquí. Cada lectura dice bajo qué versión de metodología se construyó lo que muestra. El vocabulario visible sigue en español."

## Why this feature exists

The methodology closes a loop: diagnose → model → programme → **control** → readjust.
The product has built every step except control. The swimmer has been able to answer
since feature 003 — did it, perceived effort, observations, discomfort apart — and those
answers have been written to the server ever since. Nobody has ever read them back to
the coach.

The app says so out loud today. The coach's `Análisis` tab is a placeholder that
promises: *"Aquí verás lo que tus nadadores han hecho: qué cumplieron, qué anotaron y
cómo sintieron el esfuerzo."* This feature is that sentence.

It is also the last thing standing between the project and a real swimmer. The
constitution is explicit: **a record nobody reads is not control**, and the readjustment
the methodology demands needs data the coach's flow does not currently gather.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The coach reads what his swimmers answered (Priority: P1)

The coach opens `Análisis` and sees his swimmers. He picks one and gets that swimmer's
sessions, newest first, each showing what she answered: whether she did it, her perceived
effort, and what she wrote. Next to each answer is the session that produced it — what
had been programmed — so he can read her response against the work, not in isolation.

**Why this priority**: It is the whole reason the feature exists, and the one thing the
constitution names as missing. Everything else here is refinement of this.

**Independent Test**: Sign in as a coach whose swimmer has answered sessions on another
device, open `Análisis`, and read those answers beside the sessions that produced them.
Delivers the control step on its own, with nothing else from this feature built.

**Acceptance Scenarios**:

1. **Given** a swimmer who answered three sessions from her own phone, **When** the coach
   opens her analysis, **Then** he sees those three answers, each beside the session it
   belongs to, without having used her device.
2. **Given** a session she marked as not done, **When** the coach reads it, **Then** it
   reads as not done rather than as missing — a skip the swimmer declared is information,
   an absence is not.
3. **Given** a swimmer who has answered nothing, **When** the coach opens her analysis,
   **Then** he is told she has not answered yet, and is not shown an empty frame he has to
   interpret.
4. **Given** a session whose block was readjusted after she answered it, **When** the
   coach reads it, **Then** her answer is still there, attached to the session she
   actually swam.

---

### User Story 2 - Discomfort stands apart (Priority: P1)

A discomfort or pain report does not sit in the stream of observations. It is marked
apart, it is visible without the coach going looking for it, and the app proposes nothing
about it: what to do with a swimmer's pain is his call and a health matter, not a
calculation.

**Why this priority**: The constitution puts it in two principles at once — discomfort is
set apart from other observations, and it must not be resolved automatically. Burying a
pain report in a list is the failure mode this exists to prevent. It is P1 with story 1
because shipping the reading without it would be shipping the exact mistake the rules name.

**Independent Test**: Have a swimmer report discomfort on a session, then open the coach's
analysis and confirm it is distinguishable at a glance from an ordinary observation, with
no suggested action attached to it.

**Acceptance Scenarios**:

1. **Given** a swimmer who reported discomfort on one session, **When** the coach opens
   her analysis, **Then** that session is distinguishable from the others before he opens
   it.
2. **Given** that report, **When** he reads it, **Then** the app states what she wrote and
   proposes no change to her plan, no severity score and no next step.
3. **Given** several swimmers and one of them reporting discomfort, **When** the coach
   opens `Análisis`, **Then** he can tell which swimmer it was without opening each one.

---

### User Story 3 - Internal and external load are read side by side, never merged (Priority: P2)

For a session, the coach sees what was programmed — metres, series, zones — and what she
answered — did it, perceived effort — as two separate readings placed together. The app
never combines them into a single number.

**Why this priority**: Reading the answer against the work is what makes the answer
useful, so it belongs close to story 1. It is P2 because story 1 delivers value without
the external side already formatted for comparison, and because the prohibition on
merging them is a constraint on how it is shown rather than a separate journey.

**Independent Test**: Open one session in the coach's analysis and confirm both readings
are present, labelled, and that no derived index combines them.

**Acceptance Scenarios**:

1. **Given** a session with 2000 m programmed and a perceived effort of 7, **When** the
   coach reads it, **Then** both appear, each named, and no third number is derived from
   the pair.
2. **Given** a swimmer's block, **When** the coach reads her adherence, **Then** it is the
   figure the domain already computes and is presented as adherence, not as a
   training-load score.

---

### User Story 4 - The swimmer asks for feedback on a session (Priority: P3)

After a session, the swimmer can ask her coach to look at it and tell her something. The
request names the session, carries what she wants to ask, and shows up for the coach where
he is already reading her answers.

**Why this priority**: It is the second half of the roadmap entry and it closes the loop
in the other direction, but the coach's reading has to exist before there is anywhere for
a request to arrive. Valuable on its own once stories 1 and 2 are in.

**Independent Test**: As the swimmer, ask for feedback on a past session; as the coach,
find that request in her analysis attached to that session.

**Acceptance Scenarios**:

1. **Given** a session she has already swum, **When** she asks for feedback on it,
   **Then** the request is recorded against that session and she is told it was sent.
2. **Given** a pending request, **When** the coach opens her analysis, **Then** the
   session carries the request and what she asked.
3. **Given** she has no connection, **When** she asks for feedback, **Then** the request is
   kept on her device and travels when the connection returns, exactly as her session
   records do.
4. **Given** the coach has seen her request, **When** she looks at that session, **Then**
   she can tell he saw it, even though no written answer arrives.
4. **Given** a session she has not swum yet, **When** she looks at it, **Then** asking for
   feedback is not offered: there is nothing to look at yet.

---

### Edge Cases

- **A swimmer who has answered nothing.** Says so, rather than showing an empty frame the
  coach has to interpret.
- **An answer that has not reached the server yet**, because her phone has been offline.
  The coach reads what arrived; the app does not present a partial picture as a complete
  one.
- **The same session answered twice.** Her latest answer is the one that counts, which is
  the rule the swimmer's own screen already follows.
- **An answer written against a plan version that was later readjusted.** It stays attached
  to the session she swam. Feature 009 solved this for her screen by walking the version
  lineage; the coach's reading has the same problem and must not solve it differently.
- **A session with an answer but no discomfort** must not be visually confusable with one
  carrying a discomfort report.
- **A swimmer whose guardian consent is no longer current.** Her data stops being readable
  by the coach — consent is a gate, not a one-off formality at sign-up.
- **A coach opening someone else's swimmer.** Refused by the server, not merely hidden by
  the screen.
- **A feedback request on a session that is later readjusted into a new version.** The
  request still points at the session she asked about.

## Requirements *(mandatory)*

### Functional Requirements

**What the coach reads**

- **FR-001**: The system MUST show a coach, for each of his swimmers, the answers that
  swimmer recorded — done or not done, perceived effort, observations — regardless of which
  device recorded them.
- **FR-002**: The system MUST place each answer next to the session that produced it: its
  objective and what was programmed in it.
- **FR-003**: The system MUST order a swimmer's answers so the most recent is reachable
  first, since the coach reads to decide what comes next.
- **FR-004**: The system MUST state, for every reading it shows, the methodology version
  under which the content being read was built.
- **FR-005**: The system MUST find a swimmer's answers even when the block they belong to
  has since been replaced by a new version, attaching them to the session she swam.
- **FR-006**: The system MUST show a swimmer's adherence using the figure the domain
  already computes, and MUST NOT compute a second one.
- **FR-007**: When a swimmer has recorded nothing, the system MUST say so in words rather
  than present an empty view.
- **FR-008**: When the coach's reading of the server fails, the system MUST say that it
  could not be read, and MUST NOT present an incomplete reading as a complete one.

**Discomfort**

- **FR-009**: The system MUST present a discomfort report separately from ordinary
  observations, distinguishable before the coach opens the session.
- **FR-010**: The system MUST allow the coach to tell which swimmers have reported
  discomfort without opening each swimmer in turn.
- **FR-011**: The system MUST NOT propose, score, rank or triage anything about a
  discomfort report, and MUST NOT alter a plan because of one.

**Internal and external load**

- **FR-012**: The system MUST show the programmed work and the swimmer's response as two
  separate, named readings.
- **FR-013**: The system MUST NOT present any figure that combines internal and external
  load into one indicator.

**Asking for feedback**

- **FR-014**: A swimmer MUST be able to ask her coach for feedback on a specific session
  she has already swum, in her own words.
- **FR-015**: The system MUST NOT offer to ask for feedback on a session whose day has not
  arrived.
- **FR-016**: A feedback request MUST be recorded on the swimmer's device first and travel
  to the server afterwards, so that asking never waits on the network.
- **FR-017**: The system MUST show a pending request to the coach attached to the session
  it is about, in the same place he reads her answers.
- **FR-018**: A feedback request MUST remain attached to the session it was asked about,
  even if that session's block is later replaced by a new version.
- **FR-019**: The coach MUST be able to mark a request as seen, and the swimmer MUST be
  able to tell that he saw it. Asking into a drawer is worse than not asking.
- **FR-020**: The system MUST NOT offer the coach a written reply in this feature. The
  answer happens at the poolside.
- **FR-021**: A feedback request MUST be modelled so a video can be attached to it in a
  later feature, and the system MUST NOT capture, store, transmit or display any video
  in this one.
- **FR-022**: Attaching a video MUST require that swimmer's guardian consent for video
  to be current. The check MUST exist and be proven now, so that it is already standing
  when attaching becomes possible.
- **FR-023**: The interface MUST NOT mention video, offer it or imply it is coming. A
  control the app cannot honour is a promise it should not make.

**Who may read what**

- **FR-024**: The system MUST permit only the coach role and the swimmer herself to read a
  swimmer's records and requests, and this MUST be enforced by the server and not only by
  the screen.

  **Amended during planning, and the reason is recorded rather than hidden.** This
  originally read "only his own swimmers". There is no coach→swimmer link in the product:
  `Nadador` carries no owner and the rule says `esEntrenador()`, so every coach account
  reads every swimmer. The constitution describes the product as a community *led by a
  coach*, singular, so the rule is correct for what exists — but the requirement as first
  written could not be met, and pretending otherwise would have put a promise in the spec
  that no test could keep. See decision D1.

- **FR-025**: The boundary above MUST be covered by a test that states it, so that the day
  a second coach exists the test names what has to change. This repeats what feature 003
  did with its own declared limitation, which feature 004 then closed.
- **FR-026**: The system MUST stop exposing a swimmer's records to the coach when that
  swimmer's guardian consent is no longer current.
- **FR-027**: Creating a feedback request MUST require that swimmer's guardian consent for
  training data to be current.
- **FR-028**: A swimmer MUST NOT be able to read another swimmer's records or requests.
- **FR-029**: The system MUST NOT write a swimmer's name, marks or identifiers into logs or
  analytics.

**Language**

- **FR-030**: Everything the coach and the swimmer read in this feature MUST be in Spanish,
  with no technical vocabulary leaking into the interface.

### Key Entities

- **Answer to a session** (exists since feature 003): what a swimmer recorded about one
  session — whether she did it, perceived effort, free-text observations, and a discomfort
  report kept apart. Belongs to the plan version she answered against.
- **Feedback request** (new): a swimmer asking her coach to look at one specific session,
  in her own words. Belongs to a swimmer and a session; carries when it was asked and
  whether the coach has seen it. Shaped to hold a video reference in a later feature;
  always empty in this one.
- **Swimmer's reading** (new, derived): everything the coach needs about one swimmer —
  her sessions, her answers beside them, her adherence and her discomfort reports —
  assembled for reading, not stored.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A coach can read what a swimmer answered on a session she recorded from her
  own device, having never used that device.
- **SC-002**: From opening `Análisis`, a coach reaches a specific swimmer's answer to a
  specific session in no more than three steps.
- **SC-003**: 100% of a swimmer's recorded answers that reached the server are visible to
  her coach; none is lost because the block it belonged to was readjusted afterwards.
- **SC-004**: A discomfort report is identifiable by the coach without opening the session
  it belongs to, and in a list of ten swimmers he can name the one who reported it without
  opening any of them.
- **SC-005**: No reading in the feature presents a figure that combines internal and
  external load.
- **SC-006**: A swimmer can ask for feedback with no connection, and the request reaches
  the coach once connection returns, with nothing lost.
- **SC-007**: A swimmer attempting to read another swimmer's records or requests is refused
  by the server, proven by a test that fails when the rule is removed. The coach-to-coach
  boundary is stated by a test rather than enforced, for the reason in FR-024.
- **SC-008**: A swimmer who asked for feedback can tell whether her coach has seen it,
  without a written answer existing.
- **SC-009**: No video can be attached, and the gate that will stand in front of it when
  it can is proven by a test that fails when the consent check is removed.
- **SC-010**: The deferred manual checks waiting on this feature — C1 and C2 of feature
  003, T088 and T089 of feature 004 — can be walked end to end on a real device once it
  ships.

## Assumptions

- **The coach's reading starts from the reader that already exists.** Records have been
  readable from the server since feature 007 and feature 009 built the combined reader for
  the swimmer. The coach's side uses the same source rather than a second one, because two
  readers of the same data is two truths.
- **The coach's entry point is his swimmers, then their sessions.** He already has a
  swimmer list in `Ver Plan`, and a macrocycle belongs to a swimmer, so reading by swimmer
  matches how the rest of the app is arranged. No separate inbox of unread answers is
  assumed.
- **Adherence and progress are not recomputed.** Feature 009 put them in the domain and
  both the swimmer's screen and this one read the same calculation.
- **Writing is unchanged.** The swimmer keeps writing to her device first, with the queue
  sending afterwards. This feature adds reading and one new thing to write — the request —
  which follows the same rule.
- **No notifications.** The coach finds requests where he is already reading. Pushing them
  to him is a separate decision with its own cost and is not assumed here.
- **The free tier is not touched.** Reading a swimmer's own history and asking a question
  about it are not paywalled, and the constitution forbids locking a user out of data they
  generated.

## Out of scope

- **Capturing, storing or showing video.** The request is shaped to carry one later and
  the consent gate in front of it is built and proven now, but nothing about video is
  collected in this feature and the interface says nothing about it.
- **A written reply from the coach.** He marks a request as seen; the answer happens at
  the poolside.
- **Trends across blocks or seasons.** This feature reads what was answered; charting it
  over time is a later decision.
- **Any automatic reaction to what is read.** Readjusting is the coach's act and feature
  009 already gives him the control for it.

## Clarifications

Both questions this spec raised were answered by the coach on 2026-11-11.

### Q1 — Does the feedback request anticipate video? **Shaped for it, empty for now.**

The request is modelled from the start so a video can hang off it later, "aunque no sea
obligatorio subirlo", and **the consent check is written now so it is already in place
when attaching becomes possible**.

This is deliberately narrower than it sounds, and the narrowness is the point: **nothing
about video is captured, stored, transmitted or shown in this feature.** What exists is
the shape of the request and the gate in front of the capability. The constitution forbids
collecting data without a declared use in the feature that asks for it, and this collects
none — it declares where the data will go and what must be true before any arrives.

The cost named when the question was asked still stands and is accepted: a request that
can carry something nobody can attach yet is a promise the interface must not make. The
interface therefore says nothing about video.

### Q2 — Does the coach answer inside the app? **No. It reaches him and he marks it seen.**

The conversation happens at the poolside, which for a minor is arguably where it belongs.
What the app guarantees is that she can tell he saw it — asking into a drawer is worse
than not asking.

No written reply path is built in this feature.
