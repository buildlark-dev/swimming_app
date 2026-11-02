# Feature Specification: The swimmer's request

**Feature Branch**: `008-swimmer-request`

**Created**: 2026-11-02

**Status**: Draft

**Input**: User description: "La solicitud del nadador. Un nadador puede pedirle a su entrenador un plan: responde una lista corta de preguntas —qué quiere trabajar, cuántos días puede entrenar, qué molestias tiene, qué prueba le viene— y de ahí sale un borrador que llega a la cola del entrenador. El borrador no es un plan: nadie lo recibe, nadie lo nada, y no sale de la cola sin la firma del entrenador. Él puede corregirlo entero, rechazarlo diciendo por qué, o aprobarlo; el nadador ve en qué estado va lo que pidió. Un nadador no puede pedir por otro, y un menor sin consentimiento vigente no puede pedir nada que salga del teléfono. El vocabulario visible sigue en español. Las preguntas son todas las que el motor necesite (el entrenador pidió revisar el prompt maestro para saber cuáles), y el borrador lo genera el motor determinista de la feature 002."

## Lo primero que hay que decir: el nadador no puede responder once preguntas

El entrenador pidió «todas las preguntas que sean necesarias, según el prompt maestro». La
sección 5 del `PROMPT_MAESTRO_V3.4` enumera once datos obligatorios antes de generar nada, y
el motor determinista de la feature 002 los pide igual. Al cruzarlos con quién sabe cada
cosa, el resultado no es una lista de once preguntas:

| Dato que el motor necesita | De dónde sale |
|---|---|
| Categoría del nadador | **Su ficha.** La asigna el entrenador; no es opinión del nadador |
| Estilo objetivo | Su ficha, y el nadador **confirma o pide otro** |
| Prueba objetivo | Su ficha, y el nadador **confirma o pide otra** |
| Diagnóstico técnico | **Su ficha.** Son errores observados por el entrenador. Un nadador no se autodiagnostica |
| Fase ATR | **Nadie se la puede preguntar al nadador** |
| Componente acentuado | **Nadie se la puede preguntar al nadador** |
| Días disponibles | **El nadador**, que es quien sabe cuándo puede ir |
| Duración de sesión | **El nadador** |
| Longitud de piscina | **El nadador**, que sabe dónde entrena |
| Fecha de la competencia | **El nadador**, que sabe cuándo compite. Es un hecho, no criterio |
| Fechas sin servicio | El club. No es dato del nadador |
| Lesiones o molestias | **Sus sesiones recientes**, no una pregunta nueva (aclaración Q2) |

Así que la lista corta **es corta por necesidad, no por comodidad**: el nadador responde
cinco cosas y confirma dos. Lo demás ya está en su ficha, sale de sus sesiones o es criterio
del entrenador, y preguntárselo sería pedirle que opine sobre lo que no le toca. El principio
IV dice que el criterio del entrenador no se delega; esto es el caso más directo de ese
principio desde que existe el proyecto, porque aquí la petición **viene de abajo**.

## Clarifications

### Session 2026-11-02

- **Q: El motor exige fase ATR cuando la categoría la usa, la prohíbe cuando no, y valida el
  componente acentuado contra ella. Ninguna es dato del nadador. ¿Qué pasa con ellas?**
  → **A: el sistema las deriva.** La fase, contando hacia atrás desde la fecha de la
  competencia con las duraciones de bloque que la sección 12 cita (Issurin 2010: Realización
  8-15 días, Transformación 2-4 semanas, Acumulación 2-6 semanas). El componente acentuado,
  de la fase.

  Esto tiene **dos consecuencias que el entrenador debe saber**, y están escritas aquí para
  que no se descubran al usarlo:

  1. **Hay una pregunta más para el nadador: cuándo es su competencia.** Sin fecha no hay
     fase que derivar. Es un hecho que él sabe, no un criterio, así que se le puede preguntar
     — pero si no la sabe, el sistema **no inventa una fase**: la solicitud llega a la cola
     sin borrador, con la fase pendiente de que el entrenador la ponga (regla R3: ante datos
     faltantes se pregunta, no se supone).
  2. **La derivación es una regla, y las reglas de esta app se auditan.** La fase derivada
     queda escrita en el borrador junto con de dónde salió, para que el entrenador vea «fase
     Transformación porque la competencia es en 24 días» y pueda cambiarla de un toque. Una
     fase derivada que no se puede ver ni corregir sería criterio delegado por la puerta de
     atrás.

