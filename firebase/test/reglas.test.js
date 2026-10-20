// Pruebas de las reglas de acceso de Firestore.
//
// El principio III de la constitucion exige probarlas automaticamente,
// incluidos los casos negativos: una regla que permite lo que no deberia es un
// fallo de la misma gravedad que un calculo equivocado.
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

/** Cliente del entrenador, con el rol que las reglas esperan. */
function comoEntrenador() {
  return entorno
    .authenticatedContext('entrenador-1', { rol: 'entrenador' })
    .firestore();
}

/** Cliente sin autenticar. */
function sinAutenticar() {
  return entorno.unauthenticatedContext().firestore();
}

/** Cliente de un nadador, con el rol que viaja en su token. */
function comoNadador(uid) {
  return entorno.authenticatedContext(uid, { rol: 'nadador' }).firestore();
}

/** Escribe saltandose las reglas, para dejar el escenario montado. */
async function sembrar(escribir) {
  await entorno.withSecurityRulesDisabled(async (contexto) => {
    await escribir(contexto.firestore());
  });
}

/**
 * Deja una cuenta de nadador lista: su vinculo con el perfil y, si procede,
 * su consentimiento vigente.
 *
 * Las dos cosas las escribe el servidor en la app real, nunca el cliente, asi
 * que aqui se siembran saltandose las reglas: montar el escenario por la via
 * del cliente seria probar que el cliente puede hacer algo que no debe poder.
 */
async function darDeAlta(uid, nadadorId, { conConsentimiento = false } = {}) {
  await sembrar(async (db) => {
    await db.collection('usuarios').doc(uid).set({ nadadorId });
    if (conConsentimiento) {
      await db.collection('consentimientos').doc(nadadorId).set({
        vigente: true,
        otorgadoEn: '2026-10-14T10:00:00.000Z',
        alcances: ['datosDeEntrenamiento'],
      });
    }
  });
}

const planBorrador = {
  nombre: 'Tecnica de eficiencia',
  categoria: 'Precompetitivo',
  estiloObjetivo: 'Libre',
  estado: 'borrador',
};

// --- Casos negativos: lo que NO debe poder hacerse ------------------------

test('un cliente sin autenticar no puede leer planes', async () => {
  await assertFails(sinAutenticar().collection('planes').doc('p1').get());
});

test('un cliente sin autenticar no puede escribir planes', async () => {
  await assertFails(
    sinAutenticar().collection('planes').doc('p1').set(planBorrador),
  );
});

test('un cliente sin autenticar no puede leer nadadores', async () => {
  await assertFails(sinAutenticar().collection('nadadores').doc('n1').get());
});

test('un cliente sin autenticar no puede leer sesiones', async () => {
  await assertFails(
    sinAutenticar()
      .collection('planes')
      .doc('p1')
      .collection('sesiones')
      .doc('s1')
      .get(),
  );
});

test('una coleccion no contemplada esta cerrada', async () => {
  await assertFails(
    comoEntrenador().collection('coleccionCualquiera').doc('x').set({ a: 1 }),
  );
});

test('no se puede crear un plan directamente en estado aprobado', async () => {
  await assertFails(
    comoEntrenador()
      .collection('planes')
      .doc('p-nuevo')
      .set({ ...planBorrador, estado: 'aprobado' }),
  );
});

test('no se puede escribir sobre un plan aprobado', async () => {
  await entorno.withSecurityRulesDisabled(async (contexto) => {
    await contexto
      .firestore()
      .collection('planes')
      .doc('p-aprobado')
      .set({ ...planBorrador, estado: 'aprobado' });
  });

  await assertFails(
    comoEntrenador()
      .collection('planes')
      .doc('p-aprobado')
      .update({ nombre: 'Otro nombre' }),
  );
});

test('no se puede escribir sobre un plan publicado', async () => {
  await entorno.withSecurityRulesDisabled(async (contexto) => {
    await contexto
      .firestore()
      .collection('planes')
      .doc('p-publicado')
      .set({ ...planBorrador, estado: 'publicado' });
  });

  await assertFails(
    comoEntrenador()
      .collection('planes')
      .doc('p-publicado')
      .update({ nombre: 'Otro nombre' }),
  );
});

test('no se puede borrar un plan aprobado', async () => {
  await entorno.withSecurityRulesDisabled(async (contexto) => {
    await contexto
      .firestore()
      .collection('planes')
      .doc('p-aprobado')
      .set({ ...planBorrador, estado: 'aprobado' });
  });

  await assertFails(
    comoEntrenador().collection('planes').doc('p-aprobado').delete(),
  );
});

