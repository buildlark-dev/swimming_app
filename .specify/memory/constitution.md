# Constitución de natacion_app

Producto: comunidad de natación en línea dirigida por un entrenador, con planes de
entrenamiento, seguimiento de progreso, retroalimentación en video y contenido educativo,
bajo un modelo freemium por suscripción.

El plan entregado es **interactivo**: vive dentro de la aplicación, el nadador actúa sobre
él y su respuesta vuelve al entrenador. No es un documento que se lee y se cierra.

## Core Principles

### I. Metodología del Entrenador como Norma

La metodología del entrenador, versionada en `docs/metodologia/` (`PROMPT_MAESTRO_V3.4.md`
y la Biblioteca Oficial de ejercicios), es la **fuente normativa del dominio**. El software
la implementa; no la interpreta, no la flexibiliza y no la sustituye.

Esos documentos son la única fuente válida. Una regla de entrenamiento que no esté
respaldada por ellos no se implementa, y modificarlos exige subir su versión y actualizar
las pruebas afectadas.

Reglas verificables que el sistema DEBE hacer cumplir:

- **No invención (R2):** un plan solo puede contener ejercicios de la Biblioteca Oficial,
  con el nombre exacto y el estilo entre paréntesis cuando se repita entre estilos
  (`FLECHA (Espalda)`). Un ejercicio ausente de la biblioteca no se genera ni se acepta:
  se reporta como vacío.
- **Parámetros de categoría (R4):** los volúmenes por sesión y las frecuencias semanales
  de Iniciación, Tecnificación, Precompetitivo, Competitivo y Alto Rendimiento se validan
  aritméticamente. Un descenso por afinación (taper) solo es válido si viene marcado como
  deliberado y justificado.
- **Zonas de intensidad:** A1, A2, A3, AT, Máx y Velocidad son bandas contiguas y sin
  solapamiento. Ninguna carga se contabiliza dos veces.
- **Distribuciones ATR (R5):** los porcentajes por fase (Acumulación, Transformación,
  Realización) y el porcentaje de trabajo técnico son restricciones comprobables, y cada
  fila de la distribución suma 100%.
- **Estructura de sesión:** toda sesión tiene objetivo técnico, objetivo fisiológico y las
  tres partes (inicial 40%, central 50%, final 10%).
- **Información completa (R3):** ante datos faltantes el sistema pregunta; NO DEBE
  completar vacíos con suposiciones. Un supuesto inevitable se muestra marcado como tal.
- **Auditoría (sección 16):** la tabla de auditoría DEBE ser computable. Antes de que un
  plan se entregue, el sistema muestra qué criterios cumple y cuáles no.

Cada plan almacenado DEBE registrar la versión de metodología bajo la que se construyó.
Un cambio de metodología no reescribe retroactivamente planes ya entregados.

Razón: lo que el entrenador vende es su criterio técnico, no la aplicación. Un plan que
viole estas reglas no es un defecto de software: es un daño a su nombre profesional y a la
preparación de un deportista real.

### II. Dominio en Dart Puro y Verificable

Las entidades y reglas del dominio (nadador, categoría, macrociclo, mesociclo, microciclo,
sesión, serie, zona de intensidad, marca, prueba de control) DEBEN vivir en Dart puro, sin
importar `package:flutter/*` ni ningún SDK de Firebase. El acceso a datos se expresa
mediante interfaces del dominio; la implementación con Firestore vive en la capa externa.

El vocabulario visible al usuario y el de las reglas de entrenamiento DEBEN usar la
notación del entrenador (AL, PL, PULL, PN, Hyp n, REC, `NxD / t`, RPE). Un término que no
esté en el glosario ni en la Biblioteca se trata como desconocido: se pregunta, no se
asume.

Razón: las reglas de entrenamiento son el activo del producto. Si viven dentro de widgets
o de consultas a Firestore, dejan de ser revisables y dejan de ser portables.

### III. Pruebas de las Reglas que Llegan al Nadador (NO NEGOCIABLE)

