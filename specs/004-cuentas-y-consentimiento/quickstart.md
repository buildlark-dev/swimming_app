# Verificación de extremo a extremo — Feature 004

**Feature**: cuentas, roles y consentimiento verificable
**Contratos**: [cuentas_y_roles.md](contracts/cuentas_y_roles.md) ·
[consentimiento.md](contracts/consentimiento.md)

Cada escenario trae su línea **«Falla si…»**. Es la parte que importa: dice qué cuenta como
roto, no solo qué mirar.

---

## Preparación

Emuladores de Firestore, Auth y Functions:

```bash
firebase emulators:start --project demo-natacion
```

La app contra los emuladores:

```bash
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

`demo-natacion` es un identificador ficticio. Los emuladores lo aceptan sin que exista nada
en la nube, así que no hay riesgo de tocar un proyecto real por descuido.

---

## C1 — Sin consentimiento, el nadador no queda bloqueado

**Es el escenario que distingue esta feature de la que no quisimos hacer.**

1. Crear un nadador y **no** emitir ninguna solicitud.
2. Entrar con su cuenta.
3. Recorrer la app entera: lo que tenga, su progreso, el formulario de registro.
4. Anotar una sesión.

**Esperado**: no hay un solo punto que exija consentimiento para continuar. Lo anotado queda
como pendiente, y la app lo dice.

**Falla si** aparece cualquier muro, aviso bloqueante o pantalla que impida seguir, o si lo
anotado se pierde.

---

## C2 — Sin consentimiento, los datos no salen

1. Con el nadador de C1, verificar que el entrenador **no** ve nada suyo.
2. Desde el emulador, con la cuenta correcta del nadador y saltándose la app, intentar
   escribir el registro directamente.

**Esperado**: el entrenador no ve nada. La escritura directa se deniega.

**Falla si** el registro llega por cualquiera de las dos vías. El segundo paso es el que de
verdad prueba la puerta: el primero solo prueba la pantalla.

---

## C3 — El acudiente confirma y lo retenido sale solo

1. Como entrenador, emitir la solicitud con el canal tomado de la matrícula.
2. Abrir el enlace, leer el texto informativo, declarar nombre, documento y calidad, declarar
   ser el representante legal y que el menor fue oído, y confirmar.
3. Sin tocar nada en el dispositivo del nadador, esperar.

**Esperado**: el consentimiento queda registrado con fecha de servidor. Lo que estaba
pendiente sale solo y llega íntegro. El acudiente recibe el aviso de que quedó registrado.

**Falla si** hay que pulsar algo en el dispositivo del nadador para que salga, si el contenido
cambió, o si no sale el aviso.

---

## C4 — El enlace sirve una vez y vence

1. Canjear un enlace y volver a canjearlo.
2. Emitir otro, adelantar el reloj más allá del vencimiento y canjearlo.
3. Leer el documento de la solicitud en el emulador.

**Esperado**: el segundo canje se rechaza y hay **exactamente un** consentimiento. El vencido
se rechaza. En el documento **no aparece el token**, solo su resumen.

**Falla si** se puede canjear dos veces, si el vencido sirve, o si el token está en claro en
la base de datos.

---

## C5 — El nadador designa quién consiente: no puede

1. Con cuenta de nadador, intentar emitir una solicitud.
2. Intentar cambiar el canal de una solicitud existente.

**Esperado**: las dos se deniegan.

**Falla si** cualquiera de las dos pasa. Es el agujero que toda la cadena existe para cerrar.

---

## C6 — Cada quien ve lo suyo

Con dos cuentas de nadador y una de entrenador, intentar desde cada una:

- leer el plan del otro;
- leer y escribir el registro del otro;
- leer un plan en `borrador`, uno `aprobado` sin publicar, y uno publicado sin asignar;
- como nadador, aprobar y publicar un plan;
- como entrenador, escribir un registro de un nadador;
- sin sesión iniciada, leer cualquier colección.

**Esperado**: todas se deniegan.

**Falla si** una sola pasa. Y conviene mirar la de «el entrenador escribe un registro»: en la
feature 003 esa era la única que estaba permitida, y ahora tiene que estar cerrada.

---

## C7 — Hermanos con un solo teléfono

1. Entrar con un nadador, consultar su plan, anotar sin red.
2. Cerrar sesión.
3. Inspeccionar el almacenamiento local y la caché.
4. Entrar con el otro hermano.

**Esperado**: tras cerrar sesión no queda nada del anterior. El segundo no ve ni mezcla lo del
primero, tampoco en la bandeja de salida.

**Falla si** aparece un plan, un registro o un pendiente del anterior. Es el escenario más
probable de este grupo y el más fácil de pasar por alto.

---

## C8 — La sesión caduca al borde de la piscina

1. Con un plan ya consultado, poner el modo avión.
2. Forzar la caducidad de la sesión.
3. Abrir la app, leer la sesión del día y anotar.

**Esperado**: las tres cosas funcionan. Lo que queda retenido es el envío.

**Falla si** la app pide reautenticarse para enseñar lo que ya estaba en el dispositivo.

---

## V9 — Esperar no es fallar

En Dart puro, con la puerta cerrada, muchos ciclos del sincronizador.

**Esperado**: `intentos` sigue en cero y no hay espera exponencial.

**Falla si** crece. Un consentimiento que tarda una semana no puede tratarse como un error de
red.

---

## V10 — Revocar

1. Con consentimiento vigente, enviar un registro.
2. Revocar desde el canal del acudiente, sin cuenta de entrenador.
3. Intentar enviar otro.

**Esperado**: el primero llegó, la revocación surte efecto sin pasar por el entrenador, el
segundo se deniega. El historial conserva quién otorgó y cuándo.

**Falla si** hace falta el entrenador para revocar, o si al revocar desaparece el registro de
que hubo consentimiento previo.

---

## V11 — El alcance no se concede en bloque

Con un consentimiento que cubre datos de entrenamiento y no video, intentar habilitar la carga
de video.

**Esperado**: se deniega.

**Falla si** se habilita. El video no entra en esta feature, pero su puerta sí, porque
descubrirlo después obligaría a volver a pedir el consentimiento a todas las familias.

---

## V12 — La categoría no es la edad

1. Crear un nadador de Iniciación sin fecha de nacimiento.
2. Añadirle una fecha de nacimiento de adulto. Y otra de niño.

**Esperado**: la categoría no cambia en ningún momento, y en ningún punto se sugiere.

**Falla si** cambia o se sugiere. Es la sección 11.1 de la metodología 3.6.0 escrita como
comprobación.

---

## V13 — El trabajo del entrenador sobrevive

1. Generar, auditar y aprobar un plan. Asignarlo.
2. Cerrar la app por completo. Volver a entrar.
3. Exportarlo y compararlo con lo exportado antes de cerrar.

**Esperado**: el plan está con su estado, su versión de metodología sellada y sus
asignaciones. Los dos archivos coinciden.

**Falla si** difieren en un solo byte, salvo la marca de exportación, o si un borrador volvió
como aprobado.

---

## V14 — Borrar sin destruir

1. Con un nadador con datos, exportarlos y luego eliminarlos.
2. Consultar los planes del entrenador.

**Esperado**: lo exportado es legible fuera de la app. Lo eliminado deja de estar. **Los
planes del entrenador siguen consultables.**

**Falla si** borrar los datos del nadador se lleva por delante el trabajo del entrenador.

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

Y la **verificación manual en un dispositivo real**: C7 y C8, que son los que no se pueden
comprobar de verdad en un navegador de escritorio.

**Lo que esta feature desbloquea**: con el despliegue hecho, se cierra por fin la tarea
**T071** de la feature 003 —escenarios C1 y C2 en un dispositivo real con el modo avión
puesto— que quedó pendiente por no tener dónde desplegar.

---

## Qué cubre cada escenario (T086)

Recorrido el 2026-10-15, al cerrar la implementación.

| Escenario | Estado | Qué lo cubre |
|---|---|---|
| **C1** Sin consentimiento, el nadador no queda bloqueado | ✅ | `puerta_test.dart` (P2: guardar nunca consulta la puerta) y `sin_consentimiento` en el dominio |
| **C2** Sin consentimiento, los datos no salen | ✅ | `reglas_cuentas.test.js` P1, **contra el emulador con la cuenta correcta del nadador y saltándose la app**, más `puerta_test.dart` |
| **C3** El acudiente confirma y lo retenido sale solo | ✅ | `consentimiento.test.js` (canje, fecha de servidor, aviso de vuelta) y `puerta_test.dart` P3 |
| **C4** El enlace sirve una vez y vence | ✅ | `consentimiento.test.js` C2, C3 y C4, incluida la comprobación de que el token no está en la base de datos |
| **C5** El nadador designa quién consiente: no puede | ✅ | Garantía C1 en `permisos_test.dart` y en las reglas |
| **C6** Cada quien ve lo suyo | ✅ | 34 casos de `test/acceso/casos.json`, recorridos por las **dos** suites |
| **C7** Hermanos con un solo teléfono | ⚠️ Parcial | `particion_por_cuenta_test.dart` cubre el almacenamiento y `sesion_test.dart` el cierre de sesión. **Falta en dispositivo real** (T089) |
| **C8** La sesión caduca al borde de la piscina | ⚠️ Parcial | Cubierto en el dominio; el refresco de token sin red se atrapa y conserva el rol del token guardado. **Falta en dispositivo real** (T089) |
| **V9** Esperar no es fallar | ✅ | `puerta_test.dart` P4: veinticinco ciclos dejan `intentos` en cero |
| **V10** Revocar | ✅ | `consentimiento.test.js` C8 y `reglas_cuentas.test.js` P6 |
| **V11** El alcance no se concede en bloque | ✅ | `consentimiento_test.dart` y `consentimiento.test.js` C6 |
| **V12** La categoría no es la edad | ✅ | `categoria_sin_edad_test.dart`, once pruebas |
| **V13** El trabajo del entrenador sobrevive | ✅ | `persistencia_plan_test.dart`, ida y vuelta byte a byte |
| **V14** Borrar sin destruir | ✅ | `derechos_del_titular_test.dart`, SC-014 con dos pruebas |

### Lo que no se puede marcar desde aquí

**C7 y C8 necesitan un dispositivo real**, y las dos son sobre niños: hermanos que
comparten teléfono, y una sesión que caduca sin señal. El almacenamiento y la decisión
están probados; lo que no se puede comprobar en un navegador de escritorio es el
comportamiento real del dispositivo.

Lo mismo vale para **C1 y C2 de la feature 003**, que llevan pendientes desde que no
había dónde desplegar (su tarea T071).

Las cuatro se cierran juntas cuando exista el despliegue.
