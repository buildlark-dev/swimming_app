/**
 * The data subject's own data: correcting it, and erasing it.
 *
 * **Why this is on the server at all.** The rules say `registros` is
 * `allow delete: if false`, `nadadores` is written by the coach only and
 * `usuarios` by nobody. `DerechosDelTitular` in the Dart domain has described
 * what erasure means since feature 004, with tests, and against Firestore it
 * could never run: its tests pass because they run against in-memory
 * repositories. The rule's own comment reserved this to the server — «el
 * derecho al borrado del principio V se ejerce por la vía del servidor, que
 * puede dejar constancia de que se ejerció» — and this is that way (D6).
 *
 * **Why correcting a profile is not `guardarPerfil`.** That one demands
 * `versionDeTerminos` and writes `terminos: { version, aceptadaEn:
 * serverTimestamp() }`. Reusing it to fix a surname would say the person
 * accepted today's version today, when they accepted another one a month ago
 * and nobody has shown them the new one. That falsifies a legal record, so
 * **the word `terminos` must never appear in `corregirPerfilDe`** — and a Dart
 * contract test reads this file to make sure it does not (D5, H21).
 *
 * The logic lives in exported functions and the callable wrappers are thin, so
 * the emulator tests exercise the real code instead of a replica of it.
 */

import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Firestore, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const COL_USUARIOS = 'usuarios';
const COL_NADADORES = 'nadadores';
const COL_REGISTROS = 'registros';
const COL_ASIGNACIONES = 'asignaciones';
const COL_CONSENTIMIENTOS = 'consentimientos';

/** Oldest birth date we accept. Anything before this is a typo, not a person. */
const ANO_MINIMO = 1900;

/** Must match `mayoriaDeEdad` in lib/dominio/cuentas/edad.dart. */
const MAYORIA_DE_EDAD = 18;

export type Correccion = {
  nombre?: string;
  fechaNacimiento?: string;
  pais?: string | null;
};

/** Years completed at a date. Same calculation as edad.dart, deliberately. */
function edadA(nacimiento: Date, referencia: Date): number {
  let edad = referencia.getUTCFullYear() - nacimiento.getUTCFullYear();
  const cumpleEsteAno = new Date(
    Date.UTC(
      referencia.getUTCFullYear(),
      nacimiento.getUTCMonth(),
      nacimiento.getUTCDate()
    )
  );
  if (referencia < cumpleEsteAno) edad--;
  return edad;
}

/**
 * Correct the caller's own profile. Takes no uid: a uid that comes from the
 * client is a uid somebody can point at another person.
 *
 * Writes the name in **both** places it lives — the account document and the
 * swimmer record — because otherwise the coach's panel would keep showing the
 * old one, and the same person would have two names on two screens (H22).
 */
export async function corregirPerfilDe(
  db: Firestore,
  uid: string,
  datos: Correccion
): Promise<{ nombre: string; esMenor: boolean }> {
  const limpio = (datos.nombre ?? '').trim();
  if (!limpio) {
    throw new HttpsError('invalid-argument', 'Falta el nombre.');
  }
  if (limpio.length > 80) {
    throw new HttpsError('invalid-argument', 'Ese nombre es demasiado largo.');
  }

  if (!datos.fechaNacimiento) {
    throw new HttpsError('invalid-argument', 'Falta la fecha de nacimiento.');
  }
  const nacimiento = new Date(datos.fechaNacimiento);
  if (Number.isNaN(nacimiento.getTime())) {
    throw new HttpsError('invalid-argument', 'Esa fecha no se entiende.');
  }
  const ahora = new Date();
  if (nacimiento > ahora || nacimiento.getUTCFullYear() < ANO_MINIMO) {
    throw new HttpsError(
      'invalid-argument',
      'Esa fecha de nacimiento no puede ser.'
    );
  }

  // The country is optional on purpose: it only informs, and a field that
  // decides nothing should not block anybody.
  const pais = datos.pais ?? null;
  if (pais != null && !/^[A-Z]{2}$/.test(pais)) {
    throw new HttpsError('invalid-argument', 'Ese país no se entiende.');
  }

  const usuario = db.collection(COL_USUARIOS).doc(uid);
  const nadadorId = (await usuario.get()).data()?.['nadadorId'] as
    | string
    | undefined;

  // Merge, so this never wipes the `nadadorId` the server put there. That link
  // is the whole reason this collection is server-only.
  await usuario.set(
    { nombre: limpio, fechaNacimiento: datos.fechaNacimiento, pais },
    { merge: true }
  );

  if (nadadorId) {
    await db
      .collection(COL_NADADORES)
      .doc(nadadorId)
      // Merge, so correcting a name never wipes the category the coach set.
      .set(
        { nombre: limpio, fechaNacimiento: datos.fechaNacimiento },
        { merge: true }
      );
  }

  return {
    nombre: limpio,
    esMenor: edadA(nacimiento, ahora) < MAYORIA_DE_EDAD,
  };
}

