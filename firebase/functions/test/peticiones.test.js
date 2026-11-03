/**
 * Garantia P38 — el servidor cierra la peticion, y nadie mas.
 *
 * Contra el emulador, con la funcion ya compilada en `../lib`. Cada regla con
 * su control negativo: una prueba que solo comprueba el camino bueno no
 * distingue una regla que funciona de una regla que no esta.
 *
 * Se ejecutan con:  npm --prefix firebase/functions test
 */

const assert = require('node:assert/strict');
const { after, before, beforeEach, describe, it } = require('node:test');

const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const { cerrarPeticionDe } = require('../lib/peticiones');

let app;

before(() => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'Esto solo corre contra el emulador.',
  );
  app = initializeApp({ projectId: 'demo-natacion' }, 'peticiones-test');
});

after(async () => {
  if (app) await deleteApp(app);
});

const db = () => getFirestore(app);

beforeEach(async () => {
  // **Borrar el documento NO borra su subcoleccion.** En Firestore el
  // `historial` sobrevive a la peticion de la que colgaba, asi que limpiarlo
  // a mano es lo unico que deja cada prueba empezando de cero.
  //
  // Lo descubrio esta misma prueba contando nueve entradas donde esperaba
  // una, y vale para algo mas que las pruebas: es la razon de que la supresion
  // de datos borre el historial explicitamente antes que la peticion.
  const existentes = await db().collection('peticionesDePlan').get();

  for (const documento of existentes.docs) {
    const historial = await documento.ref.collection('historial').get();
    await Promise.all(historial.docs.map((h) => h.ref.delete()));
    await documento.ref.delete();
  }
});

async function sembrar(nadadorId = 'n-ana', estado = 'enRevision') {
  await db().collection('peticionesDePlan').doc(nadadorId).set({
    nadadorId,
    estado,
    respuestas: {
      estiloObjetivo: 'Libre',
      pruebaObjetivo: '200 Libre',
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    },
  });
}

describe('cerrarPeticionDe', () => {
  it('aprueba, estampa la fecha y senala al plan', async () => {
    await sembrar();

    const cierre = await cerrarPeticionDe(db(), {
      nadadorId: 'n-ana',
      decision: 'aprobada',
      planId: 'p-1',
    });

    assert.equal(cierre.estado, 'aprobada');
    assert.ok(cierre.respondidaEn, 'La fecha la pone el servidor');

    const guardada = (
      await db().collection('peticionesDePlan').doc('n-ana').get()
    ).data();
    assert.equal(guardada.estado, 'aprobada');
    assert.equal(guardada.planId, 'p-1');
    assert.equal(guardada.motivoDelRechazo, null);
    assert.ok(guardada.respondidaEn, 'La fecha se escribe, no solo se devuelve');
  });

  it('rechaza con el motivo tal como se escribio', async () => {
    await sembrar();

    const loQueEscribio =
      'Pediste cinco dias y en Precompetitivo son tres. Te armo uno de tres.';

    await cerrarPeticionDe(db(), {
      nadadorId: 'n-ana',
      decision: 'rechazada',
      motivo: loQueEscribio,
    });

    const guardada = (
      await db().collection('peticionesDePlan').doc('n-ana').get()
    ).data();
    assert.equal(guardada.estado, 'rechazada');
    assert.equal(guardada.motivoDelRechazo, loQueEscribio);
    assert.equal(guardada.planId, null);
  });

  it('**un rechazo sin motivo se rechaza**', async () => {
    // Tercera capa de la misma regla: la pantalla, el tipo del dominio y
    // aqui. Es la que aguanta cuando las dos primeras se saltan.
    await sembrar();

    await assert.rejects(
      cerrarPeticionDe(db(), { nadadorId: 'n-ana', decision: 'rechazada' }),
      /motivo/i,
    );

    const sinTocar = (
      await db().collection('peticionesDePlan').doc('n-ana').get()
    ).data();
    assert.equal(sinTocar.estado, 'enRevision', 'No se cerro a medias');
  });

  it('un motivo en blanco tampoco cuenta', async () => {
    await sembrar();

    await assert.rejects(
      cerrarPeticionDe(db(), {
        nadadorId: 'n-ana',
        decision: 'rechazada',
        motivo: '   ',
      }),
      /motivo/i,
    );
  });

  it('**aprobar sin plan se rechaza**: seria firmar sobre nada', async () => {
    await sembrar();

    await assert.rejects(
      cerrarPeticionDe(db(), { nadadorId: 'n-ana', decision: 'aprobada' }),
      /plan/i,
    );
  });

  it('una decision que no existe se rechaza', async () => {
    // «aprobado» en masculino, o «approved». Si pasara, la peticion se
    // quedaria abierta para siempre sin que nadie se enterara.
    await sembrar();

    for (const inventada of ['aprobado', 'approved', 'APROBADA', '']) {
      await assert.rejects(
        cerrarPeticionDe(db(), {
          nadadorId: 'n-ana',
          decision: inventada,
          planId: 'p-1',
        }),
        /decisión|decision/i,
      );
    }
  });

  it('una peticion que no existe se rechaza', async () => {
    await assert.rejects(
      cerrarPeticionDe(db(), {
        nadadorId: 'n-fantasma',
        decision: 'aprobada',
        planId: 'p-1',
      }),
      /existe/i,
    );
  });

  it('sin nadadorId se rechaza', async () => {
    await assert.rejects(
      cerrarPeticionDe(db(), { nadadorId: '  ', decision: 'aprobada', planId: 'p-1' }),
      /petición|peticion/i,
    );
  });
});

describe('el archivo', () => {
  it('la respondida queda en el historial', async () => {
    await sembrar();

    const cierre = await cerrarPeticionDe(db(), {
      nadadorId: 'n-ana',
      decision: 'rechazada',
      motivo: 'Esta semana no.',
    });

    const historial = await db()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .collection('historial')
      .get();

    assert.equal(historial.size, 1);
    assert.equal(historial.docs[0].data().motivoDelRechazo, 'Esta semana no.');
    assert.ok(
      cierre.archivadaEn.includes('historial'),
      'El cierre dice donde quedo archivada',
    );
  });

  it('dos peticiones seguidas dejan dos entradas', async () => {
    // El nadador pide, le responden, vuelve a pedir. Lo anterior no se pisa:
    // el motivo que le escribieron la primera vez sigue ahi.
    await sembrar();
    await cerrarPeticionDe(db(), {
      nadadorId: 'n-ana',
      decision: 'rechazada',
      motivo: 'La primera vez.',
    });

    await sembrar();
    await cerrarPeticionDe(db(), {
      nadadorId: 'n-ana',
      decision: 'rechazada',
      motivo: 'La segunda vez.',
    });

    const historial = await db()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .collection('historial')
      .get();

    assert.equal(historial.size, 2);
  });

  it('se archiva antes de cerrar, no despues', async () => {
    // Si se cerrara primero y el archivado fallara, quedaria una peticion
    // respondida sin rastro de lo que se respondio.
    await sembrar();

    await cerrarPeticionDe(db(), {
      nadadorId: 'n-ana',
      decision: 'aprobada',
      planId: 'p-1',
    });

    const historial = await db()
      .collection('peticionesDePlan')
      .doc('n-ana')
      .collection('historial')
      .get();

    assert.equal(historial.size, 1, 'Lo aprobado tambien se archiva');
    assert.equal(historial.docs[0].data().planId, 'p-1');
  });
});
