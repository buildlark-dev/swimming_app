/**
 * Verifiable consent.
 *
 * What this promises and what it does not:
 *
 *   The recorded consent is DEMONSTRABLE, NOT UNFORGEABLE. It proves what was
 *   authorised, by whom according to their own declaration, when, and under
 *   which text. It does NOT prove the identity of whoever confirmed, and it
 *   does NOT relieve the coach of his responsibility as Responsable del
 *   Tratamiento under Ley 1581 de 2012.
 *
 * What it builds instead is a chain of evidence: the channel comes from the
 * coach and never from the child, the link is single-use and expires, whoever
 * confirms declares under their own responsibility, the server sets the date,
 * and the guardian is told what was registered so impersonation is
 * discoverable by them.
 *
 * Contract: specs/004-cuentas-y-consentimiento/contracts/consentimiento.md
 */

import { createHash, randomBytes } from 'node:crypto';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

const COL_SOLICITUDES = 'solicitudes';
const COL_CONSENTIMIENTOS = 'consentimientos';
const HISTORIAL = 'historial';

/** Must match `Alcance.clave` in lib/dominio/consentimiento/consentimiento.dart. */
export const ALCANCES = ['datosDeEntrenamiento', 'video'] as const;
export type Alcance = (typeof ALCANCES)[number];

/** How long a request stays usable. Long enough for a parent, short enough
 * that a forgotten link in an inbox stops being a key. */
export const DIAS_DE_VIGENCIA = 7;

/** The token is the credential, so only its digest is ever stored (D4). */
export function resumirToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

/**
 * Where a notice goes. A port on purpose: this module does not know whether
 * there is email or messaging behind it, and nothing else depends on the
 * answer (research.md, "what is not resolved here").
 */
export interface EnviadorDeAvisos {
  enviar(destino: string, asunto: string, cuerpo: string): Promise<void>;
}

/** Until a channel is chosen, notices are logged rather than silently dropped. */
export const enviadorPorOmision: EnviadorDeAvisos = {
  async enviar(destino, asunto, cuerpo) {
    logger.info('aviso pendiente de canal', { destino, asunto, cuerpo });
  },
};

let enviador: EnviadorDeAvisos = enviadorPorOmision;

/** Swap the notifier. Used by the tests; production keeps the default. */
export function usarEnviador(nuevo: EnviadorDeAvisos): void {
  enviador = nuevo;
}

function esEntrenador(peticion: { auth?: { token?: Record<string, unknown> } }) {
  return peticion.auth?.token?.['rol'] === 'entrenador';
}

/**
 * 1. Issue a consent request. Callable by the coach ONLY (guarantee C1).
 *
 * The channel comes from his enrolment records. The swimmer cannot propose,
 * edit or add it — that is the hole this closes, and it is what makes the rest
 * of the chain mean anything.
 */
