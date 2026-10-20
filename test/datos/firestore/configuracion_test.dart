import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/firestore/configuracion.dart';
import 'package:natacion_app/firebase_options.dart';

/// Arrancar sin Firestore.
///
/// La app promete funcionar sin conexión: el nadador lee de la caché, escribe
/// en local y lo pendiente espera en la bandeja de salida. Esa promesa empieza
/// en el arranque. Si conectar con Firestore puede tumbar la app, no hay
/// recorrido sin conexión que valga.
///
/// Esto falló de verdad: `flutter run -d chrome` sin emuladores —el arranque
/// que documenta `docs/DEVELOPMENT.md`— dejaba una pantalla de error en lugar
/// de la app, porque `firebase_core_web` no lanza una `Exception` cuando no
/// hay opciones, lanza un `AssertionError`.
void main() {
  /// Un arranque de Firebase que nunca llega a buen puerto, y que además
  /// recuerda con qué opciones lo llamaron.
  ({IniciarFirebase iniciar, List<FirebaseOptions?> llamadas}) falla(
    Object queLanza,
  ) {
    final llamadas = <FirebaseOptions?>[];
    Future<FirebaseApp> iniciar({String? name, FirebaseOptions? options}) {
      llamadas.add(options);
      throw queLanza;
    }

    return (iniciar: iniciar, llamadas: llamadas);
  }

  group('un fallo al conectar no tumba la app', () {
    test('un AssertionError, que es el fallo real de la web', () async {
      final doble = falla(
        AssertionError('FirebaseOptions cannot be null when creating the '
            'default app.'),
      );

      final datos = await ConfiguracionDatos(
        usarEmuladores: false,
        iniciar: doble.iniciar,
      ).conectar();

      expect(
        datos,
        isNull,
        reason: 'Un AssertionError es un Error, no una Exception. Atrapar '
            'solo excepciones es lo que dejó la app en una pantalla de error',
      );
    });

    test('una FirebaseException', () async {
      final doble = falla(
        FirebaseException(plugin: 'core', message: 'no hay proyecto'),
      );

      final datos = await ConfiguracionDatos(
        usarEmuladores: false,
        iniciar: doble.iniciar,
      ).conectar();

      expect(datos, isNull);
    });

    test('una excepción cualquiera', () async {
      final doble = falla(const FormatException('configuración ilegible'));

      final datos = await ConfiguracionDatos(
        usarEmuladores: true,
        iniciar: doble.iniciar,
      ).conectar();

      expect(datos, isNull);
    });

    test('tampoco con los emuladores apagados', () async {
      // El caso de todos los días: se arranca la app y no se levantaron los
      // emuladores. No hay nada que avisar, se trabaja en local.
      final doble = falla(
        Exception('Connection refused: localhost:8080'),
      );

      final datos = await ConfiguracionDatos(
        usarEmuladores: true,
        iniciar: doble.iniciar,
      ).conectar();

      expect(datos, isNull);
    });
  });

  group('nunca se apunta a un proyecto real por descuido', () {
    test('con emuladores se arranca con el proyecto ficticio', () async {
      final doble = falla(Exception('da igual, ya se registró la llamada'));

      await ConfiguracionDatos(
        usarEmuladores: true,
        iniciar: doble.iniciar,
      ).conectar();

      expect(doble.llamadas.single?.projectId, proyectoLocal);
      expect(doble.llamadas.single?.projectId, 'demo-natacion');
    });

    test('el proyecto real sale del archivo generado, no de aquí', () async {
      // Cambió al desplegar. Antes no había proyecto y estas opciones eran
      // nulas. El identificador no está escrito a mano en ningún sitio del
      // código: lo genera `flutterfire configure`.
      expect(DefaultFirebaseOptions.web.projectId, 'swimming-app-ab45f');
    });

    test('los dos caminos NUNCA apuntan al mismo sitio', () {
      // Es la prueba que de verdad importa desde que existe un proyecto real.
      // Si alguien hiciera que el camino de los emuladores usara las opciones
      // de producción, trabajar en local empezaría a escribir sobre los datos
      // de los nadadores sin que nadie se diera cuenta.
      const conEmuladores = ConfiguracionDatos(usarEmuladores: true);

      expect(conEmuladores.opciones.projectId, proyectoLocal);
      expect(
        DefaultFirebaseOptions.web.projectId,
        isNot(proyectoLocal),
        reason: 'El proyecto de desarrollo y el real tienen que ser dos',
      );
    });

    test('una plataforma sin configurar no arranca a medias', () async {
      // `flutterfire configure --platforms=web` genera **solo web**. En
      // Android o iOS, `currentPlatform` lanza un UnsupportedError, que es un
      // Error y no una Exception.
      //
      // `conectar()` lo atrapa —atrapa cualquier fallo— y la app entra en
      // modo local en lugar de caerse. Está bien que no se caiga, pero
      // significa que **en el móvil no habría servidor**: para que el nadador
      // use esto a pie de piscina hay que generar también android e iOS.
      final sinConfigurar = ConfiguracionDatos(
        usarEmuladores: false,
        iniciar: ({String? name, FirebaseOptions? options}) async {
          throw UnsupportedError('DefaultFirebaseOptions sin configurar');
        },
      );

      expect(await sinConfigurar.conectar(), isNull);
    });
  });
}
