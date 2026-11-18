# Feature Specification: Repairs to the swimmer's journey

**Feature Branch**: `011-swimmer-journey-repairs`

**Created**: 2026-11-18

**Status**: Draft

**Input**: User description: "Reparaciones del recorrido del nadador. Es trabajo de reparación sobre un área ya construida: al terminar, la app hace lo que ya promete, y no se añade ninguna superficie nueva de producto. Cuatro cosas, que los recorridos a mano en el Pixel 7 encontraron y dejaron escritas. La primera y la que pesa: el contrato de sincronización de la feature 003 nombra tres disparadores —al guardar, al volver la red y al abrir la app— y el segundo nunca se cableó. `Sincronizador.alVolverLaRed` existe y está probado, y nadie en `lib/` lo escucha; y no podría dispararse igualmente, porque el sondeo que lleva detrás pregunta «¿se inicializó Firestore?» y vale verdadero con el modo avión puesto. Segunda: `ProgresoEnElMacrociclo.pendientes` cuenta como pendiente una sesión que la nadadora contestó «no la hice». Tercera: `Mi progreso` muestra «Todavía no tienes un plan asignado» durante los veinte segundos que su plan tarda en cargar sin conexión. Cuarta: el aviso de pendiente puede sobrevivir al envío, porque la cola interna de Firestore entrega la escritura que nuestro plazo dejó de esperar. Lo que no se toca: las garantías G1, G3 y S8, y la frase literal de FR-017. Al nadador no se le muestra nunca un error de red, ni un código, ni un contador de reintentos, ni un botón de reintentar. La verificación a mano en un dispositivo real —C1 y C2 de la 003, C7 y C8 de la 004— queda para después de la feature 013, por decisión del entrenador. El vocabulario visible sigue en español."

## Why this feature exists

**Nothing here is new. Every line of it is something the product already says it does.**

Feature 003 made the swimmer a precise promise: she can annotate at the poolside with no
signal, and what she wrote reaches her coach by itself. The contract that holds that
promise names three triggers — when she saves, **when the network comes back**, and when
she opens the app. The second was never wired to anything.

So the promise holds in a weaker form than the one that was written. What she annotates
does arrive, but only the next time she opens the app. A swimmer who annotates after
training and does not open the app again until tomorrow is a swimmer whose coach reads
her session a day late, with a sentence on her screen all evening telling her it will be
sent when she has internet — true when it appeared, and no longer true somewhere on the
walk home.

Three smaller ones, found on the same walks and written down beside it:

- Her pending list counts a session she answered — one she told him she **did not do**.
  Saying "I did not do it" is an answer, not a silence, and the calculation that gets
  this wrong forbids the conflation in its own documentation.
- One of her screens tells her she has **no plan assigned** during the twenty seconds it
  takes to load the plan she does have. It is an empty state shown before the data had
  its chance, and while it is on screen it is false.
- The notice that something is waiting to be sent can outlive the sending. The record
  reaches the server by a path the app's own queue did not watch, so the server has it
  while the app still counts it waiting.

They are one feature because they are one journey and one set of files: the swimmer, her
phone, and the promise that nothing she writes is lost or quietly delayed. None of it
adds a screen, a button, or a word she has not already seen.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - What she wrote leaves by itself when the signal comes back (Priority: P1)

Ana finishes training, marks the session on the pool deck and writes two lines about how
it went. There is no signal in the building. She puts the phone in her bag. Walking out
to the street the signal returns and, without her opening the app, touching anything, or
knowing it happened, what she wrote reaches her coach and the notice stops saying it is
waiting.

**Why this priority**: It is the sentence feature 003 wrote, and the only one of the four
that is a broken promise rather than a rough edge. It is also what scenario C2 of feature
003 checks at step 5 — the step that has never passed.

**Independent Test**: With no network, annotate a session. Restore the network. Without
touching the app or the screen, the record reaches the server and the notice goes.

**Acceptance Scenarios**:

1. **Given** a record queued with no network, **When** the network returns and nothing is
   touched, **Then** the record reaches the server and the notice disappears.
2. **Given** several records queued, **When** the network returns, **Then** all of them
   are sent, and one that fails does not hold back the rest.
3. **Given** a record that has already failed attempts and is waiting out its retry
   delay, **When** the network returns, **Then** it is sent at once instead of serving
   out a delay that exists for a server that was not answering.
4. **Given** no network and the app open, **When** she looks at any of her screens,
   **Then** she is never shown a network error, a status code, a retry count, or a button
   to retry. The retrying is the app's work.
5. **Given** nothing is waiting to be sent, **When** the app is open and she is doing
   nothing, **Then** nothing is probed: her battery and her data are not spent looking
   for a network that nothing needs.
6. **Given** the network is reachable but the server does not answer, **When** a send is
   attempted, **Then** it is bounded, counts as not arrived, and is retried later — the
   app never waits on it without end.

---

### User Story 2 - A session she said she did not do stops being counted against her (Priority: P2)

