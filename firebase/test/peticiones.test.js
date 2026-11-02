// Garantias P11, P12 y P13 — quien puede escribir una peticion de plan.
//
// Estas pruebas se escriben ANTES de la regla y antes de cualquier pantalla
// que envie. El motivo es concreto: lo que impide que un nadador escriba la
// peticion de otro, y lo que impide que un cliente se apruebe su propia
// peticion, no puede ser la interfaz. Construir la pantalla primero dejaria
// una ventana en la que lo unico que lo impide es la pantalla.
//
// El identificador del documento ES el del nadador (decision D6). Esa es la
// pieza que convierte «una peticion abierta a la vez» en algo que la regla
// puede comprobar: con un identificador aleatorio ninguna regla podria contar
// las abiertas.
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

const ana = () =>
  entorno.authenticatedContext('u-ana', { rol: 'nadador' }).firestore();

const juan = () =>
  entorno.authenticatedContext('u-juan', { rol: 'nadador' }).firestore();

const elEntrenador = () =>
  entorno
    .authenticatedContext('u-entrenador', { rol: 'entrenador' })
    .firestore();

const deFuera = () => entorno.unauthenticatedContext().firestore();

// El vinculo cuenta <-> ficha, que es lo que `soyEseNadador` consulta.
async function sembrarVinculos({ conConsentimiento = true } = {}) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    const db = sinReglas.firestore();
    await db.collection('usuarios').doc('u-ana').set({ nadadorId: 'n-ana' });
    await db.collection('usuarios').doc('u-juan').set({ nadadorId: 'n-juan' });

    if (conConsentimiento) {
      for (const ficha of ['n-ana', 'n-juan']) {
        await db.collection('consentimientos').doc(ficha).set({ vigente: true });
      }
    }
  });
}

const respuestas = () => ({
  estiloObjetivo: 'Libre',
  pruebaObjetivo: '200 Libre',
  fechaDeCompetencia: '2026-11-26T00:00:00.000Z',
  diasDisponibles: ['2026-11-03T00:00:00.000Z', '2026-11-05T00:00:00.000Z'],
  duracionSesionMinutos: 90,
  longitudPiscina: 25,
});

const peticionNueva = () => ({
  nadadorId: 'n-ana',
  respuestas: respuestas(),
});

async function sembrarPeticion(nadadorId, estado, extra = {}) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('peticionesDePlan')
      .doc(nadadorId)
      .set({
        nadadorId,
        respuestas: respuestas(),
        estado,
        enviadaEn: new Date(),
        ...extra,
      });
  });
}

// --- P11: una peticion es de quien la manda -----------------------------

test('P11 — una nadadora crea la suya', async () => {
  await sembrarVinculos();

  await assertSucceeds(
    ana().collection('peticionesDePlan').doc('n-ana').set(peticionNueva()),
  );
});

test('P11 — y NO puede crear la de otro', async () => {
  // El documento se llama como el nadador, asi que pedir por otro obligaria a
  // escribir en un documento con su nombre. La regla lo ve.
  await sembrarVinculos();

  await assertFails(
    juan()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .set({ ...peticionNueva(), nadadorId: 'n-ana' }),
  );
});

test('P11 — ni poniendo su propio nadadorId dentro', async () => {
  await sembrarVinculos();

  await assertFails(
    juan()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .set({ ...peticionNueva(), nadadorId: 'n-juan' }),
  );
});

test('P11 — una nadadora no lee la peticion de otra', async () => {
  await sembrarVinculos();
  await sembrarPeticion('n-juan', 'esperando');

  await assertFails(
    ana().collection('peticionesDePlan').doc('n-juan').get(),
  );
});

test('P11 — pero si lee la suya', async () => {
  await sembrarVinculos();
  await sembrarPeticion('n-ana', 'esperando');

  await assertSucceeds(ana().collection('peticionesDePlan').doc('n-ana').get());
});

test('P11 — quien no ha entrado no ve nada', async () => {
  await sembrarPeticion('n-ana', 'esperando');

  await assertFails(
    deFuera().collection('peticionesDePlan').doc('n-ana').get(),
  );
});

// --- P12: una abierta a la vez ------------------------------------------

test('P12 — con una esperando, no se manda otra', async () => {
  await sembrarVinculos();
  await sembrarPeticion('n-ana', 'esperando');

  await assertFails(
    ana().collection('peticionesDePlan').doc('n-ana').set(peticionNueva()),
  );
});

test('P12 — tampoco con una en revision', async () => {
  await sembrarVinculos();
  await sembrarPeticion('n-ana', 'enRevision');

  await assertFails(
    ana().collection('peticionesDePlan').doc('n-ana').set(peticionNueva()),
  );
});

test('P12 — **control negativo**: cerrada la anterior, si manda otra', async () => {
  // Si esto fallara, la regla estaria bloqueando siempre y las dos pruebas de
  // arriba pasarian sin comprobar nada.
  await sembrarVinculos();
  await sembrarPeticion('n-ana', 'rechazada', {
    motivoDelRechazo: 'Pediste cinco dias y en Precompetitivo son tres.',
    respondidaEn: new Date(),
  });

  await assertSucceeds(
    ana().collection('peticionesDePlan').doc('n-ana').set(peticionNueva()),
  );
});

// --- P13: el estado es del servidor -------------------------------------

test('P13 — la nadadora no escribe el estado al crear', async () => {
  await sembrarVinculos();

  await assertFails(
    ana()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .set({ ...peticionNueva(), estado: 'aprobada' }),
  );
});

test('P13 — ni enviadaEn', async () => {
  await sembrarVinculos();

  await assertFails(
    ana()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .set({ ...peticionNueva(), enviadaEn: new Date() }),
  );
});

