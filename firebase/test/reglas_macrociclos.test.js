// Garantias M14, M16, M17 y la lectura del nadador — quien puede tocar un
// macrociclo (feature 009).
//
// **Las pruebas que tienen que estar aqui son las que PASAN.** La feature 008
// se llevo esta leccion por delante: su primera suite de reglas dio 18 de 24
// en verde contra una coleccion que no tenia ninguna regla, porque el
// deny-por-defecto hace que toda negacion pase. Las unicas seis que fallaron
// fueron las seis `assertSucceeds`.
//
// Asi que cada negacion de aqui tiene su contraparte positiva, y el control
// negativo de T017 apunta la suite a un nombre de coleccion sin regla para
// comprobar que las positivas se caen.
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

// El control negativo de T017 cambia esto por un nombre sin regla.
//
// Hecho el 2026-11-04 con `macrociclos_sin_regla`, y el resultado es la
// leccion de la 008 repetida con numeros: **13 de 20 pruebas pasaron contra
// una coleccion que no tenia ninguna regla.** Las unicas que fallaron fueron
// las siete `assertSucceeds`. Sin ellas, esta suite habria dado verde entera
// sin estar comprobando la regla que dice comprobar.
const COLECCION = 'macrociclos';

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

const estructura = () => ({
  modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
  modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
  bloques: [
    {
      fase: 'Acumulacion',
      desde: '2026-11-01',
      hasta: '2026-11-28',
      porQue: 'Acumulacion, las primeras 4 semanas.',
    },
  ],
  confirmadaEn: '2026-10-31T20:15:00.000',
});

const macrociclo = (extra = {}) => ({
  nadadorId: 'n-ana',
  nombre: 'Hacia el Departamental',
  estructura: estructura(),
  mesociclos: ['plan-a', 'plan-b'],
  fechaDeCompetencia: '2026-12-13',
  versionMetodologia: '3.6.0',
  estado: 'borrador',
  ...extra,
});

async function sembrarVinculos() {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    const db = sinReglas.firestore();
    await db.collection('usuarios').doc('u-ana').set({ nadadorId: 'n-ana' });
    await db.collection('usuarios').doc('u-juan').set({ nadadorId: 'n-juan' });
  });
}

async function sembrarMacrociclo(extra = {}) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo(extra));
  });
}

// --- Lo que el entrenador puede (las que importan) -----------------------

test('el entrenador crea un macrociclo en borrador', async () => {
  await assertSucceeds(
    elEntrenador().collection(COLECCION).doc('macro-1').set(macrociclo()),
  );
});

test('el entrenador edita un borrador suyo', async () => {
  await sembrarMacrociclo();
  await assertSucceeds(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo({ nombre: 'Hacia el Nacional' })),
  );
});

test('el entrenador firma el macrociclo: borrador -> aprobado', async () => {
  await sembrarMacrociclo();
  await assertSucceeds(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo({ estado: 'aprobado' })),
  );
});

test('el entrenador lo entrega: aprobado -> publicado', async () => {
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertSucceeds(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ estado: 'publicado' }),
  );
});

test('el entrenador borra un borrador', async () => {
  await sembrarMacrociclo();
  await assertSucceeds(
    elEntrenador().collection(COLECCION).doc('macro-1').delete(),
  );
});

test('el entrenador lee cualquiera, incluso en borrador', async () => {
  await sembrarMacrociclo();
  await assertSucceeds(
    elEntrenador().collection(COLECCION).doc('macro-1').get(),
  );
});

// --- Lo que el nadador puede: leer el suyo, entregado --------------------

test('el nadador lee su macrociclo entregado', async () => {
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertSucceeds(ana().collection(COLECCION).doc('macro-1').get());
});

test('el nadador NO lee su macrociclo mientras esta en borrador', async () => {
  // Un borrador no es de nadie todavia.
  await sembrarVinculos();
  await sembrarMacrociclo();
  await assertFails(ana().collection(COLECCION).doc('macro-1').get());
});

test('el nadador NO lee su macrociclo firmado pero no entregado', async () => {
  // **Firmar no es entregar** (M17). Es la distincion que la feature 001
  // establecio y que aqui sigue valiendo: aprobado no llega a nadie.
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertFails(ana().collection(COLECCION).doc('macro-1').get());
});

