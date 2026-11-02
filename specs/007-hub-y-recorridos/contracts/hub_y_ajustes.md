# Contrato — El HUB y los dos recorridos

Fase 1 del plan. Las garantías que esta feature promete, y el **cuerpo exacto** de las dos
llamadas nuevas al servidor.

Lo segundo está aquí por la lección más cara de la feature 006: el cliente mandaba los datos
del acudiente planos y el servidor los desempaquetaba anidados. Diez pruebas del camino del
acudiente pasaban en verde, porque **los dobles implementan la interfaz, no el cable**. Cada
llamada nueva lleva aquí su cuerpo escrito y una prueba que lo compara contra el fuente del
servidor.

---

## La barra

**H1** — Hay exactamente cinco destinos, en este orden: `Generar`, `Ver Plan`, `Home`,
`Análisis`, `Ajustes`. Ni uno menos cuando un rol no tiene contenido.

**H2** — `Home` está en la posición central, la tercera, para los dos roles.

**H3** — El orden y la posición no dependen del rol.

**H4** — Para cada destino y cada rol hay exactamente una respuesta: un contenido, o «todavía
no». Nunca dos candidatos, nunca ninguno.

**H5** — Ningún contenido aparece en los dos recorridos. La única excepción es `Ajustes`, que
es la cuenta de quien está dentro.

**H6** — El contenido del otro rol no se muestra, ni deshabilitado, ni con candado, ni
nombrado. Un nadador no sabe por la app que existe un editor de sesiones.

**H7** — El rol se lee de `Permisos`, el del dominio de la feature 004. Ninguna pantalla
decide por su cuenta de quién es un contenido.

**H8** — Cambiar de destino conserva el estado del que se abandona. Una sesión a medio editar,
una respuesta a medio escribir y una búsqueda hecha siguen ahí al volver.

**H9** — El nombre del destino en el que se está **se lee entero**, sin truncar ni abreviar, a
320 px de ancho y en los dos temas. Las cinco etiquetas de la barra se muestran a partir de
500 px; por debajo, la barra son iconos y el nombre va de título.

> **Esta garantía se corrigió durante la implementación, y la razón es aritmética.** Decía
> que las cinco etiquetas se leerían completas a 320 px. No se puede: cinco destinos en 320 px
> dan 64 px cada uno, y «Ver Plan» necesita **100 px** con la etiqueta de 13 px que la feature
> 005 fijó como suelo —«no baja de aquí», porque algunos de quienes leen esto tienen nueve
> años—. Las cinco piden 500 px, y los teléfonos miden entre 320 y 430.
>
> Las salidas eran tres: encoger la letra por debajo del suelo, abreviar el vocabulario, o que
> ceda la barra. Cede la barra. Lo que **no** se hizo fue dejar las etiquetas recortándose en
> silencio, que es lo que pasaba antes de medirlo.

**H10** — Volver atrás desde un destino que no es `Home` lleva a `Home`. Desde `Home`, sale de
la app.

## Los destinos que esperan su feature

**H11** — Un destino sin contenido dice en una frase qué llegará ahí.

**H12** — Un destino sin contenido **no tiene ningún control pulsable**. Cero, ni
deshabilitados como señuelo.

**H13** — Son exactamente dos: `Generar` del nadador y `Análisis` del entrenador. El `Análisis`
del nadador no es uno de ellos: lleva dentro la pantalla «Mi progreso» de la feature 003.

## Los resúmenes

**H14** — `Home` abre con lo que haya en el dispositivo, sin esperar red, y dice de cuándo son
los datos que muestra.

**H15** — El resumen del nadador no hace ninguna consulta nueva: sale de lo que la feature 003
ya mantiene. Por eso funciona sin conexión sin construir nada para lograrlo.

**H16** — El resumen del nadador no muestra metas, logros, rachas ni proyecciones. No existen
como dato.

**H17** — El resumen del entrenador se arma con cinco consultas como máximo, no con una por
nadador. «En uso» significa publicado, asignado, y con algún registro del nadador asignado.

**H18** — Ningún número del resumen aprueba, firma ni publica nada. Contar lo que espera
aprobación no es aprobarlo.

## Ajustes

**H19** — `Ajustes` muestra y corrige los datos de quien está dentro, y **solo** los de quien
está dentro.

**H20** — `Ajustes` muestra el texto de la versión que esa persona aceptó, no el vigente, con
su fecha de aceptación.

**H21** — **Corregir el perfil no toca la constancia de términos.** Ni la versión ni la fecha
de aceptación cambian al corregir un nombre. Es el cierre más importante de esta feature: la
alternativa falsifica un registro legal.

**H22** — Corregir el nombre lo deja igual en los dos sitios donde vive: `usuarios/{uid}` y la
ficha de `nadadores/{id}`. No hay dos nombres para la misma persona en dos pantallas.

**H23** — Cerrar sesión está en `Ajustes`, y hace lo que la feature 006 dejó hecho: vacía lo
local, vacía la caché de Firestore y arranca la app de nuevo.

**H24** — Los tres derechos de la Ley 1581 se alcanzan desde `Ajustes` en dos toques o menos.

