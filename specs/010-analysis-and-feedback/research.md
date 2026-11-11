# Research: Análisis and feedback

**Feature**: 010 · **Date**: 2026-11-11

Everything here was resolved by reading this repository, not by picking a convention.
Two of the findings change what the spec can promise, and they are first.

---

## D1. There is no coach→swimmer link, so FR-024 cannot mean what it says

**Decision**: keep the server rule at "a coach, or the swimmer herself", and declare the
gap rather than paper over it. Amend FR-024 to today's truth and record the hole as a
tested, named limitation.

**What the code says.** `Nadador` has no owner field — id, name, birth date, category,
target stroke, target event, marks, technical diagnosis, and nothing about who enrolled
her. The rule is:

```
match /nadadores/{nadadorId} {
  allow read: if esEntrenador() || soyEseNadador(nadadorId);
}
```

Any account holding the coach role reads every swimmer. The same is already true of
`registros`. So "cada entrenador ve solo a sus nadadores" is not enforceable today, and
no amount of screen work would make it so.

**Why this is not a bug.** The constitution opens by describing the product as *"comunidad
de natación en línea dirigida por un entrenador"* — one coach, singular. There is exactly
one coach account, and the rule is correct for the product that exists.

**Why declare it rather than build it.** Building the link touches the swimmer model, the
sign-up flow from feature 006, the consent channel in 004 and every rule that says
`esEntrenador()`. That is a feature, not a clause inside this one, and principle VII is
explicit that a feature is a vertical slice rather than four fronts at once.

**Precedent for declaring it.** This codebase already did exactly this once, and the note
is still in `firestore.rules`: *"La feature 003 dejó aquí una limitación declarada: las
reglas no distinguían a un nadador de otro porque no había identidad. Queda cerrada."*
Feature 004 closed it. The same shape applies here.

**Consequence for the spec**: FR-024 is amended to say what is true and what is not, and a
rules test asserts the current boundary so that the day a second coach exists, the test
names what has to change.

**Alternative rejected**: silently implementing "his swimmers" in the screen only. The
spec requires server enforcement, and a screen-only filter is the exact failure the
constitution's deny-by-default principle exists to prevent.

---

## D2. `Alcance.video` exists in the domain and is invisible to the rules

**Decision**: teach the rules about consent scopes in this feature, and put the video gate
in front of a capability nobody can reach yet.

**What the code says.** The domain has had two scopes since feature 004:

```dart
enum Alcance {
  datosDeEntrenamiento('datosDeEntrenamiento'),
  video('video');
}
```

with a comment that says why they were modelled early: *"descubrirlo después obligaría a
volver a pedirle el consentimiento a todas las familias."* The server stores them — the
consent document carries `alcances: string[]` and the callable validates them. But the
rule helper ignores them entirely:

```
function tieneConsentimientoVigente(nadadorId) {
  return exists(.../consentimientos/$(nadadorId))
      && get(.../consentimientos/$(nadadorId)).data.get('vigente', false) == true;
}
```

Current and scoped are different questions, and only the first is asked.

**Why now.** The coach's answer to Q1 was "preparado desde ya, y cuando se pueda se
comprueba". The gate is the part that can be built and proven today: a scope-aware helper,
and a rule that refuses a feedback request carrying a video reference unless video consent
is current. Nothing can carry one yet, so the rule refuses everything — which is a test
that passes for the right reason and keeps passing when the capability arrives.

**The risk, named.** A field nobody can fill and a gate nobody can reach are dead weight
if video never ships. The cost is three lines of rule and one field, against the cost the
comment above describes: re-asking every family for consent. The trade is worth it, and
the interface says nothing about video so the app promises nothing it cannot do.

**Alternative rejected**: checking only `vigente` for the video gate too. That would let a
family who consented to training data authorise video they never agreed to, which is the
precise thing two separate scopes exist to prevent.

---

## D3. The coach reads from the server reader, not the combined one

**Decision**: the coach's reading uses `RegistrosFirestore`; the combined reader
`RegistrosDeLasDosPartes` stays the swimmer's.