test('el nadador NO lee el macrociclo de otro, ni entregado', async () => {
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(juan().collection(COLECCION).doc('macro-1').get());
});

// --- Y la LISTA, que es lo que la app pide de verdad ---------------------
//
// **Las cuatro pruebas de arriba leen un documento por su identificador, y la
// app no hace eso nunca.** La pantalla del nadador no sabe el identificador
// de su macrociclo: lo busca, con una consulta sobre la coleccion. Y en
// Firestore una consulta no se evalua documento a documento. El servidor
// exige poder demostrar, *solo mirando los filtros*, que todo lo que podria
// devolver es legible. Una consulta que no repite la condicion de la regla se
// rechaza entera, aunque cada documento que fuese a devolver fuera legible.
//
// Por eso esto estaba verde y la app fallaba: el recorrido en el Pixel 7 dio
// «The caller does not have permission to execute the specified operation» en
// la primera pantalla de la nadadora, con su macrociclo entregado y bien
// guardado. La suite comprobaba una puerta por la que la app no pasa.

test('la nadadora lista su macrociclo filtrando tambien por entregado', async () => {
  // **Esta es la consulta que hace la app.** Los dos filtros: el suyo, y
  // entregado. Es la unica forma de que la regla se pueda demostrar sin abrir
  // los documentos.
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });

  await assertSucceeds(
    ana()
      .collection(COLECCION)
      .where('nadadorId', '==', 'n-ana')
      .where('estado', '==', 'publicado')
      .get(),
  );
});

test('la nadadora NO lista por nadadorId a secas', async () => {
  // El fallo tal cual estaba. Se deja escrito porque la diferencia entre esta
  // consulta y la de arriba es todo el defecto, y sin ella nadie entiende por
  // que la de arriba lleva un filtro que parece redundante.
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });

  await assertFails(
    ana().collection(COLECCION).where('nadadorId', '==', 'n-ana').get(),
  );
});

test('la nadadora NO lista los entregados de todos', async () => {
  // La otra mitad: filtrar por entregado sin decir de quien devolveria los de
  // los demas.
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });

  await assertFails(
    ana().collection(COLECCION).where('estado', '==', 'publicado').get(),
  );
});

test('el entrenador lista los de un nadador sin filtrar por estado', async () => {
  // Y el entrenador si puede, porque su rama de la regla no mira el estado:
  // tiene que ver los borradores. Si esto se cayera, el arreglo del cliente
  // habria que hacerlo tambien en su camino.
  await sembrarMacrociclo();

  await assertSucceeds(
    elEntrenador().collection(COLECCION).where('nadadorId', '==', 'n-ana').get(),
  );
});

test('el entrenador lista la coleccion entera, para saber quien tiene uno', async () => {
  // **Una sola consulta para pintar la lista de nadadores.** Preguntar ficha
  // por ficha serian N lecturas; la decision D10 de la feature 008 ya la tomo
  // para los registros y aqui vale igual. Si esto se cayera, volver a un
  // macrociclo entregado costaria una lectura por nadador.
  await sembrarMacrociclo({ estado: 'publicado' });

  await assertSucceeds(elEntrenador().collection(COLECCION).get());
});

test('la nadadora NO lista la coleccion entera', async () => {
  // La otra cara: esa consulta devolveria los macrociclos de los demas.
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });

  await assertFails(ana().collection(COLECCION).get());
});

// --- Lo que nadie puede --------------------------------------------------

test('el nadador NO crea un macrociclo, ni el suyo', async () => {
  await sembrarVinculos();
  await assertFails(
    ana().collection(COLECCION).doc('macro-2').set(macrociclo()),
  );
});

test('el nadador NO edita su macrociclo entregado', async () => {
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(
    ana()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ nombre: 'Lo que yo quiera' }),
  );
});

test('el nadador NO lo borra', async () => {
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(ana().collection(COLECCION).doc('macro-1').delete());
});

test('nadie sin sesion lee ni escribe', async () => {
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(deFuera().collection(COLECCION).doc('macro-1').get());
  await assertFails(
    deFuera().collection(COLECCION).doc('macro-2').set(macrociclo()),
  );
});

// --- El camino del estado no se salta ------------------------------------