export type Suprimido = {
  registrosEliminados: number;
  asignacionesRetiradas: number;
  perfilEliminado: boolean;
  cuentaEliminada: boolean;
};

/**
 * Erase the caller's personal data, and their account.
 *
 * Same order `DerechosDelTitular.eliminar` established: what the swimmer
 * wrote first, the account link last.
 *
 * **What survives**: the record that consent was given, with its date. It is
 * the proof that the earlier processing was authorised, and destroying it
 * would leave the coach unable to show he acted with authorisation (guarantee
 * C8 of feature 004). So the consent is revoked and its `historial` is left
 * alone.
 *
 * **The identity account goes too** (D7), confirmed by the coach on
 * 2026-10-27: the email address is personal data, and leaving the account
 * alive would turn the right to erasure into a wipe that leaves the person
 * registered with nothing.
 */
export async function suprimirDatosDe(
  db: Firestore,
  uid: string,
  opciones: { borrarCuenta?: boolean } = {}
): Promise<Suprimido> {
  const usuario = db.collection(COL_USUARIOS).doc(uid);
  const nadadorId =
    ((await usuario.get()).data()?.['nadadorId'] as string | undefined) ?? uid;

  // 1. What the swimmer wrote.
  const registros = await db
    .collection(COL_REGISTROS)
    .where('nadadorId', '==', nadadorId)
    .get();
  await Promise.all(registros.docs.map((d) => d.ref.delete()));

  // 2. What was delivered to them. The plans themselves are the coach's
  //    professional work and carry nobody's data: what goes is the assignment.
  const asignaciones = await db
    .collection(COL_ASIGNACIONES)
    .where('nadadorId', '==', nadadorId)
    .get();
  await Promise.all(asignaciones.docs.map((d) => d.ref.delete()));

  // 3. Their swimmer record.
  const nadador = db.collection(COL_NADADORES).doc(nadadorId);
  const existia = (await nadador.get()).exists;
  if (existia) await nadador.delete();

  // 4. Their personal fields on the account document. The document itself is
  //    deleted, link included: there is no account left to link.
  await usuario.delete();

  // 5. Revoke the consent, and **leave its `historial` subcollection alone**.
  //    That history is the proof the earlier processing was authorised
  //    (guarantee C8), so it is not deleted here and must not be: it is the
  //    one thing that survives this call.
  const consentimiento = db.collection(COL_CONSENTIMIENTOS).doc(nadadorId);
  if ((await consentimiento.get()).exists) {
    await consentimiento.set(
      {
        vigente: false,
        revocadoEn: FieldValue.serverTimestamp(),
        revocadoPor: 'supresion',
      },
      { merge: true }
    );
  }

  // 6. The identity account.
  let cuentaEliminada = false;
  if (opciones.borrarCuenta !== false) {
    try {
      await getAuth().deleteUser(uid);
      cuentaEliminada = true;
    } catch (_) {
      // If the account cannot be deleted, the data is already gone and that is
      // the right the person exercised. Failing the whole call here would make
      // them think nothing happened.
    }
  }

  return {
    registrosEliminados: registros.size,
    asignacionesRetiradas: asignaciones.size,
    perfilEliminado: existia,
    cuentaEliminada,
  };
}

export const corregirPerfil = onCall(async (peticion) => {
  const uid = peticion.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Hay que haber entrado.');
  }

  return corregirPerfilDe(
    getFirestore(),
    uid,
    (peticion.data ?? {}) as Correccion
  );
});

export const suprimirMisDatos = onCall(async (peticion) => {
  const uid = peticion.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Hay que haber entrado.');
  }

  // The second step of the confirmation, reaching the server. A loose call
  // deletes nothing (H27).
  const { confirmado } = (peticion.data ?? {}) as { confirmado?: boolean };
  if (confirmado !== true) {
    throw new HttpsError(
      'failed-precondition',
      'La supresión necesita confirmarse.'
    );
  }

  return suprimirDatosDe(getFirestore(), uid);
});
