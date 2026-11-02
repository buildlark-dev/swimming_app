# Investigación — El HUB y los dos recorridos

Fase 0 del plan. Trece decisiones. Cada una dice qué se eligió, por qué, y qué se descartó.

Tres salieron de leer el código y las reglas antes de escribir nada, y son las que cambian el
tamaño de la feature: **D5**, **D6** y **D4**. Ninguna estaba en la spec, porque ninguna se ve
desde fuera.

---

## D1 — La pantalla principal sale de `main.dart`

**Decisión**: el HUB vive en `lib/ui/hub/`. `main.dart` se queda con el arranque, los recursos
iniciales y la puerta de acceso.

**Razón**: `main.dart` tiene hoy 908 líneas, y `PantallaPrincipal` ocupa de la 474 a la 818
—unas 350— incluyendo el enum de pestañas, la barra de sesión y el filtro por rol. Esta feature
multiplica ese contenido por dos recorridos y añade dos `Home`. Dejarlo dentro lo llevaría por
encima de 1200 líneas y convertiría el archivo de arranque en el archivo de la interfaz.

**Alternativa descartada**: dejarlo donde está y repartir solo lo nuevo. Deja el reparto por rol
—lo más delicado de la feature— en el archivo que menos se mira.

---

## D2 — El reparto por rol es una tabla declarativa, no dos listas paralelas

**Decisión**: un tipo del dominio declara los cinco destinos y, para cada uno, **de quién es
cada contenido**. La interfaz pide «el contenido de este destino para este rol» y recibe uno o
«todavía no». No hay índices compartidos.

**Razón**: lo que hay hoy son dos listas paralelas recorridas con un mismo índice, y el propio
`main.dart` lleva escrito el aviso: «hacerlo con dos listas paralelas y un índice compartido es
la forma clásica de acabar enseñando el editor al pulsar "Mi progreso"». Con tres pestañas y un
rol ya era un riesgo; con cinco destinos y dos recorridos se duplica.

Y hay una ganancia que no es de estilo: con la tabla en Dart puro, **«ningún contenido del otro
rol aparece en un recorrido» pasa a ser comprobable sin pintar nada**. Es una propiedad de una
estructura de datos, no una inspección de pantallas.

**Alternativa descartada**: mantener el patrón actual y añadirle una condición por rol. Es
exactamente lo que el comentario advierte.

---

## D3 — La app abre en `Home`, y eso le cuesta un toque al nadador

**Decisión**: los dos roles aterrizan en `Home`.

**Razón**: `Home` está al centro y es la portada; abrir en otro sitio dejaría la posición
central sin significado. Y el resumen contesta lo primero que alguien se pregunta al abrir
—cómo voy, qué me falta— que hoy no se contesta en ninguna pantalla.

**Lo que cuesta**: hoy el nadador cae directamente en su sesión del día, porque es la primera
pestaña que le toca. Son **cero toques**, y pasan a ser **uno**. El principio VIII pide que
anotar la carga interna no sea difícil, así que esto es una regresión pequeña y declarada. Se
compensa poniendo la sesión de hoy como lo primero del `Home` del nadador, con el camino a
`Ver Plan` desde ahí.

**Alternativa descartada**: abrir al nadador en `Ver Plan` y al entrenador en `Home`. Hace que
la misma posición de la barra signifique dos cosas según quién entre, y la barra es la misma
para los dos a propósito.

---

## D4 — La preferencia de apariencia no puede vivir en `AlmacenLocal`

**Decisión**: vive en `SharedPreferences` bajo una clave **de dispositivo**, fuera del prefijo
por cuenta que usa `AlmacenLocal`.

**Razón**: `AlmacenLocal` guarda todo bajo `natacion_app/<cuentaId>/`, y `cerrarSesion()` llama
a `vaciar()` —que la feature 006 dejó así a propósito, porque el grupo son hermanos que
comparten teléfono—. Una preferencia guardada ahí desaparecería cada vez que alguien saliera.

Y es correcto que sobreviva: la apariencia es del **dispositivo**, no de la persona. Quien
tiene el teléfono en el borde de la piscina con sol lo quiere claro, y el hermano que entra
después, también. No es un dato personal y no viaja al servidor.

**Alternativa descartada**: guardarla con los datos de la cuenta y aceptar que se pierda al
salir. Es la clase de detalle que parece menor hasta que pasa tres veces.

---

## D5 — Corregir el perfil **no** reutiliza `guardarPerfil`

**Decisión**: una operación nueva, `corregirPerfil`, que escribe nombre, fecha de nacimiento y
país, refleja el nombre y la fecha en la ficha de nadador, y **no toca `terminos`**.