Ana could not train on Tuesday and said so in the app. On Thursday her plan still lists
Tuesday among the sessions she has left to mark, and her coach reads the same list as a
gap. She answered. The app is asking again.

**Why this priority**: It is a number that is wrong in front of both of them. It matters
less than User Story 1 because nothing is lost or delayed by it — only miscounted.

**Independent Test**: Answer a past session with "I did not do it" and confirm it leaves
the pending list, while a past session with no answer at all stays in it.

**Acceptance Scenarios**:

1. **Given** a past session she answered with "I did not do it", **When** she opens her
   plan, **Then** it is not among the sessions she has left to mark.
2. **Given** a past session she has not answered at all, **When** she opens her plan,
   **Then** it **is** among them. Silence is not an answer.
3. **Given** a past session she marked as done, **When** she opens her plan, **Then** it
   is not among them.
4. **Given** today's session, unanswered, **When** she opens her plan, **Then** it is not
   counted: the day has not finished.
5. **Given** the same swimmer and the same sessions, **When** the coach reads her,
   **Then** he sees the same count she does. One rule, one number, two screens.

---

### User Story 3 - No screen tells her something is missing while it is still looking for it (Priority: P2)

Ana opens her progress with no signal. For twenty seconds the screen tells her she has no
plan assigned and that her progress will appear when her coach gives her one. She has a
macrocycle, delivered weeks ago, and it is on the phone in her hand.

**Why this priority**: It is short-lived, but what it says is false and discouraging, and
it says it in the exact words the app keeps for a swimmer who genuinely has nothing. She
cannot tell "I am still looking" from "there is nothing" if the app uses one sentence for
both.

**Independent Test**: With no network and a cold start, open the progress screen and
confirm that at no moment does it state an absence it has not established.

**Acceptance Scenarios**:

1. **Given** she has a delivered macrocycle and no network, **When** she opens her
   progress after a cold start, **Then** at no point is she told she has no plan; she is
   told it is still loading until there is an answer.
2. **Given** she genuinely has no plan, **When** the reading finishes, **Then** she is
   told so, in the words the app already uses.
3. **Given** the reading fails, **When** it finishes, **Then** she is told it could not
   be read — not that there is nothing to read.

---

### User Story 4 - The notice stops outliving the sending (Priority: P3)

Her screen says her progress is saved and will be sent when she has internet. It has been
sent. The server has had it for an hour.

**Why this priority**: Nothing is lost and nothing is duplicated — the record carries a
deterministic identifier, so the same thing arriving twice is the same thing. What is
wrong is the sentence, and only after it has stopped being true. It is last because
User Story 1 makes it rare.

**Independent Test**: Put a record in a state where the server holds it but the app's own
queue still counts it waiting, and confirm the app finds out and the notice goes.

**Acceptance Scenarios**:

1. **Given** a record the server already holds while the app's queue still counts it
   waiting, **When** the app next synchronises, **Then** the queue finds out and the
   notice disappears.
2. **Given** a record the server does not hold, **When** the app synchronises, **Then**
   it stays queued and the notice stays. Clearing the notice must mean *it arrived*,
   never *we stopped looking*.

---

### Edge Cases

- **The signal flickers** — back and gone within the same second. Attempts must not pile
  up: one in flight at a time, and the next decided on the result of the last.
- **The server accepts and never answers.** The deadline already in place covers the
  send; this feature must not reintroduce an unbounded wait anywhere, the probing
  included.
- **Her clock is wrong.** The server's own timestamp already detects that (decision D3),
  and nothing here may start trusting the device clock for whether something was sent.
- **A session with no date.** It cannot be pending: there is no day it was missed on, and
  guessing one is inventing.
- **Many records queued after days offline.** All go; one failing holds none of the
  others back; and the sending never becomes a tight loop on someone's phone.
- **She signs out with things queued.** Out of scope here, and already named in feature
  004's own scenario C7, which is deferred with the rest of the device walks.

## Requirements *(mandatory)*

### Functional Requirements

**The send that retries by itself**

- **FR-001**: When connectivity returns, whatever the swimmer has queued MUST be sent
  without her doing anything — not opening the app, not pressing anything, not knowing.
- **FR-002**: Connectivity MUST be established by attempting to send and seeing whether
  it arrives, **not** by asking the device whether it has a network interface. A pool
  with wifi that does not reach the internet is the normal case, not the rare one.
- **FR-003**: The system MUST NOT probe while nothing is queued. With an empty queue
  there is nothing to find out and nothing to spend her battery or her data on.
- **FR-004**: Every probe and every send MUST be bounded in time. One that does not
  answer counts as *not arrived*, never as *arrived* and never as *still waiting*.
- **FR-005**: When connectivity returns, a record serving out its retry delay MUST be
  sent at once. That delay exists so the app does not hammer a server that is not
  answering; once it is answering, the delay has no reason left.
- **FR-006**: Retrying MUST stay bounded and MUST NOT become a tight loop. The device
  belongs to someone who is swimming. The feature MUST state what its probing costs,
  per hour, with one record queued and no network.
