# Feature Specification: The coach → swimmer relation

**Feature Branch**: `012-coach-swimmer-link`

**Created**: 2026-11-19

**Status**: Draft

**Input**: User description: "La relación entrenador–nadador, y cómo nace. Hoy no existe: un `Nadador` no tiene dueño y la regla de Firestore dice `esEntrenador()`, sin más, así que cualquier entrenador lee a cualquier nadador. La feature 010 lo declaró en vez de inventarlo y dejó en `firebase/test/reglas_analisis.test.js` una prueba que afirma que un segundo entrenador lee a la nadadora del primero y lo consigue. Primero, él le pone nombre a lo suyo, desde su pantalla de ajustes. Segundo, el nadador pide entrar al crear su cuenta: «Unirme a X entrenador» o «Unirme a X comunidad». Tercero, al entrenador le llega la solicitud y la acepta; el producto ya tiene esa forma en la feature 008. Y mientras tanto, ella entra igual: hasta que él no acepte, usa la app con normalidad y ve en planes «Esperando que el entrenador acepte tu ingreso». Lo que esta spec tiene que decidir y no heredar: qué es exactamente la relación, qué pasa con los nadadores que ya existen, qué pasa si se equivoca de comunidad o si él rechaza, si alguien puede irse o ser sacado, y si decidir quién lee los datos de una menor toca el principio V. El vocabulario visible sigue en español."

## Why this feature exists

**The product has been saying this one out loud for a feature and a half.**

There is no coach → swimmer relation. A `Nadador` has no owner, and the rule that guards a
swimmer's answers says `esEntrenador()` — any coach, full stop. Feature 010 needed
"a coach reads only his own swimmers", could not have it, and did the honest thing: it
amended the requirement, wrote the reason beside it, and left a test asserting that a
**second** coach account reads the first coach's swimmer and **succeeds**, explaining in
its own text why that is being asserted rather than hidden.

That test is where this feature starts. The day the relation exists, it is the first
thing that has to be rewritten.

**And the relation has to come from somewhere.** Today there is exactly one way a swimmer
exists: the coach creates her profile himself, from his own screen. That works for a
group he already has in front of him and it does not work for anyone else — there is no
way for a swimmer to arrive on her own and end up anywhere.

So this feature is two things that are really one: **who a swimmer belongs to**, and
**how she comes to belong**. Building the first without the second would leave a
relation that only the coach can create, which is the product it already is.

It is also the door into the community area of principle VII, and that is why it comes
before video: a video belongs to a swimmer, and who may watch it has no answer until
this exists.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The coach names what is his (Priority: P1)

The coach opens his settings and finds, beside what is already there, where to name his
group: the name his swimmers will see when they look for him. He types it, and from then
on that is how his community is known.

**Why this priority**: Nothing else in this feature can happen first. A swimmer cannot
ask to join something that has no name, and the name is the only thing she will have to
go on.

**Independent Test**: Sign in as the coach, set the name in settings, sign out, and
confirm the name is what a swimmer would be offered.

**Acceptance Scenarios**:

1. **Given** a coach with no community name set, **When** he opens his settings, **Then**
   he finds where to set it, in the same place he manages everything else about his own
   account.
2. **Given** he sets a name, **When** a swimmer reaches the point of joining, **Then**
   that is the name she is offered.
3. **Given** he changes it later, **When** a swimmer looks again, **Then** she sees the
   new one, and nobody's membership is affected by the rename.
4. **Given** he has not named it yet, **When** a swimmer reaches the point of joining,
   **Then** she is told there is nothing to join yet, in plain words, and can finish
   creating her account anyway.

---

### User Story 2 - The swimmer asks to join while creating her account (Priority: P1)

Ana installs the app and creates her account. Between the short steps that already
exist — her name, her date of birth, her country, her guardian if she is a minor, the
terms — she is offered to join: *«Unirme a …»*, with the coach's community named. She
chooses it and finishes. Her account is hers from that moment; what is still pending is
belonging.

**Why this priority**: It is the half that does not exist today, and without it the
relation is something only the coach can create from his own screen — which is the
product as it already is.