test('un borrador NO salta directo a publicado', async () => {
  // Dejaria llegar a un nadador un macrociclo que el entrenador nunca firmo,
  // y la firma es exactamente lo que el principio IV no delega.
  await sembrarMacrociclo();
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ estado: 'publicado' }),
  );
});

test('un macrociclo nace en borrador y no aprobado', async () => {
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo({ estado: 'aprobado' })),
  );
});

test('lo firmado es inmutable: su contenido no se reescribe', async () => {
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .set(macrociclo({ estado: 'aprobado', nombre: 'Otro nombre' })),
  );
});

test('la entrega solo cambia el estado, nada mas', async () => {
  // Mandar el documento entero al entregar pasaria por alto la
  // inmutabilidad: el estado avanzaria y el contenido tambien.
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ estado: 'publicado', nombre: 'Otro nombre' }),
  );
});

test('lo entregado no se borra', async () => {
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(
    elEntrenador().collection(COLECCION).doc('macro-1').delete(),
  );
});

// --- El reajuste sobre un macrociclo entregado (M31, M32) -----------------
//
// Es la unica escritura que se permite sobre un macrociclo publicado, y solo
// cambia a que versiones apunta mas el aviso. Lo firmado sigue intacto.

const unReajuste = {
  mesociclos: ['plan-a', 'plan-c'],
  ultimoReajuste: {
    hechoEn: '2026-12-04T10:00:00.000',
    bloquesAjustados: [2],
  },
};

test('el entrenador reajusta un macrociclo entregado', async () => {
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertSucceeds(
    elEntrenador().collection(COLECCION).doc('macro-1').update(unReajuste),
  );
});

test('el reajuste NO puede tocar lo que el entrenador firmo', async () => {
  // La estructura, el nombre, la fecha o el sello de metodologia: eso es lo
  // que firmo, y sigue firmado.
  await sembrarMacrociclo({ estado: 'publicado' });

  for (const tocado of [
    { nombre: 'Otro nombre' },
    { fechaDeCompetencia: '2027-05-01' },
    { versionMetodologia: '9.9.9' },
    // Una estructura **distinta**: escribir la misma no es un cambio, y el
    // `diff` no la ve. La primera version de esta prueba reescribia la misma y
    // pasaba, con razon.
    {
      estructura: {
        ...estructura(),
        modeloDelNadador: 'Otra cosa que el no dijo.',
      },
    },
  ]) {
    await assertFails(
      elEntrenador()
        .collection(COLECCION)
        .doc('macro-1')
        .update({ ...unReajuste, ...tocado }),
    );
  }
});

test('el reajuste no mueve el estado del macrociclo', async () => {
  // Devolverlo a `aprobado` seria retroceder en el ciclo de vida.
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(
    elEntrenador()
      .collection(COLECCION)
      .doc('macro-1')
      .update({ ...unReajuste, estado: 'aprobado' }),
  );
});

test('el nadador NO reajusta su macrociclo', async () => {
  // M30: reajusta el entrenador. Ni el nadador ni la app.
  await sembrarVinculos();
  await sembrarMacrociclo({ estado: 'publicado' });
  await assertFails(
    ana().collection(COLECCION).doc('macro-1').update(unReajuste),
  );
});

test('un macrociclo sin entregar no se reajusta: se cambia y ya', async () => {
  // Lo que no ha llegado al nadador no hace falta versionarlo. Esta negacion
  // existe para que la regla del reajuste no sea una puerta de atras para
  // editar un borrador saltandose su propio camino.
  await sembrarMacrociclo({ estado: 'aprobado' });
  await assertFails(
    elEntrenador().collection(COLECCION).doc('macro-1').update(unReajuste),
  );
});

// --- M24 en el servidor: el dia de la sesion ------------------------------
//
// El cerrojo principal vive en el dominio, donde se construye el registro.
// Esto es el respaldo: que ni una peticion escrita a mano pueda registrar una
// sesion cuyo dia no ha llegado.
//
// **Con su caso positivo**, que es el que importa: una sesion pasada se
// registra. Sin el, esta seccion pasaria entera contra una regla que negara
// todo, que es la leccion de la 008 otra vez.
//
// Control negativo hecho el 2026-11-04: sustituyendo `elDiaDeLaSesionYaLlego`
// por una funcion que devuelve `true` siempre, se ponen rojas exactamente las
// tres negaciones —«pero NO la de manana», «ni la de dentro de un mes» y
// «tampoco editando uno que ya existia»— y las positivas siguen verdes. Al
// primer intento la mutacion no se aplico y el control no demostro nada: en
// `sed` basico `\(` es un grupo y no un parentesis literal, asi que el patron
// nunca encajaba y las pruebas pasaban por eso.

