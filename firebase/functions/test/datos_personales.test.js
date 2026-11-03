/**
 * Guarantees H21, H22 and H27 — correcting a profile, and erasing one.
 *
 * Contract: specs/007-hub-y-recorridos/contracts/hub_y_ajustes.md
 *
 * These import the **compiled server code** from `../lib` and run it against
 * the emulator. That is the point: `npm test` builds first, so what gets
 * exercised is the code that deploys, not a replica of it written in the test.
 * Feature 006 learned that the hard way — ten green tests over a wire nobody
 * was checking.
 *
 * Two of these are not about shape. They are the ones that would hurt:
 *
 *   - correcting a surname must not touch which version of the terms the
 *     person accepted, or when;
 *   - erasing must leave the proof that the earlier processing was authorised.
 *
 * Run with:  npm --prefix firebase/functions test
 */

const assert = require('node:assert/strict');
const { after, before, beforeEach, describe, it } = require('node:test');

const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const {
  corregirPerfilDe,
  suprimirDatosDe,
} = require('../lib/datos_personales');

const PROYECTO = 'demo-natacion';

let app;
let db;

before(() => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'Estas pruebas necesitan el emulador de Firestore. Corre `npm test`.'
  );
  app = initializeApp({ projectId: PROYECTO });
  db = getFirestore(app);
});

after(async () => {
  await deleteApp(app);
});

const COLECCIONES = [
  'usuarios',
  'nadadores',
  'registros',
  'asignaciones',
  'consentimientos',
];

async function limpiar() {
  for (const coleccion of COLECCIONES) {
    const docs = await db.collection(coleccion).get();
    await Promise.all(docs.docs.map((d) => d.ref.delete()));
  }
}

beforeEach(limpiar);

/** Una cuenta con todo lo que una supresión tiene que recorrer. */
async function sembrar({ uid = 'u-ana', nadadorId = 'n-ana' } = {}) {
  const aceptadaEn = new Date('2026-09-15T10:00:00Z');

  await db.collection('usuarios').doc(uid).set({
    nombre: 'Ana María Restrepo',
    fechaNacimiento: '2014-03-07',
    pais: 'CO',
    nadadorId,
    terminos: { version: 'v1', aceptadaEn },
  });

  await db.collection('nadadores').doc(nadadorId).set({
    nombre: 'Ana María Restrepo',
    fechaNacimiento: '2014-03-07',
    categoria: 'precompetitivo',
    estiloObjetivo: 'libre',
  });

  await db.collection('registros').doc('r1').set({
    nadadorId,
    planId: 'p1',
    sesionId: 's1',
    realizada: true,
  });
  await db.collection('registros').doc('r2').set({
    nadadorId,
    planId: 'p1',
    sesionId: 's2',
    realizada: false,
  });
  // De otro nadador: no se toca.
  await db.collection('registros').doc('r-otro').set({
    nadadorId: 'n-otro',
    planId: 'p1',
    sesionId: 's1',
    realizada: true,
  });

  await db
    .collection('asignaciones')
    .doc(`p1|${nadadorId}`)
    .set({ planId: 'p1', nadadorId });
  await db
    .collection('asignaciones')
    .doc('p1|n-otro')
    .set({ planId: 'p1', nadadorId: 'n-otro' });

  await db
    .collection('consentimientos')
    .doc(nadadorId)
    .set({ vigente: true, otorgadoEn: aceptadaEn });
  await db
    .collection('consentimientos')
    .doc(nadadorId)
    .collection('historial')
    .doc('h1')
    .set({ calidad: 'madre', otorgadoEn: aceptadaEn });

  return { uid, nadadorId, aceptadaEn };
}

