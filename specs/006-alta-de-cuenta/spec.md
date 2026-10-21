# Feature Specification: Alta de cuenta y consentimiento en el registro

**Feature Branch**: `006-alta-de-cuenta`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "Alta de cuenta y consentimiento en el registro. Hoy cualquiera entra con correo y contraseña y la app no sabe quién es: no tiene nombre, ni país, ni forma de saber si es menor. El alta debe pedir nombre, edad exacta y país, repartido en varios pasos y no en un formulario largo. La edad sirve para una sola cosa: saber si es menor de 18. No toca la generación de planes ni la categoría, que se determina por habilidades y nunca por la edad (sección 11.1 de la metodología 3.6.0). Los términos y condiciones se aceptan en el registro. Cuando el alta detecta que es menor, pide el correo del acudiente explicando que es para solicitar su consentimiento, y la verificación de ese correo vale como consentimiento otorgado: alimenta la puerta de consentimiento que ya existe desde la feature 004, no la sustituye. Nada de esto impide usar la app mientras el consentimiento está pendiente: la puerta bloquea que los datos salgan del dispositivo, no que el nadador entre. Todos se registran como nadador; el rol de entrenador se asigna aparte y esa elección no se muestra. El vocabulario visible sigue en español, y las pantallas nuevas usan el tema y los componentes de la feature 005: nada de colores ni medidas propias."

## Por qué esta feature existe

La feature 004 construyó la puerta de consentimiento: las reglas que impiden que los datos de
un menor salgan del dispositivo sin autorización de su acudiente, y el formulario donde ese
acudiente autoriza. **Lo que nunca se construyó es cómo llega alguien hasta esa puerta.**

Hoy el alta pide correo y contraseña, nada más. La app no sabe el nombre de quien entra, ni
si tiene nueve años o treinta. El consentimiento de la 004 existe pero **nadie lo solicita
nunca**, porque no hay ningún momento en que la app se entere de que está tratando con un
menor. La puerta está puesta y no hay llave que pedir.

Esta feature es ese momento.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Un nadador adulto se da de alta (Priority: P1)

Alguien abre la app por primera vez, elige crear una cuenta, y la app le pregunta quién es
antes de dejarle entrar: su nombre, su fecha de nacimiento y su país, **en pasos cortos, uno
por pantalla**, no en un formulario de ocho campos. Acepta los términos y condiciones, y
entra.

**Why this priority**: es el camino que recorren todos, menores incluidos. Sin él no hay
dónde enganchar nada de lo demás, y es el único que por sí solo ya arregla algo real: que la
app sepa el nombre de quien la usa.

**Independent Test**: crear una cuenta nueva de alguien mayor de edad y comprobar que al
entrar la app le saluda por su nombre y no vuelve a preguntarle nada.

**Acceptance Scenarios**:

1. **Given** alguien sin cuenta, **When** elige crear una, **Then** la app le pide los datos
   repartidos en pasos y cada paso cabe en una pantalla sin desplazarse
2. **Given** un paso a medio llenar, **When** vuelve atrás, **Then** lo que ya escribió sigue
   ahí
3. **Given** todos los datos y los términos aceptados, **When** termina, **Then** queda dentro
   de la app, con su nombre
4. **Given** un alta sin aceptar los términos, **When** intenta terminar, **Then** no puede, y
   la app dice qué falta sin borrar lo escrito
5. **Given** alguien que ya tiene cuenta, **When** entra, **Then** no se le pregunta nada de
   esto otra vez

---

### User Story 2 - Un menor se da de alta y su acudiente recibe la solicitud (Priority: P1)

Una nadadora de doce años se da de alta igual que cualquiera. Cuando la app sabe que es menor,
le pide **el correo de su acudiente**, y le explica para qué: para pedirle permiso de guardar
sus datos. Ella termina el alta y **entra a la app**. Su acudiente recibe un correo con el
enlace al formulario de consentimiento que ya existe desde la feature 004.

**Why this priority**: es la razón de ser de la feature. Sin esto, la puerta de consentimiento
de la 004 es un mecanismo que nunca se activa, y la app no puede abrirse a nadadores reales
sin incumplir el principio V.

**Independent Test**: crear una cuenta declarando una edad menor de 18, comprobar que se pide
el correo del acudiente con su explicación, que la nadadora entra igualmente, y que queda una
solicitud de consentimiento pendiente a nombre de ese correo.

**Acceptance Scenarios**:

1. **Given** una fecha de nacimiento que da menos de 18 años, **When** avanza, **Then** la app
   pide el correo del acudiente **y explica que es para solicitar su consentimiento**
2. **Given** el correo del acudiente escrito, **When** termina el alta, **Then** queda una
   solicitud de consentimiento pendiente y el acudiente la recibe
