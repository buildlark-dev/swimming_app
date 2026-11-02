# Especificación de feature: El HUB y los dos recorridos

**Feature Branch**: `007-hub-y-recorridos`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "El HUB y los dos recorridos. La app tiene hoy tres pestañas pensadas para el entrenador (Generar, Editor, Nadadores) y el nadador entra al mismo sitio. Debe tener un HUB de cinco pestañas en este orden —Generar, Ver Plan, Home, Análisis, Ajustes— con Home al centro, y la disposición y el contenido de cada una deben ser distintos para el nadador y para el entrenador: la misma barra, dos recorridos. Lo que no corresponde a un rol no se muestra. Las pantallas que ya existen se reubican en su pestaña sin cambiar lo que hacen: el generador y el editor son el "Generar" del entrenador, el panel de nadadores y los planes generados viven en su "Ver Plan" con búsqueda y filtro por nadador, y la sesión del día del nadador —marcarla cumplida, RPE, observaciones, molestias aparte— es su "Ver Plan". Home es un resumen honesto por rol: para el nadador, cómo va su entrenamiento y qué ha cumplido; para el entrenador, cuántos planes tiene generados, cuántos en uso y cuántos pendientes de aprobar o asignar. Ajustes es donde la persona gobierna su cuenta: sus datos, el texto y la versión de los términos y del consentimiento que aceptó, cerrar sesión, y sus derechos de la Ley 1581 —ver, corregir y pedir la supresión de sus datos—. Una pestaña cuyo contenido llega en una feature posterior existe desde ya pero dice con precisión qué falta, sin botones que no hagan nada: "Análisis" para ambos roles y "Generar" para el nadador están en ese caso. El vocabulario visible sigue en español, el tema visual de la 005 se usa tal cual y no se improvisa ninguno nuevo, y ninguna prueba de las features 001 a 006 se modifica: si una falla, el HUB cambió un comportamiento y se arregla el HUB."

## Por qué existe esta feature

Seis features construyeron piezas. **La casa que las contiene sigue siendo la del
desarrollador.**

Las pestañas de hoy se llaman como las partes que se fueron construyendo —`Generar`,
`Editor`, `Nadadores`— y no como los dos recorridos que de verdad existen. El entrenador ve
tres; el nadador ve dos, y ninguna se llama como lo que él viene a hacer. Nadie tiene un
sitio al que llegar: la app abre en lo último que se programó. Salir de la sesión es un
botón pequeño en una tira gris encima de todo.

Y hay algo peor que una pestaña mal nombrada. Desde la feature 004 el proyecto tiene
construidos, en el dominio y con sus pruebas, **los tres derechos que la Ley 1581 reconoce
al titular**: saber qué se guarda sobre él dicho en frases y no en campos, llevárselo en un
archivo legible, y pedir que se elimine. Están completos. Y **ninguna pantalla los usa**:
`DerechosDelTitular` no se construye en ningún sitio de la interfaz. Desde la feature 006 la
app guarda el nombre y la fecha de nacimiento de menores de edad, y el derecho a pedir que
eso se borre existe en el código y no existe para la persona.

Esta feature es la casa: cinco destinos iguales para los dos, con contenido distinto en cada
uno, y un sitio donde cada quien manda sobre lo suyo.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - El nadador abre la app y llega a su sitio (Priority: P1)

Una nadadora abre la app y aterriza en **Home**: cuántas sesiones le han entregado, cuántas
ha cumplido, qué respondió la última vez. A un toque, en **Ver Plan**, está la sesión de hoy
con lo que ya sabía hacer: marcarla cumplida, decir cuánto le costó, escribir lo que quiera,
y reportar una molestia en su propio campo. No hay ninguna pestaña que le hable del editor
de sesiones ni del panel de nadadores, porque eso no es suyo.

