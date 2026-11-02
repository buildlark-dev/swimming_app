/// Las preferencias del **dispositivo**, no de la persona.
///
/// Viven fuera del almacén por cuenta a propósito. `AlmacenPreferencias` guarda
/// todo bajo `natacion_app/<cuentaId>/` y `cerrarSesion()` llama a `vaciar()`,
/// que borra ese prefijo entero —la feature 006 lo dejó así porque el grupo son
/// hermanos que comparten teléfono—. Una preferencia guardada ahí desaparecería
/// cada vez que alguien saliera (decisión D4).
///
/// Y es correcto que sobreviva: quien tiene el teléfono al sol lo quiere claro,
/// y el hermano que entra después, también. **No es un dato personal y no viaja
/// al servidor.**
///
/// Por eso las claves de aquí no empiezan por `natacion_app/`: así ningún
/// `vaciar()` de ninguna cuenta puede alcanzarlas.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Claro, oscuro, o lo que diga el teléfono.
enum Apariencia {
  claro('claro', 'Clara'),
  oscuro('oscuro', 'Oscura'),
  delSistema('sistema', 'La del teléfono');

  const Apariencia(this.clave, this.etiqueta);

  final String clave;

  /// Como se lee en Ajustes.
  final String etiqueta;

  static Apariencia porClave(String? clave) {
    for (final apariencia in values) {
      if (apariencia.clave == clave) return apariencia;
    }
    return delSistema;
  }
}

class PreferenciasDelDispositivo {
  const PreferenciasDelDispositivo();

  /// **No empieza por `natacion_app/`**, que es el prefijo que `vaciar()`
  /// borra al cerrar sesión.
  static const String claveApariencia = 'dispositivo/apariencia';

  /// En modo local no hay rol que consultar, así que el recorrido se elige a
  /// propósito y se recuerda (decisión D13).
  static const String claveRecorridoLocal = 'dispositivo/recorrido_local';

  Future<Apariencia> apariencia() async {
    // Si no se puede leer, se usa la del teléfono y **no se trata como un
    // fallo**: una preferencia que no se pudo leer no justifica una pantalla
    // de error.
    try {
      final prefs = await SharedPreferences.getInstance();
      return Apariencia.porClave(prefs.getString(claveApariencia));
    } catch (_) {
      return Apariencia.delSistema;
    }
  }

  Future<void> guardarApariencia(Apariencia apariencia) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(claveApariencia, apariencia.clave);
    } catch (_) {
      // Sin almacenamiento, la elección vale para esta sesión y no se guarda.
      // Dejar la app sin abrir por esto sería desproporcionado.
    }
  }

  Future<String?> recorridoLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(claveRecorridoLocal);
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarRecorridoLocal(String clave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(claveRecorridoLocal, clave);
    } catch (_) {
      // Lo mismo: es una comodidad de desarrollo, no un dato.
    }
  }
}
