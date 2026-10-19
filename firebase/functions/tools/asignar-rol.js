#!/usr/bin/env node
/**
 * Grant a role to an account.
 *
 *   npm --prefix firebase/functions run asignar-rol -- <uid> entrenador
 *
 * This exists because nobody can grant themselves the coach role. Signing up
 * always produces a swimmer; `entrenador` takes this script and Admin
 * credentials, which are never stored in this repository.
 *
 * Against the emulators, FIREBASE_AUTH_EMULATOR_HOST is enough and no
 * credentials are needed. Against a real project, the caller supplies
 * GOOGLE_APPLICATION_CREDENTIALS themselves.
 *
 * The friction is the point: the role that approves and publishes training for
 * children should not be a checkbox on a sign-up form.
 */

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const ROLES = ['entrenador', 'nadador'];
const CLAVE_DEL_ROL = 'rol';

async function main() {
  const [quien, rol] = process.argv.slice(2);

  if (!quien || !rol) {
    console.error('Uso: asignar-rol <uid-o-correo> <entrenador|nadador>');
    process.exit(2);
  }

  if (!ROLES.includes(rol)) {
    console.error(
      `«${rol}» no es un rol. Los que hay: ${ROLES.join(', ')}.\n` +
        'No se resuelve al mas parecido: asi es como se cuela un permiso.'
    );
    process.exit(2);
  }

  const contraEmulador = Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST);

  // Contra un proyecto real, el Admin SDK usa las Credenciales de Aplicacion
  // por Omision. Hay dos formas de tenerlas, y **se prefiere la primera**:
  //
  //   1. `gcloud auth application-default login`, que las deja en el perfil
  //      del usuario y caducan solas.
  //   2. GOOGLE_APPLICATION_CREDENTIALS apuntando a una clave de cuenta de
  //      servicio, que SI es un secreto de verdad: un archivo que abre el
  //      proyecto entero, que no caduca y que hay que custodiar.
  //
  // El script no exige la segunda. Pedirla cuando la primera basta seria
  // empujar a tener una clave permanente en el disco sin necesidad.
  if (!contraEmulador) {
    console.log(`Proyecto: ${process.env.GCLOUD_PROJECT || '(sin GCLOUD_PROJECT)'}`);
    console.log(
      process.env.GOOGLE_APPLICATION_CREDENTIALS
        ? 'Credenciales: GOOGLE_APPLICATION_CREDENTIALS'
        : 'Credenciales: las de gcloud (application-default)'
    );
  }

  initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-natacion' });

  // Acepta el correo además del UID. Copiar un identificador de veintiocho
  // caracteres desde la consola es justo donde se cuela una errata, y esto se
  // corre sobre la cuenta que aprueba y publica entrenamientos de menores.
  const usuario = quien.includes('@')
    ? await getAuth().getUserByEmail(quien)
    : await getAuth().getUser(quien);

  await getAuth().setCustomUserClaims(usuario.uid, {
    ...(usuario.customClaims || {}),
    [CLAVE_DEL_ROL]: rol,
  });

  console.log(`${usuario.email || usuario.uid} (${usuario.uid}) -> ${rol}`);
  console.log(
    'El token en curso todavia lleva el rol anterior. Quien lo tenga abierto\n' +
      'tiene que volver a entrar, o refrescar el token, para que surta efecto.'
  );
}

main().catch((error) => {
  console.error(error.message);

  if (/credential|authenticate|PERMISSION_DENIED/i.test(error.message)) {
    console.error(
      '\nSin credenciales para ese proyecto. Lo mas simple:\n' +
        '  gcloud auth application-default login\n' +
        'y vuelve a correrlo con GCLOUD_PROJECT puesto.'
    );
  }

  process.exit(1);
});
