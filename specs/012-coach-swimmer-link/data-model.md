# Phase 1 — Data model: The coach → swimmer relation

**Two collections, one field, and a deliberate refusal to add a third.**

---

## New: `comunidades/{comunidadId}`

What a coach calls his group. The signpost a swimmer sees before she belongs to anything.

| Field | Type | Rules |
|---|---|---|
| `entrenadorId` | string | the account that owns it. Set at creation, never changed |
| `nombre` | string | what she sees. 1 to 60 characters, trimmed, not blank |
| `creadaEn` | timestamp | the server's |

- **One per coach.** The id is the coach's own account id, which makes "one" a fact of the
  key rather than a rule somebody has to enforce.
- **Readable by any signed-in account**, because a swimmer must see the name before she is
  anyone's (research D3). Nothing about who is inside is in this document.
- **Writable only by its coach**, and `entrenadorId` is immutable once set: a community
  that could change hands is a different product.
- **Renaming is free** and affects nothing else (FR-003), which is the point of keeping the
  name here and the membership elsewhere.

---

## New: `solicitudesDeIngreso/{nadadorId|comunidadId}`

A swimmer asking for a membership that does not exist yet.

| Field | Type | Rules |
|---|---|---|
| `nadadorId` | string | who asked. Must be the asker's own profile |
| `comunidadId` | string | what she asked to join. Must exist |
| `estado` | enum | `esperando`, `aceptada`, `rechazada`, `retirada` |
| `pedidaEn` | timestamp | when she asked |
| `resueltaEn` | timestamp? | when it stopped waiting. Absent while `esperando` |

- **The id is deterministic** — `nadadorId|comunidadId` — the same shape feature 010 used
  for feedback requests, and for the same reason: asking twice is the same asking, and a
  retry cannot make two.
- **At most one waiting request per swimmer** (FR-008). The key gives "one per community";
  the rest is enforced where the request is raised, because a rule cannot count documents.
- **She writes it; she may withdraw it.** She may not change `estado` to `aceptada` —
  that word belongs to the coach, and the rule says so rather than trusting the screen.
- **He reads the ones for his community**, which is provable from the filter
  `comunidadId == mine`, and resolves them through the server (research D4).
- **It carries no personal data beyond who asked.** The coach sees a name he needs to
  decide; everything else about her stays unreadable until he accepts (FR-015).

---

## Changed: `nadadores/{nadadorId}`

One field added. Nothing removed.

| Field | Before | After |
|---|---|---|
| `comunidadId` | — | the community she belongs to, or absent |
| `miembroDesde` | — | when the membership began, or absent |

**This is the membership** (research D1). Absent means she belongs to nobody: either she
has not asked, or she is waiting, or she has left. Which of those it is comes from the
request, not from here — this field answers one question only, and answers it in one
place.

**Invariants**:

- `comunidadId` is written **only by the server** (research D4). A coach cannot write
  another person's profile from a client, and a swimmer cannot write herself into a
  community.
- Absent and present are the only two states. There is no "pending" value here, because
  pending is a property of the request.
- Ending a membership removes the field. It does not set it to a tombstone, because
  everything that reads it asks "is she mine", and absent answers that perfectly.

---

## Changed: the rules of six collections

Nothing in these documents changes. What changes is who may read them.

| Collection | Before | After |
|---|---|---|
| `nadadores` | any coach reads all | a coach reads those whose `comunidadId` is his |
| `registros` | any coach reads all | a coach reads those whose swimmer is his |
| `macrociclos` | any coach reads all | same |
| `planes` / `asignaciones` | any coach reads all | same |
| `peticiones` (feature 008) | any coach reads all | same |
| `peticionesDeFeedback` (feature 010) | any coach reads all | same |

**And every query the app makes against them is rewritten** so the filter proves it
(research D2). That is the bulk of the work and the bulk of the risk: a rule that is
tight and a query that cannot be proven is a screen that shows nothing, and this product
has had that exact failure before.

---

## What is deliberately not added

- **No `membresias` collection.** One community per swimmer means the fact has a home
  already. See research D1.
- **No copy of `comunidadId` on records, plans or requests.** It is the copy that cannot
  be unmade when a membership ends.
- **No membership history.** Who belonged when is a question nobody has asked, and keeping
  it would mean keeping a minor's association with a coach after she left — which is more
  data about her, not less.
- **No "pending" state on the swimmer.** It would be a second place to ask the same
  question, and the two could disagree.

---

## Domain types (pure Dart, no Firebase)

- **`Comunidad`** — an id, a coach, a name. Refuses a blank name and a name over 60
  characters, in the constructor, the way every other entity in this project refuses what
  it cannot represent.
- **`Membresia`** — that a swimmer belongs to a community, and since when. A value, not a
  document: it is what `comunidadId` and `miembroDesde` mean together.
- **`SolicitudDeIngreso`** — who asked, where, when, and in what state. The transitions it
  allows are the enum above, and it refuses the ones that are not its to make: a swimmer's
  copy can go to `retirada` and nowhere else.
