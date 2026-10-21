# Investigación — Feature 006

**Feature**: alta de cuenta y consentimiento en el registro
**Fecha**: 2026-10-21

Esta feature se construye **encima** de la 004, no al lado. Antes de decidir nada se leyó lo
que la 004 dejó montado, y de ahí salieron tres conflictos que la especificación no podía
ver. Están los tres aquí, cada uno con su decisión.

---

## D1 — Quién puede pedir un consentimiento

**El conflicto.** La feature 006 dice que el menor escribe el correo de su acudiente en el
alta y el sistema emite la solicitud. La feature 004 **prohibió exactamente eso**, y lo
escribió en el código:

```ts
if (!esEntrenador(peticion)) {
  throw new HttpsError(
    'permission-denied',
    'Solo el entrenador pide un consentimiento, y el canal sale de su matrícula.'
  );
}
```

Y en el dominio, sobre el campo `canal`:

> «Lo aporta el entrenador desde su matrícula, **nunca el nadador** (FR-014). Es la garantía
> que cierra el agujero obvio —un niño poniendo un correo suyo— y la que hace que el resto de
> la cadena signifique algo.»

No es una restricción accidental. Es el modelo de amenaza de la 004: **un menor que pone una
dirección que controla se autoriza a sí mismo**, y a partir de ahí todo el formulario de
consentimiento —la identificación del acudiente, la declaración de que oyó al menor— es
teatro. El FR-018 de la 006 (rechazar el mismo correo de la cuenta) tapa el caso ingenuo y
ninguno de los demás: una segunda dirección cuesta dos minutos.

**Lo que invalida la premisa de la 004.** La regla del entrenador da por hecho que existe una
matrícula: un grupo cerrado de nadadores que alguien inscribió y de quienes tiene los datos de
contacto de las familias. **Eso no es lo que esta app es.**

El entrenador lo dijo con todas las letras el 2026-10-21:

> «La app no la utilizará un grupo que yo tengo matriculado, la utilizará cualquier persona a
> nivel nacional/internacional.»

Una nadadora de catorce años en otro país que se descarga la app **no tiene un entrenador que
pueda aportar el canal**. No hay matrícula de la que sacarlo. Exigirlo no hace el
consentimiento más seguro: hace que **no exista ninguno**, que es exactamente el estado de hoy
y el peor de todos.

La regla de la 004 no era mala: era correcta para un club cerrado, que es lo que se tenía en
la cabeza al escribirla. Para una app abierta es impracticable.

**Dónde está entonces la garantía.** En el **formulario**, que es lo que el entrenador ya
había decidido antes de la feature 005 y aquí se confirma. El acudiente que abre el enlace
tiene que identificarse, declarar **en qué calidad** actúa y confirmar que **ha oído al
menor** (Decreto 1377 de 2013). Eso es lo que la ley pide y es lo que la 004 ya construyó y
probó.

Un correo verificado por sí solo no sería consentimiento informado. El formulario sí lo es, y
el correo es solo el camino hasta él.

**Decisión.** El menor declara el correo del acudiente en el alta y **la solicitud sale en el
momento**. Además, se graba de dónde vino:

| Origen | Cuándo | Qué significa |
|---|---|---|
| `declaradoPorElNadador` | El alta. **El camino normal** | La dirección la dio quien se registró |
| `matriculaDelEntrenador` | Un entrenador con su grupo | La dirección sale de sus registros |

El entrenador que **sí** tenga un grupo ve el origen y puede volver a pedirlo desde su
matrícula. Para todos los demás —que serán la mayoría— solo existe el primer camino, y está
bien que así sea.

**Por qué se graba el origen si el camino normal es uno solo.** Porque son dos cosas distintas
y cuestan un campo. El día que un entrenador con grupo mire su lista, la diferencia le importa;
y si algún día alguien pregunta cómo llegó un consentimiento concreto, la respuesta está
guardada en lugar de deducirse.

**Alternativas descartadas**:

- *Que solo emita el entrenador*, como hoy. **Impracticable**: la mayoría de los usuarios no
  tendrán entrenador en la app. Sería un consentimiento que no se pide nunca, que es el estado
  actual y el peor posible.
