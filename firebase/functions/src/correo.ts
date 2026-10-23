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
 * Must be an address on a domain verified in Resend. Until one is, Resend only
 * accepts `onboarding@resend.dev`, which works for testing and will land in
 * spam for real families - so verifying the domain is not optional before this
 * is offered to anybody.
 */
export const REMITENTE = defineString('REMITENTE_DE_AVISOS', {
  default: 'onboarding@resend.dev',
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
