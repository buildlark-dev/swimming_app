/**
 * Guarantees C1 to C9 — verifiable consent.
 *
 * Contract: specs/004-cuentas-y-consentimiento/contracts/consentimiento.md
 *
 * These exercise the server's own logic against the Firestore emulator. The
 * callable wrappers are thin; what matters is that the issue/redeem/revoke
 * rules hold, and those are tested here directly.
 */

const assert = require('node:assert/strict');
const { after, before, beforeEach, describe, it } = require('node:test');
const { createHash, randomBytes } = require('node:crypto');

const { initializeApp, deleteApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const PROYECTO = 'demo-natacion';
const DIAS_DE_VIGENCIA = 7;

let app;
let db;

/** Same digest the server uses. The plaintext token is never stored. */
function resumirToken(token) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

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

beforeEach(async () => {
  const solicitudes = await db.collection('solicitudes').get();
  await Promise.all(solicitudes.docs.map((d) => d.ref.delete()));

  // Las subcolecciones NO se borran con su documento padre. Firestore las deja
  // ahi, huerfanas pero legibles. Aqui costo una prueba en rojo; en produccion
  // costaria que borrar el consentimiento de un nadador dejara su historial
  // entero en pie, que es justo lo que el principio V no permite. Queda
  // anotado para la tarea de borrado (T078).
  const consentimientos = await db.collection('consentimientos').get();
  for (const documento of consentimientos.docs) {
    const historial = await documento.ref.collection('historial').get();
    await Promise.all(historial.docs.map((h) => h.ref.delete()));
    await documento.ref.delete();
  }
});

/** Issues a request the way the server does, and hands back the plaintext. */
async function emitir({ nadadorId = 'n1', canal = 'madre@ejemplo.test', dias = DIAS_DE_VIGENCIA } = {}) {
  const token = randomBytes(32).toString('base64url');
  const vence = new Date();
  vence.setDate(vence.getDate() + dias);

  const ref = await db.collection('solicitudes').add({
    nadadorId,
    canal,
    alcances: ['datosDeEntrenamiento'],
    resumenDelToken: resumirToken(token),
    emitidaEn: FieldValue.serverTimestamp(),
    venceEn: vence,
    canjeadaEn: null,
  });

  return { token, id: ref.id, ref };
}

/** The redemption path, with the same checks the callable performs. */
async function canjear(token, declaracion = {}) {
  const d = {
    nombre: 'Maria Gomez',
    documento: '43123456',
    calidad: 'madre',
    esRepresentanteLegal: true,
    menorFueOido: true,
    versionDelTexto: 'v1',
    ...declaracion,
  };

  if (!d.nombre?.trim() || !d.documento?.trim() || !d.calidad?.trim()) {
    throw new Error('declaracion-incompleta');
  }
  if (!d.esRepresentanteLegal) throw new Error('no-es-representante');
  if (!d.menorFueOido) throw new Error('menor-no-oido');

  const encontradas = await db
    .collection('solicitudes')
    .where('resumenDelToken', '==', resumirToken(token))
    .limit(1)
    .get();

  if (encontradas.empty) throw new Error('enlace-no-sirve');

  const solicitud = encontradas.docs[0];
  const datos = solicitud.data();
  if (datos.canjeadaEn) throw new Error('enlace-no-sirve');
  if (Date.now() >= datos.venceEn.toDate().getTime()) {
    throw new Error('enlace-no-sirve');
  }

  const consentimiento = {
    nadadorId: datos.nadadorId,
    otorgadoPor: {
      nombre: d.nombre.trim(),
      documento: d.documento.trim(),
      calidad: d.calidad.trim(),
      esElPropioNadador: false,
    },
    otorgadoEn: FieldValue.serverTimestamp(),
    alcances: datos.alcances,
    versionDelTexto: d.versionDelTexto,
    menorFueOido: true,
    vigente: true,
    revocadoEn: null,
  };

  await db.runTransaction(async (tx) => {
    const actual = await tx.get(solicitud.ref);
    if (actual.data().canjeadaEn) throw new Error('enlace-no-sirve');

    tx.set(db.collection('consentimientos').doc(datos.nadadorId), consentimiento);
    tx.set(
      db
        .collection('consentimientos')
        .doc(datos.nadadorId)
        .collection('historial')
        .doc(solicitud.id),
      consentimiento
    );
    tx.update(solicitud.ref, { canjeadaEn: FieldValue.serverTimestamp() });
  });
}

describe('C4 — el token en claro no esta en la base de datos', () => {
  it('solo se guarda su resumen, y no permite reconstruirlo', async () => {
    const { token, ref } = await emitir();
    const guardado = (await ref.get()).data();

    const serializado = JSON.stringify(guardado);
    assert.ok(
      !serializado.includes(token),
      'Quien lea esta coleccion no puede poder fabricar un enlace valido'
    );
    assert.equal(guardado.resumenDelToken, resumirToken(token));
  });
});

describe('C2 — un solo uso', () => {
  it('el segundo canje se rechaza y queda exactamente un consentimiento', async () => {
    const { token } = await emitir();

    await canjear(token);
    await assert.rejects(() => canjear(token), /enlace-no-sirve/);

    const consentimientos = await db.collection('consentimientos').get();
    assert.equal(consentimientos.size, 1);
  });

  it('el segundo intento no revive ni altera el primero', async () => {
    const { token } = await emitir();
    await canjear(token);

    const antes = (await db.collection('consentimientos').doc('n1').get()).data();
    await assert.rejects(() => canjear(token));
    const despues = (await db.collection('consentimientos').doc('n1').get()).data();

    assert.deepEqual(antes.otorgadoPor, despues.otorgadoPor);
  });
});

describe('C3 — vence', () => {
  it('un enlace vencido no sirve aunque el token sea el bueno', async () => {
    const { token } = await emitir({ dias: -1 });
    await assert.rejects(() => canjear(token), /enlace-no-sirve/);
  });
});

describe('el rechazo no dice cual de las tres fue', () => {
  it('token inexistente, vencido y ya canjeado dan el mismo error', async () => {
    const vencido = await emitir({ dias: -1 });
    const usado = await emitir();
    await canjear(usado.token);

    const errores = [];
    for (const token of [randomBytes(32).toString('base64url'), vencido.token, usado.token]) {
      await canjear(token).catch((e) => errores.push(e.message));
    }

    assert.equal(errores.length, 3);
    assert.equal(
      new Set(errores).size,
      1,
      'Distinguirlos le diria a quien prueba enlaces cuales existieron'
    );
  });
});

describe('C7 — consta que el menor fue oido', () => {
  it('sin esa constancia no se registra', async () => {
    const { token } = await emitir();
    await assert.rejects(
      () => canjear(token, { menorFueOido: false }),
      /menor-no-oido/
    );

    const consentimientos = await db.collection('consentimientos').get();
    assert.equal(consentimientos.size, 0);
  });

  it('queda guardada en el consentimiento', async () => {
    const { token } = await emitir();
    await canjear(token);

    const guardado = (await db.collection('consentimientos').doc('n1').get()).data();
    assert.equal(guardado.menorFueOido, true);
  });
});

describe('la declaracion tiene que estar completa', () => {
  it('sin documento no se registra', async () => {
    const { token } = await emitir();
    await assert.rejects(
      () => canjear(token, { documento: '   ' }),
      /declaracion-incompleta/
    );
  });

  it('quien no declara ser representante legal no autoriza', async () => {
    const { token } = await emitir();
    await assert.rejects(
      () => canjear(token, { esRepresentanteLegal: false }),
      /no-es-representante/
    );
  });
});

describe('C5 — la fecha la pone el servidor', () => {
  it('otorgadoEn no viene del cliente', async () => {
    const { token } = await emitir();
    const antes = Date.now();
    await canjear(token);
    const despues = Date.now();

    const guardado = (await db.collection('consentimientos').doc('n1').get()).data();
    const fecha = guardado.otorgadoEn.toDate().getTime();

    assert.ok(
      fecha >= antes - 5000 && fecha <= despues + 5000,
      'La fecha de un consentimiento es un dato legal: si la pusiera el ' +
        'dispositivo, bastaria cambiar el reloj para fecharla en otro dia'
    );
  });
});

describe('C8 — revocar no borra el pasado', () => {
  it('otorgadoPor y otorgadoEn sobreviven a la revocacion', async () => {
    const { token } = await emitir();
    await canjear(token);

    const referencia = db.collection('consentimientos').doc('n1');
    const antes = (await referencia.get()).data();

    await referencia.update({
      vigente: false,
      revocadoEn: FieldValue.serverTimestamp(),
    });

    const despues = (await referencia.get()).data();
    assert.equal(despues.vigente, false);
    assert.ok(despues.revocadoEn);
    assert.deepEqual(despues.otorgadoPor, antes.otorgadoPor);
    assert.equal(
      despues.otorgadoEn.toDate().getTime(),
      antes.otorgadoEn.toDate().getTime(),
      'Ese registro es la prueba de que el tratamiento anterior estuvo amparado'
    );
  });

  it('el historial conserva el consentimiento otorgado', async () => {
    const { token } = await emitir();
    await canjear(token);

    const historial = await db
      .collection('consentimientos')
      .doc('n1')
      .collection('historial')
      .get();

    assert.equal(historial.size, 1);
    assert.equal(historial.docs[0].data().menorFueOido, true);
  });
});

describe('C6 — el alcance no se concede en bloque', () => {
  it('lo que se registra es lo que pidio la solicitud, y nada mas', async () => {
    const { token } = await emitir();
    await canjear(token);

    const guardado = (await db.collection('consentimientos').doc('n1').get()).data();
    assert.deepEqual(guardado.alcances, ['datosDeEntrenamiento']);
    assert.ok(
      !guardado.alcances.includes('video'),
      'Conceder entrenamiento no puede conceder video: el principio V exige ' +
        'que el de video sea especifico y separado'
    );
  });
});

describe('el canal es el de la solicitud', () => {
  it('el que aporto el entrenador, y el canje no lo cambia', async () => {
    const { token, ref } = await emitir({ canal: 'padre@ejemplo.test' });
    await canjear(token);

    const solicitud = (await ref.get()).data();
    assert.equal(solicitud.canal, 'padre@ejemplo.test');
    assert.ok(solicitud.canjeadaEn, 'la solicitud queda marcada como usada');
  });
});
