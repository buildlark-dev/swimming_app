/**
 * Closing a plan request (feature 008).
 *
 * **The state is the server's to write.** A client that can write its own
 * state can approve its own request, so the access rules let the coach do
 * exactly one thing from the device — open a request, moving it to
 * `enRevision` — and nothing else. Approving and rejecting come through here.
 *
 * Two things only the server can honestly do:
 *
 * - **The date.** When a request was answered is a fact about the coach's
 *   work, not a declaration by whoever happened to call.
 * - **The archive.** The answered request moves to `historial` so the swimmer
 *   can send another one. Doing that on the client would mean trusting the
 *   client to not lose it on the way.
 *
 * A rejection with no reason is refused here too. It is already impossible in
 * the screen and in the domain type; this is the third layer, and it is the
 * one that holds when the first two are bypassed.
 */

import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const COL_PETICIONES = 'peticionesDePlan';
const HISTORIAL = 'historial';

/** The two decisions, spelled exactly as the client sends them. */
export const DECISIONES = ['aprobada', 'rechazada'] as const;
export type Decision = (typeof DECISIONES)[number];

export interface CierreDeLaPeticion {
  estado: Decision;
  respondidaEn: string;
  archivadaEn: string;
}

/**
 * Closes the request: writes the outcome, stamps the date and archives it.
 *
 * Exported apart from the `onCall` wrapper so the emulator tests can drive it
 * with a `Firestore` of their own, the same way features 006 and 007 do.
 */
export async function cerrarPeticionDe(
  db: Firestore,
  datos: {
    nadadorId: string;
    decision: string;
    planId?: string | null;
    motivo?: string | null;
  }
): Promise<CierreDeLaPeticion> {
  const nadadorId = (datos.nadadorId ?? '').trim();
  if (!nadadorId) {
    throw new HttpsError('invalid-argument', 'Falta de quién es la petición.');
  }

  if (!DECISIONES.includes(datos.decision as Decision)) {
    throw new HttpsError(
      'invalid-argument',
      'La decisión solo puede ser «aprobada» o «rechazada».'
    );
  }

  const decision = datos.decision as Decision;
  const motivo = (datos.motivo ?? '').trim();
  const planId = (datos.planId ?? '').trim();

  // **A rejection with no reason leaves the swimmer not knowing why**, and the
  // one waiting may be nine years old (FR-026).
  if (decision === 'rechazada' && !motivo) {
    throw new HttpsError(
      'invalid-argument',
      'Un rechazo necesita un motivo escrito.'
    );
  }

  // Approving without a plan would be a signature on nothing.
  if (decision === 'aprobada' && !planId) {
    throw new HttpsError(
      'invalid-argument',
      'Una petición aprobada tiene que señalar a un plan.'
    );
  }

  const peticion = db.collection(COL_PETICIONES).doc(nadadorId);
  const actual = await peticion.get();
  if (!actual.exists) {
    throw new HttpsError('not-found', 'Esa petición ya no existe.');
  }

  const respondidaEn = new Date().toISOString();

  const cerrada = {
    ...actual.data(),
    estado: decision,
    respondidaEn: FieldValue.serverTimestamp(),
    motivoDelRechazo: decision === 'rechazada' ? motivo : null,
    planId: decision === 'aprobada' ? planId : null,
  };

  // Archived first, then closed. The other order leaves a window where the
  // answered request is neither in the history nor in its own document.
  const enElHistorial = peticion.collection(HISTORIAL).doc(respondidaEn);
  await enElHistorial.set(cerrada);
  await peticion.set(cerrada, { merge: true });

  return {
    estado: decision,
    respondidaEn,
    archivadaEn: `${COL_PETICIONES}/${nadadorId}/${HISTORIAL}/${respondidaEn}`,
  };
}

/** Thin wrapper: identity in, nothing else. */
export const cerrarPeticion = onCall(async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que entrar primero.');
  }

  // **Only the coach closes a request.** It is his signature.
  if (peticion.auth.token?.rol !== 'entrenador') {
    throw new HttpsError(
      'permission-denied',
      'Solo el entrenador responde una petición.'
    );
  }

  const datos = peticion.data ?? {};

  return cerrarPeticionDe(getFirestore(), {
    nadadorId: datos['nadadorId'],
    decision: datos['decision'],
    planId: datos['planId'],
    motivo: datos['motivo'],
  });
});
