/**
 * Accepting and declining someone into a community (feature 012).
 *
 * **Why this is the server's and not the coach's device.**
 *
 * Accepting is two writes — the membership onto her profile, and the request
 * closed — and guarantee F5 says they happen together or not at all:
 *
 * > Half an accept is a swimmer who belongs to nobody and who no longer has a
 * > request to show for it.
 *
 * A client cannot promise that. It can lose signal between the two writes and
 * there is no way to tell afterwards which half landed. So the rules deny the
 * client every write that a membership needs — `comunidadId` is server-only
 * (F6), and `aceptada` is a word the swimmer's own copy of the request may
 * never write — and both acts come through here, in a transaction.
 *
 * This is the same shape feature 008 gave to closing a plan request, and the
 * same shape feature 004 gave to redeeming a consent, for the same reason in
 * all three: the fact being written is a fact about somebody's decision, and a
 * declaration by whoever happened to call is not that.
 *
 * **Declining carries no written reason**, deliberately. Nothing is owed by way
 * of explanation to somebody who is not yet your swimmer, and free text
 * travelling to a stranger is a problem with no upside (FR-011). It does not
 * prevent her asking again, here or anywhere else (FR-012).
 */

import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { getFirestore } from 'firebase-admin/firestore';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';

const COL_SOLICITUDES = 'solicitudesDeIngreso';
const COL_NADADORES = 'nadadores';

export interface IngresoAceptado {
  nadadorId: string;
  comunidadId: string;
  miembroDesde: string;
}

export interface IngresoRechazado {
  nadadorId: string;
  comunidadId: string;
  estado: 'rechazada';
  resueltaEn: string;
}

/**
 * The community a coach owns.
 *
 * **It is his own account id**, so "one community per coach" is a fact of the
 * key rather than a rule somebody has to remember — the same thing
 * `firestore.rules` relies on in `miComunidad()`.
 */
function suComunidad(entrenadorId: string): string {
  const limpio = (entrenadorId ?? '').trim();
  if (!limpio) {
    throw new HttpsError('invalid-argument', 'Falta quién está decidiendo.');
  }
  return limpio;
}

function elNadador(nadadorId: string): string {
  const limpio = (nadadorId ?? '').trim();
  if (!limpio) {
    throw new HttpsError('invalid-argument', 'Falta de quién es la solicitud.');
  }
  return limpio;
}

/**
 * Accepts her: writes the membership and closes the request, as one act.
 *
 * Exported apart from the `onCall` wrapper so the emulator tests can drive it
 * with a `Firestore` of their own, the same way features 006, 007 and 008 do.
 */
export async function aceptarIngresoDe(
  db: Firestore,
  datos: { entrenadorId: string; nadadorId: string }
): Promise<IngresoAceptado> {
  const comunidadId = suComunidad(datos.entrenadorId);
  const nadadorId = elNadador(datos.nadadorId);

  const solicitud = db
    .collection(COL_SOLICITUDES)
    .doc(`${nadadorId}|${comunidadId}`);
  const ficha = db.collection(COL_NADADORES).doc(nadadorId);

  const miembroDesde = new Date().toISOString();

  // **Everything inside the transaction**, reads included. Checking that the
  // request is still waiting and then writing outside one would leave the gap
  // where two taps on a slow connection accept her twice — and the second
  // would stamp a new `miembroDesde` over the real one.
  await db.runTransaction(async (t) => {
    const pedida = await t.get(solicitud);
    if (!pedida.exists) {
      // The identifier carries the community, so a request for somebody
      // else's community simply is not here. One check covers both: it does
      // not exist, or it is not yours.
      throw new HttpsError(
        'not-found',
        'Esa solicitud no existe, o no es de tu comunidad.'
      );
    }

    const estado = pedida.data()?.['estado'] ?? 'esperando';
    if (estado !== 'esperando') {
      // Not an error of the caller's making — she may have withdrawn it a
      // second ago — so it says what happened instead of failing opaquely,
      // and above all it does not overwrite her withdrawal.
      throw new HttpsError(
        'failed-precondition',
        'Esa solicitud ya no está esperando: está ' + estado + '.'
      );
    }

    const perfil = await t.get(ficha);
    if (!perfil.exists) {
      throw new HttpsError('not-found', 'Esa nadadora no existe.');
    }

    // **One community per swimmer** (research D1). If she is already
    // somebody's, accepting here would take her out of there without anyone
    // saying so — and the coach she is leaving would find out by her
    // disappearing from his screen.
    const yaEsDe = perfil.data()?.['comunidadId'] ?? '';
    if (yaEsDe && yaEsDe !== comunidadId) {
      throw new HttpsError(
        'failed-precondition',
        'Ya es de otra comunidad. Tiene que salir de ella antes de entrar aquí.'
      );
    }

    t.set(ficha, { comunidadId, miembroDesde }, { merge: true });
    t.set(
      solicitud,
      { estado: 'aceptada', resueltaEn: FieldValue.serverTimestamp() },
      { merge: true }
    );
  });

  return { nadadorId, comunidadId, miembroDesde };
}

