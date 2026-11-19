// La comunidad y las solicitudes de ingreso (feature 012, US1 y US2).
//
// **Las pruebas que tienen que estar aqui son las que PASAN.** Es la leccion
// que la feature 008 se llevo por delante y que la 010 volvio a medir: contra
// una coleccion sin ninguna regla, el deny-por-defecto hace que **toda
// negacion pase**. Solo las `assertSucceeds` dicen si las reglas estan
// cargadas siquiera.
//
// Asi que cada negacion de aqui tiene su contraparte positiva, y el control
// negativo apunta la suite a un nombre de coleccion sin regla.
//
// Y la otra regla de esta casa: **se ejercitan las consultas que hace la app**,
// no lecturas de un documento por su identificador. Una suite que solo hace
// `get` por id da verde sobre una regla que la app no puede usar, y eso ya se
// pago dos veces en la feature 009.
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

// El control negativo cambia estos dos por nombres sin regla.
const COMUNIDADES = 'comunidades';
const SOLICITUDES = 'solicitudesDeIngreso';

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

const elEntrenador = () =>
  entorno.authenticatedContext('e-uno', { rol: 'entrenador' }).firestore();

const otroEntrenador = () =>
  entorno.authenticatedContext('e-dos', { rol: 'entrenador' }).firestore();

const ana = () =>
  entorno.authenticatedContext('u-ana', { rol: 'nadador' }).firestore();

const juan = () =>
  entorno.authenticatedContext('u-juan', { rol: 'nadador' }).firestore();

const deFuera = () => entorno.unauthenticatedContext().firestore();

const comunidad = (extra = {}) => ({
  entrenadorId: 'e-uno',
  nombre: 'Club Acuatico del Valle',
  ...extra,
});

const solicitud = (extra = {}) => ({
  nadadorId: 'n-ana',
  comunidadId: 'e-uno',
  estado: 'esperando',
  pedidaEn: '2026-11-19T08:00:00.000',
  ...extra,
});

async function sembrar() {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    const db = sinReglas.firestore();
    await db.collection('usuarios').doc('u-ana').set({ nadadorId: 'n-ana' });
    await db.collection('usuarios').doc('u-juan').set({ nadadorId: 'n-juan' });
    await db.collection(COMUNIDADES).doc('e-uno').set(comunidad());
    await db
      .collection(COMUNIDADES)
      .doc('e-dos')
      .set(comunidad({ entrenadorId: 'e-dos', nombre: 'Escuela Ribera' }));
  });
}

// --- La comunidad: quien la escribe --------------------------------------

test('su entrenador la crea', async () => {
  await assertSucceeds(
    elEntrenador().collection(COMUNIDADES).doc('e-uno').set(comunidad()),
  );
});

test('y le cambia el nombre', async () => {
  await sembrar();

  await assertSucceeds(
    elEntrenador()
      .collection(COMUNIDADES)
      .doc('e-uno')
      .update({ nombre: 'Otro nombre' }),
  );
});

test('otro entrenador no escribe la suya', async () => {
  await sembrar();

  await assertFails(
    otroEntrenador()
      .collection(COMUNIDADES)
      .doc('e-uno')
      .update({ nombre: 'Secuestrada' }),
  );
});

test('una nadadora no escribe ninguna', async () => {
  await sembrar();

  await assertFails(
    ana().collection(COMUNIDADES).doc('e-uno').update({ nombre: 'Mia' }),
  );
});

test('el identificador tiene que ser el del entrenador', async () => {
  // Asi «una comunidad por entrenador» es un hecho de la clave y no una regla
  // que alguien tenga que recordar (data-model.md).
  await assertFails(
    elEntrenador().collection(COMUNIDADES).doc('inventado').set(comunidad()),
  );
});

test('el entrenadorId no se puede cambiar despues', async () => {
  await sembrar();

  await assertFails(
    elEntrenador()
      .collection(COMUNIDADES)
      .doc('e-uno')
      .update({ entrenadorId: 'e-dos' }),
  );
});

// --- La comunidad: quien la lee ------------------------------------------

test('cualquiera que haya entrado la lee', async () => {
  // **Es el letrero.** Una nadadora tiene que ver el nombre antes de
  // pertenecer a nada; si hiciera falta pertenecer para leerlo, no habria
  // manera de empezar (research D3).
  await sembrar();

  await assertSucceeds(ana().collection(COMUNIDADES).doc('e-uno').get());
  await assertSucceeds(
    otroEntrenador().collection(COMUNIDADES).doc('e-uno').get(),
  );
});

