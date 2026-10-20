# Especificación de feature: Tema visual y sistema de componentes

**Feature Branch**: `005-visual-theme`

**Created**: 2026-10-20

**Status**: Draft

**Input**: Tema visual y sistema de componentes. La app necesita una identidad
propia, armónica, construida sobre una paleta de azules marinos. Un solo sitio donde se
definan colores, tipografía, espaciado y los componentes repetidos (tarjetas, campos,
botones, avisos), para que ninguna pantalla improvise. Debe funcionar en claro y oscuro,
cumplir contraste accesible, y aplicarse a las pantallas que ya existen sin cambiar lo que
hacen. El vocabulario visible sigue en español. Los nadadores son colombianos y algunos
tienen siete años: legibilidad por encima de elegancia.

---

## Por qué existe esta feature

La app está desplegada y en uso. Su aspecto es el que salió de un color semilla puesto en
una línea, y nunca se decidió.

Tres cosas concretas que hoy fallan, medidas sobre el código que hay:

- **No hay modo oscuro.** Ninguno. A pie de piscina, de noche o bajo techo, la app es un
  rectángulo blanco.
- **Todo lo que pide atención se pinta de rojo.** De los cincuenta usos de color
  semántico, **veintisiete son el color de error**: el aviso de sincronización, el de modo
  local, las advertencias de auditoría. «Guardado el progreso, se enviará cuando tengas
  acceso a internet» es una buena noticia y se ve como una alarma.
- **El dominio no tiene lenguaje visual.** Las siete zonas de intensidad, los tres estados
  del plan y los reportes de molestia son conceptos de la metodología que hoy se distinguen
  solo por texto.

Hay una cosa que **sí** está bien y que esta feature hereda: **no hay un solo color escrito
a mano en las veintiuna pantallas**. Todo pasa ya por el esquema de color. Cambiar la
identidad de la app es, de verdad, cambiarla en un sitio.

Esta feature **no cambia lo que hace ninguna pantalla**. Cambia cómo se ve y deja escrito
el lenguaje con el que se verán las que vengan: el alta de cuenta, el HUB y las demás.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - La app se lee a pie de piscina (Priority: P1)

El nadador saca el teléfono con las manos mojadas, bajo el sol de la tarde, y lee lo que le
toca hoy sin acercarse la pantalla a la cara. Pulsa «ya la hice» a la primera.

**Why this priority**: es dónde se usa la app. Un tema bonito que no se lee al sol no sirve,
y el grupo de Iniciación Avanzada son niños de 7 a 10 años.

**Independent Test**: se abre la app en un teléfono al aire libre y se recorre la sesión del
día sin ampliar el texto ni fallar un toque.

**Acceptance Scenarios**:

1. **Given** cualquier texto de la app, **When** se mide su contraste contra el fondo,
   **Then** cumple al menos la relación exigida para texto normal.
2. **Given** cualquier control que se pulse, **When** se mide su área sensible, **Then**
   es lo bastante grande para un dedo mojado, incluso si el icono es pequeño.
3. **Given** el tamaño de letra del sistema aumentado, **When** se abre cualquier pantalla,
   **Then** el texto crece y **nada queda cortado ni superpuesto**.
4. **Given** una serie escrita con la notación del entrenador, **When** el nadador la lee,
   **Then** los números y las abreviaturas se distinguen sin ambigüedad.

---

### User Story 2 - Todas las pantallas parecen la misma app (Priority: P1)

El entrenador pasa del generador al editor y a los perfiles, y en ningún momento parece que
cambió de aplicación. Los avisos se ven igual en todas partes, los botones pesan lo mismo y
las tarjetas se separan igual.

**Why this priority**: es la razón de la feature. Sin un solo sitio donde esté decidido,
cada pantalla nueva vuelve a improvisar, y las que vienen son muchas.

**Independent Test**: se recorren las pantallas que ya existen y se comprueba que los
elementos repetidos —tarjetas, campos, botones, avisos— se ven y se comportan igual.

**Acceptance Scenarios**:

1. **Given** las pantallas que ya existen, **When** se aplica el tema, **Then** **ninguna
   cambia lo que hace ni lo que dice**: solo cómo se ve.
2. **Given** un aviso en dos pantallas distintas, **When** se comparan, **Then** son el
   mismo componente, no dos parecidos.
3. **Given** una pantalla nueva, **When** se construye con el sistema, **Then** no necesita
   decidir ni un color ni un espaciado por su cuenta.
4. **Given** cualquier pantalla, **When** se busca un color escrito a mano, **Then** no hay
   ninguno.

---

### User Story 3 - Claro y oscuro (Priority: P2)

La app respeta cómo tenga el teléfono quien la usa, y se ve bien de las dos maneras.

**Why this priority**: es P2 y no P1 porque la app funciona sin ello, pero media jornada de
entrenamiento es de noche o bajo techo, y hoy no hay más que blanco.