describe('corregirPerfilDe', () => {
  it('H22 — cambia el nombre en los dos sitios donde vive', async () => {
    const { uid, nadadorId } = await sembrar();

    await corregirPerfilDe(db, uid, {
      nombre: 'Ana María Restrepo Vélez',
      fechaNacimiento: '2014-03-07',
      pais: 'CO',
    });

    const usuario = (await db.collection('usuarios').doc(uid).get()).data();
    const nadador = (
      await db.collection('nadadores').doc(nadadorId).get()
    ).data();

    assert.equal(usuario.nombre, 'Ana María Restrepo Vélez');
    assert.equal(
      nadador.nombre,
      'Ana María Restrepo Vélez',
      'Si solo cambiara en `usuarios`, el panel del entrenador seguiría ' +
        'mostrando el nombre viejo: dos nombres para la misma persona'
    );
  });

  it('**H21 — no toca la constancia de los términos**', async () => {
    const { uid, aceptadaEn } = await sembrar();

    await corregirPerfilDe(db, uid, {
      nombre: 'Ana María Restrepo Vélez',
      fechaNacimiento: '2014-03-07',
      pais: 'CO',
    });

    const usuario = (await db.collection('usuarios').doc(uid).get()).data();

    assert.equal(
      usuario.terminos.version,
      'v1',
      'Corregir un apellido no puede cambiar qué versión aceptó'
    );
    assert.equal(
      usuario.terminos.aceptadaEn.toDate().getTime(),
      aceptadaEn.getTime(),
      'Ni cuándo la aceptó. Eso es un registro legal, no un campo más'
    );
  });

  it('no borra lo que el entrenador había puesto en la ficha', async () => {
    const { uid, nadadorId } = await sembrar();

    await corregirPerfilDe(db, uid, {
      nombre: 'Ana María Restrepo Vélez',
      fechaNacimiento: '2014-03-07',
      pais: null,
    });

    const nadador = (
      await db.collection('nadadores').doc(nadadorId).get()
    ).data();

    assert.equal(nadador.categoria, 'precompetitivo');
    assert.equal(nadador.estiloObjetivo, 'libre');
  });

  it('recalcula la minoría de edad en el servidor', async () => {
    const { uid } = await sembrar();

    const menor = await corregirPerfilDe(db, uid, {
      nombre: 'Ana María Restrepo',
      fechaNacimiento: '2014-03-07',
      pais: 'CO',
    });
    assert.equal(menor.esMenor, true);

    const adulta = await corregirPerfilDe(db, uid, {
      nombre: 'Ana María Restrepo',
      fechaNacimiento: '1995-04-12',
      pais: 'CO',
    });
    assert.equal(adulta.esMenor, false);
  });

  it('rechaza lo que no se entiende, en lugar de suponerlo', async () => {
    const { uid } = await sembrar();

    for (const datos of [
      { nombre: '   ', fechaNacimiento: '2014-03-07' },
      { nombre: 'Ana', fechaNacimiento: 'el martes' },
      { nombre: 'Ana', fechaNacimiento: '1823-01-01' },
      { nombre: 'Ana', fechaNacimiento: '2014-03-07', pais: 'Colombia' },
      { nombre: 'A'.repeat(81), fechaNacimiento: '2014-03-07' },
    ]) {
      await assert.rejects(
        () => corregirPerfilDe(db, uid, datos),
        'Se aceptó un dato que no se entiende: ' + JSON.stringify(datos)
      );
    }
  });
});