- **Q: La feature 003 ya recoge molestias por sesión, y son datos de salud de un menor. ¿Se
  vuelve a preguntar aquí?**
  → **A: no se pregunta.** La solicitud enlaza lo que el nadador ya reportó en sus sesiones
  recientes y el entrenador lo ve al abrirla. Ni un dato de salud nuevo, ni un almacén nuevo,
  ni una pregunta más en una lista que tiene que poder responder alguien de nueve años.

  La contrapartida, dicha en voz alta: **una molestia que apareció hoy no estará ahí si no ha
  habido sesión donde contarla.** Lo que la app no hace es fingir que sí: la solicitud dice
  de qué fechas salieron las molestias que muestra, y si no hay ninguna reciente, lo dice
  también, en lugar de un silencio que se lee como «no le duele nada».

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El nadador pide, y lo que sale es un borrador (Priority: P1)

Un nadador abre `Generar` —que hasta ahora le decía «todavía no»— y encuentra una lista
corta: qué quiere trabajar, qué prueba le viene, cuándo es su competencia, qué días puede
entrenar, cuánto dura cada sesión y en qué piscina. Responde, envía, y la app le dice que su
solicitud llegó. **No le dice que tiene un plan**, porque no lo tiene.

**Why this priority**: es la feature. Sin esto no hay nada: es la primera vez en el producto
que un nadador propone algo en lugar de solo recibir y responder.

**Independent Test**: se prueba entero con una cuenta de nadador: contestar la lista, enviar
y ver que la solicitud queda registrada y que en ninguna pantalla del nadador aparece un plan
nuevo.

**Acceptance Scenarios**:

1. **Given** un nadador con ficha y consentimiento vigente, **When** responde la lista y
   envía, **Then** su solicitud queda registrada y él ve en qué estado va
2. **Given** una solicitud recién enviada, **When** el nadador recorre sus destinos,
   **Then** no aparece ningún plan nuevo ni ninguna sesión nueva suya
3. **Given** la lista a medio responder, **When** falta un dato que el motor necesita,
   **Then** la app dice cuál falta y no deja enviar
4. **Given** un nadador sin ficha, **When** abre `Generar`, **Then** se le explica que su
   entrenador todavía no lo ha inscrito, en lugar de una lista que no puede llevar a nada
5. **Given** un nadador de categoría con ATR que dice cuándo es su competencia, **When** se
   genera el borrador, **Then** la fase sale de contar hacia atrás desde esa fecha, y el
   borrador dice cuál salió y por qué
6. **Given** un nadador que no sabe cuándo compite, **When** envía, **Then** la solicitud
   llega igual, sin borrador y con la fase pendiente del entrenador
7. **Given** un nadador de categoría sin ATR, **When** se genera el borrador, **Then** no
   lleva fase, porque el motor la prohíbe ahí

---

### User Story 2 - La cola del entrenador (Priority: P1)

El entrenador ve las solicitudes que le llegaron, con quién la pidió y qué pidió, y puede
abrir el borrador que salió de ella. Desde ahí: corregirlo entero con el editor que ya
existe, rechazarlo **diciendo por qué**, o aprobarlo. Nada de eso es automático.

**Why this priority**: igual de crítica que la primera. Una solicitud que llega a una cola
que nadie puede atender no es una solicitud, es un formulario que no va a ninguna parte.

**Independent Test**: con una solicitud sembrada, el entrenador la abre, la rechaza con un
motivo, y el nadador ve el motivo.

**Acceptance Scenarios**:

1. **Given** una solicitud en la cola, **When** el entrenador la abre, **Then** ve quién la
   pidió, qué respondió y el borrador que salió
2. **Given** un borrador de solicitud, **When** el entrenador lo corrige, **Then** usa el
   mismo editor y la misma auditoría que un plan suyo
