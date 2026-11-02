# Implementation Plan: El HUB y los dos recorridos

**Branch**: `007-hub-y-recorridos` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-hub-y-recorridos/spec.md`

## Summary

Cinco destinos —`Generar`, `Ver Plan`, `Home`, `Análisis`, `Ajustes`— con la misma barra para
los dos roles y contenido distinto dentro. La mayor parte del trabajo es **mudanza**: las
pantallas de las features 001 a 003 cambian de sitio sin cambiar de comportamiento.

Lo verdaderamente nuevo son tres cosas, y la tercera es la que pesa:

1. **`Home`**, una pantalla por rol, construida de datos que ya existen.
2. **El reparto por rol**, que hoy son dos listas paralelas y un índice compartido dentro de
   `main.dart` —con un comentario propio advirtiendo del riesgo— y pasa a ser una tabla
   declarativa en Dart puro, comprobable sin pintar nada.
3. **`Ajustes`**, que es donde los tres derechos de la Ley 1581 dejan de ser inalcanzables. Y
   ahí el plan se topa con las reglas de acceso: **la supresión no se puede ejecutar desde el
   cliente**. `registros` tiene `allow delete: if false`, `nadadores` solo lo escribe el
   entrenador y `usuarios` no lo escribe nadie. `DerechosDelTitular.eliminar` existe desde la
   feature 004 y solo funciona contra repositorios locales: por eso sus pruebas pasan y nadie
   lo había notado. Hace falta una función de servidor, que es exactamente lo que el
   comentario de esa regla ya anticipaba.

Sin dependencias nuevas.

## Technical Context

**Language/Version**: Dart 3.12.2 / Flutter 3.44.2. TypeScript en Node 22 para el servidor.

**Primary Dependencies**: `provider`, `cloud_firestore`, `shared_preferences`, `firebase_auth`
(un solo archivo), `cloud_functions` (un solo archivo), `web` (un solo archivo, solo web).
**Esta feature no añade ninguna.**

**Storage**: Firestore para lo compartido; `SharedPreferences` para lo del dispositivo. La
preferencia de apariencia es el único dato nuevo que esta feature guarda, y **no puede vivir
en `AlmacenLocal`**: `cerrarSesion()` llama a `vaciar()` y se la llevaría (decisión D4).

**Testing**: `flutter_test` (1283 pruebas hoy) y `@firebase/rules-unit-testing` más las de
servidor (79 hoy). La función nueva de supresión corre con el Admin SDK, que se salta las
reglas, así que lo que la vigila son pruebas de servidor y no de reglas.

**Target Platform**: PWA en Firebase Hosting, usada en teléfono a pie de piscina. Android más
adelante.

**Project Type**: una sola app Flutter con un dominio en Dart puro, más funciones de servidor.

**Performance Goals**: `Home` abre con lo que haya en el dispositivo, sin esperar red. El
resumen del entrenador se arma con cinco consultas como máximo, no con una por nadador.

**Constraints**: sin conexión como caso normal; reglas que deniegan por defecto; vocabulario
en español; colores, medidas y tipografía solo de la feature 005.

**Scale/Scope**: un entrenador, decenas de nadadores. Cinco destinos por dos recorridos, dos
pantallas `Home` nuevas, una sección `Ajustes` con seis capacidades, dos operaciones nuevas de
servidor.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitución v1.2.0, los ocho principios.

| Principio | Cómo lo cumple esta feature |
|---|---|
| **I. Metodología como norma** | No interpreta ninguna regla de la metodología. Los números de `Home` son cuentas, no juicios: «cuántos planes esperan aprobación» no dice si están bien. |
| **II. Dominio en Dart puro** | El reparto de destinos por rol y los dos resúmenes van a `lib/dominio/`, sin Flutter ni Firebase. La prueba de arquitectura ya vigila la frontera y hay que extenderla a los directorios nuevos. |
| **III. Pruebas (NO NEGOCIABLE)** | Cada cierre se escribe **antes** de lo que protege y se verifica con su control negativo. Los tres cierres de esta feature: ningún contenido del otro rol aparece en un recorrido; ningún destino ofrece un control que no haga nada; corregir el perfil no toca la constancia de términos. |
| **IV. El criterio no se delega** | Nada en esta feature aprueba, firma ni publica. `Home` cuenta lo que espera aprobación; aprobarlo sigue siendo un acto del entrenador en la pantalla que ya existe. El `Análisis` del nadador muestra lo que hizo, sin consejo automático. |
| **V. Datos mínimos, protegidos y portables** | Es el principio central de la feature: los tres derechos pasan de existir en el dominio a existir para la persona. Dos tensiones declaradas abajo. |
| **VI. Freemium honesto** | No se cobra nada y `Ajustes` no muestra precios. Será su sitio natural cuando exista la suscripción; hoy no se insinúa. |
| **VII. Rebanadas verticales y simplicidad** | Cero dependencias nuevas. La feature es ancha, así que el orden de entrega la parte en rebanadas usables: primero el HUB con las pantallas que ya existen, después `Home`, después `Ajustes`. Los destinos que esperan su feature la mantienen fuera de la 008, la 009 y la 010. |
| **VIII. Control de carga interna** | El camino del nadador para anotar su esfuerzo no se alarga en pasos, pero **sí en un toque**, y eso se declara abajo. |

### Principio V — dos tensiones, declaradas

**La supresión la ejecuta el propio menor** (FR-023, decisión del entrenador el 2026-10-25,
contraria a mi recomendación y tomada después de leerla). La feature 004 puso en el acudiente
la autoridad para que los datos se guarden; esta decisión no se la pide para borrarlos. Lo que
el plan añade por la irreversibilidad del borrado es confirmación en dos pasos, no un permiso
de nadie. Queda escrito en la spec y aquí porque es una decisión con peso legal y tiene que
leerse como decisión.

**La exportación produce un archivo con datos personales en el dispositivo.** Es el derecho de
portabilidad y por eso se construye, pero obliga a lo mismo que la garantía A17 de la 006:
nada de ese contenido puede pasar por un registro, una traza ni una métrica. El cierre que lo
protege es una prueba, no una intención.

### Principio VIII — un toque más, y por qué

Hoy el nadador abre la app y cae directamente en su sesión del día: es la primera pestaña que
le toca. **Cero toques.** Con `Home` como portada pasa a ser **un** toque.

Es una regresión pequeña y real, y el principio VIII dice que anotar la carga interna no debe
ser difícil. Se acepta porque `Home` al centro es lo que el entrenador pidió y porque el
resumen contesta la pregunta que el nadador se hace al abrir —cómo voy— que hoy no tiene
respuesta en ninguna parte. Para que el toque no se pague dos veces, lo primero del `Home` del
nadador es su sesión de hoy con el camino a `Ver Plan`, no un gráfico.

La alternativa —abrir al nadador en `Ver Plan` y al entrenador en `Home`— se rechaza porque
hace que la posición central signifique dos cosas distintas según quién entre, y la barra
tiene que ser la misma para los dos.

## Project Structure

### Documentation (this feature)

```text
specs/007-hub-y-recorridos/
├── plan.md              # Este archivo
├── spec.md              # Qué y por qué
├── research.md          # Fase 0: las decisiones, con sus alternativas
├── data-model.md        # Fase 1: las entidades y de dónde sale cada dato
├── quickstart.md        # Fase 1: cómo se comprueba que funciona
├── contracts/
│   └── hub_y_ajustes.md # Fase 1: las garantías, y el cuerpo exacto de cada llamada
├── checklists/
│   └── requirements.md  # Calidad de la spec
└── tasks.md             # Lo genera /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── hub/                        # NUEVO, Dart puro
│   │   ├── destino.dart            #   los cinco, su orden, de quién es cada contenido
│   │   ├── resumen_del_nadador.dart
│   │   └── resumen_del_entrenador.dart
│   ├── datos_personales/
│   │   └── derechos_del_titular.dart   # existe; aquí se enchufa por primera vez
│   └── repositorios/
│       └── repositorios.dart       # + nadadoresConRegistros(), + pedirCambioDeClave()
├── ui/
│   ├── hub/                        # NUEVO
│   │   ├── hub.dart                #   la barra y el índice; sale de main.dart
│   │   ├── contenidos.dart         #   destino × rol -> widget
│   │   ├── home_del_nadador.dart
│   │   ├── home_del_entrenador.dart
│   │   └── todavia_no.dart         #   lo que muestra un destino que espera su feature
│   └── ajustes/                    # NUEVO
│       ├── pantalla_ajustes.dart
│       ├── mis_datos.dart          #   ver y corregir
│       ├── lo_que_acepte.dart      #   el texto y la versión que aceptó, con su fecha
│       ├── mis_derechos.dart       #   qué se guarda, llevárselo
│       ├── supresion.dart          #   los dos pasos
│       └── apariencia.dart         #   claro / oscuro / el del sistema
├── datos/
│   ├── preferencias/               # NUEVO
│   │   └── apariencia.dart         #   preferencia de dispositivo, fuera del almacén de cuenta
│   ├── auth/sesion_firebase.dart   # + cambio de contraseña por correo verificado
│   ├── servidor/operaciones.dart   # + corregirPerfil, + suprimirMisDatos
│   └── firestore/repositorios_firestore.dart  # + nadadoresConRegistros()
└── main.dart                       # adelgaza: la pantalla principal se va a ui/hub/

