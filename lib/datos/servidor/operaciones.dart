/// Las operaciones del servidor, vistas desde la app.
///
/// **Este es el único archivo del proyecto que importa `cloud_functions`**, por
/// la misma razón que `sesion_firebase.dart` es el único que importa
/// `firebase_auth`: el dominio habla de perfiles, solicitudes y
/// consentimientos, no de llamadas remotas, y una prueba de frontera vigila
/// que no se cuele más adentro (principio II).
///
/// Hasta la feature 006 el cliente **nunca había llamado a una función**. Las
/// cuatro operaciones de la feature 004 existían en el servidor y se invocaban
/// desde los scripts de administración; la app no las tocaba. Eso dejaba la
/// cadena de consentimiento construida y desenchufada (decisión D10): la
/// puerta cerraba, el formulario existía, y nada los unía.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';

/// Lo que puede salir mal al llamar al servidor, dicho en español.
///
/// Se traduce aquí a propósito. Un código de error de Firebase en pantalla no
/// le dice nada a un entrenador ni a un acudiente, y lo que tienen que saber es
/// qué hacer.
class FalloDelServidor implements Exception {
  const FalloDelServidor(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Lo que la app necesita del servidor. En términos del dominio.
///
/// Es una interfaz para que las pruebas puedan montar las pantallas sin
/// servidor, igual que el resto de repositorios del proyecto.
/// Lo que el servidor contesta al guardar un perfil.
class PerfilGuardado {
  const PerfilGuardado({required this.esMenor, required this.nadadorId});

  final bool esMenor;

  /// Quién es, para la matrícula y para el consentimiento.
  ///
  /// Lo crea el alta si no existía: la feature 004 daba por hecho que el
  /// entrenador matricula primero, y en una app abierta la persona llega
  /// antes que la matrícula.
  final String nadadorId;
}

/// El cuerpo que espera `canjear` en el servidor.
///
/// **Los datos del acudiente van anidados en `declaracion`**, no sueltos. Esto
/// es una función con nombre y con prueba porque ya se escribió mal una vez:
/// se mandaron planos, el servidor leyó `declaracion` como indefinida, y un
/// acudiente con el formulario entero relleno veía «Hace falta quién es usted
/// y en qué calidad actúa».
///
/// Los dobles de las pruebas implementan la interfaz, no el cable, así que
/// ninguna de las diez pruebas del camino del acudiente podía verlo. Esta sí.
Map<String, dynamic> cuerpoDeCanje({
  required String token,
  required String nombre,
  required String documento,
  required String calidad,
  required bool esRepresentanteLegal,
  required bool menorFueOido,
  required String versionDelTexto,
}) =>
    {
      'token': token,
      'declaracion': {
        'nombre': nombre,
        'documento': documento,
        'calidad': calidad,
        'esRepresentanteLegal': esRepresentanteLegal,
        'menorFueOido': menorFueOido,
        'versionDelTexto': versionDelTexto,
      },
    };

abstract class OperacionesDelServidor {
  /// Guarda el perfil de quien llama.
  ///
  /// **El servidor recalcula la minoría de edad**: el cliente podría mentir, y
  /// la puerta que viene después tiene que trabajar sobre algo que el servidor
  /// comprobó.
  ///
  /// Y devuelve el `nadadorId`, que **puede no haber existido hasta ahora**:
  /// quien se da de alta es un nadador desde ese momento, y antes de guardar
  /// el perfil no había a quién pedirle el consentimiento.
  Future<PerfilGuardado> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  });

  /// Pide el consentimiento de un acudiente a una dirección.
  Future<void> pedirConsentimiento({
    required String nadadorId,
    required String canal,
    Set<Alcance> alcances,
  });

  /// Canjea el enlace que abrió el acudiente y registra su autorización.
  ///
  /// **No hace falta haber entrado**: el acudiente no tiene cuenta, y ese es el
  /// punto de todo el mecanismo.
  Future<void> canjear({
    required String token,
    required String nombre,
    required String documento,
    required String calidad,
    required bool esRepresentanteLegal,
    required bool menorFueOido,
    required String versionDelTexto,
  });
}

class OperacionesFirebase implements OperacionesDelServidor {
  OperacionesFirebase({FirebaseFunctions? funciones})
      : _funciones = funciones ?? FirebaseFunctions.instance;

  final FirebaseFunctions _funciones;

  /// Como `SesionFirebase.porOmision`: deja que `main.dart` no nombre nunca a
  /// `cloud_functions`.
  factory OperacionesFirebase.porOmision({
    bool usarEmuladores = false,
    String hostEmulador = 'localhost',
    int puertoEmulador = 5001,
  }) {
    final funciones = FirebaseFunctions.instance;
    if (usarEmuladores) {
      funciones.useFunctionsEmulator(hostEmulador, puertoEmulador);
    }
    return OperacionesFirebase(funciones: funciones);
  }

  @override
  Future<PerfilGuardado> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async {
    final respuesta = await _llamar('guardarPerfil', {
      'nombre': nombre,
      // Solo la fecha, sin hora: lo que se guarda es un día, no un instante.
      'fechaNacimiento':
          fechaNacimiento.toIso8601String().split('T').first,
      'pais': pais,
      'versionDeTerminos': versionDeTerminos,
    });

    return PerfilGuardado(
      // Ante la duda, menor: el error de pedir un consentimiento que no hacía
      // falta se arregla; el de no pedirlo, no.
      esMenor: (respuesta?['esMenor'] as bool?) ?? true,
      nadadorId: (respuesta?['nadadorId'] as String?) ?? '',
    );
  }

  @override
  Future<void> pedirConsentimiento({
    required String nadadorId,
    required String canal,
    Set<Alcance> alcances = const {Alcance.datosDeEntrenamiento},
  }) async {
    await _llamar('emitirSolicitud', {
      'nadadorId': nadadorId,
      'canal': canal,
      'alcances': alcances.map((a) => a.clave).toList(),
    });
  }

  @override
  Future<void> canjear({
    required String token,
    required String nombre,
    required String documento,
    required String calidad,
    required bool esRepresentanteLegal,
    required bool menorFueOido,
    required String versionDelTexto,
  }) async {
    await _llamar('canjear', cuerpoDeCanje(
      token: token,
      nombre: nombre,
      documento: documento,
      calidad: calidad,
      esRepresentanteLegal: esRepresentanteLegal,
      menorFueOido: menorFueOido,
      versionDelTexto: versionDelTexto,
    ));
  }

  Future<Map<String, dynamic>?> _llamar(
    String nombre,
    Map<String, dynamic> datos,
  ) async {
    try {
      final resultado = await _funciones.httpsCallable(nombre).call(datos);
      final devuelto = resultado.data;
      return devuelto is Map ? Map<String, dynamic>.from(devuelto) : null;
    } on FirebaseFunctionsException catch (e) {
      // El servidor ya manda sus mensajes en español y pensados para quien los
      // lee. Si no hubiera, se dice algo útil en lugar de un código.
      throw FalloDelServidor(
        e.message?.trim().isNotEmpty == true
            ? e.message!
            : 'No se pudo completar. Inténtalo otra vez en un momento.',
      );
    } catch (_) {
      // Sin red, sin servidor, o cualquier otra cosa. Lo que importa es que
      // quien lo lee sepa que no es culpa suya.
      throw const FalloDelServidor(
        'No se pudo conectar. Revisa tu internet e inténtalo otra vez.',
      );
    }
  }
}
