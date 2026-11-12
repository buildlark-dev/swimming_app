/// Conexión a Firestore.
///
/// Mientras se desarrolla en local, la app apunta a los **emuladores**, nunca a
/// un proyecto real. La bandera `USAR_EMULADORES` es falsa por omisión, de modo
/// que un arranque descuidado no escriba en la nube.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'package:natacion_app/firebase_options.dart';

/// Identificador ficticio. Los emuladores lo aceptan sin que exista nada en la
/// nube, y así no hay riesgo de tocar un proyecto real por descuido.
const String proyectoLocal = 'demo-natacion';

/// El nombre de la app de Firebase que se usa contra los emuladores.
///
/// Tiene nombre propio para no pisar la que Android e iOS ya inicializaron con
/// `google-services.json`: si se usara aquella, los datos del emulador caerían
/// bajo el proyecto de verdad y las herramientas, que hablan de
/// `demo-natacion`, mirarían otra base.
const String nombreDeLaAppLocal = 'emuladores';

/// La app de Firebase que esta app usa, según dónde esté.
FirebaseApp appDeFirebase({required bool usarEmuladores}) =>
    usarEmuladores ? Firebase.app(nombreDeLaAppLocal) : Firebase.app();

/// Dónde están los emuladores, **visto desde donde corre la app**.
///
/// En el emulador de Android, `localhost` es el propio teléfono emulado: la
/// máquina que ejecuta los emuladores de Firebase es `10.0.2.2`. Sin esta
/// distinción, probar en Android contra los emuladores falla con un error de
/// conexión que parece un problema de Firebase y no lo es.
///
/// En un teléfono de verdad conectado por cable no vale ninguno de los dos:
/// hay que poner la IP del portátil en la red local. Eso se hace a mano, y
/// está escrito en `docs/DEVELOPMENT.md`.
String get hostEmulador =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? '10.0.2.2'
    : 'localhost';
const int puertoFirestore = 8080;

/// Cómo se arranca Firebase. Se inyecta para poder comprobar en pruebas que un
/// arranque fallido deja la app en pie; en producción es siempre la de verdad.
typedef IniciarFirebase =
    Future<FirebaseApp> Function({String? name, FirebaseOptions? options});

class ConfiguracionDatos {
  const ConfiguracionDatos({
    required this.usarEmuladores,
    this.iniciar = Firebase.initializeApp,
  });

  final bool usarEmuladores;

  final IniciarFirebase iniciar;

  /// Opciones con las que se arranca Firebase.
  ///
  /// Contra emuladores, un proyecto ficticio: así un arranque descuidado no
  /// escribe en la nube. Sin emuladores, las del proyecto real, que genera
  /// `flutterfire configure` en `lib/firebase_options.dart`.
  ///
  /// La clave web que hay ahí **no es una credencial**: identifica el proyecto
  /// ante Google y viaja en el JavaScript de cualquier app web de Firebase.
  /// Lo que protege los datos son las reglas de `firestore.rules`, que es por
  /// lo que están probadas como están.
  FirebaseOptions get opciones => usarEmuladores
      // **Con forma válida, aunque sean de mentira.** En web cualquier cadena
      // vale; Android comprueba la **forma** del identificador de aplicación y
      // la de la clave en cuanto se llama a una API de servidor, y con cadenas
      // libres el borrado de datos moría primero con «Please set your
      // Application ID» y después con «Please set a valid API key». Lo dijo la
      // app en el teléfono las dos veces, no una prueba.
      //
      // Ninguna de las dos identifica nada: el proyecto es `demo-natacion`,
      // que no existe, y todo el tráfico va a los emuladores. Lo único que se
      // les pide es tener la forma que Android exige.
      ? const FirebaseOptions(
          apiKey: 'AIzaSyDemoEmuladorLocalNoEsUnaClave1234',
          appId: '1:000000000000:android:0000000000000000',
          messagingSenderId: '000000000000',
          projectId: proyectoLocal,
        )
      : DefaultFirebaseOptions.currentPlatform;

  /// Arranca Firebase. **Contra emuladores, con una app propia y con nombre.**
  ///
  /// Dos cosas obligan a esto, y las dos se vieron en un teléfono de verdad:
  ///
  /// 1. En Android y en iOS, `FirebaseInitProvider` inicializa la app por
  ///    omisión con `google-services.json` **antes de que corra una línea de
  ///    Dart**. Volver a inicializarla con otras opciones da `duplicate-app`,
  ///    y esta app se quedaba en modo local sin decir por qué: por eso nunca
  ///    se pudo probar contra los emuladores en un teléfono.
  /// 2. Y si se acepta la que ya hay, el proyecto pasa a ser el de verdad. El
  ///    emulador guarda los datos **por proyecto**, así que la app miraba una
  ///    base y las herramientas —que hablan de `demo-natacion`— otra. Todo
  ///    parecía vacío sin que nada fallara.
  ///
  /// Con una app con nombre propio, el proyecto ficticio vale en los dos sitios
  /// y la app por omisión del teléfono se queda donde está, sin tocar.
  Future<FirebaseApp> _iniciarLaApp() async {
    if (!usarEmuladores) {
      return iniciar(options: opciones);
    }

    try {
      return await iniciar(name: nombreDeLaAppLocal, options: opciones);
    } on FirebaseException catch (e) {
      // Un arranque en caliente puede encontrarla ya creada.
      if (e.code != 'duplicate-app') rethrow;
      return Firebase.app(nombreDeLaAppLocal);
    }
  }

  /// Inicializa Firebase y, si procede, redirige a los emuladores.
  ///
  /// Devuelve `null` si la inicialización falla: la app debe poder arrancar y
  /// explicarlo, no caerse.
  Future<FirebaseFirestore?> conectar() async {
    try {
      final app = await _iniciarLaApp();

      final firestore = FirebaseFirestore.instanceFor(app: app);

      if (usarEmuladores) {
        firestore.useFirestoreEmulator(hostEmulador, puertoFirestore);
      }

      // La persistencia va activada **también contra los emuladores**, y no es
      // un descuido: el escenario C1 del quickstart —abrir la app en modo avión
      // y ver la sesión del día— no se puede verificar en local si la caché
      // está desactivada. Verificar sin conexión con la caché apagada sería
      // verificar otra cosa.
      //
      // Decisión D1 de `specs/003-consumo-del-nadador/research.md`: la lectura
      // se apoya en la caché de Firestore; la escritura, en una bandeja de
      // salida propia.
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      return firestore;
    } catch (_) {
      // Se atrapa cualquier fallo, no solo las excepciones. En web, arrancar
      // sin opciones revienta con un `AssertionError`, que es un `Error` y no
      // una `Exception`: atrapar solo excepciones dejaba caer la app entera en
      // el arranque documentado `flutter run -d chrome`.
      //
      // Aquí no hay nada que distinguir: con Firestore o sin él, lo único que
      // cambia es que no hay destino remoto. Quedarse sin conexión no es un
      // error de programa, es el martes a pie de piscina.
      return null;
    }
  }
}