**Why this priority**: es el recorrido de quien más va a usar la app y el que hoy está peor
servido —dos pestañas, ningún resumen, ninguna portada—. Por sí solo ya entrega algo real.

**Independent Test**: entrar con una cuenta de nadador y comprobar que abre en Home con su
resumen, que la sesión del día está a un toque y que en toda la barra no aparece nada del
recorrido del entrenador.

**Acceptance Scenarios**:

1. **Given** una cuenta de nadador, **When** abre la app, **Then** aterriza en Home y ve su
   resumen
2. **Given** está en Home, **When** toca `Ver Plan`, **Then** ve la sesión de hoy, con lo
   mismo que hacía antes y sin ningún paso nuevo
3. **Given** cualquier pestaña del nadador, **When** la recorre toda, **Then** no encuentra
   el generador, el editor ni el panel de nadadores, **ni deshabilitados ni con candado**
4. **Given** un nadador sin plan todavía, **When** abre Home y Ver Plan, **Then** las dos lo
   dicen con una frase y ninguna aparece vacía sin explicación
5. **Given** marcó la sesión y escribió sus observaciones, **When** cambia de pestaña y
   vuelve, **Then** lo escrito sigue ahí

---

### User Story 2 - El entrenador abre la app y encuentra su taller (Priority: P1)

El entrenador aterriza en **Home** y ve de un golpe cuántos planes tiene, cuántos están en
uso, cuántos esperan su aprobación y cuántos aprobó pero no ha asignado. En **Generar** está
lo que ya tenía: el generador, y el editor donde cae el plan generado para que lo revise. En
**Ver Plan** están sus planes y sus nadadores, con búsqueda y filtro por nadador, para
encontrar uno y ajustarlo.

**Why this priority**: es el recorrido que hoy existe a medias y repartido en tres pestañas
sin portada. Reagruparlo no añade funciones: convierte tres cajones en un taller.

**Independent Test**: entrar con una cuenta de entrenador, generar un microciclo, comprobar
que cae en el editor sin salir de `Generar`, y encontrar ese plan después desde `Ver Plan`
filtrando por el nadador al que se lo entregó.

**Acceptance Scenarios**:

1. **Given** una cuenta de entrenador, **When** abre la app, **Then** aterriza en Home con
   los cuatro números y cada uno dice de qué es
2. **Given** está en `Generar`, **When** genera un microciclo, **Then** el plan generado se
   abre para revisarlo **sin cambiar de pestaña**
3. **Given** una sesión a medio editar, **When** se va a otra pestaña y vuelve, **Then** la
   encuentra como la dejó
4. **Given** varios planes y varios nadadores, **When** busca o filtra en `Ver Plan`,
   **Then** encuentra los de ese nadador y puede abrir uno para ajustarlo
5. **Given** un entrenador sin ningún plan, **When** abre Home, **Then** los números dicen
   cero y la pantalla le dice por dónde empezar

---

### User Story 3 - Cada quien manda sobre lo suyo (Priority: P1)

En **Ajustes**, una persona ve sus propios datos y los corrige, lee el texto íntegro de los
términos y del consentimiento **en la versión exacta que aceptó**, con la fecha en que lo
hizo, elige si quiere la app clara u oscura, cierra sesión, y ejercita sus derechos: saber
qué guarda la app sobre ella, llevárselo en un archivo, y pedir que se suprima.

**Why this priority**: los tres derechos están construidos desde la 004 y no son alcanzables
desde ninguna pantalla. Un derecho que solo existe en el dominio no está concedido. Y desde
la 006 lo que se guarda incluye datos de menores.

**Independent Test**: desde una cuenta cualquiera, abrir Ajustes y recorrer los tres
derechos: ver qué se guarda en frases comprensibles, obtener el archivo, y llegar a la
solicitud de supresión con el aviso de qué se borra y qué sobrevive.

**Acceptance Scenarios**:

1. **Given** una cuenta con perfil, **When** abre Ajustes, **Then** ve su nombre, su fecha de
   nacimiento y su país, y puede corregirlos
