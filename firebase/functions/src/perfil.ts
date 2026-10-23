/**
 * The account profile: who the person behind the email is.
 *
 * This exists on the server for one reason, and it is not the name. The rules
 * say `usuarios/{uid}` is `allow write: if false`, and the comment there
 * explains why: "si el cliente pudiera, cualquiera se declararia dueno del
 * perfil de otro y leeria sus planes". That document carries the link between
 * an account and a swimmer, which is what decides whose training you can see.
 *
 * Loosening the rule so somebody could write their own name would loosen that
 * too. So the name comes through here instead, where the server can make sure
 * you are only ever writing your own (decision D3).
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const COL_USUARIOS = 'usuarios';
const COL_NADADORES = 'nadadores';

/** Oldest birth date we accept. Anything before this is a typo, not a person. */
const ANO_MINIMO = 1900;

/** Must match `mayoriaDeEdad` in lib/dominio/cuentas/edad.dart. */
const MAYORIA_DE_EDAD = 18;

type Perfil = {
  nombre?: string;
  fechaNacimiento?: string;
  pais?: string | null;
  versionDeTerminos?: string;
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
 * Save the caller's own profile.
 *
 * Takes no uid: the only profile you can write is yours. Accepting one and
 * checking it matches would be the same thing with an extra way to get it
 * wrong.
 */
export const guardarPerfil = onCall(async (peticion) => {
  const uid = peticion.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Hay que haber entrado.');
  }

  const { nombre, fechaNacimiento, pais, versionDeTerminos } = (peticion.data ??
    {}) as Perfil;

  const limpio = (nombre ?? '').trim();
  if (!limpio) {
    throw new HttpsError('invalid-argument', 'Falta el nombre.');
  }
  if (limpio.length > 80) {
    throw new HttpsError('invalid-argument', 'Ese nombre es demasiado largo.');
  }

  if (!fechaNacimiento) {
    throw new HttpsError('invalid-argument', 'Falta la fecha de nacimiento.');
  }
  const nacimiento = new Date(fechaNacimiento);
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

  if (!versionDeTerminos) {
    throw new HttpsError(
      'invalid-argument',
      'Falta aceptar los términos y condiciones.'
    );
  }

  // The country is optional on purpose: it only informs, and a field that
  // decides nothing should not block anybody (FR-009).
  if (pais != null && !/^[A-Z]{2}$/.test(pais)) {
    throw new HttpsError('invalid-argument', 'Ese país no se entiende.');
  }

  const esMenor = edadA(nacimiento, ahora) < MAYORIA_DE_EDAD;

  // **Signing up creates the swimmer too.**
  //
  // Feature 004 assumed a closed club: the coach enrols somebody and then asks
  // for their guardian's consent. This app is open to anyone, in or out of a
  // club, so the person arrives before any enrolment - and the whole consent
  // mechanism is keyed by nadadorId. Without one, the request was rejected and
  // no email was ever sent.
  //
  // So whoever signs up is a swimmer from that moment. What the coach still
  // decides is their category and target stroke, which `Nadador.faltas`
  // already models as an incomplete profile.
  //
  // The id is the account's uid: one person, one id, and the consent key is
  // stable without an extra lookup.
  const usuario = getFirestore().collection(COL_USUARIOS).doc(uid);
  const yaExiste = (await usuario.get()).data()?.['nadadorId'] as
    | string
    | undefined;
  const nadadorId = yaExiste ?? uid;

  if (!yaExiste) {
    await getFirestore()
      .collection(COL_NADADORES)
      .doc(nadadorId)
      // Merge, so re-running sign-up never wipes the category a coach set.
      .set({ nombre: limpio, fechaNacimiento }, { merge: true });
  }

  await usuario.set(
      {
        nombre: limpio,
        fechaNacimiento,
        pais: pais ?? null,
        terminos: {
          version: versionDeTerminos,
          aceptadaEn: FieldValue.serverTimestamp(),
        },
        nadadorId,
        perfilCompletadoEn: FieldValue.serverTimestamp(),
      },
      // Merge, so writing the profile never wipes the `nadadorId` the server
      // put there when the coach linked this account to a swimmer. That link
      // is the whole reason this collection is server-only.
      { merge: true }
    );

  // The birth date is the server's business too: the client could lie about
  // being an adult, and the gate that follows has to work off something the
  // server computed.
  // El cliente necesita el id para pedir el consentimiento: al arrancar el
  // alta todavía no existía.
  return { esMenor, nadadorId };
});
