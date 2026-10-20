// Reglas de acceso de la feature 004: cuentas, roles y la puerta de
// consentimiento.
//
// **Aqui es donde se prueba la puerta.** Contra el emulador, con la cuenta
// correcta del nadador y saltandose la app: una puerta probada solo a traves
// de su propia pantalla no esta probada.
//
// Contratos:
//   specs/004-cuentas-y-consentimiento/contracts/cuentas_y_roles.md
//   specs/004-cuentas-y-consentimiento/contracts/consentimiento.md

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

function comoEntrenador() {
  return entorno
    .authenticatedContext('u-entrenador', { rol: 'entrenador' })
    .firestore();
}

function comoNadador(uid) {
  return entorno.authenticatedContext(uid, { rol: 'nadador' }).firestore();
}

function sinAutenticar() {
  return entorno.unauthenticatedContext().firestore();
}

/** Escribe saltandose las reglas, para dejar el escenario montado. */
async function sembrar(escribir) {
  await entorno.withSecurityRulesDisabled(async (contexto) => {
    await escribir(contexto.firestore());
  });
}

/**
 * Deja una cuenta de nadador lista: su vinculo con el perfil y, si procede, su
 * consentimiento vigente.
 *
 * Las dos cosas las escribe el servidor en la app real, nunca el cliente, asi
 * que aqui se siembran saltandose las reglas. Montar el escenario por la via
 * del cliente seria dar por bueno que el cliente puede hacer algo que las
 * reglas le prohiben.
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

const unPlan = {
  nombre: 'Microciclo de base',
  categoria: 'Precompetitivo',
  estiloObjetivo: 'Libre',
  estado: 'publicado',
  nadadoresIds: ['n1'],
};

const unRegistro = {
  nadadorId: 'n1',
  planId: 'p1',
  sesionId: 's1',
  versionDePlan: '3.6.0',
  realizada: true,
  registradoEn: '2026-10-15T07:30:00.000',
  rpePercibido: 7,
};

async function conPlan(cambios = {}) {
  await sembrar(async (db) => {
    await db.collection('planes').doc('p1').set({ ...unPlan, ...cambios });
  });
}

// --- A4: cada quien lee y escribe lo suyo --------------------------------

test('A4 — el nadador lee su plan publicado y asignado', async () => {
  await darDeAlta('u-n1', 'n1');
  await conPlan();
  await sembrar(async (db) => {
    await db
      .collection('asignaciones')
      .doc('p1|n1')
      .set({ planId: 'p1', nadadorId: 'n1', asignadaEn: new Date() });
  });
  await assertSucceeds(comoNadador('u-n1').collection('planes').doc('p1').get());
});

test('A4 — el nadador no lee el plan de otro', async () => {
  await darDeAlta('u-n1', 'n1');
  await conPlan({ nadadoresIds: ['n2'] });
  await assertFails(comoNadador('u-n1').collection('planes').doc('p1').get());
});

test('A4 — el nadador no lee un borrador aunque le este asignado', async () => {
  await darDeAlta('u-n1', 'n1');
  await conPlan({ estado: 'borrador' });
  await assertFails(comoNadador('u-n1').collection('planes').doc('p1').get());
});

test('A4 — un aprobado sin publicar no le llega: aprobar no es entregar', async () => {
  await darDeAlta('u-n1', 'n1');
  await conPlan({ estado: 'aprobado' });
  await assertFails(comoNadador('u-n1').collection('planes').doc('p1').get());
});

test('A4 — un plan publicado sin asignar no es de nadie', async () => {
  await darDeAlta('u-n1', 'n1');
  await conPlan({ nadadoresIds: [] });
  await assertFails(comoNadador('u-n1').collection('planes').doc('p1').get());
});

test('A4 — una cuenta sin perfil asociado no lee ningun plan', async () => {
  await conPlan();
  await assertFails(
    comoNadador('u-suelto').collection('planes').doc('p1').get(),
  );
});

test('A4 — el nadador no lee el registro de otro', async () => {
  await darDeAlta('u-n1', 'n1');
  await sembrar(async (db) => {
    await db
      .collection('registros')
      .doc('r-ajeno')
      .set({ ...unRegistro, nadadorId: 'n2' });
  });

  await assertFails(
    comoNadador('u-n1').collection('registros').doc('r-ajeno').get(),
  );
});

test('A4 — el nadador no escribe un registro con el nadadorId de otro', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await darDeAlta('u-n2', 'n2', { conConsentimiento: true });

  await assertFails(
    comoNadador('u-n1')
      .collection('registros')
      .doc('r-robado')
      .set({ ...unRegistro, nadadorId: 'n2' }),
  );
});

// --- A3: el nadador no aprueba ni publica (principio IV) -----------------

test('A3 — el nadador no mueve un plan a aprobado', async () => {
  await darDeAlta('u-n1', 'n1');
  await conPlan({ estado: 'borrador' });

  await assertFails(
    comoNadador('u-n1')
      .collection('planes')
      .doc('p1')
      .update({ estado: 'aprobado' }),
  );
});

test('A3 — el nadador no mueve un plan a publicado', async () => {
  await darDeAlta('u-n1', 'n1');
  await conPlan({ estado: 'aprobado' });

  await assertFails(
    comoNadador('u-n1')
      .collection('planes')
      .doc('p1')
      .update({ estado: 'publicado' }),
  );
});

test('A3 — el nadador no crea un plan', async () => {
  await darDeAlta('u-n1', 'n1');
  await assertFails(
    comoNadador('u-n1')
      .collection('planes')
      .doc('nuevo')
      .set({ ...unPlan, estado: 'borrador' }),
  );
});

// --- A5: el entrenador lee los registros, no los escribe -----------------

test('A5 — el entrenador lee un registro de su comunidad', async () => {
  await sembrar(async (db) => {
    await db.collection('registros').doc('r1').set(unRegistro);
  });

  await assertSucceeds(comoEntrenador().collection('registros').doc('r1').get());
});

test('A5 — el entrenador NO escribe el registro de un nadador', async () => {
  // Cambio deliberado respecto de la feature 003, donde era lo unico
  // permitido porque no habia identidad de nadador. Lo que el nadador
  // responde es su carga interna, no la del entrenador.
  await assertFails(
    comoEntrenador().collection('registros').doc('r1').set(unRegistro),
  );
});

// --- A6: sin sesion, nada ------------------------------------------------

test('A6 — sin autenticar no se leen consentimientos', async () => {
  await assertFails(
    sinAutenticar().collection('consentimientos').doc('n1').get(),
  );
});

test('A6 — sin autenticar no se leen solicitudes', async () => {
  await assertFails(sinAutenticar().collection('solicitudes').doc('s1').get());
});

test('A6 — sin autenticar no se lee el vinculo de usuario', async () => {
  await assertFails(sinAutenticar().collection('usuarios').doc('u-n1').get());
});

test('A6 — sin autenticar no se lee un plan publicado', async () => {
  await conPlan();
  await assertFails(sinAutenticar().collection('planes').doc('p1').get());
});

// --- A1 y C5: lo que solo escribe el servidor ----------------------------

test('A1 — un nadador no se declara dueno del perfil de otro', async () => {
  // Si pudiera escribir su propio vinculo se pondria el nadadorId de otro y
  // leeria sus planes y sus registros. Es la escritura mas peligrosa de todo
  // el esquema.
  await assertFails(
    comoNadador('u-n1')
      .collection('usuarios')
      .doc('u-n1')
      .set({ nadadorId: 'n2' }),
  );
});

test('C5 — ni el entrenador escribe un consentimiento', async () => {
  await assertFails(
    comoEntrenador()
      .collection('consentimientos')
      .doc('n1')
      .set({ vigente: true }),
  );
});

test('C5 — el nadador tampoco escribe su propio consentimiento', async () => {
  await darDeAlta('u-n1', 'n1');
  await assertFails(
    comoNadador('u-n1')
      .collection('consentimientos')
      .doc('n1')
      .set({ vigente: true }),
  );
});

test('C5 — nadie escribe una solicitud desde el cliente', async () => {
  await assertFails(
    comoEntrenador()
      .collection('solicitudes')
      .doc('s1')
      .set({ nadadorId: 'n1' }),
  );
});

test('el nadador lee su propio consentimiento', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await assertSucceeds(
    comoNadador('u-n1').collection('consentimientos').doc('n1').get(),
  );
});

test('el nadador no lee el consentimiento de otro', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await darDeAlta('u-n2', 'n2', { conConsentimiento: true });

  await assertFails(
    comoNadador('u-n1').collection('consentimientos').doc('n2').get(),
  );
});

// --- P1 y P6: la puerta --------------------------------------------------

test('P1 — sin consentimiento vigente, el registro se deniega', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: false });

  await assertFails(
    comoNadador('u-n1').collection('registros').doc('r1').set(unRegistro),
  );
});

test('P1 — con consentimiento vigente, el mismo registro pasa', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });

  await assertSucceeds(
    comoNadador('u-n1').collection('registros').doc('r1').set(unRegistro),
  );
});

test('P1 — un consentimiento con vigente en falso no abre la puerta', async () => {
  await sembrar(async (db) => {
    await db.collection('usuarios').doc('u-n1').set({ nadadorId: 'n1' });
    await db.collection('consentimientos').doc('n1').set({ vigente: false });
  });

  await assertFails(
    comoNadador('u-n1').collection('registros').doc('r1').set(unRegistro),
  );
});

test('P6 — revocado el consentimiento, deja de pasar', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await assertSucceeds(
    comoNadador('u-n1').collection('registros').doc('r1').set(unRegistro),
  );

  await sembrar(async (db) => {
    await db.collection('consentimientos').doc('n1').update({ vigente: false });
  });

  await assertFails(
    comoNadador('u-n1').collection('registros').doc('r2').set(unRegistro),
  );
});

test('P6 — revocado, tampoco se modifica lo ya enviado', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await assertSucceeds(
    comoNadador('u-n1').collection('registros').doc('r1').set(unRegistro),
  );

  await sembrar(async (db) => {
    await db.collection('consentimientos').doc('n1').update({ vigente: false });
  });

  await assertFails(
    comoNadador('u-n1')
      .collection('registros')
      .doc('r1')
      .update({ rpePercibido: 2 }),
  );
});

test('reenviar el mismo registro lo sobrescribe, no lo duplica', async () => {
  // El identificador del documento es el identificador determinista del
  // registro: dos envios escriben el mismo documento (FR-020). Ahora lo
  // escribe el nadador, que es de quien es.
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });

  const db = comoNadador('u-n1');
  const id = 'n1|p1|s1|3.6.0';

  await assertSucceeds(db.collection('registros').doc(id).set(unRegistro));
  await assertSucceeds(
    db.collection('registros').doc(id).set({ ...unRegistro, rpePercibido: 9 }),
  );

  const leido = await db.collection('registros').doc(id).get();
  assert.equal(
    leido.data().rpePercibido,
    9,
    'El reenvio tiene que sobrescribir el mismo documento',
  );
});

test('un registro no se borra desde el cliente', async () => {
  // El derecho al borrado del principio V se ejerce por la via del servidor,
  // que puede dejar constancia de que se ejercio.
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await sembrar(async (db) => {
    await db.collection('registros').doc('r1').set(unRegistro);
  });

  await assertFails(
    comoNadador('u-n1').collection('registros').doc('r1').delete(),
  );
  await assertFails(comoEntrenador().collection('registros').doc('r1').delete());
});

// --- Asignaciones: la puerta de publicacion -------------------------------
//
// Una asignacion por nadador, con identificador determinista. Es lo que
// permite que la regla compruebe SU consentimiento con un solo get(): con la
// lista dentro del plan haria falta recorrerla, y el lenguaje de reglas no
// tiene bucles.

/** Entrega un plan a un nadador saltandose las reglas, para montar escenario. */
async function conAsignacion(planId, nadadorId) {
  await sembrar(async (db) => {
    await db
      .collection('asignaciones')
      .doc(`${planId}|${nadadorId}`)
      .set({ planId, nadadorId, asignadaEn: new Date() });
  });
}