Toda regla de dominio nueva o modificada DEBE llegar con pruebas en `test/` que cubran el
caso típico y al menos un caso límite (fronteras de volumen por categoría, porcentajes que
no suman 100, tiempos inválidos, plan sin datos suficientes).

Cada criterio de la tabla de auditoría DEBE tener una prueba que demuestre que detecta la
violación que le corresponde. Una auditoría que nunca falla no está implementada.

Las reglas de seguridad de Firestore y Storage DEBEN probarse automáticamente contra el
emulador, incluyendo casos negativos: un nadador no puede leer los datos ni los videos de
otro.

Todo plan generado automáticamente DEBE tener pruebas que demuestren que **cumple la
auditoría por construcción**, no por casualidad: dados unos datos de entrada, la
distribución de zonas, el porcentaje técnico y el volumen por sesión salen dentro de lo
prescrito.

`flutter test` DEBE pasar en verde antes de dar por terminada cualquier tarea de
`tasks.md`. Una tarea con pruebas rojas no se reporta como completada.

Razón: aquí conviven dos riesgos que no se detectan mirando la pantalla — un cálculo de
carga equivocado y una fuga de datos de un menor de edad.

### IV. El Criterio del Entrenador no se Delega

Ningún plan, corrección técnica ni retroalimentación llega a un nadador sin **aprobación
explícita del entrenador**. Todo contenido dirigido a un deportista tiene estado
declarado: `borrador` → `aprobado` → `publicado`. Solo el entrenador mueve un contenido a
`aprobado`.

La app NO DEBE presentarse como consejo médico ni fisioterapéutico. Un reporte de dolor,
lesión o malestar se marca, se hace visible al entrenador y NO DEBE resolverse de forma
automática ni ocultarse tras una respuesta genérica.

**Automatización (dentro de alcance desde la versión 1.1.0).** La generación de planes se
incorpora únicamente a través de una interfaz del dominio, con estas condiciones no
negociables:

- su salida nace en estado `borrador`;
- pasa la auditoría de la sección 16 antes de poder aprobarse;
- queda marcada con **cómo** se generó;
- nunca alcanza a un nadador sin la firma del entrenador.

Existen dos formas de automatización, con exigencias distintas:

- **Generación determinista.** La app compone el plan a partir de las reglas ya codificadas:
  rangos de volumen por categoría, distribución de zonas de la fase, reparto de estilos,
  estructura de sesión y selección de ejercicios según el error diagnosticado. Cumple **por
  construcción**, es reproducible y funciona sin conexión. Es la vía por defecto.
- **Generación asistida por modelo de lenguaje.** Su salida es una **propuesta no
  confiable** y se valida antes de mostrarse como plan, igual que cualquier entrada externa.
  NO DEBE sustituir a la generación determinista en lo que es aritmética ni distribución: se
  reserva para lo que es criterio, como redactar objetivos, nombrar el microciclo por su
  componente acentuado o interconectar cargas. Un fallo del proveedor NO DEBE dejar al
  entrenador sin poder generar un plan.

El orden de construcción es **determinista primero y modelo encima**, nunca al revés:
montar el modelo sobre reglas no codificadas convertiría la tendencia a cumplir en la única
garantía disponible.

La automatización NO DEBE eliminar los puntos de decisión que la metodología reserva al
entrenador. **Lo que la constitución exige es el punto de decisión, no el número de
fases.** La sección 18 ordena construir un proyecto extenso en seis fases con su
confirmación entre cada una, y declara su propio motivo: «esto mejora la precisión y
reduce errores». Ese motivo se cumple de forma distinta según cómo se genere:

- **Generación determinista.** Basta **una** confirmación del entrenador sobre la
  estructura general del macrociclo, que es donde vive su criterio: modelar la prueba y
  modelar al nadador, pasos 2 y 3 de la sección 4. No son datos que una fórmula derive —
  estilo dominante, errores técnicos, ritmo de paso, tolerancia a la fatiga, recuperación
  y motivación—, y el software NO DEBE decidirlos. Fijada esa estructura, mesociclos,
  microciclos y sesiones se derivan por construcción: ahí no queda criterio que delegar,
  y exigir cinco confirmaciones más sería pedirle que firme aritmética.
