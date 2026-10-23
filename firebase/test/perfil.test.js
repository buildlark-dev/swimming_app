// Garantia A3 — el cliente no escribe el perfil.
//
// La regla de `usuarios/{uid}` esta en `allow write: if false` desde la
// feature 004, y no se afloja. Esa regla no protege el nombre: protege el
// `nadadorId` que vincula una cuenta con un nadador, que es lo que decide que
// planes se pueden leer. Abrirla para poder escribir un nombre abriria tambien
// eso.
//
// Por eso el perfil lo escribe el servidor, con `guardarPerfil`, que solo deja
// escribir el propio (decision D3).
//
// Se ejecutan contra el emulador:  npm --prefix firebase test

const assert = require('node:assert/strict');
const { test, before, after, beforeEach } = require('node:test');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('node:fs');
const path = require('node:path');

let entorno;

before(async () => {
  entorno = await initializeTestEnvironment({
    projectId: 'demo-natacion',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  if (entorno) await entorno.cleanup();
});

beforeEach(async () => {
  await entorno.clearFirestore();
});

const nadadora = () =>
  entorno.authenticatedContext('u-nadadora', { rol: 'nadador' }).firestore();

const otra = () =>
  entorno.authenticatedContext('u-otra', { rol: 'nadador' }).firestore();

const entrenador = () =>
  entorno.authenticatedContext('u-entrenador', { rol: 'entrenador' }).firestore();

test('A3 — nadie escribe su propio perfil desde el cliente', async () => {
  await assertFails(
    nadadora()
      .collection('usuarios')
      .doc('u-nadadora')
      .set({ nombre: 'Ana' }),
  );
});

test('A3 — ni el entrenador escribe un perfil desde el cliente', async () => {
  // El entrenador puede leerlos, no escribirlos. Lo que lleva dentro ese
  // documento lo pone el servidor.
  await assertFails(
    entrenador()
      .collection('usuarios')
      .doc('u-nadadora')
      .set({ nombre: 'Ana' }),
  );
});

test('A3 — y mucho menos el de otro', async () => {
  await assertFails(
    otra().collection('usuarios').doc('u-nadadora').set({ nombre: 'Ana' }),
  );
});

test('cada quien lee el suyo', async () => {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('usuarios')
      .doc('u-nadadora')
      .set({ nombre: 'Ana', nadadorId: 'n1' });
  });

  await assertSucceeds(
    nadadora().collection('usuarios').doc('u-nadadora').get(),
  );
});

test('nadie lee el de otro', async () => {
  // Es lo que la regla protege de verdad: el vinculo cuenta-nadador.
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('usuarios')
      .doc('u-nadadora')
      .set({ nombre: 'Ana', nadadorId: 'n1' });
  });

  await assertFails(otra().collection('usuarios').doc('u-nadadora').get());
});

test('el entrenador si lee los perfiles', async () => {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('usuarios')
      .doc('u-nadadora')
      .set({ nombre: 'Ana', nadadorId: 'n1' });
  });

  await assertSucceeds(
    entrenador().collection('usuarios').doc('u-nadadora').get(),
  );
});

test('la prueba no pasa por vacia: sin entrar no se lee nada', async () => {
  const anonimo = entorno.unauthenticatedContext().firestore();

  await assertFails(
    anonimo.collection('usuarios').doc('u-nadadora').get(),
  );
});

test('A3 — la coleccion sigue cerrada a escritura en las reglas', () => {
  // Si alguien aflojara la regla, las pruebas de arriba empezarian a pasar al
  // reves y costaria ver por que. Esto lo dice en una linea.
  const reglas = fs.readFileSync(
    path.join(__dirname, '..', 'firestore.rules'),
    'utf8',
  );

  // Desde la apertura del bloque hasta su cierre. El primer `}` del texto es
  // el de `{uid}`, asi que se busca a partir de la llave que abre el bloque.
  const inicio = reglas.indexOf('match /usuarios/{uid}');
  const apertura = reglas.indexOf('{', inicio + 'match /usuarios/{uid}'.length);
  const bloque = reglas.slice(apertura, reglas.indexOf('}', apertura));

  assert.match(
    bloque,
    /allow write: if false/,
    'usuarios/{uid} tiene que seguir siendo de solo lectura para el cliente: ' +
      'ese documento lleva el vinculo entre la cuenta y el nadador',
  );
});