3. **Given** una cuenta de menor con el consentimiento pendiente, **When** la nadadora usa la
   app, **Then** puede entrar, ver su plan y responder a sus sesiones **sin ninguna traba**
4. **Given** esa misma cuenta, **When** sus respuestas intentan salir del dispositivo,
   **Then** la puerta de la feature 004 las retiene, como ya hacía
5. **Given** un menor que no quiere dar el correo de su acudiente, **When** avanza, **Then**
   entra igual, y la app le dice qué es lo que no podrá hacer hasta que lo dé

---

### User Story 3 - Una cuenta que ya existe completa su perfil (Priority: P2)

Hay cuentas reales usando la app desde la feature 004, y ninguna tiene nombre ni fecha de
nacimiento: la del propio entrenador, la primera. La próxima vez que una de ellas entra, la
app le pide **una sola vez** los datos que le faltan, con los mismos pasos del alta, y después
no vuelve a preguntar.

**Why this priority**: sin esto quedan cuentas sin nombre para siempre. Y hay una consecuencia
que no es cosmética: **si alguna de esas cuentas resulta ser de un menor, su consentimiento no
se habría pedido nunca**, porque el alta ya pasó. Completar el perfil es lo que cierra ese
hueco.

**Independent Test**: entrar con una cuenta creada antes de esta feature y comprobar que se
piden los datos que faltan, que al terminar se entra con normalidad, y que a la siguiente vez
no se pregunta nada.

**Acceptance Scenarios**:

1. **Given** una cuenta sin nombre ni fecha de nacimiento, **When** entra, **Then** la app le
   pide lo que falta, con los mismos pasos del alta
2. **Given** ese perfil completado, **When** vuelve a entrar, **Then** no se le pregunta nada
3. **Given** una cuenta antigua que al completar el perfil resulta ser de un menor, **When**
   termina, **Then** se le pide el correo del acudiente y se emite la solicitud, igual que en
   un alta nueva
4. **Given** una cuenta antigua a medio completar, **When** cierra la app y vuelve, **Then**
   sigue donde lo dejó
5. **Given** una cuenta de entrenador sin perfil, **When** completa el suyo, **Then** sigue
   siendo entrenador: completar el perfil **no toca el rol**

---

### User Story 4 - El acudiente autoriza desde su correo (Priority: P2)

El acudiente abre el correo, sigue el enlace, y se encuentra el formulario de la feature 004:
el texto informativo delante, quién es, en qué calidad, y la casilla de que **ha oído al
menor**. Autoriza. A partir de ahí los datos de la nadadora pueden salir del dispositivo.

**Why this priority**: cierra el ciclo, pero el formulario ya está construido y probado. Lo
que esta feature añade es el camino hasta él.

**Independent Test**: seguir el enlace de una solicitud emitida en el alta y comprobar que
lleva al formulario correcto, y que al autorizar la puerta se abre para ese nadador.

**Acceptance Scenarios**:

1. **Given** una solicitud emitida en el alta, **When** el acudiente sigue el enlace,
   **Then** llega al formulario de consentimiento de ese nadador concreto
2. **Given** el formulario autorizado, **When** la nadadora vuelve a usar la app, **Then** lo
   que tenía guardado se envía, igual que si hubiera recuperado la conexión
3. **Given** un enlace vencido o ya usado, **When** el acudiente lo sigue, **Then** la app lo
   dice en palabras y explica cómo pedir otro

---

### Edge Cases

- **El menor cumple 18 años.** Se guarda la fecha de nacimiento, no la edad, y la condición de
  menor se recalcula cada vez: el día que cumple deja de serlo, sin que nadie actualice nada.
  Lo que no hace la app es celebrarlo ni avisar de ello.
- **Una cuenta antigua resulta ser de un menor.** Al completar el perfil se le pide el correo
  del acudiente y se emite la solicitud, como en un alta nueva. Es el hueco que US3 cierra.
- **Una cuenta antigua de entrenador completa su perfil.** Sigue siendo entrenador: completar
  el perfil no toca el rol.
- **El correo del acudiente es el del propio menor.** La app no puede comprobar parentesco,
  pero sí puede ver que son el mismo correo, y eso no es un acudiente.
- **El acudiente no responde nunca.** La cuenta funciona, la puerta sigue cerrada, y lo que el
  nadador guarde se queda en su dispositivo. No se borra, no caduca, no se pierde.
- **Se escribe mal el correo del acudiente.** Tiene que poder corregirse después sin rehacer
  el alta.
- **Alguien se da de alta estando ya dentro de la app** en otro dispositivo.
- **Un paso del alta se interrumpe** —se cierra la app, se acaba la batería— a mitad.
- **El país no está en la lista**, o la persona no quiere decirlo.
- **Un adulto que entrena en el club se registra**: nadie le pide correo de acudiente, y no se
  le muestra nada sobre consentimiento.