2. **Given** aceptó los términos en una versión, **When** los abre en Ajustes, **Then** lee
   **ese** texto y esa versión, no el texto actual, con la fecha de aceptación
3. **Given** quiere saber qué guarda la app, **When** lo pide, **Then** obtiene frases
   comprensibles y no un volcado técnico
4. **Given** pide llevarse sus datos, **When** se atiende, **Then** recibe un archivo legible
   fuera de la app
5. **Given** pide la supresión, **When** la app se lo confirma, **Then** antes le dice qué se
   borra y **qué sobrevive**: el registro de que hubo consentimiento, con su fecha
6. **Given** está dentro, **When** busca cómo salir, **Then** cerrar sesión está en Ajustes
7. **Given** cualquier cuenta, **When** recorre Ajustes, **Then** no ve ni puede cambiar
   datos de otra persona

---

### User Story 4 - Una pestaña que todavía no tiene contenido lo dice (Priority: P2)

El nadador toca `Generar` y la app le dice, en una frase, que desde ahí pedirá su
entrenamiento y que eso todavía no está. El entrenador toca `Análisis` y encuentra lo mismo.
**Lo que no encuentran es un botón que no hace nada.**

**Why this priority**: la barra debe estar completa desde el principio para que nadie
aprenda una disposición que va a cambiar. Pero una pestaña que promete lo que no hay es peor
que una pestaña ausente, y el proyecto ya decidió que no se promete.

**Independent Test**: recorrer `Análisis` como entrenador y `Generar` como nadador, y
comprobar que cada una explica qué llegará y que no hay ni un control pulsable que no
responda.

**Acceptance Scenarios**:

1. **Given** una cuenta de nadador, **When** toca `Generar`, **Then** lee qué hará ahí y por
   qué todavía no
2. **Given** una cuenta de entrenador, **When** toca `Análisis`, **Then** lee lo mismo para
   esa pestaña
3. **Given** una cuenta de nadador, **When** toca `Análisis`, **Then** **sí** hay contenido:
   su recorrido, el que la feature 003 entregó como «Mi progreso»
4. **Given** una pestaña sin contenido, **When** la recorre entera, **Then** no hay ningún
   control que no haga nada, ni deshabilitado como señuelo

---

### User Story 5 - Lo que ya funcionaba sigue funcionando (Priority: P1)

Nada de lo que las features 001 a 006 entregaron cambia de comportamiento porque cambió la
barra. El generador genera igual, el editor calcula igual, la auditoría audita igual, la
puerta de consentimiento sigue cerrada, el alta sigue pidiendo lo que pedía, y la sesión del
día se marca igual.

**Why this priority**: esta feature mueve pantallas de sitio. Es la clase de cambio que
rompe cosas lejanas sin que nadie lo note hasta que un nadador se queda sin su sesión.

**Independent Test**: las pruebas de las features 001 a 006 pasan sin tocarles una línea,
salvo las que afirman la navegación anterior, que son el objeto de esta feature.

**Acceptance Scenarios**:

1. **Given** el conjunto de pruebas de 001 a 006, **When** se ejecuta sin modificarlo,
   **Then** lo único que falla son las afirmaciones sobre la barra vieja
2. **Given** una prueba que afirma el comportamiento de una pantalla, **When** falla,
   **Then** se arregla el HUB y **no** la prueba
3. **Given** una prueba que afirma cómo se llegaba a una pantalla, **When** se actualiza,
   **Then** sigue comprobando que se llega a **esa misma** pantalla, y el número total de
   pruebas no baja

---

### Edge Cases

- **Una cuenta sin rol reconocible**: no se le muestra el HUB. Sigue viendo lo que la
  feature 004 decidió para ese caso, que no es una barra vacía.