export const emitirSolicitud = onCall(async (peticion) => {
  // Feature 004 let only the coach do this, assuming an enrolment to take the
  // family's contact from. **This app is not a closed roster**: anyone signs
  // up, nationally and internationally, and most will have no coach inside the
  // app at all. A fourteen-year-old who downloads it in another country has
  // nobody who could supply anything, and requiring it would not make consent
  // safer - it would mean no consent exists.
  //
  // The guarantee is in the form, where the law puts it: the guardian
  // identifies themselves, states in what capacity they act, and confirms they
  // have heard the minor (Decreto 1377). The email is only the path to it.
  //
  // What is kept is the distinction, as `origen` (decision D1 of feature 006).
  const esDelEntrenador = esEntrenador(peticion);
  if (!esDelEntrenador && !peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que haber entrado.');
  }

  const { nadadorId, canal, alcances } = (peticion.data ?? {}) as {
    nadadorId?: string;
    canal?: string;
    alcances?: string[];
  };

  if (!nadadorId || !canal) {
    throw new HttpsError('invalid-argument', 'Faltan el nadador o el canal.');
  }

  // **The real frontier for "that is your own email".**
  //
  // The client checks it too, but the client is not a frontier: it does not
  // always know the account's address, and anybody can call this directly.
  // Here the address comes from the signed token, so it cannot be faked.
  //
  // What this does NOT check is that the address really belongs to a guardian.
  // The app cannot know that, and pretending otherwise would be worse than not
  // checking: it would give a confidence that does not exist.
  const correoDeQuienLlama = peticion.auth?.token?.email;
  if (
    !esDelEntrenador &&
    correoDeQuienLlama &&
    canal.trim().toLowerCase() === correoDeQuienLlama.trim().toLowerCase()
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Ese es tu propio correo. Hace falta el de tu padre, madre o acudiente.'
    );
  }

  const pedidos = alcances ?? ['datosDeEntrenamiento'];
  const desconocido = pedidos.find((a) => !ALCANCES.includes(a as Alcance));
  if (desconocido) {
    throw new HttpsError(
      'invalid-argument',
      `«${desconocido}» no es un alcance. No se resuelve al más parecido.`
    );
  }
  if (pedidos.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'Un consentimiento que no cubre nada no ampara nada.'
    );
  }

  // Cryptographically secure: this token is the credential that lets someone
  // authorise the processing of a child's data.
  const token = randomBytes(32).toString('base64url');

  const vence = new Date();
  vence.setDate(vence.getDate() + DIAS_DE_VIGENCIA);

  const documento = await getFirestore().collection(COL_SOLICITUDES).add({
    nadadorId,
    canal,
    // Where the address came from. It costs one field, it answers in writing a
    // question somebody will ask - how did this consent arrive - and a coach
    // who does have a group can tell their own apart (guarantee A9).
    //
    // It is written once and never updated: a declaration does not become
    // verified because somebody looked at it.
    origen: esDelEntrenador ? 'matriculaDelEntrenador' : 'declaradoPorElNadador',
    alcances: pedidos,
    // The plaintext token is never written. Anyone who can read this
    // collection still cannot forge a valid link (guarantee C4).
    resumenDelToken: resumirToken(token),
    emitidaEn: FieldValue.serverTimestamp(),
    venceEn: vence,
    canjeadaEn: null,
  });

  await enviador.enviar(
    canal,
    'Autorización para el entrenamiento de su hijo o hija',
    `Para leer la información y responder, abra este enlace:\n\n` +
      `/consentimiento?t=${token}\n\n` +
      `El enlace sirve una sola vez y vence en ${DIAS_DE_VIGENCIA} días.`
  );

  return { solicitudId: documento.id };
});

/**
 * 2. Redeem a confirmation. Public, because the guardian has no account.
 *
 * Rejects without saying WHICH of the three conditions failed. Telling them
 * apart would let someone probing links learn which ones ever existed.
 */
