/// La red es **lo que dijo el último intento** (FR-002, decisión D1).
///
/// `estado_de_red.dart` lo lleva escrito desde la feature 003:
///
/// > La detección es deliberadamente tonta: se intenta una escritura y se ve si
/// > llega. No se consulta ningún servicio de conectividad del sistema, porque
/// > «el teléfono dice que hay wifi» y «el servidor responde» son cosas
/// > distintas, y a pie de piscina la segunda es la que importa.
///
/// Y después se cableó con `sondear: () async => datos != null`, que pregunta
/// si Firestore se inicializó: cierto con el avión puesto, cierto para siempre.
/// El valor nunca cambiaba, así que el stream nunca emitía, así que el
/// disparador que lo escuchaba no podía saltar — y encima nadie lo escuchaba.
///
/// Dos fallos independientes, cualquiera de los dos bastaba.
///
/// Esta prueba fija lo que el archivo decía desde el principio.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/red/estado_de_red.dart';

void main() {
  late RedSegunElUltimoIntento red;

  setUp(() => red = RedSegunElUltimoIntento());

  test('antes de cualquier intento es optimista', () async {
    expect(
      await red.hayConexion(),
      isTrue,
      reason:
          'un pesimista no dejaría salir el primer intento, y el primer '
          'intento es lo único que puede contestar la pregunta',
    );
  });

  test('un intento que llega la pone a cierto', () async {
    red.anotarIntento(llego: false);
    expect(await red.hayConexion(), isFalse);

    red.anotarIntento(llego: true);
    expect(await red.hayConexion(), isTrue);
  });

  test('un intento que no llega la pone a falso', () async {
    red.anotarIntento(llego: true);
    red.anotarIntento(llego: false);

    expect(await red.hayConexion(), isFalse);
  });

  test('emite solo cuando cambia', () async {
    final vistos = <bool>[];
    final suscripcion = red.cambios.listen(vistos.add);

    red.anotarIntento(llego: false);
    red.anotarIntento(llego: false);
    red.anotarIntento(llego: false);
    await Future<void>.delayed(Duration.zero);

    expect(
      vistos,
      [false],
      reason: 'tres fallos seguidos son una sola noticia, no tres',
    );

    red.anotarIntento(llego: true);
    await Future<void>.delayed(Duration.zero);

    expect(vistos, [false, true]);
    await suscripcion.cancel();
  });

  test('no le pregunta nada al sistema', () async {
    // El control negativo de todo esto, y está en lo que la clase **no**
    // recibe: no hay forma de inyectarle un servicio de conectividad, porque
    // la respuesta correcta no está ahí.
    //
    // Si alguien añade un parámetro para consultar al sistema operativo, esta
    // prueba sigue pasando — pero el principio VII pide que esa dependencia se
    // justifique por su nombre en el plan, y la 011 la rechazó por escrito
    // (research D1). Lo que esta prueba fija es que la clase **funciona sin
    // nada de eso**.
    final sola = RedSegunElUltimoIntento();
    expect(await sola.hayConexion(), isTrue);
    sola.anotarIntento(llego: false);
    expect(await sola.hayConexion(), isFalse);
  });

  test('cerrar no deja el stream abierto', () async {
    await red.cerrar();
    expect(red.cambios.isBroadcast, isTrue);
  });
}