test('y la lista completa, que es lo que se le ofrece al darse de alta', async () => {
  await sembrar();

  const vistas = await assertSucceeds(ana().collection(COMUNIDADES).get());
  assert.equal(vistas.size, 2);
});

test('sin haber entrado, nada', async () => {
  await sembrar();

  await assertFails(deFuera().collection(COMUNIDADES).doc('e-uno').get());
});

test('el letrero no cuenta quien hay detras', async () => {
  // Lo que se expone es un nombre que el entrenador eligio para que lo vean
  // quienes todavia no son sus nadadores. Nada sobre quien esta dentro.
  await sembrar();

  const vista = await assertSucceeds(
    ana().collection(COMUNIDADES).doc('e-uno').get(),
  );
  assert.deepEqual(Object.keys(vista.data()).sort(), [
    'entrenadorId',
    'nombre',
  ]);
});

// --- Las solicitudes de ingreso ------------------------------------------

test('ella pide entrar', async () => {
  await sembrar();

  await assertSucceeds(
    ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud()),
  );
});

test('y la retira mientras espera', async () => {
  await sembrar();
  await ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud());

  await assertSucceeds(
    ana()
      .collection(SOLICITUDES)
      .doc('n-ana|e-uno')
      .update({ estado: 'retirada' }),
  );
});

test('pero no se acepta a si misma', async () => {
  // «aceptada» es una palabra del entrenador, y lo dice la regla en vez de
  // confiar en que la pantalla no ofrezca el boton.
  await sembrar();
  await ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud());

  await assertFails(
    ana()
      .collection(SOLICITUDES)
      .doc('n-ana|e-uno')
      .update({ estado: 'aceptada' }),
  );
});

test('ni pide en nombre de otra', async () => {
  await sembrar();

  await assertFails(
    juan()
      .collection(SOLICITUDES)
      .doc('n-ana|e-uno')
      .set(solicitud()),
  );
});

test('el identificador tiene que concordar con lo que lleva dentro', async () => {
  await sembrar();

  await assertFails(
    ana()
      .collection(SOLICITUDES)
      .doc('n-ana|e-dos')
      .set(solicitud({ comunidadId: 'e-uno' })),
  );
});

test('no se pide a una comunidad que no existe', async () => {
  await sembrar();

  await assertFails(
    ana()
      .collection(SOLICITUDES)
      .doc('n-ana|e-inventado')
      .set(solicitud({ comunidadId: 'e-inventado' })),
  );
});

test('el entrenador lee las suyas, con la consulta que hace la app', async () => {
  // **Filtrada por comunidad.** Es la unica forma en que se puede demostrar:
  // una consulta se demuestra por sus filtros, no documento a documento.
  await sembrar();
  await ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud());

  const vistas = await assertSucceeds(
    elEntrenador()
      .collection(SOLICITUDES)
      .where('comunidadId', '==', 'e-uno')
      .get(),
  );
  assert.equal(vistas.size, 1);
});

test('y la coleccion entera se le rechaza', async () => {
  await sembrar();
  await ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud());

  await assertFails(elEntrenador().collection(SOLICITUDES).get());
});

test('otro entrenador no lee las solicitudes de esta comunidad', async () => {
  await sembrar();
  await ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud());

  await assertFails(
    otroEntrenador()
      .collection(SOLICITUDES)
      .where('comunidadId', '==', 'e-uno')
      .get(),
  );
});

test('ella lee la suya', async () => {
  await sembrar();
  await ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud());

  await assertSucceeds(
    ana().collection(SOLICITUDES).doc('n-ana|e-uno').get(),
  );
});

test('y no lee la de otra', async () => {
  await sembrar();
  await ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud());

  await assertFails(
    juan().collection(SOLICITUDES).doc('n-ana|e-uno').get(),
  );
});

test('nadie borra una solicitud', async () => {
  // Retirarla la deja en `retirada`, que es un dato. Borrarla seria quitar la
  // constancia de que alguien pidio entrar.
  await sembrar();
  await ana().collection(SOLICITUDES).doc('n-ana|e-uno').set(solicitud());

  await assertFails(ana().collection(SOLICITUDES).doc('n-ana|e-uno').delete());
  await assertFails(
    elEntrenador().collection(SOLICITUDES).doc('n-ana|e-uno').delete(),
  );
});