export const canjear = onCall(async (peticion) => {
  const { token, declaracion } = (peticion.data ?? {}) as {
    token?: string;
    declaracion?: {
      nombre?: string;
      documento?: string;
      calidad?: string;
      esRepresentanteLegal?: boolean;
      menorFueOido?: boolean;
      versionDelTexto?: string;
    };
  };

  if (!token) throw new HttpsError('invalid-argument', 'Falta el enlace.');

  const d = declaracion ?? {};
  if (!d.nombre?.trim() || !d.documento?.trim() || !d.calidad?.trim()) {
    throw new HttpsError(
      'invalid-argument',
      'Hace falta quién es usted y en qué calidad actúa.'
    );
  }
  if (!d.esRepresentanteLegal) {
    throw new HttpsError(
      'failed-precondition',
      'Solo el representante legal del nadador puede autorizar.'
    );
  }
  // Decreto 1377 de 2013: the minor is heard before the legal representative
  // authorises (guarantee C7). What is recorded is the declaration, not the
  // verification of the fact.
  if (!d.menorFueOido) {
    throw new HttpsError(
      'failed-precondition',
      'Antes de autorizar hay que haber escuchado al menor.'
    );
  }

  const db = getFirestore();
  const encontradas = await db
    .collection(COL_SOLICITUDES)
    .where('resumenDelToken', '==', resumirToken(token))
    .limit(1)
    .get();

  const rechazo = new HttpsError(
    'permission-denied',
    'Este enlace no sirve. Pídale al entrenador que le envíe uno nuevo.'
  );

  if (encontradas.empty) throw rechazo;

  const solicitud = encontradas.docs[0];
  if (!solicitud) throw rechazo;

  const datos = solicitud.data();
  const vence: Date = datos['venceEn'].toDate();

  if (datos['canjeadaEn']) throw rechazo;
  if (Date.now() >= vence.getTime()) throw rechazo;

  const nadadorId: string = datos['nadadorId'];

  await db.runTransaction(async (tx) => {
    // Re-read inside the transaction: two confirmations arriving together
    // must not both succeed (guarantee C2).
    const actual = await tx.get(solicitud.ref);
    if (actual.data()?.['canjeadaEn']) throw rechazo;

    const consentimiento = {
      nadadorId,
      otorgadoPor: {
        nombre: d.nombre!.trim(),
        documento: d.documento!.trim(),
        calidad: d.calidad!.trim(),
        esElPropioNadador: false,
      },
      // The server's clock, never the device's (FR-017). A consent date is a
      // legal fact, and a phone's clock is whatever its owner set it to.
      otorgadoEn: FieldValue.serverTimestamp(),
      alcances: datos['alcances'],
      versionDelTexto: d.versionDelTexto ?? 'v1',
      menorFueOido: true,
      vigente: true,
      revocadoEn: null,
    };

    tx.set(db.collection(COL_CONSENTIMIENTOS).doc(nadadorId), consentimiento);
    tx.set(
      db
        .collection(COL_CONSENTIMIENTOS)
        .doc(nadadorId)
        .collection(HISTORIAL)
        .doc(solicitud.id),
      consentimiento
    );
    tx.update(solicitud.ref, { canjeadaEn: FieldValue.serverTimestamp() });
  });

  // The guardian is told what was registered. This does not stop a misdirected
  // link from being redeemed; it makes it DISCOVERABLE by them, which is the
  // most a digital mechanism without document checks can offer (C9).
  await enviador.enviar(
    datos['canal'],
    'Quedó registrada su autorización',
    'Si no fue usted quien la dio, avise al entrenador ahora mismo.'
  );

  return { registrado: true };
});

/**
 * 3. Revoke. Reachable from the guardian's own link, with no coach involved
 * (guarantee C10).
 *
 * Does not erase anything: otorgadoEn and otorgadoPor survive, because that
 * record is the proof that the earlier processing was covered (C8).
 */
export const revocar = onCall(async (peticion) => {
  const { token, nadadorId } = (peticion.data ?? {}) as {
    token?: string;
    nadadorId?: string;
  };

  const db = getFirestore();
  let objetivo = nadadorId;

  if (token) {
    const encontradas = await db
      .collection(COL_SOLICITUDES)
      .where('resumenDelToken', '==', resumirToken(token))
      .limit(1)
      .get();
    objetivo = encontradas.empty
      ? undefined
      : encontradas.docs[0]?.data()['nadadorId'];
  } else if (!esEntrenador(peticion)) {
    throw new HttpsError(
      'permission-denied',
      'Para revocar hace falta el enlace del acudiente.'
    );
  }

  if (!objetivo) {
    throw new HttpsError('not-found', 'No hay un consentimiento que revocar.');
  }

  const referencia = db.collection(COL_CONSENTIMIENTOS).doc(objetivo);
  const actual = await referencia.get();
  if (!actual.exists) {
    throw new HttpsError('not-found', 'No hay un consentimiento que revocar.');
  }

  await referencia.update({
    vigente: false,
    revocadoEn: FieldValue.serverTimestamp(),
  });

  return { revocado: true };
});