- **Una cuenta sin nada asignado**: hoy la app dice «cuando tu entrenador te inscriba,
  aparecerá aquí». Con cinco destinos esa frase ya no puede sustituir a la barra entera:
  cada destino la dice en su sitio, y Ajustes sigue siendo alcanzable, porque de ahí se
  cierra sesión.
- **Modo local, sin servidor**: no hay rol que consultar. La app no puede adivinar el
  recorrido, así que ofrece cambiar de uno a otro **a propósito**, y sigue avisando de que
  no hay consentimiento registrado.
- **Pantalla angosta**: cinco etiquetas en español en 320 px. Si una no cabe entera, el
  problema es el diseño de la barra y no la palabra: no se abrevia el vocabulario.
- **Sin conexión**: Home abre con lo que haya en el dispositivo y dice de cuándo es. No se
  queda girando ni muestra ceros como si fueran datos.
- **Consentimiento pendiente**: el nadador entra y ve su recorrido, pero nada en Home ni en
  Ajustes puede dar a entender que el consentimiento ya se otorgó.
- **Volver atrás** desde una pestaña que no es Home: va a Home. Desde Home, sale de la app.
- **La página pública del acudiente** no es parte del HUB: se abre desde un enlace del
  correo, sin sesión, y así sigue.

## Requirements *(mandatory)*

### Functional Requirements

**La barra**

- **FR-001**: El HUB DEBE tener exactamente cinco destinos, en este orden: `Generar`,
  `Ver Plan`, `Home`, `Análisis`, `Ajustes`, con `Home` en la posición central.
- **FR-002**: El orden y la posición de los cinco DEBEN ser idénticos para los dos roles. Lo
  que cambia es el contenido, no la barra.
- **FR-003**: El contenido de cada destino DEBE depender del rol de quien está dentro, y el
  del otro rol NO DEBE mostrarse, ni insinuarse, ni aparecer deshabilitado o con candado.
- **FR-004**: El rol DEBE leerse de los permisos que la feature 004 estableció, nunca de una
  condición escrita en la pantalla.
- **FR-005**: La app DEBE abrir en `Home`.
- **FR-006**: Cambiar de destino DEBE conservar el estado del que se abandona: una sesión a
  medio editar, un formulario a medio llenar y una búsqueda hecha siguen ahí al volver.
- **FR-007**: El destino elegido DEBE sobrevivir a un cambio de tamaño o de orientación y al
  regreso de una pantalla abierta encima.
- **FR-008**: Las cinco etiquetas DEBEN leerse completas, sin truncarse ni abreviarse, en
  una pantalla de 320 px de ancho, en claro y en oscuro.

**El recorrido del entrenador**

- **FR-009**: `Generar` DEBE contener el generador de microciclos y el editor de sesiones, y
  el paso de un plan recién generado al editor DEBE seguir ocurriendo **sin cambiar de
  destino**.
- **FR-010**: `Ver Plan` DEBE listar los planes que el entrenador ha generado, con búsqueda
  y filtro por nadador, y DEBE dar acceso al panel de nadadores que existe hoy.
- **FR-011**: Desde `Ver Plan` DEBE poder abrirse un plan y ajustarse con el editor que ya
  existe. NO DEBE construirse un segundo editor.
- **FR-012**: `Home` DEBE mostrar, cada uno dicho en palabras: cuántos planes tiene,
  cuántos están en uso, cuántos esperan aprobación y cuántos están aprobados sin asignar.

**El recorrido del nadador**

- **FR-013**: `Ver Plan` DEBE ser la sesión del día tal como la entregó la feature 003:
  marcarla cumplida, el esfuerzo percibido, las observaciones, y el reporte de molestia en
  su campo aparte. Sin un paso nuevo y sin quitar ninguno.
- **FR-014**: `Home` DEBE mostrar cuántas sesiones le han entregado, cuántas ha cumplido y
  qué respondió la última vez.