## Requirements *(mandatory)*

### Functional Requirements

#### El alta

- **FR-001**: El alta MUST pedir, además del correo y la contraseña que ya pide hoy: **nombre**,
  **fecha de nacimiento** y **país**.
- **FR-002**: El alta MUST repartirse en **pasos cortos**, uno por pantalla, con el avance
  visible y la posibilidad de volver atrás sin perder lo escrito.
- **FR-003**: Cada paso MUST decir qué falta **sin borrar lo que ya se escribió**.
- **FR-004**: El alta MUST pedir aceptar los **términos y condiciones**, y MUST registrar
  **qué versión** se aceptó y **cuándo**.
- **FR-005**: El texto de los términos MUST estar delante, legible en la propia pantalla, **no
  detrás de un enlace**. Es la misma regla que la 004 aplicó al texto de consentimiento.
- **FR-006**: El alta MUST poder reanudarse si se interrumpe, sin empezar de cero.

#### El país

- **FR-007**: El país MUST pedirse **para que el club sepa de dónde viene cada nadador**, y
  para nada más. Ese es su uso declarado, y el principio V exige que lo tenga.
- **FR-008**: El país MUST NOT intervenir en ninguna decisión de la app: ni en planes, ni en
  categorías, ni en qué puede hacer una cuenta, ni en qué ley se le aplica. Es un dato del
  perfil, no un interruptor. **Una prueba debe impedir que eso cambie en silencio.**
- **FR-009**: Decir el país MUST ser opcional. Negarse no impide terminar el alta.

#### La edad

- **FR-010**: La **fecha de nacimiento** MUST usarse **únicamente** para determinar si la
  persona es menor de 18 años. Se guarda la fecha, no la edad.
- **FR-011**: La edad MUST NOT intervenir en la generación de planes, en la categoría, ni en
  ninguna decisión metodológica. **La categoría se determina por habilidades** (sección 11.1
  de la metodología 3.6.0), y una prueba debe impedir que esto se rompa en el futuro.
- **FR-012**: La condición de menor MUST recalcularse a partir de la fecha de nacimiento cada
  vez que se consulta, nunca guardarse como un sí o un no que envejece. El día que alguien
  cumple 18 deja de ser menor sin que nadie actualice nada.
- **FR-013**: Ser menor MUST NOT impedir entrar, crear la cuenta, ver el plan ni responder a
  las sesiones.

#### El consentimiento

- **FR-014**: Cuando la persona es menor, el alta MUST pedir el **correo del acudiente** y
  MUST explicar, en esa misma pantalla, que es para solicitarle su consentimiento.
- **FR-015**: Al terminar el alta de un menor, el sistema MUST emitir una **solicitud de
  consentimiento** dirigida a ese correo, usando el mecanismo que ya existe desde la feature
  004.
- **FR-016**: La solicitud MUST llevar al acudiente al **formulario de consentimiento ya
  construido**, que es donde se identifica, declara en qué calidad actúa y confirma que **ha
  oído al menor** (Decreto 1377 de 2013). Esta feature **no sustituye ese formulario**:
  verificar que el correo existe no es consentimiento informado.
- **FR-017**: El correo del acudiente MUST poder corregirse y la solicitud reenviarse, sin
  rehacer el alta.
- **FR-018**: El sistema MUST rechazar como acudiente el **mismo correo** de la cuenta del
  menor.
- **FR-019**: Un menor MUST poder terminar el alta **sin dar** el correo de su acudiente, y la
  app MUST decirle en palabras qué no podrá hacer hasta que lo dé.
- **FR-020**: Mientras el consentimiento esté pendiente, lo que el nadador guarde MUST
  conservarse en su dispositivo y enviarse **en cuanto se autorice**, sin que él tenga que
  repetir nada.

#### Las cuentas que ya existen

- **FR-021**: Una cuenta sin perfil completo MUST recibir, al entrar, la petición de completarlo,
  con los mismos pasos del alta.
- **FR-022**: Completar el perfil MUST pedirse **una sola vez**: hecho una vez, no se vuelve a
  preguntar.
- **FR-023**: Si al completarlo resulta que la cuenta es de un menor, el sistema MUST pedir el
  correo del acudiente y emitir la solicitud, **igual que en un alta nueva**.
- **FR-024**: Completar el perfil MUST NOT cambiar el rol de la cuenta. Una cuenta de entrenador
  sigue siendo de entrenador.
- **FR-025**: La petición de completar el perfil MUST poder reanudarse si se interrumpe.

#### El rol

- **FR-026**: Toda cuenta nueva MUST crearse como **nadador**.
- **FR-027**: La elección de rol MUST NOT mostrarse en el alta. El rol de entrenador se asigna
  aparte, como ya ocurre desde la feature 004.

