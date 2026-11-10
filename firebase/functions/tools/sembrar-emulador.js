/**
 * Siembra el emulador para poder verificar el HUB con datos de verdad.
 *
 * Solo contra los emuladores: exige FIRESTORE_EMULATOR_HOST.
 */

const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

assert.ok(
  process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST,
  'Esto solo corre contra los emuladores.'
);

const app = initializeApp({ projectId: 'demo-natacion' });
const db = getFirestore(app);
const auth = getAuth(app);

/// Pone el rol y **comprueba que se quedó puesto, y que sigue puesto**.
///
/// El disparador `alCrearseUnaCuenta` escribe el rol por omisión cuando la
/// cuenta se crea, y corre cuando el emulador de Functions lo despacha: puede
/// aterrizar después de esta escritura y pisarla. Suponer que ya corrió es
/// justo lo que fallaba.
///
/// **Y leer una vez tampoco basta.** La primera versión de esto escribía,
/// esperaba 300 ms, releía, y se daba por satisfecha en cuanto veía el rol
/// correcto. Pasó la siembra entera en verde y, un minuto después, el
/// entrenador entraba a la app como nadador: el disparador había aterrizado
/// fuera de esa ventana de tres segundos. Una comprobación que solo mira el
/// instante siguiente a la escritura no comprueba que la escritura ganó; mira
/// que nadie había llegado todavía.
///
/// Así que se exige **estabilidad**: varias lecturas seguidas, repartidas en
/// una ventana bastante más ancha que lo que tarda el emulador de Functions en
/// despachar. Si en cualquiera de ellas aparece otro rol, se vuelve a escribir
/// y el contador de lecturas estables empieza de cero.
async function fijarElRol(uid, rol, { lecturasEstables = 5, cada = 1000 } = {}) {
  const limite = Date.now() + 60_000;
  let estables = 0;

  await auth.setCustomUserClaims(uid, { rol });

  while (Date.now() < limite) {
    await new Promise((listo) => setTimeout(listo, cada));
    const { customClaims } = await auth.getUser(uid);

    if (customClaims && customClaims.rol === rol) {
      if (++estables >= lecturasEstables) return;
      continue;
    }

    // Alguien lo pisó. Se reescribe y la cuenta vuelve a empezar: lo que
    // importa es que la última palabra sea la nuestra.
    estables = 0;
    await auth.setCustomUserClaims(uid, { rol });
  }

  throw new Error(
    `No se pudo dejar el rol "${rol}" en ${uid}: algo lo sobrescribe. ` +
      'Sin esto la semilla miente y el recorrido se para en la primera pantalla.'
  );
}

const CORREO = process.argv[2] ?? 'entrenador.verifica@ejemplo.test';
const CLAVE = process.argv[3] ?? 'clave-de-prueba-007';