**Independent Test**: Create an account as a swimmer, choose to join, and confirm a
request reaches the coach without anything else having been touched.

**Acceptance Scenarios**:

1. **Given** a coach has named his community, **When** she reaches that step, **Then**
   she is offered to join it by name.
2. **Given** she chooses to join, **When** she finishes creating her account, **Then** a
   request to join is waiting for the coach.
3. **Given** she prefers not to join now, **When** she finishes, **Then** her account
   exists and works, and she can ask to join later without creating anything again.
4. **Given** she is a minor, **When** her guardian is asked for consent, **Then** the
   request names the community she asked to join, so the guardian knows who will read
   what they are consenting to.
5. **Given** she asked to join, **When** she looks, **Then** she can see that she asked
   and to whom, and she can withdraw the request while it is still waiting.

---

### User Story 3 - The coach accepts, and only then does he read her (Priority: P1)

A request is waiting where the coach already looks for things waiting for him. He sees
who asked. He accepts — and from that moment she is his, her answers are his to read, and
he can plan for her. Or he does not, and nothing of hers has ever been his to read.

**Why this priority**: It is the point of the whole feature. Everything else is how the
request gets there and what she sees while it waits.

**Independent Test**: With a request waiting, accept it as the coach and confirm the
swimmer appears among his swimmers and her answers become readable — and that before
accepting, they were not.

**Acceptance Scenarios**:

1. **Given** a request is waiting, **When** the coach looks where things wait for him,
   **Then** he sees it, with who asked and when.
2. **Given** he accepts, **When** he opens his swimmers, **Then** she is among them, and
   what she answered before he accepted is now readable, because it was always hers.
3. **Given** he has not accepted, **When** he looks at anything, **Then** nothing of hers
   is readable — not her answers, not her discomfort reports, not her name beyond what
   the request itself shows.
4. **Given** he declines, **When** she looks, **Then** she is told plainly, without a
   reason she did not get, and she can ask to join somewhere else.
5. **Given** a second coach exists, **When** he looks at anything, **Then** he reads only
   the swimmers who belong to him — **and this is the requirement feature 010 could not
   meet**.

---

### User Story 4 - While she waits, she is not left in the dark (Priority: P2)

Ana finished creating her account yesterday and nobody has accepted her yet. She opens
the app. It works. On the screen where her plan would be, it says she is waiting for her
coach to accept her.

**Why this priority**: Without it, a swimmer in the waiting state sees an app that
appears broken — an empty plan with no explanation — which is the same defect feature
011 just spent itself fixing on a different screen.

**Independent Test**: With a request still waiting, open the app as the swimmer and
confirm she is told where she stands, and that nothing else is blocked.

**Acceptance Scenarios**:

1. **Given** her request is waiting, **When** she opens the app, **Then** she can sign
   in and move around it normally.
2. **Given** she opens the screen where her plan would be, **When** it loads, **Then**
   it says she is waiting for the coach to accept her — not that she has no plan, and
   not nothing at all.
3. **Given** the coach accepts while she is in the app, **When** she next looks, **Then**
   the waiting notice is gone.
4. **Given** she never asked to join anyone, **When** she opens that screen, **Then** she
   is told how to ask, not that she is waiting for something she never asked for.

---

### User Story 5 - Leaving, and being let go (Priority: P3)

A swimmer stops training with this coach. Either she leaves, or he removes her. Afterwards
he no longer reads what she writes, and what she already wrote is still hers.

**Why this priority**: A relation that can only be created is a trap, and for a minor's
data it is worse than a trap. It is last because nothing before it depends on it.

**Independent Test**: End a membership from either side and confirm the coach stops
reading her, while her own history on her own device is untouched.

**Acceptance Scenarios**:

1. **Given** she belongs to a community, **When** she leaves it, **Then** the coach stops
   reading anything of hers from that moment.
2. **Given** she belongs to a community, **When** the coach removes her, **Then** the
   same, and she is told she is no longer in it.
3. **Given** she has left, **When** she opens her own history, **Then** everything she
   wrote is still there: leaving a community is not deleting herself.