describe('suprimirDatosDe', () => {
  it('borra sus registros, y solo los suyos', async () => {
    const { uid } = await sembrar();

    const resultado = await suprimirDatosDe(db, uid, { borrarCuenta: false });

    assert.equal(resultado.registrosEliminados, 2);

    const quedan = await db.collection('registros').get();
    assert.deepEqual(
      quedan.docs.map((d) => d.id),
      ['r-otro'],
      'Los registros de otro nadador no son de esta supresión'
    );
  });

  it('retira sus asignaciones, y solo las suyas', async () => {
    const { uid } = await sembrar();

    const resultado = await suprimirDatosDe(db, uid, { borrarCuenta: false });

    assert.equal(resultado.asignacionesRetiradas, 1);

    const quedan = await db.collection('asignaciones').get();
    assert.deepEqual(
      quedan.docs.map((d) => d.id),
      ['p1|n-otro']
    );
  });

  it('borra su ficha de nadador y el documento de su cuenta', async () => {
    const { uid, nadadorId } = await sembrar();

    const resultado = await suprimirDatosDe(db, uid, { borrarCuenta: false });

    assert.equal(resultado.perfilEliminado, true);
    assert.equal(
      (await db.collection('nadadores').doc(nadadorId).get()).exists,
      false
    );
    assert.equal(
      (await db.collection('usuarios').doc(uid).get()).exists,
      false,
      'El vínculo entre cuenta y nadador se va con lo demás'
    );
  });

  it('revoca el consentimiento', async () => {
    const { uid, nadadorId } = await sembrar();

    await suprimirDatosDe(db, uid, { borrarCuenta: false });

    const consentimiento = (
      await db.collection('consentimientos').doc(nadadorId).get()
    ).data();

    assert.equal(consentimiento.vigente, false);
    assert.ok(consentimiento.revocadoEn, 'Con fecha de cuándo se revocó');
  });

  it('**y deja en pie la prueba de que hubo consentimiento**', async () => {
    const { uid, nadadorId, aceptadaEn } = await sembrar();

    await suprimirDatosDe(db, uid, { borrarCuenta: false });

    const historial = await db
      .collection('consentimientos')
      .doc(nadadorId)
      .collection('historial')
      .get();

    assert.equal(
      historial.size,
      1,
      'Es la prueba de que el tratamiento anterior estuvo amparado ' +
        '(garantía C8). Borrarla dejaría al entrenador sin poder demostrar ' +
        'que actuó con autorización'
    );
    assert.equal(
      historial.docs[0].data().otorgadoEn.toDate().getTime(),
      aceptadaEn.getTime()
    );
  });

  it('no estalla con una cuenta que no tiene nada', async () => {
    const resultado = await suprimirDatosDe(db, 'u-vacia', {
      borrarCuenta: false,
    });

    assert.equal(resultado.registrosEliminados, 0);
    assert.equal(resultado.asignacionesRetiradas, 0);
    assert.equal(resultado.perfilEliminado, false);
  });

  it('D7 — borra también la cuenta de identidad', async () => {
    const auth = getAuth(app);
    const usuario = await auth.createUser({
      uid: 'u-con-cuenta',
      email: 'ana@ejemplo.com',
      password: 'una-clave-de-prueba',
    });

    await db
      .collection('usuarios')
      .doc(usuario.uid)
      .set({ nombre: 'Ana', nadadorId: 'n-con-cuenta' });

    const resultado = await suprimirDatosDe(db, usuario.uid);

    assert.equal(resultado.cuentaEliminada, true);
    await assert.rejects(
      () => auth.getUser(usuario.uid),
      'El correo es un dato personal: dejar la cuenta viva convertiría el ' +
        'derecho de supresión en un vaciado'
    );
  });
});

// --- Feature 008: lo que pidio se va con lo suyo (P37, FR-033) ----------

describe('feature 008 — lo que pidio se va con lo suyo', () => {
  it('P37 — la supresion se lleva la peticion de plan y su historial', async () => {
  const db = getFirestore();
  const uid = 'u-ana-peticion';
  const nadadorId = 'n-ana-peticion';

  await db.collection('usuarios').doc(uid).set({ nadadorId });
  await db.collection('nadadores').doc(nadadorId).set({ nombre: 'Ana' });
  await db.collection('peticionesDePlan').doc(nadadorId).set({
    nadadorId,
    estado: 'rechazada',
    motivoDelRechazo: 'Esta semana no.',
    respuestas: { pruebaObjetivo: '200 Libre' },
  });
  await db
    .collection('peticionesDePlan')
    .doc(nadadorId)
    .collection('historial')
    .doc('h1')
    .set({ nadadorId, estado: 'aprobada' });

  await suprimirDatosDe(db, uid, { borrarCuenta: false });

  assert.equal(
    (await db.collection('peticionesDePlan').doc(nadadorId).get()).exists,
    false,
    'La peticion lleva lo que el nadador respondio sobre su propio entrenamiento',
  );

  const historial = await db
    .collection('peticionesDePlan')
    .doc(nadadorId)
    .collection('historial')
    .get();
  assert.equal(historial.size, 0, 'El historial de peticiones tambien es suyo');
});

  it('P37 — y no toca la peticion de otro nadador', async () => {
  const db = getFirestore();

  await db.collection('usuarios').doc('u-uno').set({ nadadorId: 'n-uno' });
  await db.collection('peticionesDePlan').doc('n-uno').set({ nadadorId: 'n-uno' });
  await db.collection('peticionesDePlan').doc('n-otro').set({ nadadorId: 'n-otro' });

  await suprimirDatosDe(db, 'u-uno', { borrarCuenta: false });

  assert.equal(
    (await db.collection('peticionesDePlan').doc('n-otro').get()).exists,
    true,
  );
});
});
