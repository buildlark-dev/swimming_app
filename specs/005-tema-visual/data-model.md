# Fase 1 — Modelo del sistema visual

**Feature**: tema visual y sistema de componentes
**Decisiones**: [research.md](research.md) · **Contrato**:
[sistema_visual.md](contracts/sistema_visual.md)

Esta feature no tiene entidades de dominio ni esquema de datos: **no guarda nada**. Lo que
sí tiene es un vocabulario, y conviene que esté escrito igual que estaría un modelo.

---

## Los tokens

### Paleta

`lib/ui/tema/paleta.dart` — **el único archivo del proyecto con literales de color**.

| Grupo | Qué contiene | Restricción |
|---|---|---|
| Marca | Los azules marinos que dan identidad | Decisión del entrenador; el plan solo fija que sean azules marinos |
| Superficies | Fondos y elevaciones, en claro y oscuro | Contraste comprobado contra el texto que lleven |
| Avisos | Informativo, éxito, cuidado, error | Cuatro tonos distinguibles entre sí **sin color** |
| Zonas | Siete pasos de la rampa de intensidad | Rampa por **claridad**, no por tono (D4) |
| Estados de plan | Borrador, aprobado, publicado | Tres, y distinguibles sin leer la etiqueta |

**Invariante que vigila la prueba**: ningún otro archivo de `lib/` contiene un literal de
color.

### Escala tipográfica

`lib/ui/tema/tipografia.dart`. Construida sobre la fuente del sistema (D2).

Cada nivel lleva **declarado para qué es**. Un nivel sin uso declarado es un nivel que
alguien usará para otra cosa.

**La exigencia propia de esta app** (FR-008): donde se muestran series, las cifras van
**tabuladas**, para que `4x100 / 1'40"` se lea sin que las columnas bailen. Es una
instrucción de entrenamiento: leer mal una cifra cambia lo que el nadador hace.

### Escala de espaciado

`lib/ui/tema/espaciado.dart`. Separaciones y radios admitidos.

**Y el tamaño mínimo de un área pulsable** (FR-006), que vive aquí porque es una medida:
tiene que ser cómodo para **un dedo mojado**, aunque el icono que lleve encima sea pequeño.

---

## La escala de zonas

`lib/ui/tema/dominio/escala_de_zonas.dart`.

Traduce las siete zonas de la sección 9 a aspecto. **Vive en la interfaz, no en el
dominio**: `Zona` no sabe de qué color es, y el principio II lo exige.

| Invariante | Por qué |
|---|---|
| El orden visual sigue el orden de intensidad de la metodología | Si no, la app enseñaría una ordenación que la metodología no hace |
| Las siete se distinguen **en escala de grises** | FR-015, SC-006. El color no puede ser la única señal |
| Cada zona conserva **su etiqueta** | El color acompaña al nombre, no lo sustituye. La notación es del entrenador |
| Cada paso cumple el contraste con el texto que lleve | Comprobado **zona por zona**, no de media |

**Lo que esta escala no hace**: agrupar zonas. La metodología las define como bandas
contiguas y sin solapamiento, y pintar dos iguales sugeriría una equivalencia que no existe.

---

## Los estados del plan

`lib/ui/tema/dominio/estados_de_plan.dart`.

| Estado | Qué significa, y por eso cómo se ve |
|---|---|
| `borrador` | Todavía no es de nadie. Se ve **en curso**, no terminado |
| `aprobado` | Firmado por el entrenador, pero **no entregado**. Aprobar no es entregar, y verlo como publicado borraría esa distinción |
| `publicado` | Es el entrenamiento de alguien |

**Invariante**: se distinguen **sin leer la etiqueta** (SC-007), y sin depender solo del
color.

---

## Los cuatro tonos de aviso

`lib/ui/tema/avisos.dart`.

| Tono | Cuándo | Ejemplo de hoy |
|---|---|---|
| Informativo | Algo que conviene saber | «Sin cuentas todavía: úsalo solo con perfiles de prueba» |
| Éxito | Algo salió bien | **«Guardado el progreso, se enviará cuando tengas internet»** |
| Cuidado | Algo que mirar, sin urgencia | Modo local; avisos de auditoría; **reporte de molestia** |
| Error | Algo falló y hay que actuar | No se pudo escribir en el dispositivo |

**El caso que ordena la tabla**: «Guardado el progreso» es hoy **rojo**. Es una buena
noticia —el mecanismo de la feature 003 funcionó— y verla como alarma enseña al nadador a
ignorar el color.

**El caso delicado**: el reporte de molestia va en **cuidado**, nunca en error. Tiene que
encontrarse sin leer todas las observaciones, y a la vez **no parecer una alarma médica**:
el principio IV prohíbe que la app diagnostique o proponga conducta.

---

## Los componentes compartidos

`lib/ui/componentes/`. Lo que hoy se reconstruye en cada pantalla, decidido una vez.

| Componente | Qué sustituye |
|---|---|
| `Tarjeta` | Las tarjetas que cada pantalla arma a mano |
| `Campo` | Los campos de formulario y su validación visual |
| `Boton` | Las variantes de botón y sus estados |
| `Aviso` | **Los avisos repetidos**, que hoy son casi iguales y todos rojos |
| `CabeceraSeccion` | Los títulos de sección |
| `EstadoVacio` | «Todavía no tienes un plan asignado» y sus hermanos |

**Invariante**: un componente no decide colores ni medidas. Los toma de los tokens. Si un
componente necesitara un valor que no está en los tokens, falta un token.

---

## Lo que esta feature no toca

- **Ningún dato.** No guarda, no lee, no muestra nada nuevo.
- **Ninguna entidad del dominio.** `Zona`, `Plan` y `RegistroDeSesion` quedan igual.
- **Ningún comportamiento.** Es la condición que hace esto fusionable: si una prueba de las
  features 001 a 004 tuviera que cambiar para pasar, el tema cambió algo que no debía.