- **Generación asistida por modelo de lenguaje.** Las seis fases con confirmación entre
  cada una siguen siendo **obligatorias**. Su motivo original sigue vigente: la precisión
  de una salida larga se degrada, y ahí cada confirmación es un control real y no un
  trámite.

Lo que no cambia en ninguno de los dos caminos: nada llega a un nadador sin la firma del
entrenador, y un macrociclo cuya estructura decidiera el software sería su criterio
delegado aunque cada sesión pasara la auditoría.

Razón: la comunidad se suscribe a un entrenador con nombre propio. La automatización puede
ahorrarle tiempo; no puede ocupar su lugar ni firmar por él.

### V. Datos de Deportistas: Mínimos, Protegidos y Portables

Nombres, edades, marcas, videos, fotos y reportes de dolor son **datos personales**, con
frecuencia de menores de edad, y se tratan bajo la Ley 1581 de 2012 (habeas data,
Colombia).

- **Minimización:** no se recolecta ningún dato que no tenga un uso declarado en la feature
  que lo pide.
- **Menores de edad:** el registro de un menor exige consentimiento verificable de su
  padre, madre o acudiente, registrado con fecha. Sin ese consentimiento no se habilita la
  carga de video.
- **El consentimiento es requisito de publicación, no una feature opcional posterior.**
  Mientras no exista su registro, la app se usa únicamente con datos de prueba o del propio
  entrenador. Abrirla a nadadores reales sin él incumple este principio.
- **Video:** privado por defecto. Solo el nadador, su acudiente y el entrenador pueden
  verlo. NO DEBE usarse para promoción, para entrenar modelos ni compartirse fuera de la
  app sin consentimiento adicional, específico y revocable. Todo video tiene plazo de
  retención declarado.
- **Reglas de acceso:** deniegan por defecto; el acceso se concede explícitamente y se
  prueba (Principio III).
- **Registros y analítica:** NO DEBEN contener nombres, marcas, videos ni identificadores
  del nadador.
- **Portabilidad y borrado:** el usuario puede exportar sus datos en un formato legible y
  solicitar su eliminación. El modelo de datos DEBE permitirlo sin rediseño.

Razón: un entrenador que maneja menores responde por esa información ante las familias y
ante la ley, y ninguna funcionalidad vale una filtración.

### VI. Freemium Honesto

El nivel gratuito DEBE ser útil por sí solo: biblioteca de ejercicios, contenido educativo
y registro del progreso propio. El nivel pago cubre planes personalizados,
retroalimentación en video y comunidad privada.

- El muro de pago NUNCA bloquea el acceso del usuario a los datos que él mismo generó, a su
  historial, ni a su exportación. Al vencer una suscripción el contenido pasa a solo
  lectura; no se borra ni se secuestra.
- Los límites del plan gratuito y los precios (en COP) se definen en **una sola fuente de
  verdad** en el código y se muestran completos antes de pedir datos de pago.
- Cancelar DEBE ser tan simple como suscribirse. Se avisa antes de cada renovación.
- Prohibidos los patrones oscuros: cuentas regresivas falsas, escasez inventada, botones de
  cancelación escondidos o casillas premarcadas.

Razón: la comunidad se construye sobre confianza en una persona. Un cobro que se siente
tramposo cuesta más que lo que recauda.

### VII. Rebanadas Verticales y Simplicidad

Cada feature DEBE entregar una rebanada vertical que una persona real pueda usar de punta a
punta (dato → regla → pantalla). NO DEBEN construirse las cuatro áreas del producto
(planes, progreso, video, comunidad) en paralelo: el orden se declara en el roadmap y se
respeta.

Agregar una dependencia en `pubspec.yaml`, una capa de arquitectura o un gestor de estado
DEBE justificarse en el `plan.md` de la feature que lo necesita, nombrando el problema
concreto que resuelve. Sin esa justificación, la opción por defecto es no agregarlo.

`flutter analyze` DEBE terminar sin errores ni advertencias nuevas. Suprimir un lint exige
un comentario que explique por qué.

