#!/usr/bin/env node
/**
 * Show what the server thinks a given account is.
 *
 *   npm --prefix firebase/functions run ver-rol -- <uid-o-correo>
 *
 * Read-only. It changes nothing; it exists so that "the role was assigned"
 * stops being something anyone has to take on trust.
 *
 * The role lives in the token as a custom claim, so it is invisible in the
 * Firebase console — which is exactly why this is worth having.
 */

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const CLAVE_DEL_ROL = 'rol';
const ROLES = ['entrenador', 'nadador'];

async function main() {
  const quien = process.argv[2];

  if (!quien) {
    console.error('Uso: ver-rol <uid-o-correo>');
    process.exit(2);
  }

  initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-natacion' });

  const usuario = quien.includes('@')
    ? await getAuth().getUserByEmail(quien)
    : await getAuth().getUser(quien);

  const claims = usuario.customClaims || {};
  const rol = claims[CLAVE_DEL_ROL];

  console.log('');
  console.log(`Correo : ${usuario.email || '(sin correo)'}`);
  console.log(`UID    : ${usuario.uid}`);
  console.log(`Creada : ${usuario.metadata.creationTime}`);
  console.log(`Rol    : ${rol || '(SIN ROL)'}`);
  console.log(`Claims : ${JSON.stringify(claims)}`);
  console.log('');

  if (!rol) {
    console.log('Esta cuenta no tiene rol, asi que la app la dejara esperando.');
    console.log('Asignalo con:');
    console.log(`  npm --prefix firebase/functions run asignar-rol -- ${usuario.email || usuario.uid} entrenador`);
    process.exit(1);
  }

  if (!ROLES.includes(rol)) {
    console.log(`«${rol}» no es uno de los roles que la app entiende.`);
    console.log(`Los que hay: ${ROLES.join(', ')}.`);
    console.log('La app tratara esta cuenta como si no tuviera rol.');
    process.exit(1);
  }

  console.log('Correcto. Si la app sigue esperando, el token del navegador');
  console.log('todavia lleva el rol anterior: cierra sesion y vuelve a entrar.');
}

main().catch((error) => {
  console.error(error.message);

  if (/quota.project|adc-troubleshooting|billing|consumer/i.test(error.message)) {
    console.error(
      '\nA las credenciales de gcloud les falta el proyecto de cuota.\n' +
        'Un comando y se arregla:\n' +
        '  gcloud auth application-default set-quota-project swimming-app-ab45f'
    );
  }

  if (/credential|authenticate|PERMISSION_DENIED/i.test(error.message)) {
    console.error(
      '\nSin credenciales para ese proyecto. En PowerShell:\n' +
        '  gcloud auth application-default login\n' +
        'y vuelve a correrlo con GCLOUD_PROJECT puesto.'
    );
  }

  process.exit(1);
});