/**
 * Declines: closes the request, writes no reason, and touches nothing of hers.
 */
export async function rechazarIngresoDe(
  db: Firestore,
  datos: { entrenadorId: string; nadadorId: string }
): Promise<IngresoRechazado> {
  const comunidadId = suComunidad(datos.entrenadorId);
  const nadadorId = elNadador(datos.nadadorId);

  const solicitud = db
    .collection(COL_SOLICITUDES)
    .doc(`${nadadorId}|${comunidadId}`);

  const resueltaEn = new Date().toISOString();

  await db.runTransaction(async (t) => {
    const pedida = await t.get(solicitud);
    if (!pedida.exists) {
      throw new HttpsError(
        'not-found',
        'Esa solicitud no existe, o no es de tu comunidad.'
      );
    }

    const estado = pedida.data()?.['estado'] ?? 'esperando';
    if (estado !== 'esperando') {
      throw new HttpsError(
        'failed-precondition',
        'Esa solicitud ya no está esperando: está ' + estado + '.'
      );
    }

    // **Note what is not written here.** No `motivo`, no free text of any
    // kind, and the caller's `motivo` is not even read: there is nowhere for
    // it to land, which is stronger than deciding each time not to use it.
    t.set(
      solicitud,
      { estado: 'rechazada', resueltaEn: FieldValue.serverTimestamp() },
      { merge: true }
    );
  });

  return { nadadorId, comunidadId, estado: 'rechazada', resueltaEn };
}

/**
 * Ends a membership, from whichever side asked.
 *
 * **Nothing of hers is touched** (guarantee F7). Her records, her plans, her
 * requests and her history stay exactly as they are; what goes away is the one
 * field that says who may read them. Leaving a community is not being deleted,
 * and the asymmetry that would make it so — a coach who, on removing somebody,
 * also wiped what she wrote — is not something the client could do anyway,
 * because the rules deny it. It is not something the server does either, and
 * that is a decision, not an omission.
 *
 * The caller's own community or her own membership is checked first, so one
 * coach cannot pull somebody out of another's group, and nobody can leave a
 * community they do not belong to.
 */
