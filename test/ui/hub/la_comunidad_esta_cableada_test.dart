/// **La comunidad está conectada de punta a punta.**
///
/// Este proyecto ha construido tres cosas correctas, probadas y **nunca
/// conectadas**: `alVolverLaRed` tenía prueba y no tenía oyente durante siete
/// features, `sinContestar` tenía la regla correcta y nadie la llamaba, y la
/// feature 011 tuvo que inventarse un cerrojo sobre `hub.dart` para que no
/// pasara una cuarta vez.
///
/// Esta es esa cuarta vez vigilada. Un repositorio de comunidades que exista,
/// tenga pruebas y no llegue hasta la pantalla de ajustes sería exactamente el
/// mismo defecto con otro nombre.
///
/// Se lee del fuente porque lo que se quiere fijar es que **la línea esté
/// escrita**, y eso es justo lo que una prueba de comportamiento sobre el
/// repositorio no puede ver.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String leer(String ruta) {
    final archivo = File(ruta);
    expect(
      archivo.existsSync(),
      isTrue,
      reason: 'no se encontró $ruta; ¿cambió la estructura?',
    );
    return archivo.readAsStringSync().replaceAll('\r\n', '\n');
  }

  test('el paquete de repositorios construye el de comunidades', () {
    final fuente = leer('lib/ui/hub/repositorios_del_hub.dart');

    expect(
      fuente,
      contains('RepositorioComunidadesFirestore(db)'),
      reason:
          'sin esta línea el entrenador no puede nombrar nada, y sin nombre '
          'no hay a qué pedir entrar: la feature entera se queda en el aire',
    );
  });

  test('el HUB se lo pasa a los contenidos', () {
    final fuente = leer('lib/ui/hub/hub.dart');

    expect(fuente, contains('comunidades: _repos.comunidades'));
  });

  test('y los contenidos a la pantalla de ajustes', () {
    final fuente = leer('lib/ui/hub/contenidos.dart');

    expect(fuente, contains('comunidades: ctx.comunidades'));
  });

  test('la pantalla de ajustes lo pinta', () {
    final fuente = leer('lib/ui/ajustes/pantalla_ajustes.dart');

    expect(fuente, contains('MiComunidad('));
    expect(
      fuente,
      contains('comunidades: widget.comunidades'),
      reason: 'pintarlo sin pasárselo sería pintar una sección que no guarda',
    );
  });

  test('la prueba no pasa por vacía', () {
    // Sin esto, renombrar cualquiera de esos archivos dejaría los cuatro
    // `expect` de arriba pasando por casualidad sobre texto que ya no existe.
    expect(leer('lib/ui/hub/hub.dart'), contains('RepositoriosDelHub'));
    expect(leer('lib/ui/hub/contenidos.dart'), contains('PantallaAjustes('));
  });
}
