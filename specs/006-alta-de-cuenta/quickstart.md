# Verificación de extremo a extremo — Feature 006

**Feature**: alta de cuenta y consentimiento en el registro
**Contrato**: [alta_de_cuenta.md](contracts/alta_de_cuenta.md)

Cada escenario trae su línea **«Falla si…»**, que es donde está lo útil: dice qué cuenta como
roto, no solo qué mirar.

---

## Preparación

```bash
firebase emulators:start
```

```bash
flutter run -d chrome
```

Con los emuladores, porque el alta escribe por el servidor y emite correos.

---

## C1 — Un adulto se da de alta

1. Crear una cuenta nueva con una fecha de nacimiento de hace treinta años.
2. Recorrer los pasos.

**Esperado**: cada paso cabe en la pantalla sin desplazarse. Al terminar se entra, con el
nombre puesto. **Nunca se menciona nada de acudientes ni consentimiento.**

**Falla si** a un adulto se le pide el correo de un acudiente, o si el alta es un formulario
largo en lugar de pasos.

---

## C2 — Volver atrás no borra nada

1. Llenar dos pasos y volver al primero.

**Esperado**: lo escrito sigue ahí.

**Falla si** hay que reescribir algo. Es el fallo que hace que la gente abandone un alta.

---

## C3 — El alta se interrumpe

1. Empezar el alta, llenar un par de pasos, **cerrar la app**.
2. Volver a abrirla.

**Esperado**: sigue donde lo dejó. Y en `usuarios/{uid}` **no hay nada escrito todavía**.

**Falla si** hay que empezar de cero, o si hay un perfil a medias en el servidor.

---

## C4 — Un menor se da de alta

1. Crear una cuenta con una fecha de nacimiento de hace doce años.

**Esperado**: se pide el correo del acudiente **y se explica para qué, en esa pantalla**. Al
terminar, **se entra a la app**, y queda una solicitud pendiente con origen
`declaradoPorElNadador`.

**Falla si** el menor no puede entrar hasta que alguien autorice. La puerta bloquea que los
datos salgan, no que el nadador use la app.

---

## C5 — El menor no quiere dar el correo

1. En el paso del acudiente, continuar sin escribirlo.

**Esperado**: entra igual, y la app le dice **en palabras** qué no podrá hacer hasta que lo
dé. Queda constancia de que se le ofreció.

**Falla si** se le bloquea, o si se le deja seguir sin decirle nada y el asunto desaparece.

---

## C6 — El correo del acudiente es el suyo

1. Escribir, como acudiente, el mismo correo de la cuenta.

**Esperado**: rechazado, en el cliente y en el servidor.

**Falla si** lo acepta. Es el caso ingenuo y es el único que la app puede detectar.

---

## C7 — El acudiente autoriza

1. Abrir el enlace de la solicitud emitida en C4.
2. Llenar el formulario de la feature 004 y autorizar.

**Esperado**: lleva al formulario **de ese nadador**, con el texto informativo delante. Al
autorizar, lo que la nadadora tenía guardado se envía solo.

**Falla si** hay que crear una cuenta para autorizar, o si lo retenido no sale.

---

## C8 — El entrenador ve de dónde vino

1. Abrir la pantalla de consentimientos como entrenador.

**Esperado**: el consentimiento de C7 aparece marcado como **declarado por el nadador**, y se
puede volver a pedir desde la matrícula.

**Falla si** no se distingue de uno que el entrenador pidió. Es la garantía A9, y es la razón
por la que se le permitió al nadador declarar el correo.

---

## C9 — Una cuenta vieja completa su perfil

1. Entrar con una cuenta creada antes de esta feature.

**Esperado**: se piden los datos que faltan, con los mismos pasos. Al volver a entrar, no se
pregunta nada.

**Falla si** se pregunta dos veces, o si completar el perfil **cambia el rol**. Una cuenta de
entrenador sigue siendo de entrenador.

---

## C10 — Una cuenta vieja resulta ser de un menor

1. Completar el perfil de una cuenta antigua con fecha de hace quince años.

**Esperado**: se pide el correo del acudiente y se emite la solicitud, igual que en un alta
nueva.

**Falla si** no se pide. Es el hueco que esta historia existe para cerrar: su alta ya pasó, y
sin esto su consentimiento no se pediría nunca.

---

## C11 — Nadie se queda menor para siempre

```bash
flutter test test/dominio/perfil/
```

**Esperado**: el mismo perfil consultado el día antes y el día después de cumplir 18 da
respuestas distintas, sin que nadie escriba nada.

---

## C12 — La edad no toca la metodología

```bash
flutter test test/dominio/frontera_edad_test.dart
```

**Esperado**: pasa. Y si se mete a propósito una lectura de la edad en el generador, **falla
nombrando archivo y línea**.

**Falla si** pasa con la infracción puesta.

---

## C13 — El país no decide nada

```bash
flutter test test/dominio/frontera_pais_test.dart
```

**Esperado**: igual que C12, con el país.

---

## C14 — Las pantallas nuevas se miden

```bash
flutter test test/ui/tema/
```

**Esperado**: las pantallas del alta están en el banco, y pasan al 200% y en áreas pulsables.

**Falla si** una pantalla de `lib/ui/alta/` no aparece en `ayuda_pantallas.dart`. Una pantalla
que no está en el banco no se mide, y el desbordamiento aparece en el teléfono de alguien.

---

## C15 — Nada de las features anteriores cambia

```bash
flutter test
```

**Esperado**: las 1132 que ya existían pasan **sin haber modificado ninguna**.

---

## Puertas de calidad

Antes de cerrar la feature, en este orden:

```bash
flutter analyze
```

```bash
flutter test
```

```bash
npm --prefix firebase test
```

```bash
dart run tool/verificar_metodologia.dart
```

Y el despliegue, comprobando el sitio en vivo.

---

## Lo que ninguna máquina dice

- **Que los términos y condiciones sean correctos.** Necesitan **revisión legal antes de que
  los lea una familia real**, como el texto de consentimiento de la 004, que sigue pendiente.
- **Que el alta se entienda.** Un nadador de nueve años tiene que poder completarla sin
  preguntarle a nadie qué significa un campo (SC-002). Eso se prueba sentándose al lado de
  uno.
- **Que la historia 3 no moleste.** Toca cuentas que ya están en uso. Conviene probarla contra
  una cuenta de verdad antes de desplegar.