async function sembrarSesion({ fecha, planId = 'p1', sesionId = 's1' }) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    const db = sinReglas.firestore();
    await db.collection('usuarios').doc('u-ana').set({ nadadorId: 'n-ana' });
    await db.collection('consentimientos').doc('n-ana').set({ vigente: true });
    await db.collection('planes').doc(planId).set({ estado: 'publicado' });
    await db
      .collection('planes')
      .doc(planId)
      .collection('sesiones')
      .doc(sesionId)
      .set(fecha === null ? {} : { fecha });
  });
}

const registro = (extra = {}) => ({
  nadadorId: 'n-ana',
  planId: 'p1',
  sesionId: 's1',
  versionDePlan: '3.6.0',
  realizada: true,
  registradoEn: new Date().toISOString(),
  observaciones: '',
  ...extra,
});

const elDia = (cuantosDias) => {
  const d = new Date();
  d.setDate(d.getDate() + cuantosDias);
  return d.toISOString().split('T')[0];
};

test('el nadador registra una sesion que ya paso', async () => {
  await sembrarSesion({ fecha: elDia(-3) });
  await assertSucceeds(
    ana().collection('registros').doc('r-1').set(registro()),
  );
});

test('y la de hoy', async () => {
  // La frontera. Si la regla comparara instantes en lugar de dias, la sesion
  // de hoy fechada a las 00:00 seguiria pasando, pero la de hoy por la tarde
  // no: por eso se compara por dia.
  await sembrarSesion({ fecha: elDia(0) });
  await assertSucceeds(
    ana().collection('registros').doc('r-1').set(registro()),
  );
});

test('pero NO la de manana', async () => {
  await sembrarSesion({ fecha: elDia(1) });
  await assertFails(ana().collection('registros').doc('r-1').set(registro()));
});

test('ni la de dentro de un mes', async () => {
  await sembrarSesion({ fecha: elDia(30) });
  await assertFails(ana().collection('registros').doc('r-1').set(registro()));
});

test('tampoco editando uno que ya existia', async () => {
  // Crear y actualizar se comprueban por separado: dejar el update abierto
  // permitiria crear un registro de una sesion pasada y cambiarle el
  // `sesionId` a una futura.
  await sembrarSesion({ fecha: elDia(-3) });
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('registros')
      .doc('r-1')
      .set(registro());
  });

  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas
      .firestore()
      .collection('planes')
      .doc('p1')
      .collection('sesiones')
      .doc('s2')
      .set({ fecha: elDia(5) });
  });

  await assertFails(
    ana().collection('registros').doc('r-1').update({ sesionId: 's2' }),
  );
});

test('una sesion sin fecha en el documento no bloquea el registro', async () => {
  // **Y esto es deliberado, no un descuido.** Hoy los planes generados llegan
  // a Firestore sin sus sesiones —solo el editor las escribe, una a una—, asi
  // que exigir que el documento exista y traiga fecha dejaria a los nadadores
  // de la feature 003 sin poder registrar nada. Ese hueco es un defecto
  // aparte, anotado en el tasks.md de la 009.
  await sembrarSesion({ fecha: null });
  await assertSucceeds(
    ana().collection('registros').doc('r-1').set(registro()),
  );
});

// Un recuento, para que no pase lo de la 008: si manana alguien borra las
// positivas, esta prueba lo dice.
test('la suite tiene al menos siete pruebas que TIENEN que pasar', () => {
  const fuente = fs.readFileSync(__filename, 'utf8');
  const positivas = fuente.match(/assertSucceeds/g) || [];
  assert.ok(
    positivas.length >= 11,
    `solo hay ${positivas.length} assertSucceeds: una suite de reglas sin ` +
      'casos positivos pasa entera contra una coleccion sin regla',
  );
});
