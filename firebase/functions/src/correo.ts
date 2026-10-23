/**
 * Sending the guardian's link by email.
 *
 * Feature 004 left this as a port with nothing plugged into it: the default
 * notifier wrote a log line and that was all. The consequence only became
 * visible once the chain was wired - a twelve-year-old finished signing up,
 * the app told her an email had gone to her mother, and nothing had been sent.
 *
 * This is the thing that was behind the plug.
 *
 * **The API key never lives in this repository.** It comes from Firebase
 * secrets, which is Secret Manager underneath, and the function receives it at
 * runtime. A key in git is a key in every clone of a public repository.
 */

import { defineSecret, defineString } from 'firebase-functions/params';
import { logger } from 'firebase-functions';

import type { EnviadorDeAvisos } from './consentimiento';

/** Set with: firebase functions:secrets:set RESEND_API_KEY */
export const CLAVE_DE_RESEND = defineSecret('RESEND_API_KEY');

/**
 * Who the email comes from.
 *
 * Must be an address on a domain verified in Resend - buildlark.com is. The
 * alternative Resend offers before verification, `onboarding@resend.dev`,
 * lands in spam, and for a guardian a link in spam and a link never sent are
 * the same thing.
 *
 * **Temporary**: this is a BuildLark address because the app has no name of
 * its own yet. It changes when it has one, and it is a parameter rather than a
 * literal precisely so that change is a deploy and not an edit.
 *
 * The display name is not decoration. An email asking a parent to authorise
 * something about their child, arriving from a bare address, reads like
 * phishing.
 */
export const REMITENTE = defineString('REMITENTE_DE_AVISOS', {
  default: 'Natación <natacion@buildlark.com>',
});

/**
 * Where the app is served.
 *
 * The link in the email has to be absolute. It used to be built as
 * `/consentimiento?t=...`, which is a path: fine inside a page, useless in an
 * inbox. Nobody noticed because no email was ever sent.
 */
export const BASE_DE_LA_APP = defineString('BASE_DE_LA_APP', {
  default: 'https://swimming-app-ab45f.web.app',
});

export const enviadorResend: EnviadorDeAvisos = {
  async enviar(destino, asunto, cuerpo) {
    const clave = CLAVE_DE_RESEND.value();

    if (!clave) {
      // Degrade loudly rather than pretend. A consent request that was never
      // sent must not look like one that was.
      logger.error('no hay clave de correo: el aviso no se envió');
      throw new Error('El canal de correo no está configurado.');
    }

    const respuesta = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${clave}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: REMITENTE.value(),
        to: [destino],
        subject: asunto,
        text: cuerpo,
      }),
    });

    if (!respuesta.ok) {
      // **Neither the address nor the body is logged.** The body carries the
      // token, which is the credential that authorises processing a minor's
      // data; the address identifies the child's family. Guarantee A17.
      logger.error('el servicio de correo rechazó el aviso', {
        estado: respuesta.status,
      });
      throw new Error('No se pudo enviar el aviso al acudiente.');
    }
  },
};