test('P13 — ni planId', async () => {
  await sembrarVinculos();

  await assertFails(
    ana()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .set({ ...peticionNueva(), planId: 'p-mio' }),
  );
});

test('P13 — ni respondidaEn', async () => {
  await sembrarVinculos();

  await assertFails(
    ana()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .set({ ...peticionNueva(), respondidaEn: new Date() }),
  );
});

test('P13 — una nadadora no se aprueba su propia peticion', async () => {
  // La prueba que mas importa de este archivo. Un cliente que puede escribir
  // su estado puede firmar por el entrenador.
  await sembrarVinculos();
  await sembrarPeticion('n-ana', 'esperando');

  await assertFails(
    ana()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .update({ estado: 'aprobada', planId: 'p-1' }),
  );
});

test('P13 — ni la borra para poder mandar otra', async () => {
  await sembrarVinculos();
  await sembrarPeticion('n-ana', 'esperando');

  await assertFails(
    ana().collection('peticionesDePlan').doc('n-ana').delete(),
  );
});

// --- El entrenador: lee todo, escribe el estado y nada mas --------------

test('el entrenador lee cualquier peticion', async () => {
  await sembrarPeticion('n-ana', 'esperando');

  await assertSucceeds(
    elEntrenador().collection('peticionesDePlan').doc('n-ana').get(),
  );
});

test('el entrenador la pasa a en revision', async () => {
  await sembrarPeticion('n-ana', 'esperando');

  await assertSucceeds(
    elEntrenador()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .update({ estado: 'enRevision' }),
  );
});

test('el entrenador NO la cierra desde el cliente', async () => {
  // Aprobar y rechazar pasan por el servidor, que es quien pone la fecha y
  // quien archiva. Si el cliente pudiera, la fecha seria una declaracion suya.
  await sembrarPeticion('n-ana', 'enRevision');

  await assertFails(
    elEntrenador()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .update({ estado: 'aprobada', planId: 'p-1', respondidaEn: new Date() }),
  );
});

test('el entrenador no inventa una peticion a nombre de nadie', async () => {
  await assertFails(
    elEntrenador()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .set(peticionNueva()),
  );
});

test('el entrenador no toca las respuestas', async () => {
  // Lo que el nadador respondio es lo que hace la peticion auditable: si se
  // puede reescribir, deja de poder verse con que se genero el borrador.
  await sembrarPeticion('n-ana', 'enRevision');

  await assertFails(
    elEntrenador()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .update({ respuestas: { ...respuestas(), longitudPiscina: 50 } }),
  );
});

// --- El historial: solo el servidor -------------------------------------

test('el historial no lo escribe ningun cliente', async () => {
  await sembrarVinculos();

  for (const quien of [ana(), elEntrenador()]) {
    await assertFails(
      quien
        .collection('peticionesDePlan')
        .doc('n-ana')
        .collection('historial')
        .doc('h1')
        .set({ estado: 'aprobada' }),
    );
  }
});

test('pero la nadadora y el entrenador lo leen', async () => {
  await sembrarVinculos();
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .collection('historial')
      .doc('h1')
      .set({ nadadorId: 'n-ana', estado: 'rechazada', motivoDelRechazo: 'x' });
  });

  await assertSucceeds(
    ana()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .collection('historial')
      .doc('h1')
      .get(),
  );
  await assertSucceeds(
    elEntrenador()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .collection('historial')
      .doc('h1')
      .get(),
  );
});

test('y una nadadora no lee el historial de otra', async () => {
  await sembrarVinculos();
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('peticionesDePlan')
      .doc('n-juan')
      .collection('historial')
      .doc('h1')
      .set({ nadadorId: 'n-juan', estado: 'aprobada' });
  });

  await assertFails(
    ana()
      .collection('peticionesDePlan')
      .doc('n-juan')
      .collection('historial')
      .doc('h1')
      .get(),
  );
});

// --- La coleccion no es la de consentimiento (decision D2) --------------

test('D2 — `peticionesDePlan` y `solicitudes` son cosas distintas', async () => {
  // `solicitudes` son las de consentimiento de la feature 004, y ningun
  // cliente las escribe. Si esta prueba empieza a pasar por el otro lado,
  // alguien unifico dos colecciones que guardan cosas distintas.
  await sembrarVinculos();

  await assertFails(
    ana().collection('solicitudes').doc('n-ana').set(peticionNueva()),
  );
  assert.ok(true);
});

// --- P9: la puerta del menor, tambien en la regla -----------------------

test('P9 — sin consentimiento vigente, la peticion no sale del telefono', async () => {
  // La bandeja de salida del dispositivo ya la retiene. Esto es lo que la
  // sostiene cuando el dispositivo miente: la regla no acepta la escritura.
  await sembrarVinculos({ conConsentimiento: false });

  await assertFails(
    ana().collection('peticionesDePlan').doc('n-ana').set(peticionNueva()),
  );
});

test('P10 — y en cuanto hay consentimiento, sale', async () => {
  await sembrarVinculos({ conConsentimiento: false });
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('consentimientos')
      .doc('n-ana')
      .set({ vigente: true });
  });

  await assertSucceeds(
    ana().collection('peticionesDePlan').doc('n-ana').set(peticionNueva()),
  );
});

test('P9 — un consentimiento revocado no vale', async () => {
  await sembrarVinculos({ conConsentimiento: false });
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('consentimientos')
      .doc('n-ana')
      .set({ vigente: false, revocadoPor: 'supresion' });
  });

  await assertFails(
    ana().collection('peticionesDePlan').doc('n-ana').set(peticionNueva()),
  );
});