async function main() {
  // 1. La cuenta del entrenador, con su clave conocida y su rol.
  let usuario;
  try {
    usuario = await auth.getUserByEmail(CORREO);
    await auth.updateUser(usuario.uid, { password: CLAVE });
  } catch (_) {
    usuario = await auth.createUser({ email: CORREO, password: CLAVE });
  }
  await auth.setCustomUserClaims(usuario.uid, { rol: 'entrenador' });

  // 2. Su perfil, para que la puerta del alta no se lo pida.
  await db.collection('usuarios').doc(usuario.uid).set({
    nombre: 'Entrenador de prueba',
    fechaNacimiento: '1988-06-15',
    pais: 'CO',
    terminos: { version: 'v1', aceptadaEn: FieldValue.serverTimestamp() },
    perfilCompletadoEn: FieldValue.serverTimestamp(),
  });

  // 3. Dos nadadores suyos, con consentimiento vigente.
  const nadadores = [
    { id: 'n-ana', nombre: 'Ana María Restrepo' },
    { id: 'n-juan', nombre: 'Juan Esteban Restrepo' },
  ];
  for (const nadador of nadadores) {
    await db.collection('nadadores').doc(nadador.id).set({
      nombre: nadador.nombre,
      fechaNacimiento: '2012-05-20',
      categoria: 'precompetitivo',
      estiloObjetivo: 'libre',
      pruebaObjetivo: '800 Libre',
      // Observaciones del entrenador, que es lo unico de lo que la app puede
      // pre-rellenar los dos modelos del macrociclo (feature 009, M4). Sin
      // esto, C3 del quickstart mide un campo vacio: no se ve la diferencia
      // entre «no habia nada que ofrecer» y «la app no ofrece nada».
      diagnosticoTecnico: [
        'pierde el agarre al fatigarse',
        'respiracion tardia en el segundo 50',
      ],
      marcas: [
        {
          distancia: 800,
          estilo: 'libre',
          tiempoMilisegundos: 11 * 60 * 1000 + 42 * 1000,
          fecha: '2026-09-12',
        },
      ],
    });
    // La fecha como **marca de tiempo**, que es lo que escribe el servidor.
    // Con texto, la app se comía un `TypeError` al leerla y `Ajustes` de un
    // nadador se quedaba girando. Ya no se rompe —eso se arregló donde tocaba,
    // en la lectura—, pero sembrar con otra forma que la de producción es
    // sembrar otra cosa, y entonces probar aquí no prueba lo de allá.
    const consentimiento = {
      nadadorId: nadador.id,
      vigente: true,
      alcances: ['datosDeEntrenamiento'],
      versionDelTexto: 'v1',
      otorgadoEn: FieldValue.serverTimestamp(),
    };
    await db.collection('consentimientos').doc(nadador.id).set(consentimiento);

    // **Y su constancia.** El historial es lo único que sobrevive a una
    // supresión (garantía C8), así que sin sembrarlo no se puede comprobar
    // que sobrevive: se vería una subcolección vacía antes y después, que no
    // prueba nada.
    await db
      .collection('consentimientos')
      .doc(nadador.id)
      .collection('historial')
      .doc('sembrado')
      .set(consentimiento);
  }

  // 3.b La cuenta de Ana, para poder recorrer la supresión de un nadador:
  //     tiene ficha, asignación y una respuesta suya. La del entrenador no
  //     toca ninguna de esas ramas.
  const CORREO_NADADORA = 'nadadora.verifica@ejemplo.test';
  let laNadadora;
  try {
    laNadadora = await auth.getUserByEmail(CORREO_NADADORA);
    await auth.updateUser(laNadadora.uid, { password: CLAVE });
  } catch (_) {
    laNadadora = await auth.createUser({
      email: CORREO_NADADORA,
      password: CLAVE,
    });
  }
  await auth.setCustomUserClaims(laNadadora.uid, { rol: 'nadador' });
  await db.collection('usuarios').doc(laNadadora.uid).set({
    nadadorId: 'n-ana',
    nombre: 'Ana María Restrepo',
    fechaNacimiento: '2012-05-20',
    pais: 'CO',
    terminos: { version: 'v1', aceptadaEn: FieldValue.serverTimestamp() },
    perfilCompletadoEn: FieldValue.serverTimestamp(),
  });

  // 4. Planes en los tres estados, para que los cuatro números digan algo.
  const sesion = (id, dias) => ({
    id,
    microcicloId: 'm1',
    fecha: new Date(Date.now() + dias * 86400000).toISOString(),
    objetivoTecnico: 'Técnica de eficiencia en Libre',
    objetivoFisiologico: 'Base aeróbica con énfasis en economía de nado',
    partes: [
      { tipo: 'inicial', textoOriginal: "4x100 AL / 2'", series: [] },
      { tipo: 'central', textoOriginal: '8x50 Libre', series: [] },
      { tipo: 'cierre', textoOriginal: '', series: [] },
    ],
  });

  const plan = (id, nombre, estado) => ({
    nombre,
    categoria: 'precompetitivo',
    estiloObjetivo: 'libre',
    pruebaObjetivo: '800 Libre',
    longitudPiscina: 25,
    faseAtr: 'acumulacion',
    estado,
    origen: 'generado',
    versionMetodologia: '3.6.0',
    microciclos: [
      { id: 'm1', nombre: 'Semana 1', orden: 1, objetivo: 'Economía de nado' },
    ],
    justificaciones: [],
  });

  const planes = [
    ['p-publicado', 'Microciclo de base aeróbica', 'publicado'],
    ['p-publicado-2', 'Microciclo de transferencia', 'publicado'],
    ['p-aprobado', 'Microciclo precompetitivo', 'aprobado'],
    ['p-borrador', 'Microciclo de acumulación', 'borrador'],
  ];

  for (const [id, nombre, estado] of planes) {
    await db.collection('planes').doc(id).set(plan(id, nombre, estado));
    for (let i = 0; i < 3; i++) {
      await db
        .collection('planes')
        .doc(id)
        .collection('sesiones')
        .doc(`s${i}`)
        .set(sesion(`s${i}`, i));
    }
  }

  // 5. Entregas: uno a cada nadador, y uno sin entregar.
  await db.collection('asignaciones').doc('p-publicado|n-ana').set({
    planId: 'p-publicado',
    nadadorId: 'n-ana',
    asignadaEn: new Date().toISOString(),
  });
  await db.collection('asignaciones').doc('p-publicado-2|n-juan').set({
    planId: 'p-publicado-2',
    nadadorId: 'n-juan',
    asignadaEn: new Date().toISOString(),
  });

  // 6. **Solo Ana ha respondido.** Así «en uso» tiene que dar 1 y no 2: es la
  //    definición que la feature 007 fijó y lo que conviene ver en pantalla.
  await db.collection('registros').doc('r-ana-1').set({
    id: 'r-ana-1',
    nadadorId: 'n-ana',
    planId: 'p-publicado',
    sesionId: 's0',
    versionDePlan: '3.6.0',
    realizada: true,
    rpePercibido: 6,
    observaciones: 'Sentí bien el ritmo en los 50.',
    registradoEn: new Date().toISOString(),
  });

  // 6. Lo que la feature 008 necesita para poder recorrer su quickstart.
  //
  // Nada de esto se puede montar a mano con la app delante: hacen falta un
  // nadador **sin consentimiento vigente** —que la app, bien hecha, impide
  // crear—, uno en una categoría **sin ATR**, y fechas de competencia justo
  // en los días frontera de la derivación.
  await sembrarParaPeticiones();

  // **El rol se vuelve a poner al final, y no es redundante.** El disparador
  // `alCrearseUnaCuenta` corre cuando la cuenta se crea y escribe el rol por
  // omisión, así que pisa el que se asignó arriba: el entrenador entraba como
  // nadador y no había manera de ver su recorrido.
  //
  // Antes esto se ponía una vez y el comentario decía «al final ya ha
  // corrido». **No siempre.** El disparador vive en el emulador de Functions
  // y es asíncrono: el 2026-11-06 aterrizó después de que la semilla
  // terminara, el entrenador entró como nadador, y el recorrido se paró en la
  // primera pantalla. La semilla decía que lo había dejado listo y no era
  // verdad.
  //
  // Así que ahora **se comprueba en lugar de suponerse**: se escribe, se
  // relee, y si el disparador lo pisó se vuelve a escribir. Es la diferencia
  // entre esperar a que haya corrido y saber que ya corrió.
  await fijarElRol(usuario.uid, 'entrenador');
  await fijarElRol(laNadadora.uid, 'nadador');

  console.log(`Entrenador: ${CORREO} / ${CLAVE}  (uid ${usuario.uid})`);
  console.log(
    `Nadadora:   ${CORREO_NADADORA} / ${CLAVE}  (uid ${laNadadora.uid}, ficha n-ana)`
  );
  console.log('Planes: 4 (2 publicados, 1 aprobado, 1 borrador)');
  console.log('En uso esperado: 1 — solo Ana ha respondido algo');
}

