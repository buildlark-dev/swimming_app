/**
 * Garantia F5 — aceptar es un acto suyo, y del servidor.
 *
 * > Media aceptacion es una nadadora que no pertenece a nadie y que ya no
 * > tiene solicitud que enseñar.
 *
 * Por eso escribir la pertenencia y cerrar la solicitud es **una transaccion**,
 * y por eso esto se prueba contra el emulador y no contra un doble: una
 * transaccion que no es atomica se comporta igual que una que si lo es hasta
 * el dia que falla a la mitad.
 *
 * Cada regla con su control negativo: una prueba que solo comprueba el camino
 * bueno no distingue una regla que funciona de una regla que no esta.
 *
 * Se ejecutan con:  npm --prefix firebase/functions test
 */

const assert = require('node:assert/strict');
const { after, before, beforeEach, describe, it } = require('node:test');

const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const {
  aceptarIngresoDe,
  rechazarIngresoDe,
  terminarPertenenciaDe,
} = require('../lib/comunidad');

let app;

before(() => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'Esto solo corre contra el emulador.',
  );
  app = initializeApp({ projectId: 'demo-natacion' }, 'comunidad-test');
});

after(async () => {
  if (app) await deleteApp(app);
});

const db = () => getFirestore(app);

beforeEach(async () => {
  for (const coleccion of [
    'solicitudesDeIngreso',
    'nadadores',
    'comunidades',
    'registros',
  ]) {
    const existentes = await db().collection(coleccion).get();
    await Promise.all(existentes.docs.map((d) => d.ref.delete()));
  }
});

const E_UNO = 'e-uno';
const E_DOS = 'e-dos';

async function sembrar({ estado = 'esperando', comunidadId = E_UNO } = {}) {
  await db().collection('comunidades').doc(E_UNO).set({
    entrenadorId: E_UNO,
    nombre: 'Club Acuatico',
  });
  await db().collection('comunidades').doc(E_DOS).set({
    entrenadorId: E_DOS,
    nombre: 'Escuela Ribera',
  });
  await db().collection('nadadores').doc('n-ana').set({
    nombre: 'Ana Maria Restrepo',
    categoria: 'precompetitivo',
  });
  await db()
    .collection('solicitudesDeIngreso')
    .doc(`n-ana|${comunidadId}`)
    .set({
      nadadorId: 'n-ana',
      comunidadId,
      estado,
      pedidaEn: '2026-11-19T08:00:00.000',
    });
}

const laFicha = () => db().collection('nadadores').doc('n-ana').get();
const laSolicitud = (comunidadId = E_UNO) =>
  db().collection('solicitudesDeIngreso').doc(`n-ana|${comunidadId}`).get();

describe('aceptarIngresoDe', () => {
  it('escribe la pertenencia y cierra la solicitud, las dos cosas', async () => {
    await sembrar();

    const hecho = await aceptarIngresoDe(db(), {
      entrenadorId: E_UNO,
      nadadorId: 'n-ana',
    });

    assert.equal(hecho.comunidadId, E_UNO);

    const ficha = await laFicha();
    assert.equal(ficha.data().comunidadId, E_UNO);
    assert.ok(ficha.data().miembroDesde, 'le falta desde cuando');

    const solicitud = await laSolicitud();
    assert.equal(solicitud.data().estado, 'aceptada');
    assert.ok(solicitud.data().resueltaEn, 'le falta cuando se resolvio');
  });

  it('no deja que un entrenador resuelva lo de otra comunidad', async () => {
    // **El control que da sentido a todo lo demas.** Sin esto, la frontera de
    // las reglas la saltaria una llamada de funcion.
    await sembrar();

    await assert.rejects(
      () => aceptarIngresoDe(db(), { entrenadorId: E_DOS, nadadorId: 'n-ana' }),
      /no es de tu comunidad|no existe/i,
    );

    const ficha = await laFicha();
    assert.equal(ficha.data().comunidadId, undefined);
    assert.equal((await laSolicitud()).data().estado, 'esperando');
  });

  it('resolver una que ya no espera no hace nada, y lo dice', async () => {
    await sembrar({ estado: 'retirada' });

    await assert.rejects(
      () => aceptarIngresoDe(db(), { entrenadorId: E_UNO, nadadorId: 'n-ana' }),
      /ya no est. esperando|ya estaba resuelta/i,
    );

    // Y sobre todo: **no la pisa**. Una retirada que vuelve a «aceptada»
    // seria meter en el grupo a quien se arrepintio.
    assert.equal((await laSolicitud()).data().estado, 'retirada');
    assert.equal((await laFicha()).data().comunidadId, undefined);
  });

  it('una solicitud que no existe no crea una pertenencia', async () => {
    await sembrar();

    await assert.rejects(
      () =>
        aceptarIngresoDe(db(), { entrenadorId: E_UNO, nadadorId: 'n-nadie' }),
      /no existe/i,
    );
  });

  it('no mete a alguien que ya es de otra comunidad', async () => {
    // Una nadadora pertenece a una comunidad o a ninguna (research D1). Si ya
    // es de otro, aceptarla aqui seria sacarla de alli sin que nadie lo diga.
    await sembrar();
    await db()
      .collection('nadadores')
      .doc('n-ana')
      .set({ comunidadId: E_DOS }, { merge: true });

    await assert.rejects(
      () => aceptarIngresoDe(db(), { entrenadorId: E_UNO, nadadorId: 'n-ana' }),
      /ya es de otra comunidad/i,
    );

    assert.equal((await laFicha()).data().comunidadId, E_DOS);
  });
});

