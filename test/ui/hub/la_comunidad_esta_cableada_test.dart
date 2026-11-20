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

  // --- Y la otra mitad: la solicitud llega hasta su cola ------------------
  //
  // El mismo defecto con otro nombre otra vez. Un repositorio de solicitudes
  // que exista, tenga pruebas y no llegue hasta la cola del entrenador deja la
  // feature justo donde la 008 dejó `alVolverLaRed`: correcta y desconectada.
  // Y aquí el precio es peor que un contador en cero — es alguien esperando
  // para siempre a que la acepten.

  test('el paquete de repositorios construye el de solicitudes', () {
    final fuente = leer('lib/ui/hub/repositorios_del_hub.dart');

    expect(fuente, contains('RepositorioSolicitudesFirestore(db)'));
  });

  test('el HUB se lo pasa a los contenidos, con su comunidad', () {
    final fuente = leer('lib/ui/hub/hub.dart');

    expect(fuente, contains('solicitudes: _repos.solicitudes'));
    expect(
      fuente,
      contains('miComunidad: _miComunidad'),
      reason:
          'sin la comunidad, la consulta de solicitudes no se puede demostrar '
          'por sus filtros y el servidor la rechaza entera',
    );
  });

  test('y los contenidos a la cola del entrenador', () {
    final fuente = leer('lib/ui/hub/contenidos.dart');

    expect(fuente, contains('solicitudes: ctx.solicitudes'));
    expect(fuente, contains('alResolverIngreso: ctx.alResolverIngreso'));
  });

  test('resolver pasa por el servidor, no por el cliente', () {
    // Aceptar escribe la pertenencia y cierra la solicitud, y las dos cosas
    // tienen que ocurrir juntas o ninguna (garantía F5). Si esto se cableara
    // al repositorio, media aceptación sería posible.
    final fuente = leer('lib/ui/hub/hub.dart');

    expect(fuente, contains('aceptarIngreso'));
    expect(fuente, contains('rechazarIngreso'));
  });

  // --- Y la tercera: ella se entera de dónde está ------------------------

  test('el HUB averigua dónde está ella al abrirle lo suyo', () {
    final fuente = leer('lib/ui/hub/hub.dart');

    expect(
      fuente,
      contains('_averiguarDondeEsta'),
      reason:
          'sin esto, `DondeEsta` existe, tiene pruebas y nadie lo llama: la '
          'nadadora que espera lee «todavía no tienes un plan asignado» y se '
          'queda esperando a un entrenador que no sabe que existe',
    );
    expect(fuente, contains('anotarDondeEsta'));
  });

  test('y las pantallas lo usan para elegir el vacío', () {
    // **Son cuatro, no dos.** La portada —`home_del_nadador`— decía la misma
    // frase con otras palabras, y no estaba ni en la spec ni en las pruebas de
    // US4: lo encontró el recorrido del quickstart, con el aviso de espera ya
    // puesto en dos pantallas y la primera que ella ve al abrir la app
    // diciéndole lo contrario.
    //
    // La cuarta, `mi_macrociclo`, enseña la sesión del día cuando no hay
    // macrociclo, así que le llega por ahí y no hace falta listarla.
    for (final pantalla in [
      'lib/ui/nadador/pantalla_mi_progreso.dart',
      'lib/ui/nadador/pantalla_sesion_del_dia.dart',
      'lib/ui/hub/home_del_nadador.dart',
    ]) {
      final fuente = leer(pantalla);
      expect(fuente, contains('SinPlanTodavia('), reason: 'en $pantalla');
      expect(
        fuente,
        contains('dondeEsta: estado.dondeEsta'),
        reason: 'en $pantalla',
      );
      expect(
        fuente,
        contains('terminadaEn: estado.pertenenciaTerminadaEn'),
        reason: 'sin esto, a quien sacaron del grupo se le dice que todavía '
            'no se ha unido a ninguno ($pantalla)',
      );
    }
  });

  test('la prueba no pasa por vacía', () {
    // Sin esto, renombrar cualquiera de esos archivos dejaría los cuatro
    // `expect` de arriba pasando por casualidad sobre texto que ya no existe.
    expect(leer('lib/ui/hub/hub.dart'), contains('RepositoriosDelHub'));
    expect(leer('lib/ui/hub/contenidos.dart'), contains('PantallaAjustes('));
  });
}
