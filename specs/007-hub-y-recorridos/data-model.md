# Modelo de datos — El HUB y los dos recorridos

Fase 1 del plan. Lo que esta feature introduce, lo que deriva de lo que ya hay, y lo que solo
lee.

**Casi nada es nuevo.** Un solo dato se guarda por primera vez —la preferencia de apariencia— y
no es personal. Todo lo demás son vistas de datos que las features 001 a 006 ya escriben.

| Entidad | Qué es | Se guarda |
|---|---|---|
| `Destino` | Una de las cinco posiciones de la barra | No, es código |
| `Recorrido` | Qué contenido le toca a un rol en cada destino | No, es código |
| `ResumenDelNadador` | Cómo va: cumplidas, entregadas, hoy, de cuándo son los datos | No, se deriva |
| `ResumenDelEntrenador` | Los cuatro números | No, se deriva |
| `PreferenciaDeApariencia` | Claro, oscuro o el del sistema | **Sí**, en el dispositivo |
| `ConstanciaDeAceptacion` | Qué versión aceptó y cuándo | Ya existe (006) |
| `QueSeGuarda` / `ResultadoDeEliminacion` | Los derechos de la Ley 1581 | Ya existe (004) |

---

## Destino

Los cinco, en orden fijo. Dart puro, en `lib/dominio/hub/destino.dart`.

| Campo | Tipo | Restricción |
|---|---|---|
| `posicion` | entero | 0 a 4, sin huecos y sin repetir |
| `etiqueta` | texto | En español. `Generar`, `Ver Plan`, `Home`, `Análisis`, `Ajustes` |
| `icono` | identificador | Del juego que la app ya usa; esta feature no añade otro |

Reglas:

- Son **exactamente cinco**. No cuatro cuando un rol no tiene contenido, ni seis para meter el
  panel de nadadores.
- `Home` ocupa la **posición 2**, el centro. Es la única posición con significado propio.
- El orden es el mismo para los dos roles. Lo que cambia es lo que hay dentro.

## Recorrido

La tabla declarativa de D2: para cada destino y cada rol, **un** contenido o «todavía no».

| Destino | Entrenador | Nadador |
|---|---|---|
| `Generar` | El generador de microciclos y el editor de sesiones | **Todavía no** (feature 008) |
| `Ver Plan` | Sus planes, con búsqueda y filtro por nadador, y el panel de nadadores | Su sesión del día: cumplida, esfuerzo, observaciones, molestia aparte |
| `Home` | `ResumenDelEntrenador` | `ResumenDelNadador` |
| `Análisis` | **Todavía no** (feature 010) | Su recorrido: la pantalla «Mi progreso» de la 003 |
| `Ajustes` | Su cuenta | Su cuenta |

Reglas que la tabla hace comprobables sin pintar nada:

- Para cada destino y cada rol hay **exactamente una** respuesta: un contenido, o «todavía no».
- **Ningún contenido aparece en los dos recorridos**, salvo `Ajustes`, que es la cuenta de
  quien está dentro y por eso es el mismo contenido con datos distintos.
- Los «todavía no» son exactamente dos: `Generar` del nadador y `Análisis` del entrenador.

## ResumenDelNadador

Derivado. Sin consultas nuevas: sale de `EstadoNadador`, que la feature 003 ya mantiene.

| Campo | De dónde sale | Restricción |
|---|---|---|
| `sesionesEntregadas` | `progreso.adherenciaDelPlan` | 0 si no tiene plan |
| `sesionesCumplidas` | `progreso.adherenciaDelPlan` | Nunca mayor que las entregadas |
| `hoy` | `EstadoNadador.hoy` | Puede ser «no hay sesiones por delante»; nunca vacío sin explicación |
| `ultimaRespuesta` | el registro más reciente de `registros` | Puede faltar: un nadador que no ha anotado nada sigue viendo su plan |
| `ultimaSincronizacion` | `EstadoNadador.ultimaSincronizacion` | Puede faltar; si falta, se dice |
| `hayPendientes` | `EstadoNadador.hayPendientes` | — |

Que **no** lleva, a propósito: metas, logros, rachas ni proyecciones. No existen como dato y
el principio IV no permite inventarlos (FR-015).