- *Verificar el correo con un código antes de emitir.* Comprueba que la dirección existe y que
  alguien la lee. No comprueba que ese alguien sea el acudiente, que es lo único que importa.
  Cuesta una pantalla más y no cierra nada: quien quiera engañar al sistema lee su propio
  código igual de bien.
- *Pedir un documento del acudiente en el alta.* Más dato personal de un tercero que ni
  siquiera ha dicho que sí todavía, y recogido antes de que nadie lo autorice. Va en contra
  del principio V, y la identificación ya la hace el formulario en el momento correcto: cuando
  el acudiente está delante.

**Lo que esta decisión no pretende.** No pretende impedir que un menor decidido engañe al
sistema. Un adolescente que quiere saltarse esto lo consigue, aquí y en cualquier otra app. Lo
que sí hace es **que la familia que quiere dar su consentimiento tenga por dónde**, y que
quede constancia con fecha de quién autorizó qué, que es lo que la Ley 1581 pide y lo que
protege al entrenador.

---

## D2 — Fecha de nacimiento frente a lo que ya existe

**El conflicto.** El entrenador decidió (Q3) guardar la **fecha de nacimiento** y recalcular
la minoría de edad. Pero la 004 ya tomó la decisión contraria, y la escribió:

> «`declaraSerMayorDeEdad` es **el dato mínimo suficiente** para saber si hace falta el
> consentimiento de un acudiente, y por eso se prefiere a la fecha de nacimiento, que dice
> bastante más de lo que hace falta (minimización, principio V).»

`Nadador` tiene hoy **los dos campos**: `fechaNacimiento` y `declaraSerMayorDeEdad`.

**Decisión.** La fecha de nacimiento pasa a ser la **fuente de verdad**, y
`declaraSerMayorDeEdad` se queda **solo como respaldo para las cuentas que todavía no tienen
fecha** —que son exactamente las que la historia 3 va a completar—. La regla de
`necesitaAcudienteEn` no cambia en su parte importante: **ante la duda, menor**.

El orden de preferencia queda:

1. Si hay fecha de nacimiento, manda la fecha.
2. Si no la hay pero hay declaración, manda la declaración.
3. Si no hay ninguna de las dos, **se trata como menor**.

**Por qué no se borra el campo viejo.** Porque hay cuentas en producción que solo tienen eso,
y porque borrarlo rompería pruebas de la 004 que no se pueden tocar. Se queda, con su papel
reducido y escrito.

**Lo que esto cuesta, dicho en voz alta.** Es un paso atrás en minimización: se guarda una
fecha completa donde antes bastaba un sí o un no. Se acepta porque la alternativa —un booleano
que envejece— produce respuestas equivocadas todos los días a partir del cumpleaños, y una
respuesta equivocada aquí significa pedir un consentimiento que no hace falta, o peor, no
pedir uno que sí.

**Riesgo a vigilar**: dos campos que contestan la misma pregunta son dos sitios donde
equivocarse. Hace falta **un solo sitio** que decida si alguien es menor, y una prueba que
impida que alguna pantalla lo calcule por su cuenta.

---

## D3 — Quién escribe el perfil

**Lo que hay.** Las reglas dicen:

```
match /usuarios/{uid} {
  allow read: if esEntrenador() || (autenticado() && request.auth.uid == uid);
  allow write: if false;
}
```

El cliente **no puede escribir** ahí, a propósito: «si el cliente pudiera, cualquiera se
declararía dueño del perfil de otro y leería sus planes».

**Decisión.** El perfil se guarda **por el servidor**, con una operación nueva que el propio
usuario puede llamar para su propia cuenta. Las reglas no se aflojan: siguen en `write: if
false` para el cliente.

**Por qué no relajar la regla.** Porque la regla no está protegiendo el nombre: está
protegiendo el vínculo entre una cuenta y un nadador, que es lo que decide qué planes se ven.
Abrirla para poder escribir un nombre abriría también eso.

---

## D4 — Dónde vive el perfil

**La confusión posible.** `Nadador` ya tiene `nombre` y `fechaNacimiento`. Parece el sitio.

**Decisión.** No lo es. Son dos cosas distintas que comparten una palabra:

| | Qué es | De quién |
|---|---|---|
| **Perfil de cuenta** (`usuarios/{uid}`) | Quién es la persona detrás del correo | Suyo |
| **Nadador** (`nadadores/{id}`) | Una ficha de entrenamiento: categoría, estilo objetivo, marcas, diagnóstico | Del entrenador |

Un nadador de la matrícula puede no tener cuenta. Una cuenta puede existir antes de que el
entrenador la matricule. El vínculo entre los dos ya existe: el `nadadorId` de `Cuenta`.

**El perfil de cuenta va en `usuarios/{uid}`.** La ficha del entrenador se queda como está.

---

## D5 — Los términos y condiciones

**Decisión.** Un texto **versionado**, empaquetado con la app como el de consentimiento de la
004 (`assets/consentimiento/texto_v1.md`). La aceptación se guarda como un hecho con **versión
y fecha**, no como una casilla marcada.

**Por qué versionado.** Porque la pregunta que alguien hará algún día es «¿qué aceptó esta
familia exactamente?», y la única respuesta útil es el texto que leyeron, no el de hoy.

**Lo que esta feature no puede cerrar.** El texto necesita **revisión legal antes de que lo
lea una familia real**, igual que el de consentimiento de la 004, que sigue pendiente. La
feature se construye con un borrador; no se da por terminada con él.

---

## D6 — Los pasos del alta, y dónde se guarda lo que va a medias

**Decisión.** Los pasos se guardan **en el dispositivo** hasta que el alta termina. Al
servidor no llega un perfil a medias.

**Por qué.** Un perfil a medio escribir en el servidor es un registro que hay que limpiar,
que aparece en las listas del entrenador y que no significa nada. Y lo que se quiere —poder
cerrar la app y volver— se consigue igual guardándolo donde ya se guardan las respuestas sin
conexión, que es la bandeja de salida de la 003.

---

## D8 — Dónde se decide hoy la minoría de edad (tarea T002)

Medido sobre `lib/` antes de tocar nada, el 2026-10-21. Es la lista contra la que se comprueba
al final que **queda un solo sitio** (garantía A4).

| Archivo | Qué hace |
|---|---|
| `dominio/entidades/nadador.dart:108` `edadEn` | **Calcula** la edad desde la fecha |
| `dominio/entidades/nadador.dart:121` `esMenorEn` | **Decide** si es menor. Devuelve `null` si no hay fecha |
| `dominio/entidades/nadador.dart:83` `necesitaAcudienteEn` | **Decide** si hace falta acudiente, combinando los dos campos |
| `datos/serializacion.dart:307-334` | Solo guarda y lee los campos. No decide |
| `dominio/datos_personales/derechos_del_titular.dart:106` | Solo mira si consta la fecha. No decide |

**Ya hay un solo sitio**, y es `Nadador`. Es mejor noticia de la esperada.

**Decisión.** Entonces no se escribe un segundo cálculo en `cuentas/edad.dart`: se **extrae**
el que ya existe a ese archivo, y `Nadador` pasa a delegarle. Así `Perfil` y `Nadador`
contestan con el mismo código, no con dos que se parecen.

Escribir un cálculo nuevo «para el perfil» habría sido el camino corto y el que acaba con dos
respuestas distintas a la misma pregunta. El riesgo que D2 advertía —dos campos, dos sitios—
se cierra aquí.

**Lo que no se toca**: la firma pública de `Nadador`. `edadEn`, `esMenorEn` y
`necesitaAcudienteEn` siguen existiendo e hicieron lo mismo, porque `categoria_sin_edad_test`
de la feature 002 las usa y no se puede modificar.

---

## D9 — El cliente nunca ha llamado a una función, y ahora tiene que hacerlo

**Lo que se encontró al implementar.** El plan decía que esta feature no añade ninguna
dependencia. No se sostiene: el perfil lo escribe el servidor (D3), y **el cliente de esta app
no tiene con qué llamar a una función**. `cloud_functions` no está en `pubspec.yaml`, y las
cuatro operaciones de la feature 004 se llaman desde los scripts de administración, no desde
la app.

**Decisión.** Añadir `cloud_functions`, y justificarlo como pide el principio VII:

- Es de la misma familia que `firebase_core`, `cloud_firestore` y `firebase_auth`, que ya
  están. Funciona con los mismos emuladores.
