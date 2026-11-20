// La frontera entre entrenadores (feature 012, US3).
//
// > **Un entrenador lee a los suyos. A nadie mas, por ninguna via.**
//
// «Por ninguna via» significa lo mismo que significo en la feature 009 cuando
// se dijo de marcar una sesion: no que una pantalla esconda un boton, sino que
// **la consulta no se pueda hacer**.
//
// ## Las dos reglas de esta suite
//
// 1. **Se ejercitan las consultas que hace la app**, no `get` por id. Las
//    reglas no filtran: o la consulta se demuestra entera por sus filtros o
//    Firestore la rechaza entera. Una suite que solo lee documentos sueltos da
//    verde sobre una regla que la app no puede usar, y eso ya se pago dos veces
//    en la feature 009.
//
// 2. **Las pruebas que importan son las que PASAN.** Contra una coleccion sin
//    ninguna regla, el deny-por-defecto hace que toda negacion pase. Cada
//    negacion de aqui tiene su contraparte positiva: si el primer entrenador
//    deja de poder leer a la suya, esta suite se cae, y eso es lo que impide
//    confundir «frontera» con «no funciona nada».
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

// El entrenador de Ana.
const suyo = () =>
  entorno.authenticatedContext('e-uno', { rol: 'entrenador' }).firestore();

// El de Camila. **Este es el punto de toda la feature.**
const ajeno = () =>
  entorno.authenticatedContext('e-dos', { rol: 'entrenador' }).firestore();

const ana = () =>
  entorno.authenticatedContext('u-ana', { rol: 'nadador' }).firestore();

/// Dos comunidades, dos nadadoras, y una que no es de nadie.
async function sembrar({ anaPertenece = true } = {}) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    const db = sinReglas.firestore();

    await db.collection('usuarios').doc('u-ana').set({ nadadorId: 'n-ana' });

    await db
      .collection('comunidades')
      .doc('e-uno')
      .set({ entrenadorId: 'e-uno', nombre: 'Club Acuatico' });
    await db
      .collection('comunidades')
      .doc('e-dos')
      .set({ entrenadorId: 'e-dos', nombre: 'Escuela Ribera' });

    await db
      .collection('nadadores')
      .doc('n-ana')
      .set({
        nombre: 'Ana Maria Restrepo',
        categoria: 'precompetitivo',
        ...(anaPertenece ? { comunidadId: 'e-uno' } : {}),
      });

    await db.collection('nadadores').doc('n-camila').set({
      nombre: 'Camila Rios',
      categoria: 'precompetitivo',
      comunidadId: 'e-dos',
    });

    await db.collection('nadadores').doc('n-de-nadie').set({
      nombre: 'Valentina Ocampo',
      categoria: 'precompetitivo',
    });

    // Lo de Ana, escrito antes de que nadie la aceptara: F4 dice que se lee
    // igual despues, porque siempre fue suyo.
    await db.collection('registros').doc('n-ana|p1|s1|v1').set({
      nadadorId: 'n-ana',
      planId: 'p1',
      sesionId: 's1',
      versionDePlan: 'v1',
      realizada: true,
      registradoEn: '2026-11-10T18:00:00.000',
      rpePercibido: 7,
    });

    // El resto de lo suyo, uno por coleccion de las seis. El plan no lleva
    // dueño y eso tiene su propia prueba, al final de F2.
    await db.collection('planes').doc('p1').set({
      nombre: 'Base general',
      categoria: 'precompetitivo',
      estiloObjetivo: 'libre',
      estado: 'publicado',
      nadadoresIds: ['n-ana'],
    });

    await db.collection('asignaciones').doc('p1|n-ana').set({
      planId: 'p1',
      nadadorId: 'n-ana',
      asignadaEn: '2026-11-10T09:00:00.000',
    });

    await db.collection('macrociclos').doc('m-ana').set({
      nadadorId: 'n-ana',
      nombre: 'Temporada 2027',
      estado: 'publicado',
    });

    await db.collection('peticionesDePlan').doc('n-ana').set({
      nadadorId: 'n-ana',
      estado: 'esperando',
      respuestas: { objetivo: 'Bajar en 100 libre' },
    });

    await db.collection('peticionesDeFeedback').doc('n-ana|p1|s1').set({
      nadadorId: 'n-ana',
      planId: 'p1',
      sesionId: 's1',
      pregunta: 'El ultimo 200 me costo, ¿lo bajo?',
      pedidaEn: '2026-11-10T19:00:00.000',
    });

    await db.collection('consentimientos').doc('n-ana').set({
      estado: 'otorgado',
      alcance: ['datosDeEntrenamiento'],
      otorgadoEn: '2026-10-01T10:00:00.000',
    });
  });
}

