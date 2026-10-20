/// A quién se le entregó un plan.
///
/// **Es una relación, no un campo del plan.** Hasta la feature 004 un plan
/// llevaba dentro la lista de sus nadadores, y eso tenía dos problemas:
///
/// 1. Un plan aprobado es inmutable, así que asignarle alguien después
///    obligaba a escribir sobre algo que no debe cambiar.
/// 2. Las reglas de acceso **no pueden recorrer una lista**. Para comprobar el
///    consentimiento de los quince niños de un grupo haría falta un bucle que
///    el lenguaje de reglas no tiene, y la puerta de publicación se quedaba
///    sin poder hacerse cumplir en el servidor.
///
/// Con una asignación por nadador, cada entrega es una escritura de un solo
/// nadador y la regla hace **un** `get()` para comprobar su consentimiento.
///
/// Contrato: `specs/004-cuentas-y-consentimiento/contracts/consentimiento.md`,
/// garantía P5.
library;

class Asignacion {
  const Asignacion({
    required this.planId,
    required this.nadadorId,
    required this.asignadaEn,
  });

  final String planId;
  final String nadadorId;

  /// Cuándo se entregó. La pone el servidor, igual que la del consentimiento.
  final DateTime asignadaEn;

  /// Identificador determinista, igual que el del registro del nadador.
  ///
  /// Entregar dos veces el mismo plan a la misma persona escribe el mismo
  /// documento, así que no se duplica. No por una comprobación que alguien
  /// pueda olvidar, sino porque no hay otro documento que escribir.
  String get id => idDeterminista(planId: planId, nadadorId: nadadorId);

  static String idDeterminista({
    required String planId,
    required String nadadorId,
  }) =>
      '$planId|$nadadorId';

  @override
  bool operator ==(Object other) =>
      other is Asignacion &&
      other.planId == planId &&
      other.nadadorId == nadadorId;

  @override
  int get hashCode => Object.hash(planId, nadadorId);

  @override
  String toString() => 'Asignacion($planId -> $nadadorId)';
}
