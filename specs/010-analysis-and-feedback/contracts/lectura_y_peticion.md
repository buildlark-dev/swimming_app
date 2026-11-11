# Contract: reading a swimmer, and asking for feedback

**Feature**: 010 · **Date**: 2026-11-11

The interfaces this feature adds or extends, and what each one promises. Written as
contracts rather than signatures: what breaks if it is not kept is named.

---

## 1. `RepositorioPeticionesDeFeedback`

```dart
abstract class RepositorioPeticionesDeFeedback {
  /// Las de un nadador. Vacía si no ha pedido nada.
  Future<List<PeticionDeFeedback>> deNadador(String nadadorId);

  /// Las de un plan concreto, que es como las lee el entrenador.
  Future<List<PeticionDeFeedback>> deNadadorEnPlan(String nadadorId, String planId);

  /// Guarda la petición. **No espera a la red.**
  Future<void> guardar(PeticionDeFeedback peticion);

  /// El entrenador la marca vista. Es su única escritura aquí.
  Future<void> marcarVista(String peticionId, DateTime cuando);
}
```

**Promises**

- `guardar` writes to the device and returns. It never blocks on the network, and it never
  fails because of it (G1, FR-016).
- `marcarVista` touches `vistaEn` and nothing else. The server rejects anything wider, so a
  client that tried would be refused rather than silently allowed.
- `deNadadorEnPlan` filters on both `nadadorId` and `planId`. **Both filters, and the
  second is not redundant**: a Firestore query is proven by its filters, and this is the
  lesson feature 009 learned twice — seven positive rules tests over a collection and none
  over the query the app actually makes.

**Breaks if not kept**: a request that waits on the network is a swimmer at the poolside
who cannot ask. A `marcarVista` that writes more is a coach editing her question.

---

## 2. `LecturaDelEntrenador` — assembling one swimmer's reading

```dart
Future<LecturaDelNadador> leerAlNadador({
  required Nadador nadador,
  required Macrociclo? macrociclo,
  required List<Plan> mesociclos,
  required RepositorioRegistros registros,
  required RepositorioPlanes planes,
  required RepositorioPeticionesDeFeedback peticiones,
});
```

**Promises**

- Records come through `registrosDelLinaje`, so an answer written against a version that
  was later readjusted stays attached to the session she swam (FR-005, D4).
- Adherence comes from `ProgresoEnElMacrociclo`. Nothing here computes a second one (FR-006,
  D6).
- Every `RespuestaASesion` carries the session and the record as two values. **No method on
  it returns a figure derived from both** (FR-013, D8).
- A swimmer with no records yields a reading with empty `respuestas`, not an error. The
  screen says so in words (FR-007).
- When the server cannot be read, the failure reaches the caller. It is not swallowed into
  an empty list, because an empty reading and an unreadable one say opposite things to a
  coach deciding what to programme next (FR-008).

**Breaks if not kept**: swallowing the failure is the defect feature 009 shipped twice —
a screen that looks fine and is wrong.

---

## 3. The server rules

### `peticionesDeFeedback/{peticionId}`

```
allow read:   esEntrenador() || soyEseNadador(resource.data.nadadorId)

allow create: soyEseNadador(request.resource.data.nadadorId)
              && peticionId == nadadorId + '|' + planId + '|' + sesionId
              && tieneConsentimientoDeAlcance(nadadorId, 'datosDeEntrenamiento')
              && request.resource.data.pregunta is string
              && request.resource.data.pregunta.size() > 0
              && !('video' in request.resource.data)

allow update: esEntrenador()
              && request.resource.data.diff(resource.data).affectedKeys()
                   .hasOnly(['vistaEn'])

allow delete: false
```

### The new helper

```
function tieneConsentimientoDeAlcance(nadadorId, alcance) {
  return exists(/databases/$(database)/documents/consentimientos/$(nadadorId))
      && get(/databases/$(database)/documents/consentimientos/$(nadadorId))
           .data.get('vigente', false) == true
      && alcance in get(/databases/$(database)/documents/consentimientos/$(nadadorId))
           .data.get('alcances', []);
}
```

**Current and scoped are different questions.** `tieneConsentimientoVigente` asks only the
first. A family that agreed to training data would otherwise be authorising video they
never agreed to, which is exactly what two separate scopes exist to prevent (D2).

### Tests this contract demands

Each of these fails when its rule is removed, which is the only way a rules test means
anything — feature 008 learned it with 18 of 24 passing against a collection that had no
rule at all.

| Must pass | Must fail |
|---|---|
| She creates her own request, consent current | She creates one for another swimmer |
| She reads her own | She reads another swimmer's |
| She queries hers in a plan, filtering by both | She queries by plan alone |
| The coach reads hers | The coach writes her question |
| The coach sets `vistaEn` | The coach sets `vistaEn` **and** `pregunta` |
| — | She creates one with consent revoked |
| — | She creates one carrying `video` |
| — | Anyone deletes one |

**And one test that states a boundary rather than enforcing it** (FR-025, D1): a second
coach account reads the first coach's swimmer, and **succeeds**. The test asserts that it
succeeds and says in its own text why: there is no coach→swimmer link, the product has one
coach, and when that changes this test is what has to change first.

---

## 4. What the HUB hands over

`destino.dart` stops answering the coach with `TodaviaNo(feature: '010')` and returns the
new content. `RepositoriosDelHub` gains the requests repository and exposes, for the
coach, the server-side records reader it already resolves for his Home count (D3).

The swimmer's `Análisis` is untouched except for where she asks and where she sees that he
looked.

---

## 5. What this feature does not add

- No reply path. No `respuesta` field, no collection, no rule (Q2).
- No video capture, storage or display. The type exists, the constructor refuses it, the
  rule refuses it, and the interface never mentions it (Q1, FR-021 to FR-023).
- No notifications.
- No coach→swimmer link (D1).
