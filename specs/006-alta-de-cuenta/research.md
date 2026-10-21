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

**La tensión de fondo.** Las dos features tienen razón en lo suyo. La 004 protege la cadena de
consentimiento. La 006 quiere que una familia no dependa de que el entrenador haga un trámite
para que su hija pueda empezar. Si el entrenador es el único que puede emitir, una nadadora
que se da de alta un sábado espera al lunes.

**Decisión.** Las dos cosas, distinguidas:

1. El menor **declara** el correo de su acudiente en el alta. Eso crea una
   **declaración de acudiente**, no un consentimiento.
2. El sistema emite la solicitud **inmediatamente** desde esa declaración, para que la
   familia no espere a nadie.
3. La solicitud y el consentimiento que produzca llevan grabado su **origen**: `declarado por
   el nadador` o `matrícula del entrenador`.
4. El entrenador **ve el origen** en su pantalla de consentimientos, y puede volver a pedirlo
   desde su matrícula cuando quiera. Un consentimiento de origen declarado es válido y es
   **visiblemente** de segunda mano.

**Por qué así.** Porque el problema de la 004 no se resuelve escondiéndolo, y el de la 006 no
se resuelve bloqueando a la familia. Lo que no se puede hacer es dejar que los dos orígenes se
confundan: el entrenador responde ante las familias y ante la ley, y tiene derecho a saber
cuál de los consentimientos de su lista llegó por un canal que él verificó y cuál por uno que
le dio un niño de doce años.

**Alternativas descartadas**:

- *Que solo emita el entrenador*, como hoy. Contradice el FR-013 de la 006 —nada impide usar
  la app— y, peor, hace que el consentimiento dependa de un trámite que el entrenador puede
  olvidar. Las solicitudes que nadie emite son el estado actual.
- *Que el nadador emita sin marcar el origen.* Borra la distinción que la 004 construyó y le
  quita al entrenador la información con la que decide si fiarse. Es el camino que parece más
  simple y el que deja al entrenador peor.
- *Verificar el correo con un código antes de emitir.* Comprueba que la dirección existe y que
  alguien la lee. No comprueba que ese alguien sea el acudiente, que es lo único que importa.
  Cuesta una pantalla más y no cierra nada.

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