test('P5 — el entrenador asigna a quien tiene consentimiento vigente', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await conPlan();

  await assertSucceeds(
    comoEntrenador()
      .collection('asignaciones')
      .doc('p1|n1')
      .set({ planId: 'p1', nadadorId: 'n1', asignadaEn: new Date() }),
  );
});

test('P5 — sin consentimiento vigente, NO se le puede asignar', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: false });
  await conPlan();

  await assertFails(
    comoEntrenador()
      .collection('asignaciones')
      .doc('p1|n1')
      .set({ planId: 'p1', nadadorId: 'n1', asignadaEn: new Date() }),
  );
});

test('P5 — revocado el consentimiento, deja de poder asignarsele', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await sembrar(async (db) => {
    await db.collection('consentimientos').doc('n1').update({ vigente: false });
  });

  await assertFails(
    comoEntrenador()
      .collection('asignaciones')
      .doc('p1|n1')
      .set({ planId: 'p1', nadadorId: 'n1', asignadaEn: new Date() }),
  );
});

test('el identificador tiene que coincidir con su contenido', async () => {
  // Si no, se podria escribir una asignacion para n1 en el documento de n2 y
  // la regla de lectura del plan —que busca por identificador— la encontraria.
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });

  await assertFails(
    comoEntrenador()
      .collection('asignaciones')
      .doc('p1|n2')
      .set({ planId: 'p1', nadadorId: 'n1', asignadaEn: new Date() }),
  );
});