- La alternativa es montar a mano una petición HTTPS con el token de sesión, lo que significa
  otra dependencia (`http`) **más** el código de firmar y reintentar que la librería ya trae.
  Más dependencia y más superficie para equivocarse.
- No aflojar la regla no es negociable: `usuarios/{uid}` lleva el vínculo entre cuenta y
  nadador, y es lo que decide qué planes se leen.

Queda escrito aquí porque el plan decía lo contrario, y un plan que se incumple en silencio
deja de servir para nada.

---

## D10 — La cadena de consentimiento de la 004 **nunca se ha enchufado**

**Lo que se encontró.** `PantallaConfirmacion` —el formulario donde un acudiente autoriza—
existe, está probada y **no la construye nadie**. No hay ruta `/consentimiento` en
`main.dart`, ni nada en `lib/` que la monte. La función `emitirSolicitud` del servidor
tampoco la llama la app.

Es decir: la feature 004 construyó la puerta, el formulario y el mecanismo, **y los tres
nunca se han tocado entre sí fuera de las pruebas**. El enlace que un acudiente recibiría no
lleva a ninguna parte.

**Lo que esto significa para la 006.** La tarea T045 estaba escrita como «comprobar que el
enlace lleva al formulario». No hay nada que comprobar: **hay que construir ese camino**. Es
más trabajo del previsto y hay que decirlo, no absorberlo.

Concretamente, falta:

1. Una ruta que entienda `/consentimiento?t=…` y abra el formulario con ese token.
2. Que el formulario llame a `canjear` en el servidor, que ya existe y está probado.
3. Que la app, al arrancar con esa ruta, **no exija haber entrado**: el acudiente no tiene
   cuenta, y ese es el punto.

**Por qué no se notó antes.** Porque la feature 004 se dio por buena con 88 de 90 tareas y dos
pendientes de verificación en dispositivo real —las T088 y T089, que siguen abiertas—. Las
pruebas de unidad cubrían cada pieza por separado, y el escenario que las juntaba era
precisamente uno de los que quedaron pendientes.

Es el mismo patrón que la feature 005 encontró dos veces: **un banco solo mide los caminos que
monta**. Aquí no había banco que montara el camino entero.

---

## D7b — Lo que la app sea internacional deja abierto

Al decidir la Q2 se acordó que el país es **solo informativo**: para que el club sepa de dónde
viene cada nadador. Esa respuesta se dio antes de saber que la app es para «cualquier persona
a nivel nacional/internacional».

**No se cambia nada en esta feature**, y el país sigue siendo informativo. Pero queda anotado
que la Ley 1581 de 2012 es colombiana, y un usuario de otro país está bajo otra ley. Mientras
la app no salga de Colombia en la práctica, no es un problema. **El día que lo sea, el país
deja de ser informativo** y esa será una decisión con consecuencias.

Esto es una nota, no una tarea. Se deja aquí para que dentro de un año haya constancia de
cuándo se supo.

---

## D7 — El país, y cómo se impide que crezca

**Decisión.** Se guarda, es opcional, y **ninguna decisión de la app lo lee**. Lo vigila una
prueba de frontera, igual que la V1 del tema vigila los literales de color: recorre `lib/` y
falla si el país aparece en cualquier sitio que no sea mostrarlo o guardarlo.

**Por qué una prueba y no un comentario.** Porque un dato que solo informa es exactamente el
que alguien usará dentro de seis meses para una condición rápida, y nadie lo notará. La 005
enseñó que una regla sin prueba es una buena intención: el cerrojo del color de error se
escribió justo por eso.

---

## Lo que ya estaba resuelto y no se vuelve a decidir

- **El mecanismo de solicitud**: token, resumen SHA-256, canje, vencimiento de 7 días. Es de
  la 004 y no se toca.
- **El formulario de consentimiento**: identificación, calidad, casilla de que oyó al menor.
  Es de la 004, está probado, y esta feature solo conduce hasta él.
- **La puerta de publicación**: lo que impide que los datos salgan sin consentimiento. Es de
  la 004 y sigue siendo quien manda.
- **El rol**: toda cuenta nace nadador; el entrenador se promueve con el comando de la 004.