- **FR-015**: `Home` NO DEBE mostrar metas ni logros que el sistema no tenga: hoy no existen
  como dato y no se inventan.
- **FR-016**: `Home` DEBE abrir sin conexión con lo que haya en el dispositivo y DEBE decir
  de cuándo son los datos que muestra.

**Ajustes**

- **FR-017**: `Ajustes` DEBE mostrar los datos del perfil de quien está dentro —nombre,
  fecha de nacimiento y país— y permitir corregirlos.
- **FR-018**: `Ajustes` DEBE mostrar el texto íntegro y la versión de los términos y del
  consentimiento que esa persona aceptó, con la fecha de aceptación. DEBE ser el texto de
  **esa** versión, no el vigente.
- **FR-019**: Cerrar sesión DEBE estar en `Ajustes`.
- **FR-020**: `Ajustes` DEBE dar acceso a los tres derechos de la Ley 1581 que el dominio ya
  implementa: saber qué se guarda, exportarlo y pedir la supresión.
- **FR-021**: Lo que se guarda DEBE decirse en frases comprensibles, no en un volcado
  técnico.
- **FR-022**: Antes de ejecutar una supresión, la app DEBE decir qué se borra y qué
  sobrevive: el registro de que hubo consentimiento, con su fecha, no se borra, porque es la
  prueba de que el tratamiento anterior estuvo amparado.
- **FR-023**: En una cuenta de una persona menor de edad, la supresión la ejecuta **ella
  misma** desde Ajustes, igual que un adulto: el derecho es del titular y la titular es
  ella. No hay un paso de confirmación del acudiente. Dado que el borrado no se deshace, la
  app DEBE pedir una confirmación explícita en un segundo paso —no basta pulsar una vez— y
  esa confirmación DEBE mostrar lo de FR-022: qué se borra y qué sobrevive.
- **FR-024**: `Ajustes` NO DEBE permitir ver ni modificar los datos de otra persona.
- **FR-025**: `Ajustes` DEBE permitir elegir entre apariencia clara, oscura o la del sistema,
  y la elección DEBE sobrevivir al cierre de la app.
- **FR-026**: `Ajustes` DEBE permitir pedir el cambio de contraseña por el mismo medio
  verificado que usa la identidad. La contraseña nueva NO DEBE escribirse en una pantalla
  que no comprueba quién la escribe.
- **FR-027**: En modo local, `Ajustes` DEBE permitir cambiar de recorrido a propósito, y la
  app DEBE seguir avisando de que no hay servidor ni consentimiento registrado.

**Los destinos que esperan su feature**

- **FR-028**: Un destino sin contenido para un rol DEBE decir en una frase qué llegará ahí.
- **FR-029**: Un destino sin contenido NO DEBE ofrecer ningún control pulsable que no haga
  nada, ni deshabilitado como señuelo de algo futuro.
- **FR-030**: En esta feature esos destinos son `Análisis` **del entrenador** y `Generar` del
  nadador. El `Análisis` del nadador **no** es uno de ellos.
- **FR-031**: La pantalla «Mi progreso» que la feature 003 entregó DEBE pasar a ser el
  `Análisis` del nadador, sin cambiar lo que hace. El `Home` del nadador DEBE ser un resumen
  más corto, construido de los mismos datos, y NO DEBE repetir la pantalla completa.

**Lo que no se puede romper**

- **FR-032**: Ninguna prueba de las features 001 a 006 que afirme el **comportamiento** de
  una pantalla DEBE modificarse. Si una falla, se arregla el HUB.
- **FR-033**: Las pruebas que afirman la **navegación anterior** —el inventario de pestañas y
  la forma de llegar al editor, hoy en `test/widget_test.dart`— DEBEN actualizarse una por
  una, cada una DEBE seguir comprobando que se alcanza la misma pantalla, y el número total
  de pruebas NO DEBE bajar.
- **FR-034**: Toda pantalla nueva DEBE usar el tema y los componentes de la feature 005. NO
  DEBE declararse ningún color, medida ni tipografía propios.
