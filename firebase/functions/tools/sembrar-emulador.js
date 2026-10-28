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
    });
    await db.collection('consentimientos').doc(nadador.id).set({
      vigente: true,
      alcances: ['datosDeEntrenamiento'],
      versionDelTexto: 'v1',
      otorgadoEn: new Date().toISOString(),
    });
  }

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

  console.log(`Entrenador: ${CORREO} / ${CLAVE}  (uid ${usuario.uid})`);
  console.log('Planes: 4 (2 publicados, 1 aprobado, 1 borrador)');
  console.log('En uso esperado: 1 — solo Ana ha respondido algo');
}

main().then(() => process.exit(0));
