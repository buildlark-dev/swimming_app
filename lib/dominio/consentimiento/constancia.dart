/// La constancia de un consentimiento: qué se autorizó, en qué versión y
/// cuándo.
///
/// La feature 004 la guarda; aquí se **lee**, para que la persona pueda ver en
/// `Ajustes` lo que su acudiente autorizó y bajo qué texto. Un consentimiento
/// que no se puede consultar es un consentimiento que hay que creer de palabra.
library;

import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';

class ConstanciaDeConsentimiento {
  const ConstanciaDeConsentimiento({
    required this.vigente,
    required this.alcances,
    this.versionDelTexto,
    this.otorgadoEn,
    this.revocadoEn,
  });

  final bool vigente;
  final Set<Alcance> alcances;

  /// Qué versión del texto informativo leyó quien autorizó.
  ///
  /// Puede faltar en los consentimientos más viejos, y entonces se dice que no
  /// consta en lugar de mostrar el texto de hoy como si fuera aquel.
  final String? versionDelTexto;

  final DateTime? otorgadoEn;
  final DateTime? revocadoEn;
}

abstract class LectorDeConstancias {
  /// La constancia de un nadador, o nula si no hay ninguna.
  Future<ConstanciaDeConsentimiento?> de(String nadadorId);
}