firebase/functions/src/
├── datos_personales.ts             # NUEVO: corregirPerfil y suprimirMisDatos
└── index.ts                        # + los dos export

test/
├── dominio/hub/                    # el reparto y los dos resúmenes, sin pintar nada
├── ui/hub/                         # los cinco destinos, los dos recorridos, los vacíos
├── ui/ajustes/                     # las seis capacidades
├── datos/servidor/                 # el contrato de las dos llamadas nuevas, leyendo el .ts
└── widget_test.dart                # se actualizan sus pruebas de navegación (FR-033)

firebase/test/
└── datos_personales.test.ts        # NUEVO: qué borra y qué sobrevive
```

**Structure Decision**: la app sigue siendo un solo proyecto Flutter con el dominio en Dart
puro y las funciones aparte. Lo único que cambia de forma es que **la pantalla principal sale
de `main.dart`**: hoy son unas 350 líneas dentro de un archivo de 900, y meterle cinco
destinos por dos recorridos lo llevaría por encima de 1200 (decisión D1).

## Fases

### Fase 0 — Investigación

Salida: [research.md](./research.md), con trece decisiones. Las cuatro que condicionan todo lo
demás:

- **D2** — el reparto por rol pasa a ser una tabla declarativa en el dominio, no dos listas
  paralelas con un índice compartido.
- **D5** — corregir el perfil **no** puede reutilizar `guardarPerfil`: exige la versión de
  términos y volvería a estampar `terminos.aceptadaEn` con la fecha de hoy, falsificando la
  constancia de qué versión aceptó la persona. Y no actualiza el nombre en la ficha de
  nadador, así que el panel del entrenador se quedaría con el viejo.
- **D6** — la supresión va al servidor porque las reglas no dejan otra salida, y reutiliza el
  orden que `DerechosDelTitular` ya estableció.
- **D7** — qué se borra, qué sobrevive, y si se borra también la cuenta de identidad.

### Fase 1 — Diseño

Salidas:

- [data-model.md](./data-model.md) — las siete entidades, sus campos con sus restricciones, y
  **de dónde sale cada dato**: qué es nuevo, qué se deriva y qué ya existe.
- [contracts/hub_y_ajustes.md](./contracts/hub_y_ajustes.md) — las garantías H1–H20 y el
  **cuerpo exacto** de las dos llamadas nuevas. Lo segundo es por la lección de la 006: los
  dobles de las pruebas implementan la interfaz, no el cable, y un cuerpo mal formado pasó
  diez pruebas verdes. Cada llamada nueva lleva su prueba de contrato contra el fuente del
  servidor.
- [quickstart.md](./quickstart.md) — los escenarios de validación, incluidos los que solo
  puede hacer el entrenador en un teléfono de verdad.

### Re-comprobación constitucional tras el diseño

Nada del diseño añade dependencias, capas ni gestores de estado. Lo que el diseño sí descubrió
—y queda arriba, no escondido— es que el principio V obligaba a servidor donde la spec daba a
entender que bastaba una pantalla, y que el principio VIII paga un toque. Las dos cosas están
declaradas con su alternativa rechazada.

## Complexity Tracking

| Violación | Por qué hace falta | Alternativa más simple, y por qué se rechaza |
|---|---|---|
| Dos destinos que no hacen nada todavía | La barra tiene que estar completa desde el principio para que nadie aprenda una disposición que va a cambiar | Ocultarlos hasta tener contenido: enseña cinco posiciones distintas en tres features seguidas |
| Una función de servidor nueva para la supresión | `registros` tiene `allow delete: if false`, y `nadadores` y `usuarios` no los escribe el titular. Es la vía que el propio comentario de la regla reserva al servidor | Abrir tres reglas para que el cliente borre: la de `registros` está cerrada a propósito para que el borrado deje constancia de que se ejerció |
| Una segunda función que escribe el perfil | `guardarPerfil` exige la versión de términos y re-sella la aceptación con la fecha de hoy | Reutilizarla: corregir un apellido falsificaría la constancia de qué versión se aceptó y cuándo |
| Un método nuevo en el repositorio de registros | «En uso» necesita saber qué nadadores han respondido algo | Contar por nadador: son N consultas en lugar de una, y el número de nadadores crece |
| Una preferencia que sobrevive al cierre de sesión | La apariencia es del dispositivo, no de la persona, y `vaciar()` borra todo lo de la cuenta | Guardarla con lo demás: desaparecería cada vez que alguien sale, en el teléfono que comparten hermanos |

## Lo que este plan no puede cerrar

**Si la supresión borra también la cuenta de identidad.** El plan propone que sí (decisión
D7): el correo es un dato personal, y dejar la cuenta viva convertiría el derecho de supresión
en un vaciado que deja a la persona registrada y sin nada. Pero es irreversible y afecta a
quien ya esté usando la app, así que **lo confirma el entrenador antes de que esa tarea se
ejecute**, igual que confirmó los valores de la paleta en la 005.

**Qué muestra exactamente el `Home` del entrenador cuando los cuatro números son cero.** Hay
que verlo en pantalla con sus propios datos; se decide en la implementación con él delante, no
aquí.

**Los textos de `Ajustes` que hablan de derechos** los redacta el plan, pero quien los valida
es la misma revisión legal que sigue pendiente para los términos y el consentimiento. No
bloquean esta feature: bloquean que la lea una familia real.