Razón: el proyecto lo sostiene una sola persona que además entrena. Cuatro frentes abiertos
a la vez es la forma más segura de no terminar ninguno.

### VIII. Control de Carga Interna

La metodología exige cerrar el ciclo diagnóstico → modelar → programar → **controlar** →
reajustar (sección 4). El producto DEBE implementar el control, no solo la programación.

- El nadador DEBE poder registrar, por sesión: si la cumplió, su RPE percibido (Borg 0-10) y
  observaciones en texto libre.
- Esos registros DEBEN llegar al entrenador y mostrarse junto al plan que los originó. Un
  registro que nadie lee no es control.
- La **carga externa** (lo programado: metros, series, pausas, ritmos) y la **carga interna**
  (la respuesta del nadador) se almacenan y se muestran por separado. NO DEBEN combinarse en
  un mismo indicador.
- Un reporte de dolor, lesión o malestar se marca **aparte** del resto de observaciones,
  llega al entrenador y NO DEBE resolverse de forma automática (Principio IV).
- El registro de la carga interna NO DEBE ser obligatorio para usar la app: un nadador que
  no anota nada sigue viendo su plan. Lo que no se permite es que la app no ofrezca dónde
  anotarlo.

Razón: sin la respuesta del nadador, un plan es una hipótesis que nadie comprueba. El
reajuste que la metodología exige necesita datos que hoy no se recogen en ninguna parte del
flujo del entrenador.

## Restricciones Técnicas y de Plataforma

- **Lenguaje y framework:** Flutter con Dart. Cambiar de stack es una enmienda a esta
  constitución, no una decisión de feature.
- **Plataforma:** Firebase — Authentication, Firestore, Cloud Storage (video) y Hosting
  para el despliegue de la web Flutter.
- **Lógica de servidor** (validación de suscripciones, webhooks de pago, auditoría del
  lado servidor, intermediación con el proveedor del modelo de lenguaje): Cloud Functions en
  TypeScript, o Cloud Run con un servidor Dart `shelf` detrás de un *rewrite* de Hosting si
  se prefiere mantener todo en Dart. La ruta elegida se documenta en el `plan.md` de la
  primera feature que la necesite.
- **Claves de proveedores externos:** una clave de API NUNCA viaja al cliente. La llamada al
  proveedor del modelo de lenguaje se hace desde el servidor; la app habla con ese servidor,
  no con el proveedor.
- **Exportabilidad:** Firestore es NoSQL y las consultas de progreso histórico son su punto
  débil. Por eso el esquema DEBE estar documentado y ser exportable a JSON o formato
  tabular desde el inicio, de modo que migrar a una base relacional siga siendo posible.
- **Idiomas.** El reparto no es arbitrario y cada parte tiene su razón:
  - **En inglés, todo lo que GitHub muestra:** mensajes de commit, pull requests, `README`,
    `CONTRIBUTING`, `docs/DEVELOPMENT.md`, configuración de integración continua,
    plantillas y nombres de rama. Es la cara pública del proyecto.
  - **En español, la interfaz y todo mensaje que un usuario lee.** Los nadadores son
    colombianos y algunos tienen siete años. No es una preferencia de estilo: traducirla
    rompe el producto para quien lo usa.
  - **En español, los documentos de metodología y los documentos de feature** de `specs/`.
    Citan el documento normativo del entrenador, y traducirlos rompería la trazabilidad
    con él.
  - **En español, el vocabulario de dominio en el código:** `Zona`, `FaseAtr`,
    `Microciclo`, `CriterioTransferencia`. Mapean uno a uno con el documento normativo:
    `Zona` en el código **es** la «zona» de la sección 9. Traducirlo metería una capa de
    traducción justo donde este proyecto está construido para no interpretar nada, y un
    error de traducción se volvería una regla de entrenamiento equivocada.
  - El esquema de datos conserva las claves con que ya hay planes guardados. Cambiarlas no
    es un cambio de idioma: es una migración, y se trata como tal.
- **Sin credenciales en el repositorio:** claves de API, secretos de pasarela y archivos de
  configuración sensibles se inyectan en tiempo de ejecución o de build.