main().then(() => process.exit(0));

/**
 * Lo que hace falta para recorrer el quickstart de la feature 008.
 *
 * Son tres cosas que **no se pueden preparar desde la app**, y por eso viven
 * aquí:
 *
 * - Un nadador **sin consentimiento vigente**. La app, bien hecha, no deja
 *   crear uno: el alta pide el consentimiento. Sin él no se puede comprobar
 *   que su petición se queda en el teléfono (C12).
 * - Un nadador en una categoría **sin ATR**, para ver que su borrador no lleva
 *   fase y que la app lo dice en lugar de dejar el hueco (C9).
 * - Tres peticiones con la competencia a **15, 16 y 44 días**, que son los
 *   días frontera de la derivación (C8). A mano, esas fechas se calculan mal.
 */
async function sembrarParaPeticiones() {
  const CLAVE_COMUN = CLAVE;

  async function cuentaDe(correo, nadadorId, nombreVisible, rol = 'nadador') {
    let cuenta;
    try {
      cuenta = await auth.getUserByEmail(correo);
      await auth.updateUser(cuenta.uid, { password: CLAVE_COMUN });
    } catch (_) {
      cuenta = await auth.createUser({ email: correo, password: CLAVE_COMUN });
    }
    await fijarElRol(cuenta.uid, rol);
    await db.collection('usuarios').doc(cuenta.uid).set({
      nadadorId,
      // **El perfil completo**, o la puerta del alta los manda a rellenarlo y
      // nunca llegan a `Generar`. Lo vio el recorrido del quickstart: la
      // siembra escribía el identificador como nombre y sin fecha.
      nombre: nombreVisible,
      fechaNacimiento: '2015-03-11',
      pais: 'CO',
      terminos: { version: 'v1', aceptadaEn: FieldValue.serverTimestamp() },
      perfilCompletadoEn: FieldValue.serverTimestamp(),
    });
    return cuenta;
  }

  // --- Sin consentimiento vigente (C12) ---------------------------------
  await db.collection('nadadores').doc('n-sin-permiso').set({
    nombre: 'Samuel Ríos',
    fechaNacimiento: '2015-03-11',
    categoria: 'precompetitivo',
    estiloObjetivo: 'libre',
    pruebaObjetivo: '100 Libre',
  });
  // **A propósito no se le siembra consentimiento.** La ausencia es el dato.
  await db.collection('consentimientos').doc('n-sin-permiso').delete();
  const sinPermiso = await cuentaDe(
    'nadador.sinpermiso@ejemplo.test',
    'n-sin-permiso',
    'Samuel Ríos',
  );

  // --- Categoría sin ATR (C9) -------------------------------------------
  await db.collection('nadadores').doc('n-inicia').set({
    nombre: 'Lucía Mesa',
    fechaNacimiento: '2018-09-02',
    categoria: 'iniciacion',
    estiloObjetivo: 'libre',
    pruebaObjetivo: '50 Libre',
  });
  await db.collection('consentimientos').doc('n-inicia').set({
    nadadorId: 'n-inicia',
    vigente: true,
    alcances: ['datosDeEntrenamiento'],
    versionDelTexto: 'v1',
    otorgadoEn: FieldValue.serverTimestamp(),
  });
  const inicia = await cuentaDe(
    'nadadora.inicia@ejemplo.test',
    'n-inicia',
    'Lucía Mesa',
  );

  // --- Los días frontera (C8) -------------------------------------------
  //
  // 15 → Realización, 16 → Transformación, 44 → Acumulación. Son las tres
  // fronteras que la derivación tiene que acertar; lo de en medio se deduce.
  const enDias = (dias) => {
    const cuando = new Date();
    cuando.setDate(cuando.getDate() + dias);
    return cuando.toISOString();
  };

  const fronteras = [
    { id: 'n-frontera-15', nombre: 'Frontera 15 días', dias: 15 },
    { id: 'n-frontera-16', nombre: 'Frontera 16 días', dias: 16 },
    { id: 'n-frontera-44', nombre: 'Frontera 44 días', dias: 44 },
  ];

  for (const quien of fronteras) {
    await db.collection('nadadores').doc(quien.id).set({
      nombre: quien.nombre,
      fechaNacimiento: '2011-01-15',
      categoria: 'precompetitivo',
      estiloObjetivo: 'libre',
      pruebaObjetivo: '200 Libre',
    });
    await db.collection('consentimientos').doc(quien.id).set({
      nadadorId: quien.id,
      vigente: true,
      alcances: ['datosDeEntrenamiento'],
      versionDelTexto: 'v1',
      otorgadoEn: FieldValue.serverTimestamp(),
    });

    // La petición ya mandada, para que la cola tenga las tres esperando.
    await db.collection('peticionesDePlan').doc(quien.id).set({
      nadadorId: quien.id,
      estado: 'esperando',
      enviadaEn: FieldValue.serverTimestamp(),
      respuestas: {
        estiloObjetivo: 'Libre',
        pruebaObjetivo: '200 Libre',
        fechaDeCompetencia: enDias(quien.dias),
        diasDisponibles: [enDias(1), enDias(3), enDias(5)],
        duracionSesionMinutos: 90,
        longitudPiscina: 25,
      },
    });
  }

  // --- Una molestia reciente de Ana, para C12 ----------------------------
  //
  // La cola la enseña con su fecha, leída de donde ya vive. Si esta siembra
  // escribiera algo en `peticionesDePlan`, estaría violando FR-038 justo en
  // la herramienta que sirve para comprobarlo.
  await db.collection('registros').doc('r-ana-molestia').set({
    nadadorId: 'n-ana',
    planId: 'p-publicado',
    sesionId: 's-2',
    versionDePlan: '3.6.0',
    realizada: true,
    rpePercibido: 7,
    molestia: {
      descripcion: 'Me molesta al sacar el brazo',
      zonaDelCuerpo: 'Hombro derecho',
    },
    registradoEn: new Date().toISOString(),
  });

  console.log(
    `Sin permiso: nadador.sinpermiso@ejemplo.test  (uid ${sinPermiso.uid}, ficha n-sin-permiso, SIN consentimiento)`,
  );
  console.log(
    `Sin ATR:     nadadora.inicia@ejemplo.test  (uid ${inicia.uid}, ficha n-inicia, Iniciación)`,
  );
  console.log('Fronteras:  3 peticiones esperando, a 15, 16 y 44 días');
  console.log('Molestia:   Ana contó una hace un momento, para ver la cola');
}
