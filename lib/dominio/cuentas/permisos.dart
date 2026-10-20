/// Quién puede hacer qué, decidido en un solo sitio.
///
/// Hasta la feature 003 esta decisión vivía repartida por las pantallas: cada
/// una comprobaba lo suyo, y lo que ninguna comprobaba no lo comprobaba nadie.
/// Aquí está entera y en Dart puro.
///
/// **Esta no es la puerta.** Quien hace cumplir el acceso es
/// `firebase/firestore.rules`, en el servidor (decisión D1). Este archivo es la
/// misma decisión escrita del lado del cliente, para no ofrecer en la interfaz
/// lo que el servidor va a denegar, y para poder explicarlo.
///
/// Que las dos escrituras coincidan lo vigila la lista de casos compartida de
/// `test/dominio/cuentas/permisos_test.dart` y de `firebase/test/reglas.test.js`
/// (garantía A10). No hay forma automática de demostrar que dos lenguajes
/// distintos expresan la misma regla; lo que hay es la misma lista de casos en
/// los dos sitios, y la disciplina de ampliarla en los dos.
library;

import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

/// Decide qué puede hacer una cuenta.
///
/// Todas las respuestas son para una cuenta concreta. Sin cuenta no hay
/// permiso: [sinSesion] lo dice de una vez para que nadie tenga que acordarse.
abstract final class Permisos {
  /// Sin sesión iniciada no se obtiene nada de nadie (garantía A6).
  ///
  /// No es una optimización ni una cortesía: las reglas deniegan igual. Está
  /// aquí para que la interfaz no pida lo que sabe que va a rebotar.
  static bool sinSesion(Cuenta? cuenta) => cuenta == null;

  /// Mover un plan a `aprobado` es del entrenador y de nadie más.
  ///
  /// Principio IV: «ningún plan llega a un nadador sin aprobación explícita del
  /// entrenador». Un nadador que pudiera aprobarse su propio plan haría de ese
  /// principio una decoración.
  static bool puedeAprobar(Cuenta? cuenta) => cuenta?.esEntrenador ?? false;

  /// Publicar tampoco. Aprobar no es entregar, y las dos son suyas.
  static bool puedePublicar(Cuenta? cuenta) => cuenta?.esEntrenador ?? false;

  /// Editar un plan: el entrenador, y nunca sobre uno ya inmutable.
  static bool puedeEditarPlan(Cuenta? cuenta, Plan plan) =>
      (cuenta?.esEntrenador ?? false) && !_esInmutable(plan.estado);

  /// Qué planes ve un nadador: solo los **publicados** que le están asignados.
  ///
  /// Las tres condiciones importan por separado. Un plan en `borrador` no es de
  /// nadie todavía; uno `aprobado` está firmado pero no entregado; uno
  /// publicado sin asignar no es de este nadador.
  ///
  /// La asignación entra como dato y no se lee del plan: desde la feature 004
  /// es un documento aparte, uno por nadador, y el plan ya no la lleva dentro.
  static bool puedeLeerPlan(
    Cuenta? cuenta,
    Plan plan, {
    bool leEstaAsignado = false,
  }) {
    if (cuenta == null) return false;
    if (cuenta.esEntrenador) return true;
    if (cuenta.nadadorId == null) return false;

    return plan.estado == EstadoPlan.publicado && leEstaAsignado;
  }

  /// Entregar un plan a un nadador. Es la puerta de publicación (FR-013).
  ///
  /// Una asignación por nadador y no una lista: así cada entrega es una
  /// escritura de una sola persona, y la regla del servidor comprueba **su**
  /// consentimiento con un solo `get()`. Con una lista dentro del plan haría
  /// falta un bucle que el lenguaje de reglas no tiene, y la puerta se
  /// quedaría sin poder hacerse cumplir donde importa.
  static bool puedeAsignar(
    Cuenta? cuenta, {
    required bool tieneConsentimiento,
  }) =>
      (cuenta?.esEntrenador ?? false) && tieneConsentimiento;

  /// Escribir un registro de sesión: **solo el nadador al que pertenece**.
  ///
  /// El entrenador no escribe aquí, y es un cambio deliberado respecto de la
  /// feature 003, donde era el único que podía porque no había identidad de
  /// nadador. Lo que el nadador responde es su carga interna, no la del
  /// entrenador (garantía A5).
  static bool puedeEscribirRegistro(Cuenta? cuenta, String nadadorIdDelRegistro) {
    if (cuenta == null) return false;
    if (cuenta.esEntrenador) return false;
    return cuenta.nadadorId == nadadorIdDelRegistro;
  }

  /// Leer un registro: su dueño, o el entrenador de su comunidad.
  static bool puedeLeerRegistro(
    Cuenta? cuenta,
    String nadadorIdDelRegistro, {
    required bool esDeSuComunidad,
  }) {
    if (cuenta == null) return false;
    if (cuenta.esEntrenador) return esDeSuComunidad;
    return cuenta.nadadorId == nadadorIdDelRegistro;
  }

  /// Emitir una solicitud de consentimiento: solo el entrenador.
  ///
  /// Es la garantía C1, y es la que cierra el agujero de que un menor designe
  /// quién consiente por él. El canal sale de la matrícula del entrenador.
  static bool puedeEmitirSolicitud(Cuenta? cuenta) =>
      cuenta?.esEntrenador ?? false;

  /// Leer el consentimiento de un nadador: él mismo, o su entrenador.
  static bool puedeLeerConsentimiento(
    Cuenta? cuenta,
    String nadadorId, {
    required bool esDeSuComunidad,
  }) {
    if (cuenta == null) return false;
    if (cuenta.esEntrenador) return esDeSuComunidad;
    return cuenta.nadadorId == nadadorId;
  }

  /// **Nadie** escribe consentimientos ni solicitudes desde el cliente.
  ///
  /// Ni el entrenador. La fecha la pone el servidor (D5) y el canje lo hace el
  /// servidor (D4); si el cliente pudiera escribir aquí, las dos garantías
  /// serían declaraciones suyas.
  static bool puedeEscribirConsentimiento(Cuenta? cuenta) => false;

  static bool _esInmutable(EstadoPlan estado) =>
      estado == EstadoPlan.aprobado || estado == EstadoPlan.publicado;
}