// --- F2: la consulta se demuestra por sus filtros ------------------------

test('el suyo lee su lista de nadadores, filtrada por comunidad', async () => {
  await sembrar();

  const vistas = await assertSucceeds(
    suyo().collection('nadadores').where('comunidadId', '==', 'e-uno').get(),
  );
  assert.equal(vistas.size, 1);
  assert.equal(vistas.docs[0].id, 'n-ana');
});

test('y la coleccion entera de nadadores se le rechaza', async () => {
  // Hoy esta consulta funciona y devuelve a todo el mundo. Es una de las cinco
  // lecturas de coleccion entera que esta feature tiene que quitar.
  await sembrar();

  await assertFails(suyo().collection('nadadores').get());
});

test('el ajeno no lee la lista de la otra comunidad', async () => {
  await sembrar();

  await assertFails(
    ajeno().collection('nadadores').where('comunidadId', '==', 'e-uno').get(),
  );
});

test('el suyo lee los registros de ella, filtrados por nadadora', async () => {
  await sembrar();

  const vistos = await assertSucceeds(
    suyo().collection('registros').where('nadadorId', '==', 'n-ana').get(),
  );
  assert.equal(vistos.size, 1);
});

test('el ajeno no lee los registros de ella', async () => {
  // **La prueba que la feature 010 dejo afirmando lo contrario.**
  await sembrar();

  await assertFails(
    ajeno().collection('registros').where('nadadorId', '==', 'n-ana').get(),
  );
});

test('ni uno suelto, por su identificador', async () => {
  await sembrar();

  await assertFails(
    ajeno().collection('registros').doc('n-ana|p1|s1|v1').get(),
  );
});

test('ni la coleccion entera de registros', async () => {
  await sembrar();

  await assertFails(ajeno().collection('registros').get());
  await assertFails(suyo().collection('registros').get());
});

test('el ajeno no lee su ficha', async () => {
  await sembrar();

  await assertFails(ajeno().collection('nadadores').doc('n-ana').get());
});

test('el suyo si', async () => {
  // La contraparte positiva, y es la que sostiene el control negativo: sin
  // ella, esta suite daria verde entera sin reglas cargadas.
  await sembrar();

  await assertSucceeds(suyo().collection('nadadores').doc('n-ana').get());
});

// --- F3: antes de aceptar, nada ------------------------------------------

test('una nadadora que no es de nadie no la lee ningun entrenador', async () => {
  await sembrar();

  await assertFails(suyo().collection('nadadores').doc('n-de-nadie').get());
  await assertFails(ajeno().collection('nadadores').doc('n-de-nadie').get());
});

test('mientras la solicitud espera, el no lee nada de ella', async () => {
  // Pedir entrar no es pertenecer. Lo unico que el ve es la solicitud.
  await sembrar({ anaPertenece: false });

  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('solicitudesDeIngreso')
      .doc('n-ana|e-uno')
      .set({
        nadadorId: 'n-ana',
        comunidadId: 'e-uno',
        estado: 'esperando',
        nombre: 'Ana Maria Restrepo',
        pedidaEn: '2026-11-19T08:00:00.000',
      });
  });

  await assertFails(suyo().collection('nadadores').doc('n-ana').get());
  await assertFails(
    suyo().collection('registros').where('nadadorId', '==', 'n-ana').get(),
  );

  // Y la solicitud si, que es lo que le deja decidir.
  const enCola = await assertSucceeds(
    suyo()
      .collection('solicitudesDeIngreso')
      .where('comunidadId', '==', 'e-uno')
      .get(),
  );

  // **Y la solicitud lleva su nombre dentro, que es lo que hace que F3 y
  // FR-009 puedan ser ciertas a la vez.** Sin esto la cola le enseña «alguien»
  // y le pide decidir sobre una desconocida; con el nombre en la ficha —que es
  // donde estaba— habria que dejarle leer la ficha, y eso es justo lo que esta
  // prueba acaba de comprobar que NO puede hacer.
  assert.equal(enCola.size, 1);
  assert.equal(enCola.docs[0].data().nombre, 'Ana Maria Restrepo');
});