4. **Given** she has left, **When** she asks to join somewhere else, **Then** she can,
   and that is a new request like any other.

---

### Edge Cases

- **Two requests at once.** She asks one community, changes her mind and asks another
  before either answers. She belongs to one community at a time, so asking somewhere
  else withdraws the first.
- **He accepts after she withdrew.** The request is gone; accepting a request that is no
  longer waiting does nothing and says so.
- **She asks again after being declined.** Allowed. A decline is not a ban, and nothing
  in the product supports one.
- **The coach renames his community** while requests are waiting. Membership and requests
  follow the coach, not the name.
- **The swimmer whose profile the coach created himself.** She belongs to him from the
  moment he created her — there is nobody else she could belong to, and no request makes
  sense for a profile that only he can see.
- **Everybody who already exists.** Every swimmer in the product today was created by the
  one coach there is. They belong to him, and nothing about their day changes.
- **A minor leaves.** Her guardian consented to her data being kept and used; the coach
  reading it was part of that. Ending the membership ends the reading and does not touch
  the consent, which is about her data and not about him.
- **Nobody has named a community yet**, which is true of a brand-new install. Joining is
  not offered; the app says so rather than offering an empty list.

## Requirements *(mandatory)*

### Functional Requirements

**The community has a name**

- **FR-001**: A coach MUST be able to set and change the name of his community from the
  screen where he manages his own account.
- **FR-002**: That name MUST be what a swimmer is offered when she is asked whether she
  wants to join, and it MUST be visible to her afterwards.
- **FR-003**: Renaming MUST NOT affect who belongs to it or any request waiting on it.

**Asking to join**

- **FR-004**: Creating a swimmer account MUST offer joining a named community, among the
  steps that already exist and without lengthening the flow with a step she cannot skip.
- **FR-005**: Joining MUST be optional. An account created without it MUST work, and she
  MUST be able to ask later without starting again.
- **FR-006**: When no community has been named, she MUST be told so in plain words and be
  able to finish creating her account.
- **FR-007**: She MUST be able to see that she asked, to whom, and to withdraw it while
  it is still waiting.
- **FR-008**: A swimmer MUST belong to at most one community at a time, and MUST have at
  most one request waiting. Asking elsewhere withdraws the first.

**Accepting**

- **FR-009**: A request MUST reach the coach where things already wait for him, showing
  who asked and when.
- **FR-010**: The coach MUST be able to accept or decline, and the swimmer MUST be told
  either way.
- **FR-011**: Accepting MUST be the only thing that creates a membership from a request.
  Nothing about it may be automatic (principle IV).
- **FR-012**: A declined request MUST NOT prevent her from asking again, there or
  elsewhere.
- **FR-013**: A profile the coach creates himself MUST belong to him from the moment it
  is created, with no request.

**Who reads whom**

- **FR-014**: A coach MUST read only the swimmers who belong to him: their answers, their
  discomfort reports, their adherence, their plans and their requests for feedback.
- **FR-015**: Before a request is accepted, **nothing** of the swimmer's MUST be readable
  by that coach beyond what the request itself carries.
- **FR-016**: After accepting, what she wrote **before** he accepted MUST be readable by
  him. It was always hers, and the membership says who may read it, not when it was
  written.
- **FR-017**: The boundary MUST be enforced where it cannot be bypassed by a screen, and
  MUST be proven by tests that exercise the queries the app actually makes, not reads of
  single documents by their identifier.
- **FR-018**: The test that today asserts a second coach **succeeds** in reading another
  coach's swimmer MUST be inverted, and the suite's negative control MUST be re-run and
  its new numbers recorded. That assertion is one of the five that made the control
  meaningful, so losing it changes what the control proves.

**While she waits**

- **FR-019**: A swimmer whose request is waiting MUST be able to sign in and use the app.
- **FR-020**: Where her plan would be, she MUST be told she is waiting for the coach to
  accept her — distinct from "you have no plan" and distinct from an empty screen.
- **FR-021**: A swimmer who has not asked to join anyone MUST be told how to ask, not
  that she is waiting.
- **FR-022**: When the membership begins, the waiting message MUST stop appearing without
  her having to do anything to clear it.

