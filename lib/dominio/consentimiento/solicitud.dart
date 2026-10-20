/// La solicitud de consentimiento: el enlace que se le manda al acudiente.
///
/// Es el **instrumento**, distinto del consentimiento que produce. Separarlos
/// importa: una solicitud puede vencer sin haber producido nada, y un
/// consentimiento sobrevive a la solicitud que lo originó.
///
/// Contrato: `specs/004-cuentas-y-consentimiento/contracts/consentimiento.md`.
library;

/// Por qué no se puede canjear.
///
/// Existe para razonar aquí dentro. **Hacia fuera no se dice cuál de las tres
/// fue**: distinguirlas le diría a quien prueba enlaces cuáles existieron.
enum MotivoDeRechazo { noCoincide, vencida, yaCanjeada }

class SolicitudDeConsentimiento {
  const SolicitudDeConsentimiento({
    required this.id,
    required this.nadadorId,
    required this.resumenDelToken,
    required this.canal,
    required this.emitidaEn,
    required this.venceEn,
    this.canjeadaEn,
  });

  final String id;
  final String nadadorId;

  /// El resumen SHA-256 del token. **El token en claro no se guarda nunca**
  /// (decisión D4).
  ///
  /// Si se guardara, cualquiera con acceso de lectura a la colección podría
  /// consentir en nombre de un acudiente. El token **es** la credencial, y a
  /// una credencial se le aplica lo mismo que a una contraseña.
  final String resumenDelToken;

  /// Adónde se envió. **Lo aporta el entrenador** desde su matrícula, nunca el
  /// nadador (FR-014).
  ///
  /// Es la garantía que cierra el agujero obvio —un niño poniendo un correo
  /// suyo— y la que hace que el resto de la cadena signifique algo.
  final String canal;

  final DateTime emitidaEn;
  final DateTime venceEn;

  final DateTime? canjeadaEn;

  bool get yaSeCanjeo => canjeadaEn != null;

  bool venceAntesDe(DateTime cuando) => !cuando.isBefore(venceEn);

  /// Si se puede canjear con este token, y si no, por qué no.
  ///
  /// Las tres condiciones se comprueban **en el servidor**. Aquí viven para
  /// poder razonarlas y probarlas en Dart puro.
  MotivoDeRechazo? porQueNoSePuedeCanjear({
    required String resumenPresentado,
    required DateTime ahora,
  }) {
    if (yaSeCanjeo) return MotivoDeRechazo.yaCanjeada;
    if (venceAntesDe(ahora)) return MotivoDeRechazo.vencida;
    if (resumenPresentado != resumenDelToken) return MotivoDeRechazo.noCoincide;
    return null;
  }

  bool esUtilizable({
    required String resumenPresentado,
    required DateTime ahora,
  }) =>
      porQueNoSePuedeCanjear(
        resumenPresentado: resumenPresentado,
        ahora: ahora,
      ) ==
      null;

  /// Marca la solicitud como usada. Canjear es **único en su uso**: el segundo
  /// intento con el mismo token no produce un segundo consentimiento ni revive
  /// el primero.
  SolicitudDeConsentimiento canjear(DateTime cuando) =>
      SolicitudDeConsentimiento(
        id: id,
        nadadorId: nadadorId,
        resumenDelToken: resumenDelToken,
        canal: canal,
        emitidaEn: emitidaEn,
        venceEn: venceEn,
        canjeadaEn: cuando,
      );
}