**H25** — Lo que se guarda se dice en frases comprensibles, no en un volcado técnico.

**H26** — Lo exportado es legible fuera de la app, y **nada de su contenido pasa por un
registro, una traza ni una métrica**. Es la garantía A17 de la 006 aplicada aquí.

**H27** — La supresión exige dos acciones deliberadas. La segunda dice qué se borra y qué
sobrevive.

**H28** — En una cuenta de una persona menor de edad, la supresión la ejecuta ella misma, sin
paso de confirmación del acudiente. Decisión del entrenador del 2026-10-25, contraria a mi
recomendación; FR-023 y la sección «Clarifications» de la spec.

**H29** — La preferencia de apariencia sobrevive al cierre de sesión, porque es del dispositivo
y no de la persona. No viaja al servidor.

**H30** — El cambio de contraseña va por el correo ya verificado. Ninguna pantalla de la app
pide una contraseña nueva.

---

## El cuerpo exacto de `corregirPerfil`

Lo que el cliente manda:

```json
{
  "nombre": "María Fernanda Gallón",
  "fechaNacimiento": "2014-03-07",
  "pais": "CO"
}
```

Lo que el servidor desempaqueta: `{ nombre, fechaNacimiento, pais }`. **No hay
`versionDeTerminos`**, y su ausencia es el contrato: esta operación no puede estampar una
aceptación.

- `nombre`: obligatorio, sin espacios sobrantes, máximo 80 caracteres. Las mismas
  restricciones que `guardarPerfil`, porque es el mismo campo.
- `fechaNacimiento`: obligatoria, `AAAA-MM-DD`, no futura, año no anterior a 1900.
- `pais`: opcional, dos letras mayúsculas o nulo. Un campo que no decide nada no bloquea a
  nadie.
- **No toma `uid`**: el único perfil que se puede corregir es el propio. Aceptar uno y
  comprobar que coincide es lo mismo con una forma más de equivocarse, y es el criterio que
  `guardarPerfil` ya sigue.

Lo que devuelve:

```json
{ "nombre": "María Fernanda Gallón", "esMenor": true }
```

`esMenor` se recalcula en el servidor, porque corregir la fecha de nacimiento puede cambiarlo y
la puerta de consentimiento tiene que trabajar sobre algo que el servidor calculó.

Lo que escribe: `usuarios/{uid}` con `{ nombre, fechaNacimiento, pais }` en modo `merge`, y
`nadadores/{nadadorId}` con `{ nombre, fechaNacimiento }` en modo `merge` si hay ficha.
**`terminos` no aparece en ninguna de las dos escrituras**, y eso es lo que la prueba de
contrato comprueba leyendo el fuente.

## El cuerpo exacto de `suprimirMisDatos`

Lo que el cliente manda:

```json
{ "confirmado": true }
```

Lo que el servidor desempaqueta: `{ confirmado }`. Sin `uid` y sin `nadadorId`: los dos salen
del token de quien llama. Una supresión que acepta un identificador es una supresión que
alguien puede dirigir contra otra persona.

`confirmado` tiene que ser exactamente `true`. No es una cortesía: es el segundo paso de H27
llegando hasta el servidor, para que una llamada suelta no borre nada.

Lo que devuelve:

```json
{
  "registrosEliminados": 34,
  "asignacionesRetiradas": 2,
  "perfilEliminado": true,
  "cuentaEliminada": true
}
```

Los tres primeros campos son los de `ResultadoDeEliminacion`, que el dominio ya definió.
`cuentaEliminada` es el único nuevo, y depende de la confirmación del entrenador (decisión D7).

El orden en que borra, que es el mismo del dominio:

1. Los registros del nadador.
2. Sus asignaciones.
3. Su ficha de `nadadores`.
4. Sus datos personales de `usuarios/{uid}`.
5. Revoca el consentimiento por la vía de `revocar`, **sin borrar su historial**.
6. Borra la cuenta de identidad.

Y después, en el cliente: la app arranca de nuevo, con el reinicio que la 006 construyó.

**Lo que no borra**: el registro de que hubo consentimiento, con su fecha. Es la prueba de que
el tratamiento anterior estuvo amparado (garantía C8 de la feature 004). La confirmación lo
dice antes, con esas palabras, y no en letra pequeña.

---

## Qué comprueba cada prueba de contrato

| Prueba | Qué fija |
|---|---|
| Contrato de `corregirPerfil` | Que el cuerpo del cliente y lo que el `.ts` desempaqueta coinciden, y **que `terminos` no aparece en el fuente de esa función** |
| Contrato de `suprimirMisDatos` | Que el cuerpo coincide, que no acepta identificador ajeno, y que el fuente exige `confirmado === true` |
| Servidor, qué borra | Contra el emulador: los registros, las asignaciones, la ficha y los datos personales dejan de estar |
| Servidor, qué sobrevive | Contra el emulador: el historial de consentimiento sigue ahí, con su fecha |
| Frontera del dominio | Que `lib/dominio/hub/` no importa Flutter ni Firebase |
| Reparto por rol | Que la tabla cumple H4, H5 y H13 sin pintar una sola pantalla |
