# Modelo de datos — Feature 006

**Feature**: alta de cuenta y consentimiento en el registro

Todo lo que sigue es **dominio en Dart puro** salvo donde se dice lo contrario (principio II).

---

## Perfil de cuenta

Quién es la persona detrás del correo. Vive en `usuarios/{uid}`, que **solo escribe el
servidor** (decisión D3).

| Campo | Tipo | Obligatorio | Para qué |
|---|---|---|---|
| `nombre` | texto, 1 a 80 | **sí** | Saludar, y que el entrenador sepa quién es quién |
| `fechaNacimiento` | fecha | **sí** | **Solo** para saber si es menor de 18 (FR-010) |
| `pais` | código de país, 2 letras | no | Que el club sepa de dónde viene (FR-007). Nada más |
| `terminosAceptados` | aceptación | **sí** | Qué versión aceptó y cuándo |
| `correoDelAcudiente` | correo | solo si es menor | A dónde va la solicitud |

### Reglas

- `nombre` se recorta y no puede quedar vacío. No se valida su forma: hay nombres de una letra
  y nombres con cuatro apellidos.
- `fechaNacimiento` no puede ser futura ni anterior a 1900. Más allá de eso no se opina: una
  fecha rara es un error del usuario, no un ataque.
- `pais` es opcional y **nulo es un valor legítimo**, no un perfil incompleto.
- Un perfil está **completo** cuando tiene nombre, fecha de nacimiento y términos aceptados.
  El país no cuenta.

### Estado del perfil

```
PerfilIncompleto   → falta algo obligatorio. Dispara la petición de completarlo (US3)
PerfilCompleto     → no se vuelve a preguntar
```

**`PerfilIncompleto` no es un error.** Es el estado de todas las cuentas creadas antes de esta
feature, incluida la del entrenador.

---

## Aceptación de términos

Un hecho con fecha, no una casilla.

| Campo | Tipo | Para qué |
|---|---|---|
| `version` | texto | Qué texto leyó. `v1`, `v2`… |
| `aceptadaEn` | fecha y hora | Cuándo |

La pregunta que alguien hará algún día es «¿qué aceptó esta familia exactamente?», y la única
respuesta útil es el texto que leyeron. Por eso se guarda la versión y no un `true`.

---

## Edad y minoría

**Un solo sitio decide si alguien es menor.** Ninguna pantalla lo calcula por su cuenta.

```
esMenorDeEdad(perfil, ahora):
  1. si hay fechaNacimiento  → la fecha manda
  2. si no, si hay declaraSerMayorDeEdad → la declaración manda
  3. si no hay ninguna        → MENOR
```

El paso 3 no es cautela decorativa: **el error de pedir un consentimiento que no hacía falta
se arregla; el de no pedirlo, no.** Es la misma regla que la 004 ya aplicaba.

`declaraSerMayorDeEdad` sobrevive solo para el paso 2, que atiende a las cuentas viejas
mientras no completan su perfil (decisión D2).

### Lo que la edad NO hace

- No determina la categoría. **La categoría se declara por habilidades** (sección 11.1 de la
  metodología 3.6.0).
- No entra en la generación de planes.
- No cambia qué puede hacer una cuenta, salvo si hace falta consentimiento.

Una prueba de frontera lo vigila (FR-011).

---

## Declaración de acudiente

**Nuevo en esta feature.** Es lo que el menor escribe en el alta: una dirección, no una
persona.

| Campo | Tipo | Para qué |
|---|---|---|
| `nadadorId` | id | De quién |
| `correo` | correo | A dónde va la solicitud |
| `declaradaEn` | fecha y hora | Cuándo |
| `origen` | `declaradoPorElNadador` \| `matriculaDelEntrenador` | **Quién la aportó** |

### Por qué existe `origen`

Es la decisión D1 hecha dato. La feature 004 solo dejaba al entrenador aportar el canal,
porque «un niño poniendo un correo suyo» invalida toda la cadena. La 006 necesita que la
familia no espere al entrenador.

La solución es que la solicitud **se emita igual, y que se sepa de dónde vino**. Un
consentimiento de origen declarado es válido y es visiblemente de segunda mano, y el
entrenador decide si lo da por bueno o lo vuelve a pedir desde su matrícula.

### Reglas

- El correo del acudiente **no puede ser el de la cuenta del menor** (FR-018). Tapa el caso
  ingenuo; no pretende tapar el resto.
- Se puede corregir y reenviar sin rehacer el alta (FR-017).
- `origen` **no se puede cambiar** después. Una solicitud declarada no se convierte en
  verificada porque alguien la mire.

---

## Lo que esta feature NO cambia

| | Por qué |
|---|---|
| `SolicitudDeConsentimiento` | Su forma es de la 004. Esta feature la emite, no la redefine. Solo gana `origen` |
| `Consentimiento` | Igual. Hereda el `origen` de su solicitud |
| `PuertaDeConsentimiento` | Sigue decidiendo exactamente lo mismo |
| `Nadador` | La ficha del entrenador se queda como está (decisión D4) |
| `Rol`, `Cuenta` | Toda cuenta nace nadador. El rol se asigna aparte |

---

## Dónde vive cada cosa

```
usuarios/{uid}                    perfil de cuenta        ← escribe el servidor
solicitudes/{id}                  + campo origen          ← ya existía
consentimientos/{nadadorId}       + campo origen          ← ya existía
nadadores/{id}                    sin cambios
assets/terminos/texto_v1.md       el texto, empaquetado   ← nuevo
```
