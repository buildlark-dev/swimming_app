# Phase 0 — Research: The coach → swimmer relation

Seven decisions. D1 and D2 carry the feature; the rest follow from them.

---

## D1 — The membership is one field on the swimmer, read from one place

**Decision**: a `comunidadId` on the swimmer's profile, and nothing else. It is **not**
copied onto her records, her plans, her assignments or her feedback requests.

**Rationale**:

FR-024 says that when a membership ends, the coach stops reading her — immediately. A
copy of the membership on every document she has ever written is a set of things that can
still say the old answer, and ending a membership would mean rewriting all of them, in
order, without failing halfway. There is no version of that which is correct on a phone
with no signal.

This is also not a new position here. The consent gate pays a read per write and says why
in its own comment:

> Cuesta una lectura por escritura. A esta escala —decenas de nadadores— es irrelevante,
> y desnormalizarlo para ahorrarla crearia la posibilidad de que el estado de la puerta
> discrepe de si mismo en dos sitios.

The same sentence applies word for word, with "la puerta" replaced by "la pertenencia".

**Alternatives considered**:

- **A `membresias` collection.** An extra document and an extra read to express a
  one-to-one fact that already has a natural home. Its only advantage is making
  many-to-many easy later, and many-to-many is explicitly out of scope — building for it
  now would be building a product nobody has asked for.
- **The macrocycle as proof of the link.** Tempting, because a delivered macrocycle really
  does imply a coach. But a swimmer who has just been accepted has no macrocycle, and the
  waiting state of US4 exists precisely for the stretch before any plan. It would also make
  "who may read her" depend on a document she does not control and cannot see.
- **Copying the community onto each record at write time.** Correct at the instant of
  writing and wrong from then on. Worse than a stale read: it would make "who read this"
  a property of history rather than of now.

---

## D2 — The five whole-collection reads cannot survive, and replacing them is the work

**Decision**: every query the coach makes is rewritten so that what he is allowed to see
is expressed **in the query's own filters**.

**Rationale**:

This product has already paid for this lesson once, in feature 009: the swimmer's
macrocycle query filtered only by `nadadorId`, the rule required «suyo **y** entregado»,
and Firestore rejected the query entirely — not the documents, the query — because *a
query is proven by its filters, not document by document*.

Today the coach makes five reads of an entire collection:

| Where | What it reads | Why it was allowed |
|---|---|---|
| `registros_firestore.dart` → `nadadoresConRegistros` | all of `registros` | the rule says `esEntrenador()`, full stop |
| `repositorios_firestore.dart` → the swimmer list | all of `nadadores` | same |
| `macrociclos_firestore.dart` → `macrocicloPorNadador` | all of `macrociclos` | same |
| `peticiones_firestore.dart` | all of `peticiones` | same |
| `repositorios_firestore.dart` → assignments | all of `asignaciones` | same |

The moment a rule asks *which* swimmer, none of them can be proven and all five break.
And they break loudly, which is the good case: the bad case would be a rule that looks
tight and a query that still returns everything.

**There is already a comment in the code that assumes this feature exists.**
`nadadoresConRegistros` says *«Solo el entrenador puede hacerla: las reglas le dejan leer
los registros de su comunidad»*. There is no community. It reads everyone's.

**What replaces each**: the coach's swimmer list is filtered by community, which is
provable. The other four are then expressed in terms of **his swimmers**, whose ids he
now has.

**The one that costs something**: `nadadoresConRegistros` exists specifically to avoid
being N queries — decision D10 of feature 007 bought "one query" on purpose, because
counting swimmer by swimmer grows with the group. It becomes a small number of chunked
queries instead, since an `in` filter takes a bounded list of ids. At tens of swimmers
that is one or two queries. **The trade is made with its eyes open**, and the number
belongs in the quickstart rather than in anyone's memory.

**Alternatives considered**:

- **Denormalise `comunidadId` onto every queried collection** so each query can filter by
  it directly. Rejected by D1: it is the copy that cannot be unmade when a membership
  ends.
- **Keep the whole-collection reads and filter in the client.** Rejected outright, and
  worth stating because it is the mistake that looks like it works: the documents would
  already have left the server. Filtering after reading is not a boundary, it is a
  decoration.

---

## D3 — The community is its own document, readable by anyone signed in

**Decision**: a `comunidades/{id}` document with the coach's id and the name he chose.
Any authenticated account may read it; only its coach may write it.

**Rationale**:

A swimmer has to see the name **before** she belongs to anything — that is the whole of
US2. She may not even have a profile yet at the moment the option is offered. So the name
cannot live anywhere that requires membership to read, which rules out hanging it off the
coach's own user document.

What is exposed is a name the coach chose for the purpose of being seen by people who are
not yet his swimmers. That is not personal data leaking; it is the signpost, and it says
nothing about who is inside.

**Alternatives considered**:

- **On the coach's `usuarios/{uid}` document.** That document is `allow write: if false`
  and holds identity plumbing; making part of it world-readable to show a name would
  widen a document that exists to be narrow.
