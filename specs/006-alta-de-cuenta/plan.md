# Implementation Plan: Alta de cuenta y consentimiento en el registro

**Branch**: `006-alta-de-cuenta` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-alta-de-cuenta/spec.md`

## Summary

La feature 004 construyó la puerta de consentimiento y nadie la usa, porque **no hay ningún
momento en que la app se entere de que está tratando con un menor**. Esta feature es ese
momento: un alta por pasos que pregunta nombre, fecha de nacimiento y país, acepta los
términos, y cuando la fecha dice que es menor, pide el correo del acudiente y emite la
solicitud que la 004 ya sabía atender.

Lo que no es: una feature de pantallas. Es **una decisión sobre quién puede pedir un
consentimiento**, y esa decisión choca con una que la 004 ya había tomado. La investigación
([research.md](research.md), D1) explica el choque y lo resuelve dejando que el nadador
declare el correo y **grabando de dónde vino**, para que el entrenador lo distinga.

---

## Technical Context

**Language/Version**: Dart 3.12.2 / Flutter 3.44.2; TypeScript en Cloud Functions sobre Node 22

**Primary Dependencies**: las que ya hay. Esta feature **no añade ninguna** (principio VII)

**Storage**: Firestore (`usuarios`, `solicitudes`, `consentimientos`), y el almacenamiento
local que la 003 ya usa para lo que va a medias

**Testing**: `flutter test` para dominio e interfaz; `node --test` con emuladores para reglas
y servidor

**Target Platform**: PWA en navegador, usada desde teléfonos a pie de piscina

**Project Type**: app móvil con servidor

**Performance Goals**: el alta se completa en menos de dos minutos (SC-001)

**Constraints**: funciona sin conexión hasta el envío final; el cliente **no escribe** el
perfil; nada de esto llega a los registros

**Scale/Scope**: cuatro a seis pantallas nuevas, una operación de servidor nueva, un campo
nuevo en dos colecciones existentes

---

## Constitution Check

*GATE: debe pasar antes de la fase 0, y volver a comprobarse tras la fase 1.*

| Principio | Cómo lo cumple | Estado |
|---|---|---|
| **I — Metodología como norma** | La edad no toca nada metodológico. La categoría se sigue declarando por habilidades (sección 11.1), y una frontera lo vigila (A7) | ✅ |
| **II — Dominio en Dart puro** | Perfil, edad y declaración de acudiente son dominio puro. Firestore y Functions se quedan en `datos/` y `firebase/` | ✅ |
| **III — Pruebas (NO NEGOCIABLE)** | Lo que esta feature decide llega al nadador: si se le pide consentimiento o no. 18 garantías con prueba en el contrato | ✅ |
| **IV — El criterio del entrenador no se delega** | La app no decide si un consentimiento declarado es de fiar: **lo marca y el entrenador decide**. Es la decisión D1 | ✅ |
| **V — Datos de deportistas** | Ver abajo: **un punto de tensión declarado** | ⚠️ |
| **VI — Freemium honesto** | No toca | — |
| **VII — Simplicidad** | Cero dependencias nuevas. Reutiliza el mecanismo de solicitud de la 004 entero | ✅ |
| **VIII — Control de carga interna** | No toca | — |

### Principio V — dos tensiones, declaradas

**1. Se guarda más dato del mínimo.** La 004 eligió `declaraSerMayorDeEdad` —un sí o un no—
sobre la fecha de nacimiento, **por minimización**, y lo dejó escrito. Esta feature guarda la
fecha (decisión del entrenador, Q3).

Se acepta porque un booleano **envejece**: quien se registra con 17 figura como menor para
siempre, y una respuesta equivocada aquí significa no pedir un consentimiento que hacía falta.
Queda compensado con A6, que exige que la minoría se recalcule, y con A7, que impide que la
fecha se use para otra cosa.

**2. El canal del consentimiento puede venir del propio menor.** La 004 lo prohibió con un
modelo de amenaza explícito: un niño que pone una dirección suya se autoriza a sí mismo.

No se resuelve prohibiéndolo —eso bloquearía a la familia hasta que el entrenador haga un
trámite— ni permitiéndolo en silencio —eso borraría la distinción—. Se resuelve **grabando el
origen** y enseñándoselo al entrenador (A9). El consentimiento declarado es válido y es
visiblemente de segunda mano.

**Esto es lo que más conviene revisar de toda la feature.** Está en
[Complexity Tracking](#complexity-tracking).

---

## Project Structure

### Documentation (this feature)

```text
specs/006-alta-de-cuenta/
├── plan.md              # Este archivo
├── research.md          # D1 a D7: los conflictos con la 004 y cómo se resuelven
├── data-model.md        # Perfil, edad, declaración de acudiente
├── quickstart.md        # 15 escenarios
├── contracts/
│   └── alta_de_cuenta.md   # 18 garantías, A1 a A18
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── cuentas/
│   │   ├── perfil.dart              # nuevo: el perfil y si está completo
│   │   └── edad.dart                # nuevo: EL sitio que decide si alguien es menor
│   └── consentimiento/
│       └── declaracion.dart         # nuevo: acudiente declarado, con su origen
├── datos/
│   └── perfil/
│       ├── repositorio_perfil.dart  # nuevo
│       └── perfil_firestore.dart    # nuevo: llama a la operación del servidor
└── ui/
    └── alta/                        # nuevo: las pantallas por pasos
        ├── estado_alta.dart         #   el recorrido y lo que lleva escrito
        ├── pantalla_alta.dart       #   el contenedor con los pasos
        ├── paso_nombre.dart
        ├── paso_nacimiento.dart
        ├── paso_pais.dart
        ├── paso_terminos.dart
        └── paso_acudiente.dart      #   solo si es menor