- **FR-035**: El vocabulario visible DEBE seguir en español.

### Key Entities

- **Destino**: una de las cinco posiciones de la barra. Tiene etiqueta en español, icono,
  posición fija, y un contenido por cada rol —que puede ser «todavía no».
- **Recorrido**: el conjunto de contenidos que le corresponde a un rol. Hay dos, y son
  disjuntos: ningún contenido pertenece a los dos.
- **Resumen del entrenador**: los cuatro números de su Home —planes, en uso, por aprobar,
  aprobados sin asignar—, derivados de lo que ya existe. No es un dato nuevo que se guarde.
- **Resumen del nadador**: entregadas, cumplidas y la última respuesta. También derivado.
- **Constancia de aceptación**: qué texto se aceptó, en qué versión y cuándo. Existe desde
  la feature 006; aquí se lee.
- **Qué se guarda** y **Resultado de la supresión**: existen en el dominio desde la feature
  004; aquí se alcanzan por primera vez desde una pantalla.
- **Preferencia de apariencia**: clara, oscura o la del sistema. Es el único dato nuevo que
  esta feature guarda, y vive en el dispositivo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El nadador llega a la sesión de hoy en **un** toque desde que abre la app.
- **SC-002**: El entrenador llega al generador en **un** toque desde que abre la app.
- **SC-003**: El nombre del destino en el que se está se lee **entero**, sin truncar, a 320 px
  de ancho y en los dos temas. Las cinco etiquetas de la barra se muestran desde 500 px.
  Corregido durante la implementación: el enunciado anterior —las cinco a 320 px— era
  imposible, porque «Ver Plan» necesita 100 px con la letra mínima que la feature 005 declaró
  y cinco destinos en 320 px tienen 64 cada uno. Lo que cede es la barra, no la palabra; la
  medida y las alternativas rechazadas están en la garantía H9 del contrato.
- **SC-004**: Una persona que no ha visto la app encuentra dónde cerrar sesión en menos de
  diez segundos, sin ayuda.
- **SC-005**: Los tres derechos de la Ley 1581 se alcanzan desde Ajustes en **dos** toques o
  menos, y hoy no se alcanzan en ninguno.
- **SC-006**: Las pruebas de las features 001 a 006 pasan; las únicas modificadas son las de
  navegación de `test/widget_test.dart`, y el total de pruebas no baja.
- **SC-007**: Home abre sin conexión y dice de cuándo son sus datos, en los dos recorridos.
- **SC-008**: **Cero** controles pulsables que no hagan nada en toda la app.
- **SC-009**: Cambiar de destino y volver no pierde nada escrito, comprobado con una sesión a
  medio editar y una respuesta del nadador a medio escribir.
- **SC-010**: El entrenador encuentra el plan de un nadador concreto, entre al menos veinte
  planes, en menos de quince segundos usando la búsqueda o el filtro.
- **SC-011**: Nadie borra sus datos con un solo toque: la supresión exige **dos** acciones
  deliberadas, y la segunda muestra qué se borra y qué sobrevive.

## Assumptions

- **La app abre en Home** para los dos roles. Es la portada y está al centro; abrir en otro
  sitio haría que la posición central no significara nada.
- **«En uso»** es un plan publicado, asignado al menos a un nadador, y con al menos una
  sesión respondida. Un plan asignado que nadie ha tocado está asignado, no en uso.
- **«Pendiente de aprobar»** es un plan en borrador que ya pasó la auditoría sin bloqueos.
  **«Aprobado sin asignar»** es un plan aprobado sin ninguna asignación.
- **El entrenador gobierna en Ajustes solo su propia cuenta.** Los derechos de un nadador los
  ejercita ese nadador o su acudiente, no él. Lo que el entrenador ve de sus nadadores sigue
  donde está: en `Ver Plan`.
