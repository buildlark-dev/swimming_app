// Garantia A9 — se sabe de donde vino cada solicitud.
//
// La feature 004 solo dejaba al entrenador aportar el canal, dando por hecho
// una matricula de la que sacar el contacto de la familia. **Esta app no es un
// grupo cerrado**: la usa cualquiera, a nivel nacional e internacional, y la
// mayoria no tendra entrenador dentro de la app. Una nadadora de catorce anos
// que se la descarga en otro pais no tiene a nadie que aporte nada.
//
// Asi que el camino normal es que lo declare quien se registra, y lo que se
// conserva es la distincion: queda grabado de donde vino.
//
// Lo que esto NO pretende: impedir que un menor decidido enganie al sistema.
// Un adolescente que quiere saltarselo lo consigue, aqui y en cualquier app.
// Lo que si hace es que la familia que quiere dar su consentimiento tenga por
// donde, y que quede constancia con fecha de quien autorizo que.
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

// El origen lo escribe el servidor, no el cliente. Estas pruebas comprueban
// las dos cosas que las reglas si pueden garantizar: que nadie lo escriba a
// mano, y que nadie lo reescriba despues.

const nadadora = () =>
  entorno.authenticatedContext('u-nadadora', { rol: 'nadador' }).firestore();

const entrenador = () =>
  entorno.authenticatedContext('u-entrenador', { rol: 'entrenador' }).firestore();

async function sembrarSolicitud(origen) {
  await entorno.withSecurityRulesDisabled(async (sinReglas) => {
    await sinReglas.firestore().collection('solicitudes').doc('s1').set({
      nadadorId: 'n1',
      canal: 'madre@ejemplo.com',
      origen,
      resumenDelToken: 'un-resumen',
      emitidaEn: new Date(),
      venceEn: new Date(Date.now() + 7 * 24 * 3600 * 1000),
      canjeadaEn: null,
    });
  });
}

test('A9 — el nadador no puede crear una solicitud a mano', async () => {
  // La crea el servidor al terminar el alta. Si el cliente pudiera, podria
  // ponerle el origen que quisiera, y el origen dejaria de significar nada.
  await assertFails(
    nadadora().collection('solicitudes').doc('mia').set({
      nadadorId: 'n1',
      canal: 'yo@ejemplo.com',
      origen: 'matriculaDelEntrenador',
    }),
  );
});

test('A9 — el entrenador tampoco la escribe desde el cliente', async () => {
  await assertFails(
    entrenador().collection('solicitudes').doc('suya').set({
      nadadorId: 'n1',
      canal: 'madre@ejemplo.com',
      origen: 'matriculaDelEntrenador',
    }),
  );
});

test('A9 — el origen no se puede cambiar despues', async () => {
  // Una declaracion no se convierte en verificada porque alguien la mire.
  await sembrarSolicitud('declaradoPorElNadador');

  await assertFails(
    nadadora()
      .collection('solicitudes')
      .doc('s1')
      .update({ origen: 'matriculaDelEntrenador' }),
  );
  await assertFails(
    entrenador()
      .collection('solicitudes')
      .doc('s1')
      .update({ origen: 'matriculaDelEntrenador' }),
  );
});

test('el entrenador si puede leer de donde vino', async () => {
  // Es para lo que existe el campo: que vea cuales pidio el y cuales
  // declararon los propios nadadores.
  await sembrarSolicitud('declaradoPorElNadador');

  const leida = await assertSucceeds(
    entrenador().collection('solicitudes').doc('s1').get(),
  );

  assert.equal(leida.data().origen, 'declaradoPorElNadador');
});

test('los dos origenes son valores distintos', async () => {
  // Si fueran el mismo, el campo seria decorativo.
  const codigo = fs.readFileSync(
    path.join(__dirname, '..', 'functions', 'src', 'consentimiento.ts'),
    'utf8',
  );

  assert.match(codigo, /declaradoPorElNadador/);
  assert.match(codigo, /matriculaDelEntrenador/);
});

test('A9 — el servidor decide el origen, no quien llama', async () => {
  // Lo importante de la decision D1 en una linea: el origen sale de si quien
  // llama es entrenador, no de un campo que mande el cliente.
  const codigo = fs.readFileSync(
    path.join(__dirname, '..', 'functions', 'src', 'consentimiento.ts'),
    'utf8',
  );

  assert.match(
    codigo,
    /origen:\s*esDelEntrenador\s*\?/,
    'El origen tiene que derivarse de quien llama. Si viniera en peticion.data, ' +
      'cualquiera podria declararse matriculado',
  );
});

test('A17 — ni el correo ni el token llegan a los registros', () => {
  // Lo encontro la garantia A17 de la feature 006, y era peor que un desliz de
  // privacidad: el cuerpo del aviso lleva **el token**, que es la credencial
  // que autoriza tratar los datos de un menor.
  //
  // Guardar solo el resumen en Firestore protegia la base de datos (garantia
  // C4) y el registro lo regalaba: cualquiera con acceso a los logs podia
  // consentir en nombre de un acudiente.
  const codigo = fs.readFileSync(
    path.join(__dirname, '..', 'functions', 'src', 'consentimiento.ts'),
    'utf8',
  );

  const bloque = codigo.slice(
    codigo.indexOf('export const enviadorPorOmision'),
    codigo.indexOf('let enviador'),
  );

  assert.ok(
    !/logger\.\w+\([^)]*\bdestino\b/.test(bloque),
    'El correo del acudiente no puede ir a los registros (principio V)',
  );
  assert.ok(
    !/logger\.\w+\([^)]*\bcuerpo\b/.test(bloque),
    'El cuerpo del aviso lleva el token: registrarlo es regalar la credencial',
  );
});