describe('rechazarIngresoDe', () => {
  it('cierra la solicitud y no toca la ficha', async () => {
    await sembrar();

    const hecho = await rechazarIngresoDe(db(), {
      entrenadorId: E_UNO,
      nadadorId: 'n-ana',
    });

    assert.equal(hecho.estado, 'rechazada');
    assert.equal((await laSolicitud()).data().estado, 'rechazada');
    assert.equal((await laFicha()).data().comunidadId, undefined);
  });

  it('no lleva motivo escrito, aunque se lo manden', async () => {
    // **No se le debe una explicacion a quien todavia no es su nadadora**, y
    // un texto libre viajando hasta una desconocida es un problema sin ninguna
    // ventaja (FR-011). Que la pantalla no lo pida no basta: esto es lo que
    // aguanta cuando alguien llama la funcion a mano.
    await sembrar();

    await rechazarIngresoDe(db(), {
      entrenadorId: E_UNO,
      nadadorId: 'n-ana',
      motivo: 'no me cae bien',
    });

    const guardada = (await laSolicitud()).data();
    assert.equal(
      JSON.stringify(guardada).includes('no me cae bien'),
      false,
      'el motivo se guardo, y no deberia existir ningun sitio donde quepa',
    );
  });

  it('rechazar no le impide volver a pedir', async () => {
    // FR-012. Un rechazo es una respuesta, no una prohibicion.
    await sembrar();
    await rechazarIngresoDe(db(), {
      entrenadorId: E_UNO,
      nadadorId: 'n-ana',
    });

    // Ella vuelve a pedir: el identificador es determinista, asi que es el
    // mismo documento volviendo a «esperando».
    await db()
      .collection('solicitudesDeIngreso')
      .doc(`n-ana|${E_UNO}`)
      .set({ estado: 'esperando', resueltaEn: null }, { merge: true });

    const hecho = await aceptarIngresoDe(db(), {
      entrenadorId: E_UNO,
      nadadorId: 'n-ana',
    });
    assert.equal(hecho.comunidadId, E_UNO);
  });

  it('tampoco el ajeno rechaza lo que no es suyo', async () => {
    await sembrar();

    await assert.rejects(
      () => rechazarIngresoDe(db(), { entrenadorId: E_DOS, nadadorId: 'n-ana' }),
      /no es de tu comunidad|no existe/i,
    );

    assert.equal((await laSolicitud()).data().estado, 'esperando');
  });
});