export async function terminarPertenenciaDe(
  db: Firestore,
  datos: { nadadorId: string; comunidadId: string }
): Promise<{ nadadorId: string; comunidadId: string; terminadaEn: string }> {
  const comunidadId = suComunidad(datos.comunidadId);
  const nadadorId = elNadador(datos.nadadorId);

  const ficha = db.collection(COL_NADADORES).doc(nadadorId);
  const terminadaEn = new Date().toISOString();

  await db.runTransaction(async (t) => {
    const perfil = await t.get(ficha);
    if (!perfil.exists) {
      throw new HttpsError('not-found', 'Esa nadadora no existe.');
    }

    const esDe = perfil.data()?.['comunidadId'] ?? '';
    if (esDe !== comunidadId) {
      // One message for both callers, and it is true for both: the coach is
      // not hers, or she is not in that community.
      throw new HttpsError(
        'failed-precondition',
        'No pertenece a esa comunidad.'
      );
    }

    // **Only the two fields that say she belongs.** `FieldValue.delete()` and
    // not an empty string: absent means she belongs to nobody, and the rules
    // read it with `get('comunidadId', '')`, so a stray empty value would be
    // a second way of saying the same thing.
    t.update(ficha, {
      comunidadId: FieldValue.delete(),
      miembroDesde: FieldValue.delete(),
      // Para que ella se entere sin preguntarle a nadie (FR-026). Es un dato
      // sobre su cuenta, no sobre el entrenador: no dice quién ni por qué.
      pertenenciaTerminadaEn: terminadaEn,
    });
  });

  return { nadadorId, comunidadId, terminadaEn };
}

/** Thin wrapper: identity in, nothing else. */
function soloElEntrenador(auth: CallableRequest['auth']): string {
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Hay que entrar primero.');
  }
  if (auth.token?.rol !== 'entrenador') {
    throw new HttpsError(
      'permission-denied',
      'Solo el entrenador decide quién entra en su comunidad.'
    );
  }
  return auth.uid;
}

export const aceptarIngreso = onCall(async (peticion) => {
  // **The coach is taken from the token, never from the payload.** A caller
  // who could name the community would be able to accept somebody into
  // another coach's group, which is precisely the boundary this feature
  // exists to build.
  const entrenadorId = soloElEntrenador(peticion.auth);
  const datos = peticion.data ?? {};

  return aceptarIngresoDe(getFirestore(), {
    entrenadorId,
    nadadorId: datos['nadadorId'],
  });
});

export const rechazarIngreso = onCall(async (peticion) => {
  const entrenadorId = soloElEntrenador(peticion.auth);
  const datos = peticion.data ?? {};

  return rechazarIngresoDe(getFirestore(), {
    entrenadorId,
    nadadorId: datos['nadadorId'],
  });
});

/** Él la saca de su comunidad. */
export const sacarDeLaComunidad = onCall(async (peticion) => {
  const entrenadorId = soloElEntrenador(peticion.auth);
  const datos = peticion.data ?? {};

  return terminarPertenenciaDe(getFirestore(), {
    nadadorId: datos['nadadorId'],
    // Su comunidad, del token. Mandarla sería poder sacar a alguien del grupo
    // de otro entrenador.
    comunidadId: entrenadorId,
  });
});

/**
 * Ella se va de la suya.
 *
 * **Simétrica con `sacarDeLaComunidad`, y a propósito** (garantía F7). No hay
 * permiso que pedir ni confirmación del entrenador: pertenecer es algo que a
 * ella le pasa, y una salida que dependiera de que él la acepte sería una
 * puerta con cerrojo por fuera.
 *
 * La comunidad tampoco viaja: se lee de su propia ficha, que es donde vive la
 * pertenencia. Así no se puede pedir salir de una a la que no se pertenece.
 */
export const salirDeLaComunidad = onCall(async (peticion) => {
  const auth = peticion.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Hay que entrar primero.');
  }

  const db = getFirestore();

  // Qué perfil es el suyo lo dice `usuarios/{uid}`, que solo escribe el
  // servidor. Tomarlo de la llamada permitiría sacar a cualquiera.
  const vinculo = await db.collection('usuarios').doc(auth.uid).get();
  const nadadorId = vinculo.data()?.['nadadorId'] ?? '';
  if (!nadadorId) {
    throw new HttpsError(
      'failed-precondition',
      'Esta cuenta no tiene un perfil de nadador.'
    );
  }

  const perfil = await db.collection(COL_NADADORES).doc(nadadorId).get();
  const comunidadId = perfil.data()?.['comunidadId'] ?? '';
  if (!comunidadId) {
    throw new HttpsError(
      'failed-precondition',
      'No perteneces a ninguna comunidad.'
    );
  }

  return terminarPertenenciaDe(db, { nadadorId, comunidadId });
});
