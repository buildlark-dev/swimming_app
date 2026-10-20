/**
 * Server surface for feature 004.
 *
 * Four operations and no more, as research.md D3 commits:
 *
 *   1. assign the role claim
 *   2. issue a consent request
 *   3. redeem the confirmation and record the consent
 *   4. revoke a consent
 *
 * What never enters here: methodology, plan generation, auditing, or any
 * domain rule. Those live in Dart, in `lib/dominio/`. If a fifth operation
 * ever seems necessary, it gets discussed before it gets written.
 */

import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { alCrearseUnaCuenta, asignarRol } from './roles';
export { emitirSolicitud, canjear, revocar } from './consentimiento';