#### Lo visible

- **FR-028**: Todo el vocabulario visible MUST estar en español.
- **FR-029**: Las pantallas nuevas MUST usar el tema y los componentes de la feature 005, **sin
  colores ni medidas propias**. Las fronteras V1, V2 y V3 ya lo hacen cumplir.
- **FR-030**: Las pantallas nuevas MUST añadirse al banco de pantallas que miden el tamaño de
  letra al 200% y las áreas pulsables. Una pantalla que no está en el banco no se mide.
- **FR-031**: Nada de lo que esta feature introduzca MUST aparecer en registros ni analítica:
  ni nombres, ni fechas de nacimiento, ni países, ni correos (principio V).

### Key Entities

- **Perfil de la cuenta**: quién es la persona detrás del correo. Nombre, fecha de nacimiento
  y país (este último, opcional). Vive junto a la cuenta que ya existe desde la feature 004, no
  la sustituye. Un perfil puede estar **incompleto**, y eso es un estado con consecuencias: es
  lo que dispara la petición de completarlo.
- **Aceptación de términos**: qué versión del texto aceptó quién, y cuándo. Es un hecho con
  fecha, no una casilla.
- **Solicitud de consentimiento**: ya existe desde la feature 004. Esta feature la **emite**;
  no cambia su forma.
- **Acudiente declarado**: el correo que el menor dio, y el estado de su solicitud. No es una
  persona identificada hasta que autoriza: hasta entonces es solo una dirección.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Una persona completa el alta en **menos de dos minutos**, sin ayuda.
- **SC-002**: Un nadador de nueve años completa el alta **sin preguntarle a nadie qué
  significa un campo**.
- **SC-003**: El **100%** de las altas de menores deja una solicitud de consentimiento
  pendiente o un rechazo explícito registrado. Ninguna se queda en el limbo.
- **SC-004**: Un menor con el consentimiento pendiente puede recorrer su sesión del día y
  responderla **sin encontrarse una sola traba**.
- **SC-005**: Ninguna prueba de las features 001 a 005 cambia para que esta pase.
- **SC-006**: La app no pide **ningún dato** que no tenga su uso declarado en esta
  especificación (principio V, minimización).
- **SC-007**: Un acudiente que recibe la solicitud llega al formulario y autoriza **sin crear
  ninguna cuenta**.
- **SC-008**: Después de esta feature, **ninguna cuenta de la app queda sin nombre**: las
  nuevas lo dan al darse de alta y las antiguas al entrar la primera vez.

## Assumptions

- El mecanismo de solicitud de consentimiento de la feature 004 —token, canal, vencimiento,
  canje— se reutiliza **sin cambios de forma**. Lo que esta feature añade es quién la emite y
  cuándo.
- El envío del correo al acudiente usa el canal que la feature 004 ya definió.
- La cuenta sigue creándose con correo y contraseña; esta feature añade pasos alrededor, no
  cambia cómo se autentica.
- Los términos y condiciones **todavía no existen**: hay que escribirlos. Como el texto de
  consentimiento de la 004, necesitan **revisión legal antes de que los vea una familia
  real**, y eso queda fuera de lo que esta feature puede cerrar por sí sola.
- La app sigue sin distinguir edades para nada que no sea la mayoría de edad: no hay
  categorías por edad y no las habrá.
- Las cuentas que hay hoy en producción son pocas y conocidas. Si fueran muchas, pedirles
  completar el perfil al entrar sería más delicado de lo que esta especificación supone.

## Clarifications

Resueltas con el entrenador el 2026-10-21.

- **Q1 — Las cuentas que ya existen**: se les pide completar el perfil **la próxima vez que
  entren**, una sola vez, con los mismos pasos del alta. Es la historia de usuario 3.

  La razón de peso no es la cosmética de tener nombres: es que **si una de esas cuentas es de
  un menor, su consentimiento no se habría pedido nunca**, porque su alta ya pasó. Dejarlas
  como estaban habría dejado ese hueco abierto para siempre.

- **Q2 — Para qué se usa el país**: para que **el club sepa de dónde viene cada nadador**, sin
  ningún otro efecto en la app. Queda escrito así en FR-007 y FR-008 precisamente para que
  nadie lo convierta después en otra cosa —un interruptor de ley aplicable, un filtro, una
  categoría— sin que se note. Y por eso es opcional: un dato que solo informa no bloquea a
  nadie.

- **Q3 — Qué se guarda de la edad**: la **fecha de nacimiento**, y la condición de menor se
  recalcula cada vez que se consulta. Un número envejece: quien se registra con 17 figuraría
  como menor para siempre. Es algo más de dato personal del que hace falta para una pregunta
  de sí o no, y se acepta a cambio de que la respuesta sea correcta todos los días.