- **In the app, as a constant**, since there is one coach. Rejected: it would have to be
  rebuilt and redeployed to rename anything, and US1 is a screen he uses.

---

## D4 — Accepting goes through the server, in one call

**Decision**: accepting, declining, removing and leaving are server calls. Accepting
writes the membership and closes the request as one act.

**Rationale**:

Two writes that must both happen cannot be left to a client on a phone. A half-finished
accept is a swimmer who belongs to nobody with no request left to show for it — she would
have to ask again and would not know why.

It also avoids widening the rules in an ugly direction: letting a coach write
`comunidadId` onto someone else's profile from the client means a rule that lets a coach
write another person's profile at all, and that rule would then have to be careful about
every other field on it. The server writes it; the client cannot.

This is the shape feature 008 already uses — the swimmer raises something, it waits where
the coach looks, and nothing happens without his signature — and the existing
`emitirSolicitud` / `cerrarPeticion` functions are the precedent for how that is done
here.

**Alternatives considered**:

- **Client-side accept under rules.** Rejected for atomicity and for the shape of the rule
  it would require.
- **Reuse feature 008's `peticiones` collection** for join requests too. Rejected: that
  collection carries a swimmer's plan request, with its own lifecycle and its own rules.
  Two unrelated things in one collection means every rule has to ask which kind it is
  first, and the first rule that forgets is a hole.

---

## D5 — There is nobody to migrate, and that deletes a decision

**Decision**: no migration, no deploy ordering, no one-time server step. The **seed**
creates a community and puts the seeded swimmers in it, and that is the whole of it.

**Rationale**:

This decision used to say the opposite. It specified a one-time server step that linked
every existing swimmer to the one existing coach's community, running **before** the
tightened rules went out, because the reverse order leaves a window — a deploy long — in
which the coach can see none of his swimmers.

All of that rested on an assumption that was never checked: that the swimmers in the
product belong to somebody. **They do not.** The coach said so plainly — *«todavía no
existe nadie a quien vincular»* — and the profiles that exist are his own test data.

So the migration disappears, the deploy ordering disappears, and with them a class of
risk that was about to become a task, a requirement and a success criterion. What is left
is much smaller and lives somewhere else entirely: `sembrar-emulador.js` has to create a
community and put the seeded swimmers in it, or the walk exercises a product that nobody
belongs to.

**It is worth keeping the deleted reasoning visible**, because the day there *are*
swimmers with a coach — which is the point of the feature — the ordering argument comes
back exactly as it was written: link first, tighten second.

**Alternatives considered**:

- **Write the migration anyway, defensively.** Rejected: code for a population that does
  not exist cannot be tested against that population, so it would ship unproven and be
  trusted later for precisely the case nobody checked.
- **Leave the old plan in place and let it find nothing.** Rejected for the same reason,
  plus it would leave a deploy ordering requirement that no longer protects anything, and
  requirements that protect nothing get dropped at the worst moment.

---

## D6 — "Waiting" is an empty state, not a fifth kind of reading

**Decision**: the swimmer's plan screen keeps feature 011's `Lectura` for *whether the
plan has been read*, and asks a **separate** question — does she belong to a community? —
to choose which empty state to show.

**Rationale**:

Feature 011 made `Cargando` / `Hay` / `NoHay` / `NoSePudo` exhaustive because a null meant
two things. Adding `Esperando` to that type would repeat the mistake in a new costume:
waiting is not a state of the *reading*, it is a fact about her that explains why the
reading found nothing.

Keeping them separate also gets US4's four cases right for free: she has a plan; she has
none and belongs to a community; she has none and is waiting; she has none and has not
asked. Those are two independent questions with four answers, not one question with four.

**Alternatives considered**:

- **A fifth `Lectura` case.** Rejected above.
- **A single flag `estaEsperando` beside the nullable.** That is precisely the "two fields
  that can disagree" that feature 011's D4 rejected.

---

## D7 — The inversion of the second-coach test changes what the suite proves

**Decision**: invert it, and **re-run the suite's negative control and record the new
numbers** in the same commit.

**Rationale**:

`reglas_analisis.test.js` was measured against a collection with no rule at all: 5 of 10
tests passed anyway, and the only failures were the five that assert a success. The
second-coach test is one of those five.

So inverting it does not just change one assertion. It removes one of the five things that
can tell you the rules are loaded at all, because **a test that asserts a refusal passes
for free when nothing is enforced**. After the inversion, the control must be re-run; if
the suite's ability to notice a missing rule has dropped, that is a finding and the suite
needs another `assertSucceeds` that this feature can honestly make — and it can, because a
coach reading **his own** swimmer must succeed.

**Alternatives considered**:

- **Invert it and move on.** Rejected: it would quietly weaken the measurement that makes
  the rest of the suite meaningful, and the spec made this a requirement (FR-018) for that
  reason.

---

## What this research did not decide

**Nothing about video** (feature 013), which waits on this one. And nothing about what
happens the day there are two coaches in one community, or a swimmer in two — both named
out of scope in the spec, both the reason D1 chose the shape it chose.