**Ending it**

- **FR-023**: A swimmer MUST be able to leave her community, and a coach MUST be able to
  remove a swimmer from his.
- **FR-024**: After either, the coach MUST stop reading anything of hers.
- **FR-025**: Ending a membership MUST NOT delete, hide or alter anything the swimmer
  wrote. Her history stays hers.
- **FR-026**: The swimmer MUST be told when she has been removed.

**What this may not break**

- **FR-027**: Every swimmer who exists when this feature ships MUST keep working exactly
  as before, with no gap in which her coach cannot see her.
- **FR-028**: A minor's guardian MUST be told which community is involved when their
  consent is requested, when there is one to name.
- **FR-029**: Nothing here weakens the consent gate of feature 004. Consent governs
  whether her data may leave the device at all; the membership governs who may read it.
  Both must be satisfied.
- **FR-030**: Visible vocabulary stays in Spanish.

### Key Entities

- **A community**: what a coach calls his group. It has a name he chooses and can change,
  and it belongs to exactly one coach. It is the thing a swimmer sees and asks to join.
- **A membership**: that a particular swimmer belongs to a particular community, and
  since when. It is what decides who may read her. At most one per swimmer at a time.
- **A request to join**: a swimmer asking for a membership that does not exist yet. It
  carries who asked, which community, and when; it is waiting, accepted, declined or
  withdrawn; and only the coach's acceptance turns it into a membership.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A second coach account reads **zero** of another coach's swimmers — no
  answers, no discomfort reports, no plans, no feedback requests — and this is proven by
  the queries the app makes, not by reads of single documents.
- **SC-002**: A swimmer can create an account and ask to join in the same sitting,
  without a separate step after signing up and without being blocked if she skips it.
- **SC-003**: A request reaches the coach and is visible to him without him doing
  anything to fetch it, in the place he already looks.
- **SC-004**: A swimmer waiting to be accepted can sign in and move through the app, and
  **every screen that would otherwise be empty tells her why**.
- **SC-005**: 100% of the swimmers who exist before this feature keep working after it,
  with their coach able to see them throughout.
- **SC-006**: Ending a membership stops the coach reading her **immediately**, and leaves
  100% of what she wrote intact.
- **SC-007**: The negative control of the rules suite is re-run and its numbers recorded.
  The suite must still fail against a collection with no rule.

## Assumptions

- **One community per swimmer, one coach per community.** The constitution describes a
  community led by *a* coach, singular. Several coaches sharing a group, or a swimmer in
  two groups, is a bigger product than this and nothing today needs it.
- **Every swimmer who exists today belongs to the one coach who exists today**, because
  he created every one of their profiles himself from his own screen. Linking them is a
  statement of fact, not a guess, and FR-027 requires it to be invisible to everyone.
- **Discovery is by name, offered, not searched.** With one community there is nothing to
  search. A list or a search becomes necessary the day there are many, and inventing it
  now would be inventing a product nobody has asked for.
- **A decline carries no reason.** The coach is not required to justify himself to someone
  who is not his swimmer, and a free-text reason reaching a stranger is a liability
  nobody needs.
- **The guardian's consent is unchanged in what it permits.** It governs whether a minor's
  data may be kept and used at all. Naming the community in the request (FR-028) is
  strictly more information for the guardian, not a new permission.
- **The request reuses the shape feature 008 already built** — something the swimmer
  raises, waiting where the coach already looks, nothing happening without his signature.
  Whether that is literally the same mechanism is the plan's call.

## Out of scope

- **More than one coach in a community**, and anything that follows from it: assistants,
  transfers between coaches, shared groups.
- **Searching or browsing communities.** There is one. See the assumption above.
- **Invitations from the coach** — a code, a link, a QR. The swimmer asks; he accepts.
  The other direction is a feature of its own and nothing here depends on it.
- **Anything about video** (feature 013), which waits on this one precisely because who
  may watch a swimmer's video has no answer until a membership exists.
- **Messaging of any kind** between coach and swimmer. The feedback request of feature
  010 remains the only channel, and it stays as it is.
