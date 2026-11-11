// Lo que el entrenador puede leer de los registros de sus nadadores
// (feature 010, US1).
//
// **Las pruebas que tienen que estar aqui son las que PASAN.** La feature 008
// se llevo esta leccion por delante: su primera suite de reglas dio 18 de 24
// en verde contra una coleccion que no tenia ninguna regla, porque el
// deny-por-defecto hace que toda negacion pase. Las unicas seis que fallaron
// fueron las seis `assertSucceeds`.
//
// Asi que cada negacion de aqui tiene su contraparte positiva, y el control
// negativo de T023 apunta la suite a un nombre de coleccion sin regla para
// comprobar que las positivas se caen.
//
// La regla que se comprueba existe desde la feature 007 y esta feature no la
// cambia: lo que cambia es que ahora hay una pantalla que la usa. Que no haga
// falta abrir nada es exactamente el motivo de que esta suite se escriba
// ahora: **una regla que nadie ejercitaba.**
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

// El control negativo de T023 cambia esto por un nombre sin regla.
//
// Hecho el 2026-11-11 con `registros_sin_regla`, y el resultado repite la
// leccion de la 008 con numeros: **5 de 10 pruebas pasaron contra una
// coleccion que no tenia ninguna regla.** Las unicas que fallaron fueron las
// cinco `assertSucceeds` — las cuatro lecturas permitidas y el limite
// declarado de T022, que tambien afirma un exito. Sin ellas, esta suite
// habria dado verde entera sin comprobar la regla que dice comprobar.
const COLECCION = 'registros';

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

// El segundo entrenador existe solo para T022, que declara un limite.
const otroEntrenador = () =>
  entorno
    .authenticatedContext('u-otro-entrenador', { rol: 'entrenador' })
    .firestore();

const deFuera = () => entorno.unauthenticatedContext().firestore();

const registro = (extra = {}) => ({
  nadadorId: 'n-ana',
  planId: 'plan-1',
  sesionId: 's1',
  versionDePlan: 'plan-1',
  realizada: true,
  registradoEn: '2026-11-02T18:30:00.000',
  rpePercibido: 7,
  observaciones: 'Me costo el ultimo 200',
  ...extra,
});

async function sembrarVinculos() {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    const db = sinReglas.firestore();
    await db.collection('usuarios').doc('u-ana').set({ nadadorId: 'n-ana' });
    await db.collection('usuarios').doc('u-juan').set({ nadadorId: 'n-juan' });
    await db
      .collection('consentimientos')
      .doc('n-ana')
      .set({ vigente: true, alcances: ['datosDeEntrenamiento'] });
  });
}

async function sembrarRegistro(id = 'n-ana|plan-1|s1|plan-1', extra = {}) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection(COLECCION)
      .doc(id)
      .set(registro(extra));
  });
}

// --- Lo que el entrenador puede (las que importan) -----------------------

test('el entrenador lee el registro de una nadadora', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  await assertSucceeds(
    elEntrenador().collection(COLECCION).doc('n-ana|plan-1|s1|plan-1').get(),
  );
});

test('el entrenador lee la coleccion entera, que es como cuenta', async () => {
  await sembrarVinculos();
  await sembrarRegistro();
  await sembrarRegistro('n-juan|plan-1|s1|plan-1', { nadadorId: 'n-juan' });

  // Una consulta, no una por nadador: es la decision D10 de la feature 008, y
  // es tambien como la 010 marca en la lista quien conto una molestia.
  const leidos = await assertSucceeds(
    elEntrenador().collection(COLECCION).get(),
  );
  assert.equal(leidos.size, 2);
});

test('el entrenador consulta los de una nadadora por su id', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  const leidos = await assertSucceeds(
    elEntrenador().collection(COLECCION).where('nadadorId', '==', 'n-ana').get(),
  );
  assert.equal(leidos.size, 1);
});

test('la nadadora lee los suyos', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  await assertSucceeds(
    ana().collection(COLECCION).doc('n-ana|plan-1|s1|plan-1').get(),
  );
});

// --- Lo que nadie puede --------------------------------------------------

test('una nadadora no lee el registro de otra', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  await assertFails(
    juan().collection(COLECCION).doc('n-ana|plan-1|s1|plan-1').get(),
  );
});

test('una nadadora no lee la coleccion entera', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  // **Esta es la que de verdad protege.** Leer un documento concreto de otra
  // es difícil sin conocer su id; barrer la coleccion no lo es.
  await assertFails(ana().collection(COLECCION).get());
});

test('el entrenador no escribe lo que la nadadora contesto', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  // Es un cambio deliberado respecto de la feature 003, donde escribir era lo
  // unico permitido: lo que la nadadora responde es su carga interna, no la
  // del entrenador. La 010 lo lee y no lo toca.
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('n-ana|plan-1|s1|plan-1')
      .update({ rpePercibido: 2 }),
  );
});

test('el entrenador no borra un registro', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  await assertFails(
    elEntrenador().collection(COLECCION).doc('n-ana|plan-1|s1|plan-1').delete(),
  );
});

test('sin sesion no se lee nada', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  await assertFails(
    deFuera().collection(COLECCION).doc('n-ana|plan-1|s1|plan-1').get(),
  );
});

// --- El limite declarado (T022, FR-025, decision D1) ---------------------

test('UN SEGUNDO ENTRENADOR LEE A LA NADADORA DEL PRIMERO, y pasa', async () => {
  await sembrarVinculos();
  await sembrarRegistro();

  // **Esta prueba afirma que algo SALE BIEN cuando la spec preferiria que no.**
  //
  // No hay vinculo entrenador -> nadador en el producto: `Nadador` no tiene
  // dueno y la regla dice `esEntrenador()`, sin mas. La constitucion describe
  // una comunidad dirigida por *un* entrenador, en singular, asi que la regla
  // es la correcta para lo que existe — pero FR-024 pedia «solo sus
  // nadadores» y eso no se puede cumplir hoy.
  //
  // Se enmendo FR-024, el motivo quedo escrito al lado en la spec, y esto es
  // lo que FR-025 exige: **el limite afirmado, no silenciado.** El dia que
  // exista un segundo entrenador, esta es la primera prueba que se cae, y es
  // justo lo que tiene que pasar.
  //
  // La feature 003 declaro una limitacion igual —las reglas no distinguian a
  // un nadador de otro porque no habia identidad— y la 004 la cerro.
  await assertSucceeds(
    otroEntrenador().collection(COLECCION).doc('n-ana|plan-1|s1|plan-1').get(),
  );
});