- **FR-007**: At most one send per record MUST be in flight at a time, and at most one
  synchronisation at a time.
- **FR-008**: The swimmer MUST never be shown a network error, a status code, a retry
  count, or a button to retry.
- **FR-009**: The sentence feature 003's FR-017 requires MUST stay exactly as it is,
  word for word: «Guardado el progreso, se enviará cuando tengas acceso a internet».

**What counts as pending**

- **FR-010**: A session the swimmer has answered MUST NOT be counted as pending,
  whether she answered that she did it or that she did not. An answer is an answer.
- **FR-011**: A past, dated session she has **not** answered MUST still be counted.
  Today's MUST NOT: the day has not finished. One with no date MUST NOT: there is no day
  it was missed on.
- **FR-012**: The swimmer and the coach MUST read the same count for the same sessions,
  from one rule in one place.

**Saying "I do not know yet" instead of "there is nothing"**

- **FR-013**: A screen that has not finished reading MUST NOT state an absence. It MUST
  be able to tell apart, and show differently, these three: *still reading*, *read, and
  there is nothing*, and *could not be read*.
- **FR-014**: The wording already used for a swimmer who genuinely has no plan MUST stay
  reserved for that case.

**The notice means it arrived**

- **FR-015**: The notice MUST disappear once the record is on the server, including when
  it got there by a path the app's queue did not observe.
- **FR-016**: The notice MUST NOT disappear for any other reason. Clearing it means *it
  arrived*, never *we stopped looking*.

**What this feature may not break**

- **FR-017**: Guarantee G1 is unchanged: annotating writes to the device and queues,
  without consulting the network, and cannot fail because of it.
- **FR-018**: Guarantee G3 is unchanged: a record is never discarded, however many
  attempts it has taken.
- **FR-019**: Guarantee S8 is unchanged: a failure writing **locally** does surface,
  because there the data would be lost.
- **FR-020**: No new product surface. No new screen, no new control the swimmer can
  press, and no vocabulary she has not already seen. When this feature is done the app
  does what it already promised, and nothing more.
- **FR-021**: Visible vocabulary stays in Spanish.

### Key Entities

- **A queued send**: one record waiting to leave the device. It carries which record it
  is, what state it is in, how many attempts it has taken, and when the last one was.
  Nothing new is added to it by this feature; what changes is when the next attempt is
  allowed (FR-005) and how its state is reconciled with the server (FR-015).
- **The state of the network**, as the app understands it: not what the device reports,
  but whether the last attempt to send arrived (FR-002).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A session annotated with no signal reaches the coach **within one minute**
  of the signal returning, with the swimmer touching nothing.
- **SC-002**: 100% of queued records reach the server without the swimmer pressing
  anything, including those that had already failed several attempts.
- **SC-003**: With nothing queued, the app makes **zero** network attempts of its own
  accord. Everything it asks for is something a screen she opened needs.
- **SC-004**: The cost of the probing, with one record queued and no network, is written
  down as a number per hour, and it is bounded.
- **SC-005**: No screen states an absence it has not established: for every screen that
  reads before it shows, the three outcomes of FR-013 are distinguishable on screen.
- **SC-006**: The count of sessions left to mark equals the number of past, dated
  sessions with no answer — nothing more, nothing less — and it is the same number on
  the swimmer's screen and the coach's.
- **SC-007**: No text a swimmer can reach mentions a network error, a status code, a
  retry count, or retrying, verifiable by reading every file that draws her screens.
- **SC-008**: The notice is on screen if and only if something is genuinely not yet on
  the server.

## Assumptions

- **The device clock may be wrong**, and whether something was sent is never decided by
  it. The server's own timestamp already covers detecting a skewed clock (decision D3 of
  feature 003), and this feature does not revisit that.
- **Firestore's own queue may deliver a write the app stopped waiting for.** This is why
  FR-015 exists: the app's record of what is pending can fall behind the truth, and the
  truth is the server.
- **The existing retry delay is kept** — growing with attempts, capped — and what changes
  is only that returning connectivity cuts it short (FR-005). It exists for battery, and
  that reason is still good.
- **No new dependency is assumed.** If one turns out to be needed, principle VII requires
  it to be justified by name in the plan.
- **The four repairs share a set of files** and are specified together for that reason,
  but each user story is independently testable and independently deliverable.

## Out of scope

- **The manual verification on a real device.** C1 and C2 of feature 003 and C7 and C8 of
  feature 004 — tasks T071, T088 and T089 — are **not closed here**. The coach decided to
  walk them all together after feature 013. This feature therefore proves by test
  everything that can be proven without a phone, and says explicitly what is left for
  that walk.
- **Anything on the coach's side.** He reads what arrives; nothing about his screens
  changes.
- **The coach → swimmer relation** (feature 012) and **video** (feature 013).
- **Signing out with things queued** (feature 004's C7), named in the edge cases and
  deferred with the other device walks.
