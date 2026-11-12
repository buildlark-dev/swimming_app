// Quien puede tocar una peticion de feedback (feature 010, US4).
//
// **Las pruebas que tienen que estar aqui son las que PASAN.** La feature 008
// dio 18 de 24 en verde contra una coleccion que no tenia ninguna regla,
// porque el deny-por-defecto hace que toda negacion pase. Cada negacion de
// aqui tiene su contraparte positiva.
//
// Dos cosas que esta coleccion hace y que conviene leer juntas:
//
// 1. **El nadador escribe su pregunta; el entrenador solo escribe «la vi».**
//    La actualizacion del entrenador esta limitada a `hasOnly(['vistaEn'])`,
//    que es la forma que la feature 009 uso para entregar un plan. Cualquier
//    cosa mas ancha se rechaza, asi que «vista» no puede colar una edicion.
// 2. **La puerta del menor es por alcance, no solo por vigencia.** Una familia
//    que consintio los datos de entrenamiento no consintio el video, y
//    `tieneConsentimientoVigente` no sabe distinguirlos (decision D2).
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

// El control negativo de T058 cambia esto por un nombre sin regla.
//
// Hecho el 2026-11-11 con `peticionesDeFeedback_sin_regla`: **12 de 18
// pruebas pasaron contra una coleccion que no tenia ninguna regla.** Las
// unicas que fallaron fueron las seis `assertSucceeds`. Doce negaciones en
// verde sin que exista la regla que dicen comprobar: es exactamente lo que le
// paso a la feature 008, y el motivo de que cada negacion de aqui lleve su
// contraparte positiva al lado.
const COLECCION = 'peticionesDeFeedback';

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

const ID = 'n-ana|plan-1|s1';

const peticion = (extra = {}) => ({
  id: ID,
  nadadorId: 'n-ana',
  planId: 'plan-1',
  sesionId: 's1',
  pregunta: 'El viraje del tercer 50, lo hice bien?',
  pedidaEn: '2026-11-02T19:30:00.000',
  ...extra,
});

async function sembrarVinculos({ alcances, vigente = true } = {}) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    const db = sinReglas.firestore();
    await db.collection('usuarios').doc('u-ana').set({ nadadorId: 'n-ana' });
    await db.collection('usuarios').doc('u-juan').set({ nadadorId: 'n-juan' });
    await db
      .collection('consentimientos')
      .doc('n-ana')
      .set({
        vigente,
        alcances: alcances ?? ['datosDeEntrenamiento'],
      });
    await db
      .collection('consentimientos')
      .doc('n-juan')
      .set({ vigente: true, alcances: ['datosDeEntrenamiento'] });
  });
}

async function sembrarPeticion(extra = {}) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection(COLECCION)
      .doc(ID)
      .set(peticion(extra));
  });
}

// --- Lo que ella puede (las que importan) --------------------------------

test('la nadadora crea su peticion, con consentimiento vigente', async () => {
  await sembrarVinculos();

  await assertSucceeds(
    ana().collection(COLECCION).doc(ID).set(peticion()),
  );
});

test('la nadadora lee la suya', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  await assertSucceeds(ana().collection(COLECCION).doc(ID).get());
});

test('la nadadora consulta las suyas de un plan, filtrando por los dos', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  const leidas = await assertSucceeds(
    ana()
      .collection(COLECCION)
      .where('nadadorId', '==', 'n-ana')
      .where('planId', '==', 'plan-1')
      .get(),
  );
  assert.equal(leidas.size, 1);
});

test('reenviar reescribe su propia peticion', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  // El identificador es determinista, asi que una segunda pregunta sobre la
  // misma sesion es un `update` sobre el documento que ya existe.
  await assertSucceeds(
    ana()
      .collection(COLECCION)
      .doc(ID)
      .set(peticion({ pregunta: 'Y el viraje, lo hice bien?' })),
  );
});

