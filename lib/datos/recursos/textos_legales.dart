/// Los textos legales, empaquetados y versionados.
///
/// Van con la app y no se descargan, por lo mismo que la tipografía de la
/// feature 005: leer el texto que uno acepta no puede depender de que haya
/// internet.
///
/// **Versionados** porque la pregunta que alguien hará algún día es «¿qué
/// aceptó esta familia exactamente?», y la única respuesta útil es el texto que
/// leyeron, no el de hoy. Cambiar el texto no reescribe lo que alguien ya
/// aceptó.
library;

import 'package:flutter/services.dart' show rootBundle;

/// La versión vigente del texto de consentimiento.
const String versionDelConsentimiento = 'v1';

/// La versión vigente de los términos y condiciones.
const String versionDeLosTerminos = 'v1';

class CargadorTextosLegales {
  const CargadorTextosLegales({this.cargar = _delPaquete});

  /// `rootBundle.loadString` no es constante, así que no puede ser un valor
  /// por omisión directamente.
  static Future<String> _delPaquete(String ruta) => rootBundle.loadString(ruta);

  /// Inyectado para que las pruebas no necesiten el paquete de recursos.
  final Future<String> Function(String) cargar;

  /// El texto informativo que lee un acudiente antes de autorizar.
  Future<String> consentimiento([
    String version = versionDelConsentimiento,
  ]) =>
      cargar('assets/consentimiento/texto_$version.md');

  /// Los términos y condiciones que se aceptan en el registro.
  Future<String> terminos([String version = versionDeLosTerminos]) =>
      cargar('assets/terminos/texto_$version.md');
}