**Why.** The combined reader exists because a swimmer's own device holds answers that have
not been sent yet, and those are her latest word. A coach's device never wrote her
answers, so its local store has nothing to contribute and "local wins" has nothing to win
with. Reading both would be one pointless read per request.

This is the same source, not a second one: `RegistrosDeLasDosPartes` wraps
`RegistrosFirestore`, and `registrosParaContar` in `RepositoriosDelHub` already resolves
to it for the coach's Home count. The spec's assumption — one reader, because two readers
of the same data is two truths — is satisfied by using the one underneath.

---

## D4. The version lineage is reused as-is, and the coach can walk it

**Decision**: the coach's reading calls `registrosDelLinaje` exactly as the swimmer's
screen does.

**Why it works for him and nearly did not for her.** Feature 009 found that a readjustment
makes a new plan with a new id, so records written against the old version fall out of
sight. It also found that the swimmer cannot read the retired version, because delivering
a readjustment retires her assignment and the plan rule leans on it. The walk now goes by
identifiers and tolerates a denied plan.

The coach has no such problem: `allow read: if esEntrenador()` on `planes` lets him read
every version, retired or not. So for him the walk is complete rather than truncated, and
the limit recorded in feature 009 — two chained readjustments lose the oldest generation —
does not apply to his side.

---

## D5. The feedback request follows the outbox, like everything a swimmer writes

**Decision**: written to the device first, queued, sent afterwards. Same shape as
`RegistroDeSesion`.

**Why.** Garantía G1 since feature 003: writing never waits on the network. FR-016 says
the same for the request. The project has two precedents and the right one is the simpler:

- `BandejaDeSalida` + `Sincronizador`, used for records — local write, queue, retry.
- `PeticionesConPuerta` from feature 008, which additionally *holds* a request on the
  device until guardian consent exists.

The second is for data that must not leave without consent. A feedback request is about a
session she already swam and whose data has already left under
`Alcance.datosDeEntrenamiento`, so the simpler outbox is enough. The consent gate still
applies to creating it — FR-025 — but it does not need the holding behaviour.

---

## D6. Adherence is read, never recomputed

**Decision**: the coach's reading uses `ProgresoEnElMacrociclo` from feature 009.

It already computes `hechas`, `dijoQueNo`, `sinContestar`, `pendientes`, `adherencia` and
`adherenciaPorMesociclo` from records and plans, and is pure domain. The swimmer's screen
reads it. A second calculation would be a second methodology by the back door, which is
what the spec's assumption forbids and what principle I guards.

---

## D7. Where it lands in the HUB

**Decision**: replace the coach's placeholder, leave the swimmer's tab alone.

`destino.dart` currently answers the coach with a `TodaviaNo` naming this feature:

```dart
case Destino.analisis:
  return esEntrenador
      ? const TodaviaNo(
          loQueLlegara: 'Aquí verás lo que tus nadadores han hecho: qué '
              'cumplieron, qué anotaron y cómo sintieron el esfuerzo.',
          feature: '010')
      : const Contiene(Contenido.miProgreso);
```

The swimmer's `miProgreso` already exists and is not touched except to add where she asks
for feedback and sees that he looked.

---

## D8. Internal and external load, kept apart by construction

**Decision**: no type in this feature holds both, so no screen can accidentally combine
them.

Principle VIII forbids a single indicator mixing them, and FR-013 repeats it. The cheapest
way to keep a rule is to make breaking it require writing a new type: the reading carries
the session's programmed work and the swimmer's answer as two values side by side, with no
constructor that takes both and returns one number.

---

## Technical context, resolved

| Question | Answer | From |
|---|---|---|
| Language | Dart 3.12.2 / Flutter 3.44.2 | `pubspec.yaml`, unchanged |
| New dependencies | **None.** Principle VII requires justifying any addition, and nothing here needs one | — |
| Storage | Firestore for records and requests; device store for the outbox | features 003, 004 |
| Testing | `flutter test`, rules tests against the emulator, functions tests | the four gates |
| Target | Android, iOS and web, one codebase | existing |
| Scale | One coach, a handful of swimmers, a few hundred records each | constitution |
| Performance | A swimmer's reading assembled from one query per block, not one per session | D3, D4 |