**Independent Test**: se cambia el tema del sistema y se recorren las pantallas en los dos
modos.

**Acceptance Scenarios**:

1. **Given** el teléfono en modo oscuro, **When** se abre la app, **Then** se muestra en
   oscuro sin que nadie lo configure.
2. **Given** cualquier pantalla en modo oscuro, **When** se mide el contraste, **Then**
   cumple lo mismo que en claro.
3. **Given** un aviso o un estado, **When** se ve en los dos modos, **Then** significa lo
   mismo y se reconoce igual.

---

### User Story 4 - Lo que la metodología distingue, la app lo distingue (Priority: P2)

Las siete zonas de intensidad, los tres estados del plan y los reportes de molestia dejan de
diferenciarse solo por texto.

**Why this priority**: es lo que convierte un tema en el lenguaje visual de **esta** app y
no de cualquier otra. Es P2 porque hoy se entiende leyendo, y lo que esta historia añade es
reconocer de un vistazo.

**Independent Test**: se muestran una tabla de zonas, un plan en cada estado y una sesión
con molestia, y se comprueba que se distinguen sin leer la etiqueta y **también** con la
etiqueta tapada en escala de grises.

**Acceptance Scenarios**:

1. **Given** las siete zonas, **When** se muestran juntas, **Then** se distinguen entre sí y
   su orden visual sigue el orden de intensidad de la metodología.
2. **Given** cualquier distinción del dominio, **When** se mira sin color —en escala de
   grises o con daltonismo—, **Then** **sigue distinguiéndose**, porque el color nunca es la
   única señal.
3. **Given** un plan en `borrador`, `aprobado` y `publicado`, **When** se ven juntos,
   **Then** se reconoce cuál es cuál sin leer el estado.
4. **Given** un reporte de molestia, **When** el entrenador lo ve, **Then** destaca lo
   suficiente para encontrarlo, y **no se presenta como una alarma médica**: la app no
   diagnostica ni propone conducta (principio IV).

---

### Edge Cases

- **Un aviso que hoy es rojo y no es un error.** «Guardado, se enviará cuando haya
  internet» es tranquilizador; «sin consentimiento, lo tuyo no sale» es informativo; «modo
  local» es una advertencia. Hoy los tres son del mismo rojo que un fallo de verdad.
- **El tamaño de letra del sistema al 200%.** Hay personas que lo llevan así siempre.
- **Pantallas muy estrechas**, de un teléfono pequeño y viejo, que es lo que puede llevar un
  niño de nueve años.
- **Sol directo sobre la pantalla**, con el brillo al máximo y la pantalla mojada.
- **Daltonismo.** Entre un grupo de nadadores, es cuestión de tiempo.
- **Un texto largo donde se esperaba uno corto**: el nombre de un ejercicio de la Biblioteca
  o una observación del nadador no se recortan en silencio.
- **El tema no carga.** La app tiene que abrir igual, con lo que haya por omisión, antes que
  no abrir.

## Requirements *(mandatory)*

### Functional Requirements

#### Un solo sitio

- **FR-001**: Colores, tipografía, espaciado y radios DEBEN estar definidos en **un solo
  lugar**, y toda la interfaz DEBE tomarlos de ahí.
- **FR-002**: Ninguna pantalla DEBE contener un color, un tamaño de letra ni un espaciado
  escrito a mano. Hoy no hay ninguno y esa propiedad DEBE conservarse.
- **FR-003**: Los elementos repetidos —tarjetas, campos, botones, avisos, cabeceras de
  sección— DEBEN existir como componentes compartidos, no reconstruirse en cada pantalla.
- **FR-004**: Aplicar el tema NO DEBE cambiar lo que ninguna pantalla hace ni el texto que
  muestra.

#### Que se lea

- **FR-005**: Todo texto DEBE cumplir el contraste mínimo exigido para su tamaño, en claro
  y en oscuro.
- **FR-006**: Toda área pulsable DEBE tener un tamaño mínimo cómodo para un dedo mojado,
  aunque su icono sea más pequeño.
- **FR-007**: La interfaz DEBE respetar el tamaño de letra del sistema y seguir siendo
  legible y completa cuando esté aumentado.
- **FR-008**: La tipografía DEBE distinguir sin ambigüedad los caracteres que la notación
  del entrenador usa junta —cifras, `x`, `/`, `'`, `"`— porque `4x100 / 1'40"` es una
  instrucción y leerla mal cambia el entrenamiento.

#### Claro y oscuro

- **FR-009**: La app DEBE ofrecer modo claro y modo oscuro y seguir por omisión el del
  sistema.
- **FR-010**: Los dos modos DEBEN cumplir las mismas exigencias de contraste.
- **FR-011**: Un mismo significado DEBE reconocerse igual en los dos modos.