3. **Given** una solicitud que el entrenador rechaza, **When** la rechaza, **Then** tiene que
   escribir un motivo, y sin motivo no se puede rechazar
4. **Given** una solicitud rechazada, **When** el nadador mira su solicitud, **Then** lee el
   motivo que escribió su entrenador
5. **Given** un borrador que no pasa la auditoría de la sección 16, **When** el entrenador
   intenta aprobarlo, **Then** no puede, y ve qué criterios faltan

---

### User Story 3 - El nadador ve en qué va lo suyo (Priority: P2)

El nadador ve el estado de lo que pidió: esperando, en revisión, aprobado o rechazado con su
motivo. Sin fechas prometidas y sin lenguaje que insinúe que hay algo nadable antes de que lo
haya.

**Why this priority**: sin esto la solicitud se siente como un sobre echado al correo. Pero
la feature funciona sin ella —el entrenador puede trabajar la cola igual—, así que va después.

**Independent Test**: mover una solicitud por sus cuatro estados y ver que el nadador lee cada
uno, sin inventar fechas.

**Acceptance Scenarios**:

1. **Given** una solicitud en cada uno de sus estados, **When** el nadador la mira, **Then**
   lee en cuál está, en español y sin jerga
2. **Given** una solicitud esperando, **When** el nadador la mira, **Then** no se le promete
   ninguna fecha de respuesta

---

### User Story 4 - La puerta del menor, también aquí (Priority: P1)

Un menor sin consentimiento vigente no manda nada fuera del teléfono. La lista se puede
responder y lo respondido se queda en el dispositivo, igual que sus registros de la feature
003; la app dice que falta la autorización de su acudiente y **no finge que la solicitud se
envió**.

**Why this priority**: es el principio V, y es la misma puerta que la feature 004 construyó.
Dejarla fuera aquí abriría un camino nuevo por donde los datos de un menor salen sin
autorización, que es exactamente lo que esa puerta existe para impedir.

**Independent Test**: con un menor sin consentimiento vigente, responder la lista y comprobar
contra el servidor que no llegó nada, y que la app lo dijo.

**Acceptance Scenarios**:

1. **Given** un menor sin consentimiento vigente, **When** responde la lista y envía,
   **Then** nada sale del dispositivo y la app explica que falta la autorización
2. **Given** ese mismo nadador, **When** su acudiente autoriza, **Then** lo que estaba
   retenido puede salir sin volver a escribirlo
3. **Given** un nadador cualquiera, **When** intenta pedir en nombre de otro, **Then** no
   puede: una solicitud es de quien la manda y de nadie más

---

### Edge Cases

- **El nadador ya tiene una solicitud esperando.** No se acumulan: mientras una esté sin
  responder, no manda otra, y se le dice por qué.
- **El nadador pide días que no existen** —siete sesiones semanales en Iniciación—. El motor
  tiene rangos por categoría y la auditoría los comprueba: el borrador sale marcado con lo
  que no cuadra, y es el entrenador quien decide, no la app.
- **El nadador arrastra una molestia de sus sesiones recientes.** No modifica el plan. La
  metodología es explícita: se registra y se avisa, porque deducir qué ejercicio está
  contraindicado sería simular criterio clínico. Lo que cambia es que el entrenador la ve
  cuando decide, no después.
- **La ficha del nadador está incompleta** —sin categoría, sin prueba objetivo—. El motor no
  puede partir de ahí. Se le dice que su entrenador tiene que completar su ficha, en lugar de
  generar con huecos rellenados a ojo (regla R3: ante datos faltantes se pregunta).
- **El entrenador aprueba el borrador y luego cambia de idea.** Un plan aprobado o publicado
  es inmutable (FR-025 de la 001): lo que hay es una versión nueva, no una edición.
- **Dos solicitudes del mismo nadador separadas por semanas.** La segunda no hereda nada de
  la primera: cada una se responde entera.
- **El nadador deja de serlo** —su ficha se borra por supresión de datos (feature 007)—. Sus
  solicitudes se van con lo suyo.
- **Llega una solicitud mientras el entrenador no tiene conexión.** La cola es lectura: se ve
  lo que haya en caché y se dice que puede faltar lo último.