test('ella escribe su nombre en su solicitud, y solo en la suya', async () => {
  await sembrar({ anaPertenece: false });

  await assertSucceeds(
    ana().collection('solicitudesDeIngreso').doc('n-ana|e-uno').set({
      nadadorId: 'n-ana',
      comunidadId: 'e-uno',
      estado: 'esperando',
      nombre: 'Ana Maria Restrepo',
      pedidaEn: '2026-11-19T08:00:00.000',
    }),
  );

  // Y no la de otra persona: el nombre que viaja es el de quien pide.
  await assertFails(
    ana().collection('solicitudesDeIngreso').doc('n-camila|e-uno').set({
      nadadorId: 'n-camila',
      comunidadId: 'e-uno',
      estado: 'esperando',
      nombre: 'Camila Rios',
      pedidaEn: '2026-11-19T08:00:00.000',
    }),
  );
});

// --- F4: despues de aceptar, tambien lo de antes --------------------------

test('lo que ella escribio antes de pertenecer se lee despues', async () => {
  // El registro de arriba lleva fecha del 10 de noviembre. La pertenencia dice
  // **quien** puede leerlo, no desde cuando existe.
  await sembrar();

  const vistos = await assertSucceeds(
    suyo().collection('registros').where('nadadorId', '==', 'n-ana').get(),
  );
  assert.equal(vistos.size, 1);
  assert.equal(vistos.docs[0].data().registradoEn, '2026-11-10T18:00:00.000');
});

// --- F2 para las otras cuatro colecciones --------------------------------
//
// Las mismas dos afirmaciones en cada una: **la consulta que hace la app**, y
// la de la coleccion entera que deja de poder hacerse.

test('macrociclos: el suyo los lee acotados a los suyos; la coleccion entera no', async () => {
  await sembrar();

  const vistos = await assertSucceeds(
    suyo()
      .collection('macrociclos')
      .where('nadadorId', 'in', ['n-ana'])
      .get(),
  );
  assert.equal(vistos.size, 1);

  await assertFails(suyo().collection('macrociclos').get());
});

test('macrociclos: el ajeno no lee el de ella ni acotando', async () => {
  await sembrar();

  await assertFails(
    ajeno()
      .collection('macrociclos')
      .where('nadadorId', 'in', ['n-ana'])
      .get(),
  );
  await assertFails(ajeno().collection('macrociclos').doc('m-ana').get());
});

test('asignaciones: el suyo las lee acotadas a los suyos; la coleccion entera no', async () => {
  await sembrar();

  const vistas = await assertSucceeds(
    suyo()
      .collection('asignaciones')
      .where('nadadorId', 'in', ['n-ana'])
      .get(),
  );
  assert.equal(vistas.size, 1);

  await assertFails(suyo().collection('asignaciones').get());
});

test('asignaciones: el ajeno no lee a quien le entregaron que plan', async () => {
  // **Esto si es un hecho sobre ella**, aunque el plan no lo sea: quien
  // entrena con quien.
  await sembrar();

  await assertFails(
    ajeno()
      .collection('asignaciones')
      .where('nadadorId', 'in', ['n-ana'])
      .get(),
  );
  await assertFails(ajeno().collection('asignaciones').doc('p1|n-ana').get());
});

test('peticionesDePlan: la cola va acotada a los suyos; la coleccion entera no', async () => {
  await sembrar();

  const enCola = await assertSucceeds(
    suyo()
      .collection('peticionesDePlan')
      .where('nadadorId', 'in', ['n-ana'])
      .get(),
  );
  assert.equal(enCola.size, 1);

  await assertFails(suyo().collection('peticionesDePlan').get());
});

test('peticionesDePlan: el ajeno no lee lo que ella pidio', async () => {
  await sembrar();

  await assertFails(
    ajeno()
      .collection('peticionesDePlan')
      .where('nadadorId', 'in', ['n-ana'])
      .get(),
  );
  await assertFails(ajeno().collection('peticionesDePlan').doc('n-ana').get());
});

test('peticionesDeFeedback: el suyo lee las de ella; el ajeno no', async () => {
  await sembrar();

  const vistas = await assertSucceeds(
    suyo()
      .collection('peticionesDeFeedback')
      .where('nadadorId', '==', 'n-ana')
      .get(),
  );
  assert.equal(vistas.size, 1);

  await assertFails(
    ajeno()
      .collection('peticionesDeFeedback')
      .where('nadadorId', '==', 'n-ana')
      .get(),
  );
  await assertFails(suyo().collection('peticionesDeFeedback').get());
});