#### El lenguaje del dominio

- **FR-012**: El sistema DEBE definir una escala visual para las **siete zonas de
  intensidad** cuyo orden corresponda al orden de intensidad de la metodología (sección 9).
- **FR-013**: El sistema DEBE definir cómo se muestran los **tres estados del plan**:
  `borrador`, `aprobado` y `publicado`.
- **FR-014**: El sistema DEBE definir cómo se señala un **reporte de molestia**: visible
  para encontrarlo sin leerlo todo, y **sin apariencia de alarma médica** ni de conducta
  sugerida (principio IV).
- **FR-015**: El color NUNCA DEBE ser la única señal de una distinción. Toda diferencia DEBE
  reconocerse también sin color.

#### Avisos

- **FR-016**: El sistema DEBE distinguir al menos **cuatro tonos de aviso**: informativo,
  de éxito, de advertencia y de error. Hoy la app usa el de error para todos.
- **FR-017**: Un registro guardado a la espera de envío NO DEBE presentarse como un error:
  es el funcionamiento normal a pie de piscina y así tiene que verse.

#### Lo que no se rompe

- **FR-018**: Si el tema no se pudiera cargar, la app DEBE abrir igual con una apariencia
  por omisión. Quedarse sin abrir por un asunto de aspecto no es aceptable.
- **FR-019**: El vocabulario visible DEBE seguir en español.

### Key Entities

- **Paleta**: los colores de la app, construidos sobre azules marinos, con sus variantes
  para claro y oscuro. Incluye los de marca, los de aviso y los del dominio.
- **Escala tipográfica**: los tamaños y pesos del texto, con su uso declarado.
- **Escala de espaciado**: las separaciones y radios admitidos, para que el ritmo de las
  pantallas sea uno.
- **Componentes compartidos**: tarjeta, campo, botón, aviso, cabecera de sección, estado
  vacío. Lo que se repite, decidido una vez.
- **Escala de zonas**: la correspondencia entre las siete zonas de intensidad y su
  representación visual.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: **El 100% del texto** cumple el contraste mínimo de su tamaño, en claro y en
  oscuro, comprobado sobre todas las pantallas.
- **SC-002**: **Ningún color, tamaño de letra ni espaciado escrito a mano** en toda la
  interfaz, comprobable de forma automática.
- **SC-003**: Con el tamaño de letra del sistema al **200%**, ninguna pantalla corta,
  superpone ni oculta texto.
- **SC-004**: **Toda área pulsable** alcanza el tamaño mínimo cómodo, sin excepciones.
- **SC-005**: Las pantallas que ya existen hacen **exactamente lo mismo** después del tema:
  las pruebas que había siguen pasando sin modificarse.
- **SC-006**: **Las siete zonas se distinguen entre sí en escala de grises**, no solo en
  color.
- **SC-007**: Los tres estados del plan se reconocen sin leer la etiqueta.
- **SC-008**: Un aviso de «guardado, se enviará luego» **no se ve como un error**,
  comprobado porque no usa el tono de error.
- **SC-009**: La app abre con una apariencia utilizable aunque el tema no cargue.
- **SC-010**: Un elemento repetido se ve igual en todas las pantallas donde aparece, porque
  **es el mismo componente**.

## Assumptions

- **Se construye sobre lo que el framework ya ofrece.** No se añade una dependencia de
  terceros para esto: el principio VII pide nombrar el problema que resuelve una
  dependencia, y «queremos otros colores» no lo es.
- **El punto de partida es bueno.** Las veintiuna pantallas no tienen un solo color escrito
  a mano, así que el trabajo es definir bien el sistema, no limpiar antes.
- **El modo claro y el oscuro siguen al sistema**, sin ajuste propio. El ajuste manual, si
  se quiere, pertenece a la pantalla de Ajustes de la feature 007.
- **Esta feature no añade ni quita pantallas.** Reviste las que hay.
- **El contraste se mide, no se opina.** Las comprobaciones son automáticas allí donde se
  pueda.
- **La identidad es azul marino** por decisión del entrenador, y el resto de la paleta se
  construye para armonizar con ella y para cumplir el contraste, no al revés.

## Dependencies

- **Feature 001 a 004**: las veintiuna pantallas que esta feature reviste.
- **Metodología 3.6.0**: la sección 9 define las siete zonas y su orden, que es lo que la
  escala visual tiene que respetar.

## Out of Scope

- **Pantallas nuevas.** El alta de cuenta es la feature 006 y el HUB la 007.
- **Cambiar lo que una pantalla hace o dice.**
- **Un ajuste manual de claro/oscuro**, que pertenece a la pantalla de Ajustes de la 007.
- **Animaciones y transiciones.**
- **Ilustraciones, iconografía propia y logotipo.**
- **Reorganizar la navegación**, que es la 007.
