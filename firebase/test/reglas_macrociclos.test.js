// Garantias M14, M16, M17 y la lectura del nadador — quien puede tocar un
// macrociclo (feature 009).
//
// **Las pruebas que tienen que estar aqui son las que PASAN.** La feature 008
// se llevo esta leccion por delante: su primera suite de reglas dio 18 de 24
// en verde contra una coleccion que no tenia ninguna regla, porque el
// deny-por-defecto hace que toda negacion pase. Las unicas seis que fallaron
// fueron las seis `assertSucceeds`.
//
// Asi que cada negacion de aqui tiene su contraparte positiva, y el control
// negativo de T017 apunta la suite a un nombre de coleccion sin regla para
// comprobar que las positivas se caen.
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

// El control negativo de T017 cambia esto por un nombre sin regla.
//
// Hecho el 2026-11-04 con `macrociclos_sin_regla`, y el resultado es la
// leccion de la 008 repetida con numeros: **13 de 20 pruebas pasaron contra
// una coleccion que no tenia ninguna regla.** Las unicas que fallaron fueron
// las siete `assertSucceeds`. Sin ellas, esta suite habria dado verde entera
// sin estar comprobando la regla que dice comprobar.
const COLECCION = 'macrociclos';

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

const ana = () =>
  entorno.authenticatedContext('u-ana', { rol: 'nadador' }).firestore();

const juan = () =>
  entorno.authenticatedContext('u-juan', { rol: 'nadador' }).firestore();

const elEntrenador = () =>
  entorno
    .authenticatedContext('u-entrenador', { rol: 'entrenador' })
    .firestore();

const deFuera = () => entorno.unauthenticatedContext().firestore();

const estructura = () => ({
  modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
  modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
  bloques: [
    {
      fase: 'Acumulacion',
      desde: '2026-11-01',
      hasta: '2026-11-28',
      porQue: 'Acumulacion, las primeras 4 semanas.',
    },
  ],
  confirmadaEn: '2026-10-31T20:15:00.000',
});

const macrociclo = (extra = {}) => ({
  nadadorId: 'n-ana',
  nombre: 'Hacia el Departamental',
  estructura: estructura(),
  mesociclos: ['plan-a', 'plan-b'],
  fechaDeCompetencia: '2026-12-13',
  versionMetodologia: '3.6.0',
  estado: 'borrador',
  ...extra,
});

async function sembrarVinculos() {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    const db = sinReglas.firestore();
    await db.collection('usuarios').doc('u-ana').set({ nadadorId: 'n-ana' });
    await db.collection('usuarios').doc('u-juan').set({ nadadorId: 'n-juan' });
  });
}

async function sembrarMacrociclo(extra = {}) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo(extra));
  });
}

// --- Lo que el entrenador puede (las que importan) -----------------------

test('el entrenador crea un macrociclo en borrador', async () => {
  await assertSucceeds(
    elEntrenador().collection(COLECCION).doc('macro-1').set(macrociclo()),
  );
});

test('el entrenador edita un borrador suyo', async () => {
  await sembrarMacrociclo();
  await assertSucceeds(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo({ nombre: 'Hacia el Nacional' })),
  );
});

test('el entrenador firma el macrociclo: borrador -> aprobado', async () => {
  await sembrarMacrociclo();
  await assertSucceeds(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo({ estado: 'aprobado' })),
  );
});

test('el entrenador lo entrega: aprobado -> publicado', async () => {
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertSucceeds(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ estado: 'publicado' }),
  );
});

test('el entrenador borra un borrador', async () => {
  await sembrarMacrociclo();
  await assertSucceeds(
    elEntrenador().collection(COLECCION).doc('macro-1').delete(),
  );
});

test('el entrenador lee cualquiera, incluso en borrador', async () => {
  await sembrarMacrociclo();
  await assertSucceeds(
    elEntrenador().collection(COLECCION).doc('macro-1').get(),
  );
});

// --- Lo que el nadador puede: leer el suyo, entregado --------------------

test('el nadador lee su macrociclo entregado', async () => {
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertSucceeds(ana().collection(COLECCION).doc('macro-1').get());
});

test('el nadador NO lee su macrociclo mientras esta en borrador', async () => {
  // Un borrador no es de nadie todavia.
  await sembrarVinculos();
  await sembrarMacrociclo();
  await assertFails(ana().collection(COLECCION).doc('macro-1').get());
});

test('el nadador NO lee su macrociclo firmado pero no entregado', async () => {
  // **Firmar no es entregar** (M17). Es la distincion que la feature 001
  // establecio y que aqui sigue valiendo: aprobado no llega a nadie.
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertFails(ana().collection(COLECCION).doc('macro-1').get());
});

test('el nadador NO lee el macrociclo de otro, ni entregado', async () => {
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(juan().collection(COLECCION).doc('macro-1').get());
});

// --- Lo que nadie puede --------------------------------------------------

test('el nadador NO crea un macrociclo, ni el suyo', async () => {
  await sembrarVinculos();
  await assertFails(
    ana().collection(COLECCION).doc('macro-2').set(macrociclo()),
  );
});

test('el nadador NO edita su macrociclo entregado', async () => {
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(
    ana()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ nombre: 'Lo que yo quiera' }),
  );
});

test('el nadador NO lo borra', async () => {
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(ana().collection(COLECCION).doc('macro-1').delete());
});

test('nadie sin sesion lee ni escribe', async () => {
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(deFuera().collection(COLECCION).doc('macro-1').get());
  await assertFails(
    deFuera().collection(COLECCION).doc('macro-2').set(macrociclo()),
  );
});

// --- El camino del estado no se salta ------------------------------------

test('un borrador NO salta directo a publicado', async () => {
  // Dejaria llegar a un nadador un macrociclo que el entrenador nunca firmo,
  // y la firma es exactamente lo que el principio IV no delega.
  await sembrarMacrociclo();
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ estado: 'publicado' }),
  );
});

test('un macrociclo nace en borrador y no aprobado', async () => {
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo({ estado: 'aprobado' })),
  );
});

test('lo firmado es inmutable: su contenido no se reescribe', async () => {
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo({ estado: 'aprobado', nombre: 'Otro nombre' })),
  );
});

test('la entrega solo cambia el estado, nada mas', async () => {
  // Mandar el documento entero al entregar pasaria por alto la
  // inmutabilidad: el estado avanzaria y el contenido tambien.
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ estado: 'publicado', nombre: 'Otro nombre' }),
  );
});

test('lo entregado no se borra', async () => {
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(
    elEntrenador().collection(COLECCION).doc('macro-1').delete(),
  );
});

// Un recuento, para que no pase lo de la 008: si manana alguien borra las
// positivas, esta prueba lo dice.
test('la suite tiene al menos siete pruebas que TIENEN que pasar', () => {
  const fuente = fs.readFileSync(__filename, 'utf8');
  const positivas = fuente.match(/assertSucceeds/g) || [];
  assert.ok(
    positivas.length >= 7,
    `solo hay ${positivas.length} assertSucceeds: una suite de reglas sin ` +
      'casos positivos pasa entera contra una coleccion sin regla',
  );
});