test('un nadador no se asigna un plan a si mismo', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });

  await assertFails(
    comoNadador('u-n1')
      .collection('asignaciones')
      .doc('p1|n1')
      .set({ planId: 'p1', nadadorId: 'n1', asignadaEn: new Date() }),
  );
});

test('una asignacion no se edita, para que no se salte la puerta', async () => {
  // Permitir un update dejaria cambiar el nadadorId de una asignacion ya
  // concedida sin volver a comprobar su consentimiento.
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await conAsignacion('p1', 'n1');

  await assertFails(
    comoEntrenador()
      .collection('asignaciones')
      .doc('p1|n1')
      .update({ nadadorId: 'n2' }),
  );
});

test('el nadador lee su asignacion y no la de otro', async () => {
  await darDeAlta('u-n1', 'n1');
  await conAsignacion('p1', 'n1');
  await conAsignacion('p1', 'n2');

  await assertSucceeds(
    comoNadador('u-n1').collection('asignaciones').doc('p1|n1').get(),
  );
  await assertFails(
    comoNadador('u-n1').collection('asignaciones').doc('p1|n2').get(),
  );
});

test('retirar un plan es del entrenador', async () => {
  await darDeAlta('u-n1', 'n1', { conConsentimiento: true });
  await conAsignacion('p1', 'n1');

  await assertFails(
    comoNadador('u-n1').collection('asignaciones').doc('p1|n1').delete(),
  );
  await assertSucceeds(
    comoEntrenador().collection('asignaciones').doc('p1|n1').delete(),
  );
});

// --- La entrega: el unico cambio admitido sobre un plan aprobado ----------

test('el entrenador pasa un plan de aprobado a publicado', async () => {
  await conPlan({ estado: 'aprobado' });

  await assertSucceeds(
    comoEntrenador().collection('planes').doc('p1').update({ estado: 'publicado' }),
  );
});

test('la entrega no puede cambiar nada mas que el estado', async () => {
  // La inmutabilidad de FR-025 es sobre lo que el entrenador firmo. Entregar
  // no es tocarlo.
  await conPlan({ estado: 'aprobado' });

  await assertFails(
    comoEntrenador()
      .collection('planes')
      .doc('p1')
      .update({ estado: 'publicado', nombre: 'Otro nombre' }),
  );
});

test('un publicado no vuelve a aprobado', async () => {
  await conPlan({ estado: 'publicado' });

  await assertFails(
    comoEntrenador().collection('planes').doc('p1').update({ estado: 'aprobado' }),
  );
});

test('un borrador no salta directo a publicado', async () => {
  await conPlan({ estado: 'borrador' });

  await assertFails(
    comoEntrenador().collection('planes').doc('p1').update({ estado: 'publicado' }),
  );
});