assets/terminos/texto_v1.md          # nuevo: borrador, pendiente de revisión legal

firebase/
├── firestore.rules                  # `usuarios` sigue en write: if false
└── functions/src/
    ├── perfil.ts                    # nuevo: guardarPerfil
    └── consentimiento.ts            # cambia: emitir desde una declaración, con origen

test/
├── dominio/
│   ├── cuentas/{perfil,edad}_test.dart
│   ├── frontera_edad_test.dart      # A7
│   └── frontera_pais_test.dart      # A16
├── ui/alta/…
└── ui/tema/ayuda_pantallas.dart     # cambia: las pantallas nuevas entran al banco

firebase/test/                       # cambia: reglas y servidor del perfil y el origen
```

**Structure Decision**: la de siempre en este proyecto —dominio puro, datos, interfaz— con
`lib/ui/alta/` como carpeta nueva. El perfil de cuenta va a `usuarios/{uid}` y **no** a
`nadadores/`, porque son cosas distintas que comparten la palabra «nombre» (research.md, D4).

---

## Fases

### Fase 0 — Investigación ✅

[research.md](research.md). Siete decisiones, tres de ellas conflictos reales con la feature
004 que la especificación no podía ver:

| | Qué |
|---|---|
| **D1** | Quién puede pedir un consentimiento. **El conflicto grande** |
| **D2** | Fecha de nacimiento frente a `declaraSerMayorDeEdad`, que ya existe |
| **D3** | El cliente no puede escribir `usuarios/{uid}`, y no se va a aflojar |
| **D4** | El perfil de cuenta no es la ficha de nadador |
| **D5** | Términos versionados, pendientes de revisión legal |
| **D6** | Lo que va a medias se queda en el dispositivo |
| **D7** | El país no decide nada, y una prueba lo vigila |

### Fase 1 — Diseño ✅

- [data-model.md](data-model.md) — perfil, el único sitio que decide la minoría de edad, y la
  declaración de acudiente con su origen
- [contracts/alta_de_cuenta.md](contracts/alta_de_cuenta.md) — 18 garantías
- [quickstart.md](quickstart.md) — 15 escenarios

### Re-comprobación constitucional tras el diseño

Nada empeoró. Las dos tensiones del principio V siguen siendo las mismas, declaradas y
compensadas. El diseño **no añadió** ninguna dependencia ni ninguna colección nueva: el perfil
va donde ya había un sitio para él y la solicitud gana un campo.

Lo que el diseño sí añadió es **tres pruebas de frontera** —edad, país, y las pantallas en el
banco—, que es la forma que este proyecto ha encontrado de que una regla sobreviva seis meses.

---

## Complexity Tracking

| Violación | Por qué hace falta | Alternativa más simple, y por qué se descartó |
|---|---|---|
| Se guarda la **fecha de nacimiento** donde la 004 guardaba un booleano, con más dato personal del mínimo | Un booleano envejece: quien se registra con 17 figura como menor para siempre, y eso significa no pedir un consentimiento que hacía falta | *Seguir con el booleano*: produce respuestas equivocadas todos los días a partir del cumpleaños. *Preguntar de nuevo cada año*: una pantalla que nadie contesta |
| El **menor puede aportar el canal** del consentimiento, que la 004 prohibía | Si solo emite el entrenador, una familia que se da de alta un sábado espera al lunes, y una solicitud que nadie emite es el estado actual | *Solo el entrenador*: contradice FR-013 y deja el consentimiento colgando de un trámite que se olvida. *Dejar que lo aporte sin marcarlo*: borra la distinción que la 004 construyó y le quita al entrenador la información con la que decide |
| **Dos campos** contestan «¿es menor?» mientras queden cuentas sin completar | Hay cuentas en producción que solo tienen el booleano, y borrarlo rompería pruebas de la 004 | *Borrar el booleano ya*: rompe lo que está en uso. Se queda con papel reducido, y A4 exige **un solo sitio** que decida |

---

## Lo que este plan no puede cerrar

- **El texto de los términos y condiciones** necesita revisión legal antes de que lo lea una
  familia real. La feature se construye con un borrador; no se cierra con él. Es la misma
  deuda que la 004 dejó con el texto de consentimiento, que **sigue pendiente**.
- **Que el alta se entienda** solo lo dice un nadador de nueve años completándola sin
  preguntar.
- **La historia 3 toca cuentas en producción.** Conviene probarla contra una cuenta de verdad
  antes de desplegar.