describe('terminarPertenenciaDe', () => {
  /// Deja a n-ana dentro, con algo escrito suyo que no se puede perder.
  async function dentro() {
    await sembrar();
    await aceptarIngresoDe(db(), { entrenadorId: E_UNO, nadadorId: 'n-ana' });
    await db().collection('registros').doc('n-ana|p1|s1|v1').set({
      nadadorId: 'n-ana',
      planId: 'p1',
      sesionId: 's1',
      versionDePlan: 'v1',
      realizada: true,
      registradoEn: '2026-11-10T18:00:00.000',
      rpePercibido: 7,
      observaciones: 'Me costo el ultimo 200',
    });
  }

  it('quita la pertenencia, y SOLO la pertenencia', async () => {
    // **Garantia F7, y es la mitad que importa.** Irse de una comunidad no es
    // borrarse: lo que se quita es el campo que dice quien puede leerla, y
    // nada de lo que ella escribio se toca.
    await dentro();

    await terminarPertenenciaDe(db(), {
      nadadorId: 'n-ana',
      comunidadId: E_UNO,
    });

    const ficha = (await laFicha()).data();
    assert.equal(ficha.comunidadId, undefined);
    assert.equal(ficha.miembroDesde, undefined);

    // Lo suyo, intacto, campo por campo.
    assert.equal(ficha.nombre, 'Ana Maria Restrepo');
    assert.equal(ficha.categoria, 'precompetitivo');

    const registro = await db()
      .collection('registros')
      .doc('n-ana|p1|s1|v1')
      .get();
    assert.equal(registro.exists, true, 'le borraron lo que escribio');
    assert.equal(registro.data().rpePercibido, 7);
    assert.equal(registro.data().observaciones, 'Me costo el ultimo 200');
  });

  it('y le deja constancia de cuando dejo de pertenecer', async () => {
    // FR-026: que se entere sin tener que preguntarle a nadie. Es un dato
    // sobre su cuenta y no sobre el entrenador: no dice quien ni por que.
    await dentro();

    await terminarPertenenciaDe(db(), {
      nadadorId: 'n-ana',
      comunidadId: E_UNO,
    });

    assert.ok((await laFicha()).data().pertenenciaTerminadaEn);
  });

  it('un entrenador no saca a quien no es suya', async () => {
    await dentro();

    await assert.rejects(
      () =>
        terminarPertenenciaDe(db(), {
          nadadorId: 'n-ana',
          comunidadId: E_DOS,
        }),
      /no pertenece a esa comunidad/i,
    );

    assert.equal((await laFicha()).data().comunidadId, E_UNO);
  });

  it('nadie sale de una comunidad a la que no pertenece', async () => {
    // La otra cara de la misma comprobacion, y con el mismo mensaje: el
    // entrenador no es suyo, o ella no esta en esa comunidad.
    await sembrar();

    await assert.rejects(
      () =>
        terminarPertenenciaDe(db(), {
          nadadorId: 'n-ana',
          comunidadId: E_UNO,
        }),
      /no pertenece a esa comunidad/i,
    );
  });

  it('salir dos veces no revienta la segunda de otra manera', async () => {
    await dentro();
    await terminarPertenenciaDe(db(), {
      nadadorId: 'n-ana',
      comunidadId: E_UNO,
    });

    await assert.rejects(
      () =>
        terminarPertenenciaDe(db(), {
          nadadorId: 'n-ana',
          comunidadId: E_UNO,
        }),
      /no pertenece a esa comunidad/i,
    );
  });

  it('y despues puede volver a pedir entrar donde sea', async () => {
    // Terminar no es una prohibicion. Es la misma promesa que FR-012 hace
    // sobre un rechazo, por el otro lado.
    await dentro();
    await terminarPertenenciaDe(db(), {
      nadadorId: 'n-ana',
      comunidadId: E_UNO,
    });

    await db()
      .collection('solicitudesDeIngreso')
      .doc(`n-ana|${E_UNO}`)
      .set({ estado: 'esperando', resueltaEn: null }, { merge: true });

    const hecho = await aceptarIngresoDe(db(), {
      entrenadorId: E_UNO,
      nadadorId: 'n-ana',
    });
    assert.equal(hecho.comunidadId, E_UNO);
  });
});

/// FR-028 — el acudiente sabe a que comunidad pidio entrar.
///
/// **Es estrictamente mas informacion para quien decide**, y no cambia nada de
/// lo que el consentimiento permite: autorizar que se guarden sus datos de
/// entrenamiento es lo mismo con nombre que sin el. Pero un acudiente que lee
/// «se registro en una app» y uno que lee el nombre del club no estan
/// decidiendo con lo mismo delante.
describe('nombreDeSuComunidad', () => {
  const { nombreDeSuComunidad } = require('../lib/consentimiento');

  it('da el nombre de donde ya pertenece', async () => {
    await sembrar();
    await aceptarIngresoDe(db(), { entrenadorId: E_UNO, nadadorId: 'n-ana' });

    assert.equal(await nombreDeSuComunidad(db(), 'n-ana'), 'Club Acuatico');
  });

  it('y si solo lo pidio, el de donde lo pidio', async () => {
    await sembrar();

    assert.equal(await nombreDeSuComunidad(db(), 'n-ana'), 'Club Acuatico');
  });

  it('la pertenencia manda sobre la solicitud', async () => {
    // Si ya pertenece, ahi es donde esta, diga lo que diga una solicitud
    // vieja. Es el orden de la verdad, no una preferencia.
    await sembrar();
    await db().collection('nadadores').doc('n-ana').set(
      { comunidadId: E_DOS },
      { merge: true },
    );

    assert.equal(await nombreDeSuComunidad(db(), 'n-ana'), 'Escuela Ribera');
  });

  it('sin comunidad ni solicitud, nulo', async () => {
    await sembrar({ comunidadId: E_DOS });
    await db()
      .collection('solicitudesDeIngreso')
      .doc(`n-ana|${E_DOS}`)
      .delete();

    assert.equal(await nombreDeSuComunidad(db(), 'n-ana'), null);
  });

  it('una solicitud ya resuelta no cuenta', async () => {
    // Un rechazo no es un sitio donde este. Nombrarlo en el correo del
    // acudiente diria algo que no es verdad.
    await sembrar({ estado: 'rechazada' });

    assert.equal(await nombreDeSuComunidad(db(), 'n-ana'), null);
  });

  it('NUNCA se inventa un nombre', async () => {
    // **Lo que hace util a esta funcion es lo que no hace.** Esto va en un
    // correo que pide autorizar el tratamiento de los datos de una menor: un
    // nombre adivinado ahi es peor que ningun nombre.
    await sembrar();
    await db().collection('comunidades').doc(E_UNO).set({
      entrenadorId: E_UNO,
      nombre: '   ',
    });

    assert.equal(await nombreDeSuComunidad(db(), 'n-ana'), null);
  });
});
