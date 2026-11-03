/**
 * The server's surface.
 *
 * Feature 004 committed to four operations — assign the role claim, issue a
 * consent request, redeem the confirmation, revoke a consent — and said a
 * fifth would get discussed before it got written. Feature 006 added the
 * fifth, `guardarPerfil`, because `usuarios/{uid}` is server-write-only.
 *
 * Feature 007 adds two more, and the discussion is in its research.md:
 *
 *   - `corregirPerfil` (D5), because reusing `guardarPerfil` to fix a surname
 *     would re-stamp which version of the terms the person accepted and when.
 *   - `suprimirMisDatos` (D6), because the rules deny the client every write
 *     that erasure needs. `DerechosDelTitular` described what erasure means
 *     back in 004 and could never run against Firestore.
 *
 * What never enters here: methodology, plan generation, auditing, or any
 * domain rule. Those live in Dart, in `lib/dominio/`.
 */

import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { alCrearseUnaCuenta, asignarRol } from './roles';
export { emitirSolicitud, canjear, revocar } from './consentimiento';
export { guardarPerfil } from './perfil';
export { corregirPerfil, suprimirMisDatos } from './datos_personales';
export { cerrarPeticion } from './peticiones';