## Requirements *(mandatory)*

### Functional Requirements

**La lista de preguntas**

- **FR-001**: La app DEBE preguntarle al nadador solo lo que él sabe: días en que puede
  entrenar, cuánto dura cada sesión, en qué longitud de piscina entrena y cuándo es la
  competencia que le viene
- **FR-002**: La app DEBE mostrarle el estilo y la prueba objetivo que tiene en su ficha, y
  dejarle **confirmar o pedir otros** para esta solicitud
- **FR-003**: La app NO DEBE preguntarle al nadador su categoría, su fase ATR, su componente
  acentuado ni su diagnóstico técnico. Los dos primeros salen de su ficha o del entrenador;
  los otros dos son criterio del entrenador
- **FR-004**: La app NO DEBE dejar enviar una solicitud a la que le falte un dato que el motor
  necesita, y DEBE decir cuál falta
- **FR-005**: Cada pregunta DEBE poder responderse **sin escribir texto libre**: la lista
  entera se contesta tocando
- **FR-006**: El nadador DEBE poder decir que **no sabe cuándo es su competencia**, y esa
  respuesta NO DEBE impedirle enviar la solicitud
- **FR-007**: La lista DEBE poder responderse sin conexión, y lo respondido DEBE sobrevivir a
  cerrar la app

**Lo que sale de la lista**

- **FR-008**: El borrador DEBE generarlo el **motor determinista de la feature 002**, sin
  modelo de lenguaje, con las reglas ya codificadas
- **FR-009**: El borrador DEBE nacer en estado `borrador`, como cualquier salida de la
  automatización (principio IV)
- **FR-010**: El borrador DEBE quedar marcado con **cómo** se generó y a partir de qué
  solicitud, y con la versión de metodología bajo la que se construyó
- **FR-011**: El borrador DEBE pasar la auditoría de la sección 16 antes de poder aprobarse, y
  la app DEBE mostrar qué criterios cumple y cuáles no
- **FR-012**: El sistema NO DEBE entregar, publicar ni asignar el borrador a nadie por el
  hecho de haberse generado
- **FR-013**: El nadador NO DEBE poder ver el contenido del borrador antes de que su
  entrenador lo apruebe: lo que él ve es el estado de su solicitud
- **FR-014**: Cuando la categoría usa ATR, el sistema DEBE **derivar la fase** contando hacia
  atrás desde la fecha de la competencia, con las duraciones de bloque citadas en la sección
  12 de la metodología: Realización los últimos 8-15 días, Transformación las 2-4 semanas
  anteriores, Acumulación antes de eso
- **FR-015**: Cuando la categoría **no** usa ATR, el sistema NO DEBE poner fase: el motor la
  prohíbe en ese caso
- **FR-016**: El sistema DEBE derivar el componente acentuado de la fase, y el resultado DEBE
  pasar la comprobación de coherencia que el motor ya hace entre fase y componente
- **FR-017**: El borrador DEBE mostrar **qué fase se derivó y por qué** —en términos de la
  fecha de competencia y los días que faltan—, y el entrenador DEBE poder cambiarla
- **FR-018**: Si no hay fecha de competencia y la categoría usa ATR, el sistema NO DEBE
  generar borrador: la solicitud DEBE llegar a la cola con la fase pendiente, para que el
  entrenador la ponga (regla R3)

**La cola del entrenador**

- **FR-019**: El entrenador DEBE ver las solicitudes que le llegaron, con quién la pidió,
  cuándo, qué respondió y el borrador que salió
- **FR-020**: El entrenador DEBE poder corregir el borrador con el mismo editor y la misma
  auditoría que un plan propio
- **FR-021**: El entrenador DEBE poder rechazar una solicitud, y el sistema DEBE exigirle un
  motivo escrito
- **FR-022**: El entrenador DEBE poder aprobar el borrador, y solo él
- **FR-023**: El sistema NO DEBE mover una solicitud de estado por su cuenta, ni por tiempo
  transcurrido ni por ninguna otra regla automática
- **FR-024**: La cola DEBE distinguir lo que espera respuesta de lo que ya se respondió