**Razón**: dos, y la primera es grave.

`guardarPerfil` exige `versionDeTerminos` y escribe
`terminos: { version, aceptadaEn: serverTimestamp() }`. Si `Ajustes` la reutilizara para
corregir un apellido, **volvería a estampar la aceptación con la fecha de hoy y con la versión
que se le pasara**. Eso falsifica una constancia legal: la app diría que la persona aceptó la
versión vigente hoy, cuando aceptó otra hace un mes y nadie le ha mostrado la nueva. La
feature 006 versionó esos textos justo para que cambiar el texto no reescriba lo que alguien ya
aceptó; corregir el perfil por esa vía lo reescribiría.

La segunda: `guardarPerfil` solo escribe en `nadadores/{id}` **cuando la ficha no existía**
(`if (!esEntrenador && !yaExiste)`). Para quien ya tiene ficha, corregir el nombre actualizaría
`usuarios/{uid}` y dejaría el de la ficha como estaba, así que el panel del entrenador seguiría
mostrando el viejo. Dos nombres para la misma persona en dos pantallas.

**Alternativa descartada**: añadirle un parámetro a `guardarPerfil` para no tocar los términos.
Una función que hace dos cosas según una bandera, en el sitio donde una de las dos falsifica un
registro legal, es peor que dos funciones con nombre.

---

## D6 — La supresión se ejecuta en el servidor, porque las reglas no dejan otra salida

**Decisión**: una operación nueva, `suprimirMisDatos`, en el servidor. El dominio
`DerechosDelTitular` se queda como la descripción de **qué significa** suprimir, y el servidor
hace lo mismo en el mismo orden.

**Razón**: `DerechosDelTitular.eliminar` existe desde la feature 004 y contra Firestore **no
puede funcionar**:

| Lo que necesita borrar | Lo que dicen las reglas |
|---|---|
| `registros` del nadador | `allow delete: if false` — ni el nadador ni el entrenador |
| su ficha en `nadadores` | `allow write: if esEntrenador()` — el titular no |
| sus datos en `usuarios/{uid}` | `allow write: if false` — nadie |
| sus `asignaciones` | `allow delete: if esEntrenador()` — el titular no |

Sus pruebas pasan porque corren contra repositorios en memoria. **El derecho está construido,
probado y es inalcanzable**, y esta tabla es la razón por la que nadie lo había notado.

No es un descuido de la 004: el comentario de la regla de `registros` dice exactamente esto —«un
registro no se borra desde el cliente. El derecho al borrado del principio V se ejerce por la
vía del servidor, que puede dejar constancia de que se ejerció»—. Lo que faltaba era la vía.

**Alternativa descartada**: abrir las cuatro reglas para que el titular borre lo suyo. Abre
`registros` a escrituras de borrado desde el cliente, que es justo lo que se cerró para que el
borrado deje constancia; y obliga a distinguir en lenguaje de reglas «borro lo mío» de «borro
lo de otro» cuatro veces, cuando el servidor ya sabe quién llama.

---

## D7 — Qué se borra, qué sobrevive, y la cuenta

**Decisión**: se borran los registros, las asignaciones, la ficha de nadador y los datos
personales de `usuarios/{uid}`. **Sobrevive** el registro de que hubo consentimiento, con su
fecha. Y se borra también **la cuenta de identidad**.

**Razón**: lo que sobrevive ya estaba decidido y escrito en el dominio
(`ResultadoDeEliminacion.loQueSobrevive`): es la prueba de que el tratamiento anterior estuvo
amparado, y destruirla dejaría al entrenador sin poder demostrar que actuó con autorización
(garantía C8 de la 004).

Lo de la cuenta es nuevo. El correo es un dato personal, y dejar la cuenta viva convertiría el
derecho de supresión en un vaciado: la persona seguiría registrada, entraría otra vez y la app
la mandaría al alta como si fuera nueva. Borrar la cuenta es lo que hace que «suprimir mis
datos» signifique lo que dice. Después, la app arranca de nuevo, reutilizando el reinicio que
la feature 006 construyó para el cierre de sesión.

**Esto lo confirma el entrenador antes de ejecutarse**, porque es irreversible y porque afecta
a cuentas reales. Está en «lo que este plan no puede cerrar».

**Alternativa descartada**: vaciar los datos y conservar la cuenta. Más suave y menos honesto:
quien pidió que no quede nada suyo seguiría existiendo en el sistema de identidad.

---

## D8 — El consentimiento se revoca con la función que ya existe

**Decisión**: `suprimirMisDatos` llama a la misma lógica de `revocar` que la feature 004 dejó
construida, en lugar de escribir «vigente: false» por su cuenta.

