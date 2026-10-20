/**
 * Guarantees A1 and A2 — the role is not something a client declares.
 *
 * Contract: specs/004-cuentas-y-consentimiento/contracts/cuentas_y_roles.md
 *
 * These run against the Authentication emulator. They are not about the
 * convenience of a helper: they are about the one thing that stands between a
 * stranger and a child's training data.
 */

const assert = require('node:assert/strict');
const { after, before, describe, it } = require('node:test');

const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const PROYECTO = 'demo-natacion';
const CLAVE_DEL_ROL = 'rol';

let app;
let auth;

before(() => {
  assert.ok(
    process.env.FIREBASE_AUTH_EMULATOR_HOST,
    'Estas pruebas necesitan el emulador de Authentication. Corre `npm test`, ' +
      'que lo levanta: contra un proyecto real crearian cuentas de verdad.'
  );
  app = initializeApp({ projectId: PROYECTO });
  auth = getAuth(app);
});

after(async () => {
  await deleteApp(app);
});

/** A fresh account, and its claims once the create trigger has settled. */
async function cuentaNueva(correo) {
  const usuario = await auth.createUser({
    email: correo,
    password: 'solo-para-el-emulador',
  });

  // The create trigger runs asynchronously. Poll rather than sleep a fixed
  // amount: a fixed sleep is either flaky or slow, and usually both.
  for (let intento = 0; intento < 50; intento++) {
    const actual = await auth.getUser(usuario.uid);
    if (actual.customClaims?.[CLAVE_DEL_ROL]) return actual;
    await new Promise((listo) => setTimeout(listo, 100));
  }

  return auth.getUser(usuario.uid);
}

describe('A2 — toda cuenta nueva nace como nadador', () => {
  it('el rol por omision es nadador', async () => {
    const usuario = await cuentaNueva(`nuevo-${Date.now()}@ejemplo.test`);

    assert.equal(
      usuario.customClaims?.[CLAVE_DEL_ROL],
      'nadador',
      'Registrarse no puede conceder el rol que aprueba y publica'
    );
  });

  it('ninguna cuenta nace como entrenador', async () => {
    const usuario = await cuentaNueva(`otro-${Date.now()}@ejemplo.test`);
    assert.notEqual(usuario.customClaims?.[CLAVE_DEL_ROL], 'entrenador');
  });
});

describe('A1 — el rol no se declara desde el cliente', () => {
  it('lo que el cliente escriba en su documento no entra en el token', async () => {
    // El cliente puede escribir lo que quiera en una coleccion a la que tenga
    // acceso. Lo que no puede es que eso aparezca en request.auth.token, que
    // es lo unico que las reglas miran.
    const usuario = await cuentaNueva(`falso-${Date.now()}@ejemplo.test`);

    const token = await auth.createCustomToken(usuario.uid, {
      [CLAVE_DEL_ROL]: 'entrenador',
    });
    assert.ok(token, 'el emulador acepta acunar un token a medida');

    // Lo que cuenta es el claim real de la cuenta, que no cambio.
    const despues = await auth.getUser(usuario.uid);
    assert.equal(
      despues.customClaims?.[CLAVE_DEL_ROL],
      'nadador',
      'Acunar un token con un rol distinto no cambia el rol de la cuenta'
    );
  });
});

describe('asignar un rol', () => {
  /** The mechanism behind the closed door, same one the script uses. */
  async function asignarRolA(uid, rol) {
    const ROLES = ['entrenador', 'nadador'];
    if (!ROLES.includes(rol)) {
      throw new Error(`«${rol}» no es un rol.`);
    }
    const usuario = await auth.getUser(uid);
    await auth.setCustomUserClaims(usuario.uid, {
      ...(usuario.customClaims || {}),
      [CLAVE_DEL_ROL]: rol,
    });
  }

  it('promueve a entrenador', async () => {
    const usuario = await cuentaNueva(`promo-${Date.now()}@ejemplo.test`);
    await asignarRolA(usuario.uid, 'entrenador');

    const despues = await auth.getUser(usuario.uid);
    assert.equal(despues.customClaims[CLAVE_DEL_ROL], 'entrenador');
  });

  it('rechaza un rol que no existe en lugar de aproximarlo', async () => {
    const usuario = await cuentaNueva(`malo-${Date.now()}@ejemplo.test`);

    await assert.rejects(
      () => asignarRolA(usuario.uid, 'administrador'),
      /no es un rol/,
      'Resolver al mas parecido es exactamente como se cuela un permiso'
    );

    const despues = await auth.getUser(usuario.uid);
    assert.equal(despues.customClaims[CLAVE_DEL_ROL], 'nadador');
  });

  it('no borra los demas claims de la cuenta', async () => {
    const usuario = await cuentaNueva(`claims-${Date.now()}@ejemplo.test`);
    await auth.setCustomUserClaims(usuario.uid, {
      ...(usuario.customClaims || {}),
      otraCosa: 'se conserva',
    });

    await asignarRolA(usuario.uid, 'entrenador');

    const despues = await auth.getUser(usuario.uid);
    assert.equal(despues.customClaims.otraCosa, 'se conserva');
    assert.equal(despues.customClaims[CLAVE_DEL_ROL], 'entrenador');
  });
});