**Lo que el nadador ve**

- **FR-025**: El nadador DEBE ver en qué estado va su solicitud: esperando, en revisión,
  aprobada o rechazada
- **FR-026**: Si fue rechazada, el nadador DEBE leer el motivo que escribió su entrenador
- **FR-027**: El sistema NO DEBE prometerle al nadador ninguna fecha de respuesta
- **FR-028**: El vocabulario visible DEBE seguir en español y con la notación del entrenador

**Quién puede pedir**

- **FR-029**: Una solicitud DEBE pertenecer a quien la mandó. Un nadador NO DEBE poder pedir
  en nombre de otro, ni leer la solicitud de otro
- **FR-030**: Un menor sin consentimiento vigente NO DEBE poder mandar una solicitud fuera del
  dispositivo, y la app DEBE decir que falta la autorización de su acudiente en lugar de
  fingir que se envió
- **FR-031**: Lo retenido por falta de consentimiento DEBE poder salir, sin volver a
  escribirlo, en cuanto el consentimiento exista
- **FR-032**: Un nadador NO DEBE tener más de una solicitud esperando respuesta a la vez
- **FR-033**: Al suprimirse los datos de un nadador (feature 007), sus solicitudes DEBEN irse
  con ellos

**Las molestias**

- **FR-034**: La solicitud NO DEBE preguntar por molestias: DEBE enlazar las que el nadador ya
  reportó en sus sesiones recientes
- **FR-035**: Una molestia NO DEBE modificar el plan que genera el motor. La metodología es
  explícita: se registra y se avisa, porque deducir qué ejercicio está contraindicado sería
  simular criterio clínico
- **FR-036**: Las molestias enlazadas DEBEN hacerse visibles al entrenador al abrir la
  solicitud, sin resolverse automáticamente ni esconderse tras una respuesta genérica
  (principio IV)
- **FR-037**: La solicitud DEBE decir **de qué fechas** salieron las molestias que muestra, y
  DEBE decir explícitamente cuando no hay ninguna reciente, en lugar de callar: un hueco en
  blanco se lee como «no le duele nada»
- **FR-038**: La solicitud NO DEBE guardar una copia de las molestias: las enlaza donde ya
  viven, para que la supresión de datos del nadador se las lleve una sola vez

### Key Entities

- **Solicitud**: lo que un nadador pidió. Lleva de quién es, cuándo se mandó, lo que
  respondió, en qué estado va, y el motivo si fue rechazada. **No lleva el plan**: lleva la
  referencia al borrador que salió de ella
- **Respuestas de la solicitud**: los datos que el nadador aportó —días, duración, piscina,
  estilo y prueba confirmados o pedidos, fecha de competencia—. Es lo que hace la solicitud
  auditable:
  se puede ver con qué se generó el borrador
- **Estado de la solicitud**: `esperando` → `en revisión` → `aprobada` | `rechazada`.
  Solo el entrenador lo mueve
- **Fase derivada**: la fase ATR que el sistema dedujo, **con su razón** —la fecha de la
  competencia y los días que faltaban—. Va en el borrador para que el entrenador la vea y la
  pueda cambiar. Una fase derivada que no se puede ver ni corregir sería criterio delegado
  por la puerta de atrás
- **Molestias enlazadas**: no son de la solicitud. Son los reportes de la feature 003 que
  caen en la ventana reciente, mostrados con su fecha. La solicitud apunta a ellos; no los
  copia
- **Borrador generado**: un `Plan` en estado `borrador`, de los que ya existen desde la
  feature 001, marcado con su origen

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un nadador de nueve años responde la lista entera y la envía sin ayuda, en menos
  de tres minutos
- **SC-002**: Ninguna solicitud produce contenido visible para un nadador sin que su
  entrenador lo haya aprobado — comprobable en el 100% de los casos, incluido el de un
  borrador que pasa la auditoría a la primera
- **SC-003**: El 100% de los borradores generados desde una solicitud nacen en `borrador` y
  llevan registrado cómo se generaron y bajo qué versión de metodología
- **SC-004**: Dos solicitudes con las mismas respuestas y la misma ficha producen el mismo
  borrador, verificable sin conexión