- **Uso a pie de piscina.** La señal en las piscinas suele ser mala, así que funcionar sin
  conexión no es una mejora opcional:
  - **Lectura:** consultar los planes propios, la sesión del día y el progreso propio NUNCA
    DEBE requerir red.
  - **Escritura:** el nadador DEBE poder anotar su retroalimentación y marcar una sesión
    como realizada sin conexión. La app guarda el registro en el dispositivo, muestra un
    estado explícito del tipo «Guardado el progreso, se enviará cuando tengas acceso a
    internet» y sincroniza cuando la red vuelve. Ningún dato escrito sin conexión se pierde
    en silencio.
  - Requieren red únicamente la carga de video, la comunidad, los pagos y la generación
    asistida por modelo de lenguaje.
- **El entregable vive en la app:** un plan aprobado se consulta y se usa dentro de la
  aplicación. La exportación o descarga es una copia para archivo o impresión, no el
  producto.
- **Unidades y formatos:** sistema métrico, piscina de 25 m o 50 m declarada en cada plan,
  tiempos en `mm:ss.cc`, RPE en escala de Borg 0-10.
- **Canal de cobro:** pendiente de decisión. La feature de pagos DEBE resolverlo en su
  `plan.md` antes de escribir código, porque condiciona la arquitectura y el margen.

## Flujo de Desarrollo y Puertas de Calidad

- Toda feature sigue el flujo de Spec Kit: `/speckit-specify` → `/speckit-plan` →
  `/speckit-tasks` → `/speckit-implement`. La implementación no empieza sin `tasks.md`.
- `plan.md` DEBE incluir una revisión contra estos ocho principios. Toda desviación se
  documenta con su justificación **antes** de escribir código.
- Puertas de calidad antes de cerrar una feature, en este orden: `flutter analyze` limpio,
  `flutter test` en verde, pruebas de reglas de seguridad en el emulador, y verificación
  manual del flujo en al menos una plataforma.
- Los defectos entran por la extensión `bug` (`/speckit-bug-assess` → `/speckit-bug-fix` →
  `/speckit-bug-test`). Toda corrección DEBE incluir una prueba que falle antes del arreglo.
- Un cambio en las reglas de metodología exige, en el mismo cambio: actualizar el documento
  de metodología versionado dentro del repositorio, subir su versión y actualizar las
  pruebas afectadas.
- Los entregables para el entrenador (especificaciones, planes, informes) van en español.
- Lo que GitHub muestra va en inglés: mensajes de commit, pull requests y documentación de
  la raíz. Los commits anteriores al 2026-10-13 están en español y no se reescriben: el
  historial ya empujado se queda como está.

## Governance

Esta constitución tiene precedencia sobre cualquier otra convención del proyecto, incluidas
las instrucciones de agentes y las plantillas de `.specify/templates/`.

**Precedencia frente a la metodología:** el `PROMPT_MAESTRO` define **qué es un plan de
entrenamiento válido** y manda en todo lo relativo al contenido deportivo. Esta
constitución define **cómo se construye el software** y manda en todo lo relativo a
arquitectura, pruebas, datos y producto. Si un requisito de software obligara a violar la
metodología, se detiene el trabajo y decide el entrenador.

Enmiendas: se realizan únicamente sobre `.specify/memory/constitution.md` mediante
`/speckit-constitution`, registrando qué principio cambia y por qué. Una enmienda que
invalide trabajo ya planificado DEBE indicar cómo se migran las features afectadas.

Versionado semántico de este documento:

- MAJOR: se elimina o redefine un principio de forma incompatible con lo anterior.
- MINOR: se agrega un principio o una sección, o se amplía materialmente una guía.
- PATCH: aclaraciones, redacción y correcciones sin cambio de obligación.

Revisión de cumplimiento: en cada `/speckit-plan` y antes de cerrar cada feature se
verifica el cumplimiento de los ocho principios. La complejidad no justificada se elimina
o se documenta.

**Version**: 2.0.0 | **Ratified**: 2026-09-25 | **Last Amended**: 2026-11-04
