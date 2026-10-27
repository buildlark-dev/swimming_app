/// La respuesta del nadador a una sesión.
///
/// Contrato: `specs/003-consumo-del-nadador/contracts/registro_del_nadador.md`.
///
/// Es el principio VIII de la constitución convertido en entidad: «el nadador
/// DEBE poder registrar, por sesión: si la cumplió, su RPE percibido (Borg
/// 0-10) y observaciones en texto libre».
///
/// **Esta entidad no contiene metros, series ni zonas, y es a propósito.** Eso
/// es carga externa y vive en el plan. El principio VIII exige que la carga
/// externa y la interna se almacenen y se muestren por separado y que NO se
/// combinen en un mismo indicador; dejarlas en entidades distintas hace que
/// combinarlas no sea un error posible, sino algo que habría que ir a buscar a
/// propósito.
///
/// **Un plan aprobado es inmutable.** Este registro *apunta* a la sesión; no la
/// modifica. La relación es en un solo sentido: el registro conoce la sesión, la
/// sesión no conoce el registro.
library;

/// Reporte de dolor, lesión o malestar.
///
/// Va en un campo propio y no dentro de las observaciones generales porque el
/// principio VIII lo exige: «un reporte de dolor, lesión o malestar se marca
/// **aparte** del resto de observaciones, llega al entrenador y NO DEBE
/// resolverse de forma automática».
///
/// Si viviera dentro del texto libre, encontrarlo dependería de que alguien
/// leyera todas las observaciones de todas las sesiones.
class ReporteDeMolestia {
  const ReporteDeMolestia({required this.descripcion, this.zonaDelCuerpo = ''});

  final String descripcion;

  /// Texto libre a propósito: no se ofrece una lista cerrada. No somos quién
  /// para acotar el vocabulario con que alguien describe lo que le duele.
  final String zonaDelCuerpo;

  bool get estaVacio => descripcion.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is ReporteDeMolestia &&
      other.descripcion == descripcion &&
      other.zonaDelCuerpo == zonaDelCuerpo;

  @override
  int get hashCode => Object.hash(descripcion, zonaDelCuerpo);
}

/// RPE fuera de la escala de Borg.
class RpeFueraDeEscala implements Exception {
  const RpeFueraDeEscala(this.valor);

  final int valor;

  @override
  String toString() =>
      'RPE $valor fuera de la escala de Borg 0-10 (sección 9 de la metodología)';
}

class RegistroDeSesion {
  /// Construye un registro, validando el RPE.
  ///
  /// Lanza [RpeFueraDeEscala] si el RPE viene fuera de 0-10. No se recorta ni
  /// se ajusta al límite más cercano: la regla R3 dice preguntar, no suponer, y
  /// un RPE de 11 es un dato que alguien tiene que mirar.
  factory RegistroDeSesion({
    required String nadadorId,
    required String planId,
    required String sesionId,
    required String versionDePlan,
    required bool realizada,
    required DateTime registradoEn,
    int? rpePercibido,
    String observaciones = '',
    ReporteDeMolestia? molestia,
    DateTime? recibidoEn,
  }) {
    if (rpePercibido != null && (rpePercibido < 0 || rpePercibido > 10)) {
      throw RpeFueraDeEscala(rpePercibido);
    }

    return RegistroDeSesion._(
      id: idDeterminista(
        nadadorId: nadadorId,
        planId: planId,
        sesionId: sesionId,
        versionDePlan: versionDePlan,
      ),
      nadadorId: nadadorId,
      planId: planId,
      sesionId: sesionId,
      versionDePlan: versionDePlan,
      realizada: realizada,
      registradoEn: registradoEn,
      rpePercibido: rpePercibido,
      observaciones: observaciones,
      molestia: molestia,
      recibidoEn: recibidoEn,
    );
  }

  const RegistroDeSesion._({
    required this.id,
    required this.nadadorId,
    required this.planId,
    required this.sesionId,
    required this.versionDePlan,
    required this.realizada,
    required this.registradoEn,
    required this.rpePercibido,
    required this.observaciones,
    required this.molestia,
    required this.recibidoEn,
  });

  /// Identificador **determinista**, derivado de a quién, a qué plan, a qué
  /// sesión y bajo qué versión.
  ///
  /// Decisión D2 de `research.md`. Es lo que hace que reenviar un registro
  /// sobrescriba en vez de duplicar (FR-020): la duplicación se vuelve
  /// imposible por construcción, no por una comprobación que alguien pueda
  /// olvidar.
  ///
  /// Hay exactamente un registro por nadador, sesión y versión de plan. Si
  /// algún día la respuesta pasa a ser un historial de ediciones, esta decisión
  /// se revisa.
  static String idDeterminista({
    required String nadadorId,
    required String planId,
    required String sesionId,
    required String versionDePlan,
  }) => '$nadadorId|$planId|$sesionId|$versionDePlan';

  final String id;
  final String nadadorId;
  final String planId;
  final String sesionId;

  /// Bajo qué versión del plan entrenó el nadador.
  ///
  /// Un plan corregido crea otra versión; esta sigue apuntando a la que él
  /// vivió. Sin esto, un plan corregido haría parecer que respondió a series
  /// que nunca hizo.
  final String versionDePlan;

  final bool realizada;

  /// Hora del **dispositivo**: cuándo entrenó. Es la que ve el entrenador.
  final DateTime registradoEn;

  /// Hora del **servidor**, al llegar. Ordena y permite detectar un reloj
  /// desajustado (decisión D3). Nula mientras el registro no haya viajado.
  final DateTime? recibidoEn;

  /// Borg 0-10. **Nulo es válido**: anotar no es obligatorio (FR-010).
  final int? rpePercibido;

  /// Texto libre. Se guarda **tal cual**: no es la notación del entrenador, no
  /// se analiza, no se corrige y no se normaliza.
  final String observaciones;

  final ReporteDeMolestia? molestia;

  bool get tieneMolestia => molestia != null && !molestia!.estaVacio;

  /// Verdadero si el nadador no anotó nada más allá de marcar la sesión.
  ///
  /// No es un defecto: un nadador que solo marca y se va usó la app bien.
  bool get soloMarcada =>
      rpePercibido == null && observaciones.trim().isEmpty && !tieneMolestia;

  /// Diferencia entre la hora del dispositivo y la del servidor.
  ///
  /// Nula si todavía no ha llegado. Se **muestra** cuando es absurda; no se
  /// corrige (regla R3: ante un dato que no cuadra se avisa, no se supone).
  Duration? get desfaseDeReloj {
    final recibido = recibidoEn;
    if (recibido == null) return null;
    return recibido.difference(registradoEn);
  }

  RegistroDeSesion copiarCon({
    bool? realizada,
    DateTime? registradoEn,
    int? rpePercibido,
    String? observaciones,
    ReporteDeMolestia? molestia,
    DateTime? recibidoEn,
    bool quitarMolestia = false,
    bool quitarRpe = false,
  }) {
    return RegistroDeSesion(
      nadadorId: nadadorId,
      planId: planId,
      sesionId: sesionId,
      versionDePlan: versionDePlan,
      realizada: realizada ?? this.realizada,
      registradoEn: registradoEn ?? this.registradoEn,
      rpePercibido: quitarRpe ? null : (rpePercibido ?? this.rpePercibido),
      observaciones: observaciones ?? this.observaciones,
      molestia: quitarMolestia ? null : (molestia ?? this.molestia),
      recibidoEn: recibidoEn ?? this.recibidoEn,
    );
  }

  @override
  bool operator ==(Object other) => other is RegistroDeSesion && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RegistroDeSesion($id, realizada: $realizada)';
}