**Razón**: el estado de la puerta de consentimiento tiene un solo sitio donde se decide. Un
segundo camino que escriba ese campo es un segundo sitio donde la puerta puede quedar
discrepando de sí misma, que es justo lo que las reglas de la 004 evitaron poniendo la
colección como `allow write: if false`.

---

## D9 — El cambio de contraseña va por correo, desde el único archivo que puede

**Decisión**: `Ajustes` pide un correo de restablecimiento. La operación se añade al puerto
`Identidad` y se implementa en `sesion_firebase.dart`.

**Razón**: `sesion_firebase.dart` es el único archivo del proyecto que puede importar
`firebase_auth`, y la prueba de arquitectura lo vigila. Y el correo es el medio **verificado**:
una pantalla que pide la contraseña nueva sin comprobar quién la escribe deja que cualquiera
con el teléfono desbloqueado se quede con la cuenta. El teléfono lo comparten hermanos.

**Alternativa descartada**: pedir la contraseña actual y la nueva en la pantalla. Comprueba algo
—que sabes la actual— pero añade un formulario de credenciales donde no hacía falta, y el
correo ya está verificado desde el alta.

---

## D10 — Los cuatro números del entrenador, con cinco consultas

**Decisión**:

| Número | De dónde sale |
|---|---|
| Planes generados | `RepositorioPlanes.listar()` |
| Esperando aprobación | `listar(estado: borrador)` que ya pasó la auditoría sin bloqueos |
| Aprobados sin asignar | `listar(estado: aprobado)` menos los que tienen asignación |
| En uso | publicados, con asignación, y cuyo nadador tiene **algún** registro |

Para el último se añade `RepositorioRegistros.nadadoresConRegistros()`: una consulta que
devuelve el conjunto de nadadores que han respondido algo.

**Razón**: «en uso» sin la condición de respuesta sería «asignado», y un plan que nadie ha
tocado no está en uso. Calcularlo por nadador son N consultas; una consulta y un conjunto es
una, y el entrenador lee la colección de registros completa de todos modos en su `Análisis`.

**Alternativa descartada**: guardar contadores en un documento y mantenerlos al día. Es un
segundo sitio donde la verdad puede discrepar de sí misma, por ahorrar cinco consultas a
escala de decenas de nadadores.

---

## D11 — El resumen del nadador no consulta nada

**Decisión**: sale de `EstadoNadador`, que la feature 003 ya tiene montado: `progreso`
—`Adherencia` del plan, con cumplidas y entregadas—, `hoy`, `ultimaSincronizacion` y
`hayPendientes`.

**Razón**: cero consultas nuevas, y por eso `Home` abre sin conexión sin tener que construir
nada para lograrlo. `ultimaSincronizacion` ya existe justamente para decir de cuándo son los
datos, que es lo que FR-016 pide.

---

## D12 — Las pruebas de navegación de `widget_test.dart`

**Decisión**: dos cambios, cada uno con su control negativo.

1. **El ayudante `irAlEditor`** pulsa hoy `Editor`. Pasa a entrar por `Generar`, que es donde
   vive el editor del entrenador. Las cuatro pruebas que lo usan siguen comprobando lo mismo
   —las tres partes de la sesión, la sesión incompleta, los metros al escribir una serie— sin
   cambiarles una aserción.
2. **La prueba «la app tiene las tres pestañas»** afirma lo que esta feature cambia a
   propósito. Pasa a afirmar los cinco destinos y **el reparto por rol**, que es más de lo que
   comprobaba antes.

**Razón**: FR-032 y FR-033. Lo que afirma comportamiento no se toca; lo que afirma la
navegación anterior es el objeto de la feature. El número de pruebas no baja y cada una sigue
comprobando que se llega a la misma pantalla.

---

## D13 — Modo local: el recorrido se elige a mano

**Decisión**: en modo local, `Ajustes` ofrece un conmutador de recorrido, guardado con la misma
preferencia de dispositivo de D4. El aviso de que no hay servidor se queda.

**Razón**: sin servidor no hay rol que consultar. Hoy la app resuelve eso mostrando las cinco
pestañas de los dos roles a la vez, que con el HUB dejaría de ser posible: cada destino tendría
dos contenidos candidatos y nada para elegir entre ellos. Elegir a propósito es más honesto que
adivinar, y además hace que el modo de desarrollo pueda recorrer los dos recorridos de verdad,
uno a uno, como los ve una persona.

**Alternativa descartada**: mostrar en modo local el recorrido del entrenador y nada del
nadador. Dejaría la mitad de la feature sin forma de verse sin servidor.
