/// Cerrar sesión no puede dejar la base de datos inservible.
///
/// **Esta prueba existe por el fallo que más costó encontrar de la feature
/// 006**, y el síntoma no se parecía a la causa: al cerrar sesión y volver a
/// entrar, la app mandaba al flujo del alta a quien ya tenía su perfil
/// completo. Cerrar la PWA y abrirla de nuevo lo arreglaba.
///
/// La causa está en `cerrarSesion`. Vaciar la caché de Firestore —que hace
/// falta, porque el grupo son hermanos que comparten el teléfono (garantía
/// A7)— exige llamar a `terminate()` antes de `clearPersistence()`. Y
/// `terminate()` **mata el cliente para toda la vida de la página**: el plugin
/// guarda la instancia de JavaScript en un campo (`_webFirestore ??= ...`) que
/// nadie vuelve a limpiar, así que toda lectura posterior falla con
/// «el cliente ya se ha terminado». No es una carrera ni un token tardío: es
/// definitivo, y por eso ningún reintento lo arreglaba.
///
/// El alta era lo primero que se notaba, no lo único roto: después de cerrar
/// sesión, **nada** de la app podía leer ni escribir en Firestore.
///
/// Así que el vaciado se queda, y detrás va lo que lo hace seguro: la app
/// arranca de nuevo. Es lo mismo que el entrenador hacía a mano cerrando la
/// PWA, hecho por la app y en el único sitio que sabe que hizo falta.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/auth/reinicio.dart';

void main() {
  final fuente =
      File('lib/datos/auth/sesion_firebase.dart').readAsStringSync();

  final desde = fuente.indexOf('Future<void> cerrarSesion()');
  final cerrarSesion = fuente.substring(
    desde,
    fuente.indexOf('/// Traduce un usuario de Firebase', desde),
  );

  group('cerrarSesion', () {
    test('la prueba no pasa por vacía', () {
      expect(desde, greaterThan(0));
      expect(cerrarSesion.length, greaterThan(200));
    });

    test('vacía lo que esta app guarda en el dispositivo', () {
      // Primero, mientras todavía se sabe de quién era.
      expect(cerrarSesion, contains('almacenLocal?.vaciar()'));
    });

    test('vacía la caché de Firestore (garantía A7)', () {
      // Sobrevive al cierre de sesión si no se limpia, y el siguiente que
      // entre en este teléfono leería de ella.
      expect(cerrarSesion, contains('terminate()'));
      expect(cerrarSesion, contains('clearPersistence()'));
    });

    test('**y por eso la app tiene que arrancar de nuevo**', () {
      // `terminate()` deja el cliente muerto para toda la vida de la página.
      // Sin esto, lo que se arregla con el vaciado se paga con una app que ya
      // no puede leer nada.
      expect(
        cerrarSesion,
        contains('reiniciarLaApp'),
        reason: 'Vaciar la caché termina el cliente de Firestore y el plugin '
            'no lo vuelve a crear. Sin reinicio, cerrar sesión deja la app sin '
            'base de datos hasta que alguien cierre la PWA a mano',
      );
    });

    test('el reinicio va después de cerrar la sesión, no antes', () {
      // Al revés, la página se recargaría con la sesión todavía abierta y
      // quien entrara después seguiría siendo el anterior.
      expect(
        cerrarSesion.indexOf('reiniciarLaApp'),
        greaterThan(cerrarSesion.indexOf('signOut()')),
      );
    });
  });

  group('el reinicio', () {
    test('fuera de la web no hace nada, y no estalla', () async {
      // Las pruebas corren en la VM. Lo que se comprueba es que el puerto
      // existe y que llamarlo no rompe nada donde no hay página que recargar.
      await expectLater(reiniciarLaApp(), completes);
    });
  });
}
