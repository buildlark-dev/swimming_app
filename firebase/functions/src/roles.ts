/**
 * Roles.
 *
 * The rules read the role straight from the token — `request.auth.token.rol`.
 * That is why it is a custom claim and not a document: a claim is signed by
 * the Admin SDK, costs nothing to read inside a rule, and a client cannot
 * forge it (decision D2).
 *
 * Which is also why this file has to exist on a server at all. Nobody can hand
 * themselves the role that approves and publishes training for minors.
 */

import * as auth from 'firebase-functions/v1/auth';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { getAuth } from 'firebase-admin/auth';

/** The two roles. Must match `Rol.clave` in lib/dominio/cuentas/cuenta.dart. */
export const ROLES = ['entrenador', 'nadador'] as const;
export type Rol = (typeof ROLES)[number];

/** What the claim is called inside the token. firestore.rules reads this. */
export const CLAVE_DEL_ROL = 'rol';

/**
 * Every new account is a swimmer (guarantee A2).
 *
 * `entrenador` is never granted by signing up. It takes the administrative
 * call below, which the app cannot make.
 *
 * There is a window worth knowing about: this trigger runs after the account
 * exists, so the very first token a client holds may not carry the claim yet.
 * The client closes it by force-refreshing the token once when it finds a user
 * with no recognised role, rather than concluding there is no session. The
 * alternative — a blocking `beforeUserCreated` function — would put the claim
 * in the first token but requires Identity Platform, which is paid, and this
 * is a one-coach project.
 */
export const alCrearseUnaCuenta = auth.user().onCreate(async (usuario) => {
  await getAuth().setCustomUserClaims(usuario.uid, {
    [CLAVE_DEL_ROL]: 'nadador' satisfies Rol,
  });
});

/**
 * Grant a role. Administrative, and deliberately not reachable from the app.
 *
 * It refuses every caller. The only way to run it is with Admin credentials —
 * the emulator, or the script in tools/ against a real project — which is the
 * friction we want: see `docs/DEVELOPMENT.md`, "The first coach".
 */
export const asignarRol = onCall(async (peticion) => {
  const quienLlama = peticion.auth;

  // Even a coach cannot promote anyone. Being able to mint coaches from inside
  // the app would make the role a checkbox, and the role is what stands
  // between a stranger and a child's training data.
  if (quienLlama) {
    throw new HttpsError(
      'permission-denied',
      'Asignar un rol no se hace desde la app. Ver docs/DEVELOPMENT.md.'
    );
  }

  throw new HttpsError(
    'permission-denied',
    'Esta operación requiere credenciales de administrador.'
  );
});

/**
 * The actual role assignment, used by the admin script and by the tests.
 *
 * Kept apart from the callable on purpose: the callable is the door that stays
 * shut, this is the mechanism behind it.
 */
export async function asignarRolA(uid: string, rol: string): Promise<void> {
  if (!ROLES.includes(rol as Rol)) {
    throw new Error(
      `«${rol}» no es un rol. Los que hay: ${ROLES.join(', ')}. No se ` +
        `resuelve al más parecido: así es como se cuela un permiso.`
    );
  }

  const usuario = await getAuth().getUser(uid);
  await getAuth().setCustomUserClaims(usuario.uid, {
    ...(usuario.customClaims ?? {}),
    [CLAVE_DEL_ROL]: rol,
  });
}