## ResumenDelEntrenador

Derivado, con cinco consultas (decisión D10).

| Campo | Definición exacta | Restricción |
|---|---|---|
| `planesGenerados` | Todos los planes que existen | — |
| `esperandoAprobacion` | En `borrador` y sin bloqueos en la auditoría | Un borrador con bloqueos no espera su firma: espera corrección |
| `aprobadosSinAsignar` | En `aprobado` y sin ninguna asignación | — |
| `enUso` | `publicado`, con asignación, y el nadador asignado tiene **algún** registro | Asignado y sin tocar **no** es en uso |

`enUso` necesita `RepositorioRegistros.nadadoresConRegistros()`, el único método nuevo de
repositorio de la feature.

## PreferenciaDeApariencia

**El único dato que esta feature guarda.** No es personal y no viaja al servidor.

| Campo | Tipo | Restricción |
|---|---|---|
| `apariencia` | `claro` \| `oscuro` \| `delSistema` | Por omisión `delSistema`, que es lo que hace hoy |
| `recorridoEnModoLocal` | `entrenador` \| `nadador` | Solo se usa en modo local (D13) |

Dónde vive: `SharedPreferences`, bajo una clave **de dispositivo**, fuera del prefijo
`natacion_app/<cuentaId>/` de `AlmacenLocal`. Si viviera dentro, `cerrarSesion()` la borraría
al llamar a `vaciar()` (decisión D4).

Qué pasa si no se puede leer: la app usa `delSistema` y no lo trata como un fallo. Una
preferencia que no se pudo leer no justifica una pantalla de error.

## ConstanciaDeAceptacion

Ya existe desde la feature 006, en `usuarios/{uid}.terminos`. Aquí solo **se lee**.

| Campo | Qué es |
|---|---|
| `version` | La versión del texto que esa persona aceptó |
| `aceptadaEn` | Cuándo, con la hora del servidor |

Lo que `Ajustes` muestra es **el texto de esa versión**, no el vigente. Los textos están
versionados en `assets/terminos/` y `assets/consentimiento/` desde la 006 precisamente para
esto.

**Nada en esta feature escribe estos campos.** La operación de corregir el perfil los deja
intactos, y es la razón de que sea una operación aparte (decisión D5).

## QueSeGuarda y ResultadoDeEliminacion

Ya existen en `lib/dominio/datos_personales/derechos_del_titular.dart` desde la feature 004,
con sus pruebas. Esta feature **no los modela de nuevo**: los enchufa.

- `QueSeGuarda.enPalabras` → lo que `Ajustes` muestra. Frases, no campos (FR-021).
- `exportar()` → el archivo que la persona se lleva. Se puede hacer desde el cliente: el
  titular lee su propia ficha y sus propios registros.
- `eliminar()` → **no se puede hacer desde el cliente** (decisión D6). El dominio se queda
  como la descripción de qué significa suprimir; lo ejecuta el servidor en el mismo orden.
- `ResultadoDeEliminacion.loQueSobrevive` → lo que la confirmación tiene que decir antes del
  segundo paso (FR-022).

---

## Lo que se escribe en Firestore, y por quién

| Colección | Esta feature escribe | Cómo |
|---|---|---|
| `usuarios/{uid}` | Corrige nombre, fecha, país. **Nunca `terminos`** | Servidor (`corregirPerfil`) |
| `nadadores/{id}` | Refleja el nombre y la fecha corregidos | Servidor (`corregirPerfil`) |
| `registros` | Los borra al suprimir | Servidor (`suprimirMisDatos`) |
| `asignaciones` | Las retira al suprimir | Servidor (`suprimirMisDatos`) |
| `consentimientos/{id}` | Revoca; **no borra el historial** | Servidor, por la vía de `revocar` (D8) |
| Identidad (Auth) | Borra la cuenta al suprimir | Servidor, pendiente de confirmación del entrenador |

Ninguna regla de acceso cambia en esta feature. Las dos operaciones nuevas corren con el Admin
SDK, que se las salta, y por eso lo que las vigila son pruebas de servidor: qué borran y qué
dejan.