- **SC-005**: Ninguna solicitud de un menor sin consentimiento vigente sale del dispositivo —
  comprobable contra el servidor, no solo en la pantalla
- **SC-006**: El entrenador pasa de ver una solicitud a tener el borrador delante en menos de
  dos toques
- **SC-007**: El 100% de los rechazos llevan un motivo escrito por el entrenador, y el nadador
  lo lee
- **SC-008**: Ningún nadador puede leer ni mandar la solicitud de otro, comprobado contra las
  reglas de acceso y no solo en la interfaz
- **SC-009**: El 100% de los borradores con fase derivada muestran **cuál es y por qué**, y
  el entrenador la cambia en un toque
- **SC-010**: Ningún borrador de categoría sin ATR lleva fase, y ninguno de categoría con ATR
  se genera sin ella — las dos caras de la regla, comprobadas
- **SC-011**: La solicitud no guarda ni una copia de una molestia: lo que el entrenador ve
  sale de donde ya vivía

## Assumptions

- **La solicitud produce un microciclo, no más.** El motor de la feature 002 genera una
  semana, y por encima del microciclo el dominio no tiene nada: `Macrociclo` y `Mesociclo`
  llegan en la 009. Pedir un plan largo desde aquí obligaría a inventar esa jerarquía de paso
- **El borrador aprobado sigue el ciclo de vida que ya existe** (`borrador` → `aprobado` →
  `publicado`, feature 001). Aprobar la solicitud no entrega el plan: entregarlo es el acto
  aparte que la feature 007 ya tiene en `Ver Plan`. Así el entrenador puede firmar hoy y
  entregar cuando le convenga
- **Las fechas sin servicio las pone el entrenador**, no el nadador: son del club. Si no hay
  ninguna declarada, el motor trabaja con los días que el nadador dijo
- **El diagnóstico técnico sale de la ficha del nadador**, donde el entrenador lo escribe. Si
  está vacío, se aplica la progresión estándar y **no se inventan errores** (sección 7 del
  prompt maestro)
- **La categoría sale de la ficha.** Si falta, no se genera: se le dice al nadador que su
  entrenador tiene que completarla
- **`Generar` del nadador deja de decir «todavía no»** y pasa a ser este destino. El reparto
  de la feature 007 ya tiene el hueco previsto
- **La cola del entrenador vive en su `Generar`**, junto al generador y el editor que ya
  están ahí, y no en un destino nuevo: los cinco destinos de la 007 no cambian
- **Un menor con consentimiento vigente pide como cualquiera.** La puerta mira el
  consentimiento, no la edad
- **La ventana de «molestias recientes» son las últimas cuatro semanas**, que es lo que cubre
  un microciclo más el anterior. Se declara aquí para que sea comprobable, no porque la
  metodología fije ese número
- **La fecha de competencia es de esta solicitud, no de la ficha.** No se guarda en el perfil
  del nadador: una competencia que pasó no debería seguir decidiendo fases
- **El nadador no puede retirar una solicitud enviada.** Si se arrepiente, se lo dice a su
  entrenador, que la rechaza. Añadir un retiro abriría la pregunta de qué pasa con un
  borrador que el entrenador ya está corrigiendo

## Dependencies

- **Feature 002** (motor determinista) — es quien genera el borrador. Ya está, con sus
  pruebas
- **Feature 001** (ciclo de vida y auditoría) — el borrador nace y se audita con lo que ya
  existe
- **Feature 004** (consentimiento) — la puerta que impide que un menor mande datos sin
  autorización. Ya está
- **Feature 007** (el HUB) — el destino `Generar` del nadador y el `Generar` del entrenador
  donde vive la cola

## Out of Scope

- Planes de más de un microciclo: eso es la 009
- Que el nadador vea el contenido del plan antes de la firma
- Cualquier sugerencia automática sobre una molestia
- Preguntarle al nadador por molestias: salen de sus sesiones (aclaración Q2)
- Un calendario de competencias del club. La fecha sale de lo que el nadador diga, y si no
  sabe, la fase la pone el entrenador
- Notificaciones push de que llegó una solicitud o de que se respondió