// --- Lo que el entrenador puede ------------------------------------------

test('el entrenador la lee', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  await assertSucceeds(elEntrenador().collection(COLECCION).doc(ID).get());
});

test('el entrenador la marca vista', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  await assertSucceeds(
    elEntrenador()
      .collection(COLECCION)
      .doc(ID)
      .update({ vistaEn: '2026-11-03T08:00:00.000' }),
  );
});

// --- Lo que nadie puede --------------------------------------------------

test('la nadadora no crea una peticion a nombre de otra', async () => {
  await sembrarVinculos();

  await assertFails(
    juan()
      .collection(COLECCION)
      .doc('n-ana|plan-1|s1')
      .set(peticion()),
  );
});

test('la nadadora no lee la de otra', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  await assertFails(juan().collection(COLECCION).doc(ID).get());
});

test('una consulta por plan a secas se rechaza', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  // **Esta es la que la feature 009 pago dos veces.** Una consulta se
  // demuestra por sus filtros: sin «de este nadador», la regla no puede
  // probar que solo pide lo permitido, y el servidor la niega entera.
  await assertFails(
    ana().collection(COLECCION).where('planId', '==', 'plan-1').get(),
  );
});

test('el entrenador no escribe su pregunta', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc(ID)
      .update({ pregunta: 'otra cosa' }),
  );
});

test('el entrenador no cuela una edicion junto a vistaEn', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  // `hasOnly(['vistaEn'])`: un campo y ninguno mas. Sin esto, «la vi» seria
  // un hueco por donde reescribir lo que ella escribio.
  await assertFails(
    elEntrenador().collection(COLECCION).doc(ID).update({
      vistaEn: '2026-11-03T08:00:00.000',
      pregunta: 'otra cosa',
    }),
  );
});

test('con el consentimiento revocado no puede crear', async () => {
  await sembrarVinculos({ vigente: false });

  await assertFails(ana().collection(COLECCION).doc(ID).set(peticion()));
});

test('sin el alcance de datos de entrenamiento no puede crear', async () => {
  // Una familia que consintio **solo** el video —caso raro, y justo por eso
  // util: distingue preguntar por vigencia de preguntar por alcance.
  await sembrarVinculos({ alcances: ['video'] });

  await assertFails(ana().collection(COLECCION).doc(ID).set(peticion()));
});

test('una peticion con video se rechaza', async () => {
  await sembrarVinculos();

  // El campo existe en el modelo y la puerta existe aqui; ninguno de los dos
  // se usa todavia. Esta prueba es la que demuestra que la puerta esta puesta
  // (decision D2): el dia que el video llegue, lo que se quita es la negativa,
  // y ninguna familia tiene que volver a consentir.
  await assertFails(
    ana()
      .collection(COLECCION)
      .doc(ID)
      .set(
        peticion({
          video: { ruta: 'videos/n-ana/s1.mp4', subidoEn: '2026-11-02' },
        }),
      ),
  );
});

test('una pregunta vacia se rechaza', async () => {
  await sembrarVinculos();

  await assertFails(
    ana().collection(COLECCION).doc(ID).set(peticion({ pregunta: '' })),
  );
});

test('el identificador tiene que ser el determinista', async () => {
  await sembrarVinculos();

  // Con un identificador libre, la misma nadadora podria crear veinte
  // peticiones sobre la misma sesion y ninguna regla podria contarlas.
  await assertFails(
    ana().collection(COLECCION).doc('cualquier-cosa').set(peticion()),
  );
});

test('nadie la borra', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  await assertFails(ana().collection(COLECCION).doc(ID).delete());
  await assertFails(elEntrenador().collection(COLECCION).doc(ID).delete());
});

test('sin sesion no se lee nada', async () => {
  await sembrarVinculos();
  await sembrarPeticion();

  await assertFails(deFuera().collection(COLECCION).doc(ID).get());
});