test('los planes siguen siendo de cualquier entrenador, y esto lo declara', async () => {
  // **Una limitacion declarada, no un descuido.**
  //
  // `planes` es la unica de las seis donde la frontera no se puede demostrar:
  // un plan no lleva dueño. Lleva `nadadoresIds`, que esta vacio en un
  // borrador —y un borrador es justo lo que su autor tiene que poder leer—,
  // asi que la regla no tiene por donde preguntar «de quien es esto».
  //
  // Añadirle un `entrenadorId` seria un campo nuevo sobre documentos que **ya
  // existen** en produccion, es decir una migracion; y la decision D5 de esta
  // feature dice que no se escribe codigo para una poblacion que no se puede
  // probar contra ella. Los planes de verdad si existen.
  //
  // Lo que se filtra aqui es el diseño de entrenamiento del entrenador, no un
  // dato de ella: a quien se le entrego cada plan esta en `asignaciones`, y eso
  // si queda cerrado arriba. La frontera de ella esta completa; la de el, a
  // medias, y el dia que un plan tenga autor esta prueba es la que se cae.
  await sembrar();

  await assertSucceeds(ajeno().collection('planes').doc('p1').get());
});

// --- F6: el cliente no escribe la pertenencia ----------------------------

test('el entrenador no escribe comunidadId en la ficha de nadie', async () => {
  await sembrar({ anaPertenece: false });

  await assertFails(
    suyo().collection('nadadores').doc('n-ana').update({ comunidadId: 'e-uno' }),
  );
});

test('ni ella se mete sola en una comunidad', async () => {
  await sembrar({ anaPertenece: false });

  await assertFails(
    ana().collection('nadadores').doc('n-ana').update({ comunidadId: 'e-uno' }),
  );
});

test('ni se la quita el entrenador por su cuenta', async () => {
  await sembrar();

  await assertFails(
    suyo()
      .collection('nadadores')
      .doc('n-ana')
      .update({ comunidadId: null }),
  );
});

// --- F7: terminar corta la lectura ---------------------------------------

test('sin pertenencia, deja de leerla en la consulta siguiente', async () => {
  await sembrar();
  await assertSucceeds(suyo().collection('nadadores').doc('n-ana').get());

  // Se reescribe la ficha entera sin `comunidadId` en vez de borrar el campo
  // con un centinela: el contexto de `withSecurityRulesDisabled` da un
  // Firestore del SDK de cliente, no el de admin, asi que `FieldValue.delete()`
  // de `firebase-admin` no significa nada aqui — se guardaba como un objeto y
  // la pertenencia seguia en pie, con lo que esta prueba pasaba por el motivo
  // contrario al que dice.
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas.firestore().collection('nadadores').doc('n-ana').set({
      nombre: 'Ana Maria Restrepo',
      categoria: 'precompetitivo',
    });
  });

  await assertFails(suyo().collection('nadadores').doc('n-ana').get());

  // **Y lo que ella escribio sigue estando, y sigue siendo suyo.** Es la otra
  // mitad de F7: irse de una comunidad no es borrarse. Si esto se cayera, el
  // precio de terminar una pertenencia seria su historial.
  const suyos = await assertSucceeds(
    ana().collection('registros').where('nadadorId', '==', 'n-ana').get(),
  );
  assert.equal(suyos.size, 1);
  assert.equal(suyos.docs[0].data().rpePercibido, 7);
  await assertSucceeds(ana().collection('nadadores').doc('n-ana').get());

  // Lo que el deja de leer es solo eso: lo de ella. Lo que el escribio —el
  // plan, el macrociclo— no se toca tampoco, y por el mismo motivo por el
  // otro lado.
  await assertFails(
    suyo().collection('registros').where('nadadorId', '==', 'n-ana').get(),
  );
});

// --- F8: el consentimiento y la pertenencia se componen -------------------

test('con pertenencia y sin consentimiento, lo suyo no sale igual', async () => {
  await sembrar();

  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('consentimientos')
      .doc('n-ana')
      .delete();
  });

  // Ella pertenece a su comunidad, y aun asi no puede escribir: la puerta de
  // la feature 004 sigue en pie y ninguna de las dos sustituye a la otra.
  await assertFails(
    ana().collection('registros').doc('n-ana|p1|s2|v1').set({
      nadadorId: 'n-ana',
      planId: 'p1',
      sesionId: 's2',
      versionDePlan: 'v1',
      realizada: true,
      registradoEn: '2026-11-19T18:00:00.000',
    }),
  );
});

test('ella lee lo suyo, pertenezca o no a alguien', async () => {
  // Su historial es suyo. Dejar de pertenecer no es borrarse (F7).
  await sembrar({ anaPertenece: false });

  await assertSucceeds(
    ana().collection('registros').where('nadadorId', '==', 'n-ana').get(),
  );
  await assertSucceeds(ana().collection('nadadores').doc('n-ana').get());
});
