# Contrato — Alta de cuenta y consentimiento en el registro

**Feature**: 006

Cada garantía dice **qué se comprueba** y **por qué importa**. Una garantía sin prueba es una
buena intención; en este proyecto eso ya costó dos veces.

---

## Lo que la app sabe de quien entra

### A1 — Toda cuenta acaba teniendo nombre y fecha de nacimiento

Las nuevas al darse de alta; las que ya existían, la primera vez que entran.

**Se comprueba**: una cuenta sin perfil recibe la petición de completarlo al entrar, y una con
perfil completo no la recibe.

**Por qué importa**: no es tener la ficha llena. Es que **una cuenta sin fecha de nacimiento
es una cuenta de la que no sabemos si necesita consentimiento**, y hay cuentas así en
producción ahora mismo.

### A2 — Un perfil a medias no llega al servidor

Los pasos se guardan en el dispositivo hasta que el alta termina.

**Se comprueba**: interrumpir el alta a mitad y verificar que no queda nada escrito en
`usuarios/{uid}`; volver a abrir y encontrar los pasos donde se dejaron.

### A3 — El cliente no escribe el perfil

Las reglas siguen en `allow write: if false` para `usuarios/{uid}`.

**Se comprueba**: la suite de reglas intenta escribir el perfil como el propio usuario y es
rechazada.

**Por qué importa**: esa regla no protege el nombre, protege el vínculo entre cuenta y
nadador, que es lo que decide qué planes se ven.

---

## La edad

### A4 — Un solo sitio decide si alguien es menor

**Se comprueba**: una prueba de frontera recorre `lib/` y falla si alguna pantalla calcula la
minoría de edad por su cuenta en lugar de preguntarla.

**Por qué importa**: dos sitios que contestan la misma pregunta son dos sitios donde
equivocarse, y equivocarse aquí significa no pedir un consentimiento que hacía falta.

### A5 — Ante la duda, menor

Sin fecha y sin declaración, se trata como menor.

**Se comprueba**: un perfil vacío necesita acudiente.

**Por qué importa**: el error de pedir un consentimiento que no hacía falta se arregla; el de
no pedirlo, no.

### A6 — Nadie se queda menor para siempre

La minoría se recalcula de la fecha cada vez que se consulta.

**Se comprueba**: el mismo perfil consultado el día antes y el día después de cumplir 18 da
respuestas distintas, sin que nadie haya escrito nada.

### A7 — La edad no toca la metodología

**Se comprueba**: una prueba de frontera falla si la edad o la fecha de nacimiento aparecen en
`lib/dominio/generacion/`, `lib/dominio/metodologia/` o en el cálculo de categoría.

**Por qué importa**: la categoría se declara **por habilidades** (sección 11.1). Un niño y un
adulto pueden entrenar en Iniciación, y la app no está para contradecir eso.

---

## El consentimiento

### A8 — El alta de un menor nunca se queda en el limbo

Termina con una solicitud emitida o con un rechazo explícito registrado.

**Se comprueba**: dar de alta un menor con correo de acudiente deja una solicitud; darlo de
alta sin él deja constancia de que se le ofreció y no quiso.

### A9 — Se sabe de dónde vino cada solicitud

Toda solicitud y todo consentimiento llevan `origen`: declarado por el nadador, o de la
matrícula del entrenador.

**Se comprueba**: emitir por los dos caminos y verificar que el origen queda grabado y que
**no se puede cambiar después**.

**Por qué importa**: la feature 004 solo dejaba al entrenador aportar el canal, dando por hecho
una matrícula. **La app es para cualquiera, nacional e internacional**, y la mayoría no tendrá
entrenador: el camino normal es que lo declare quien se registra. El origen se graba porque
cuesta un campo, sirve a los entrenadores que sí tengan grupo, y deja contestada por escrito
la pregunta de cómo llegó un consentimiento concreto.

**Dónde está la garantía de verdad**: en el formulario, no en quién escribió la dirección. El
acudiente se identifica, declara en qué calidad actúa y confirma que oyó al menor. Eso es lo
que pide el Decreto 1377, y la 004 ya lo construyó.

### A10 — El consentimiento no bloquea el uso de la app

**Se comprueba**: una cuenta de menor con el consentimiento pendiente entra, ve su plan y
responde a sus sesiones sin una sola traba; y lo que responde **no sale del dispositivo**.

**Por qué importa**: la puerta de la 004 bloquea que los datos salgan, no que el nadador use
la app. Confundir las dos cosas convertiría una protección en un castigo.

### A11 — Lo guardado se envía en cuanto se autoriza

**Se comprueba**: autorizar y verificar que lo que estaba retenido sale, sin que el nadador
repita nada.

### A12 — El correo del acudiente no puede ser el del menor

**Se comprueba**: intentarlo y ser rechazado, en el cliente y en el servidor.

**Lo que esta garantía NO dice**: que el correo sea de verdad de un acudiente. Eso no lo puede
saber la app. Tapa el caso ingenuo; para lo demás está A9.

---

## Lo visible

### A13 — Todo en español

### A14 — Las pantallas nuevas no deciden colores ni medidas

**Se comprueba**: las fronteras V1, V2 y V3 de la feature 005, que ya recorren `lib/`.

### A15 — Las pantallas nuevas están en el banco que se mide

**Se comprueba**: la prueba del banco falla si una pantalla de `lib/ui/alta/` no aparece en
`test/ui/tema/ayuda_pantallas.dart`.

**Por qué importa**: la 005 lo aprendió dos veces. Una pantalla que no está en el banco no se
mide al 200% ni en áreas pulsables, y el desbordamiento aparece en el teléfono de alguien.

### A16 — El país no decide nada

**Se comprueba**: una prueba de frontera falla si el país aparece en `lib/` fuera de
mostrarlo o guardarlo.

**Por qué importa**: un dato que solo informa es exactamente el que alguien usará dentro de
seis meses para una condición rápida. La 005 enseñó que una regla sin prueba es una buena
intención.

### A17 — Nada de esto llega a los registros

Ni nombres, ni fechas de nacimiento, ni países, ni correos (principio V).

---

## Lo que no cambia

### A18 — Ninguna prueba de las features 001 a 005 se modifica

**Se comprueba**: que las 1132 pasen sin tocarlas. Es la misma condición que hizo fusionable
la 005.