test('no se pueden escribir sesiones de un plan aprobado', async () => {
  await entorno.withSecurityRulesDisabled(async (contexto) => {
    await contexto
      .firestore()
      .collection('planes')
      .doc('p-aprobado')
      .set({ ...planBorrador, estado: 'aprobado' });
  });

  await assertFails(
    comoEntrenador()
      .collection('planes')
      .doc('p-aprobado')
      .collection('sesiones')
      .doc('s1')
      .set({ objetivoTecnico: 'x' }),
  );
});

// --- Casos positivos: lo que SI debe poder hacerse ------------------------

test('el entrenador crea un plan en borrador', async () => {
  await assertSucceeds(
    comoEntrenador().collection('planes').doc('p-borrador').set(planBorrador),
  );
});

test('el entrenador edita un plan en borrador', async () => {
  await comoEntrenador().collection('planes').doc('p-borrador').set(planBorrador);

  await assertSucceeds(
    comoEntrenador()
      .collection('planes')
      .doc('p-borrador')
      .update({ nombre: 'Ritmo competitivo' }),
  );
});

test('el entrenador lee sus planes', async () => {
  await assertSucceeds(
    comoEntrenador().collection('planes').doc('p-borrador').get(),
  );
});

test('el entrenador escribe sesiones de un plan en borrador', async () => {
  await comoEntrenador().collection('planes').doc('p-borrador').set(planBorrador);

  await assertSucceeds(
    comoEntrenador()
      .collection('planes')
      .doc('p-borrador')
      .collection('sesiones')
      .doc('s1')
      .set({ objetivoTecnico: 'Tecnica de espalda' }),
  );
});

test('el entrenador gestiona nadadores', async () => {
  await assertSucceeds(
    comoEntrenador().collection('nadadores').doc('n1').set({ nombre: 'Ana' }),
  );
});

// ---------------------------------------------------------------------------
// Registros del nadador (feature 003)
//
// Lo que se prueba es lo que hay: sin identidad de nadador, la regla solo puede
// distinguir entrenador de no-entrenador. Las reglas por nadador llegan con la
// feature 004, y entonces se anaden sus casos aqui.
// ---------------------------------------------------------------------------

const unRegistro = {
  nadadorId: 'n1',
  planId: 'p1',
  sesionId: 's1',
  versionDePlan: '3.5.0',
  realizada: true,
  registradoEn: '2026-10-14T07:30:00.000',
  rpePercibido: 7,
};

test('sin autenticar no se leen registros del nadador', async () => {
  await assertFails(sinAutenticar().collection('registros').doc('r1').get());
});

test('sin autenticar no se escriben registros del nadador', async () => {
  await assertFails(
    sinAutenticar().collection('registros').doc('r1').set(unRegistro),
  );
});

test('sin autenticar no se borra un registro', async () => {
  await assertFails(sinAutenticar().collection('registros').doc('r1').delete());
});

test('sin autenticar no se listan los registros de nadie', async () => {
  await assertFails(sinAutenticar().collection('registros').get());
});

test('A5 — el entrenador lee los registros pero NO los escribe', async () => {
  // Cambio deliberado de la feature 004. En la 003 el entrenador era el unico
  // que podia escribir aqui, porque no habia identidad de nadador y dejar la
  // coleccion abierta era peor. Con cuentas, lo que el nadador responde solo
  // lo escribe el nadador: es su carga interna, no la del entrenador.
  await sembrar(async (db) => {
    await db.collection('registros').doc('r1').set(unRegistro);
  });

  await assertSucceeds(comoEntrenador().collection('registros').doc('r1').get());
  await assertFails(
    comoEntrenador().collection('registros').doc('r2').set(unRegistro),
  );
});

test('reenviar el mismo registro lo sobrescribe, no lo duplica', async () => {
  // El identificador del documento es el identificador determinista del
  // registro: dos envios escriben el mismo documento (FR-020, decision D2).
  // Ahora lo escribe el nadador, que es de quien es.
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });

  const db = comoNadador('u-n1');
  const id = 'n1|p1|s1|3.5.0';

  await assertSucceeds(db.collection('registros').doc(id).set(unRegistro));
  await assertSucceeds(
    db.collection('registros').doc(id).set({ ...unRegistro, rpePercibido: 9 }),
  );

  const leido = await db.collection('registros').doc(id).get();
  if (leido.data().rpePercibido !== 9) {
    throw new Error('El reenvio no sobrescribio el registro');
  }
});