- **El panel de nadadores vive dentro de `Ver Plan`**, no como un sexto destino. La barra
  tiene cinco posiciones y esa decisión es del entrenador.
- **La tira de sesión de encima de la app puede desaparecer** cuando cerrar sesión viva en
  Ajustes. El aviso de modo local se queda, porque avisa de una condición, no de una
  identidad.
- **Los iconos salen del juego que ya usa la app**; esta feature no introduce un sistema de
  iconos nuevo.
- **La preferencia de apariencia es por dispositivo**, no por cuenta: no viaja al servidor.
- **El `Análisis` del entrenador llega en la feature 010** y el `Generar` del nadador en la
  **008**, según el roadmap. El `Análisis` del nadador nace con «Mi progreso» dentro, y la
  010 lo extiende en lugar de inventarlo.

## Dependencies

- **Feature 004**: los roles y los permisos que deciden el recorrido, y el dominio
  `DerechosDelTitular` que Ajustes alcanza por primera vez.
- **Feature 003**: la sesión del día, que pasa a `Ver Plan`, y «Mi progreso», que pasa a
  `Análisis`. Ninguna de las dos cambia lo que hace.
- **Feature 005**: el tema, los componentes y el espaciado. Esta feature no define ninguno.
- **Feature 006**: el perfil —nombre, fecha de nacimiento, país— y las constancias de
  aceptación que Ajustes muestra.
- **Features 001 y 002**: el generador y el editor, que pasan a ser el `Generar` del
  entrenador.

## Out of Scope

- El `Análisis` del entrenador, y lo que al nadador le falta en el suyo: el recorrido
  detallado y la petición de feedback son la feature **010**, y el video sigue fuera de
  alcance con su propio ámbito de consentimiento. Lo que esta feature pone en `Análisis` del
  nadador es lo que ya existía, movido de sitio.
- La solicitud de entrenamiento del nadador, que es la feature **008**.
- El macrociclo, el mesociclo y el revelado progresivo, que son la feature **009**: el
  dominio hoy solo tiene `Microciclo`.
- Notificaciones de cualquier clase.
- Cambiar el correo de la cuenta.
- Las verificaciones manuales aplazadas —T088 y T089 de la 004, C1 y C2 de la 003—, que se
  cierran después de la 010.

## Clarifications

### Sesión 2026-10-25

**¿Quién ejecuta la supresión en la cuenta de un menor?** (FR-023)

Decisión del entrenador: **la ejecuta el propio menor**, igual que un adulto. El derecho es
del titular, y el titular es el menor.

Yo había recomendado lo contrario —que quedara como solicitud a confirmar por el acudiente,
por coherencia con la feature 004, donde es él quien autoriza que los datos se guarden— y el
entrenador mantuvo su decisión después de leerlo. Queda escrito aquí porque es una decisión
con peso legal y conviene que se sepa que fue deliberada: la Ley 1581 reconoce el derecho al
titular, y el Decreto 1377 exige que el menor sea oído. Lo que esta decisión acepta es que
un nadador de nueve años puede borrar su propio historial sin que nadie lo revise, y que eso
no se deshace.

Lo único que se añadió por esa irreversibilidad es la confirmación en dos pasos (FR-023,
SC-011), que es lo habitual en cualquier acción que no se puede deshacer y no le quita el
derecho a nadie.

**¿Dónde queda la pantalla «Mi progreso» de la feature 003?** (FR-031)

Decisión: **pasa a ser el `Análisis` del nadador**, y su `Home` es un resumen más corto
construido de los mismos datos.

Consecuencias que esto arrastró por la spec: el `Análisis` del nadador **ya no** es una
pestaña sin contenido —solo lo es el del entrenador—, la feature 010 extiende lo que
encuentre ahí en lugar de partir de cero, y `Home` tiene que construirse: es la única
pantalla verdaderamente nueva del recorrido del nadador en esta feature.
