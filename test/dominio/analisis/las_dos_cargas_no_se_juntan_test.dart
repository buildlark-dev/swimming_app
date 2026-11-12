/// El principio VIII, fijado sobre el tipo que lleva las dos cargas.
///
/// `RespuestaASesion` expone la sesión —carga externa: metros, series, zonas— y
/// el registro —carga interna: si la hizo, el esfuerzo percibido, lo que
/// anotó—. El principio VIII dice que no se combinan en un mismo indicador, y
/// la forma de que eso no se rompa por descuido es que **no exista ningún
/// miembro que mire a los dos a la vez**.
///
/// Se comprueba sobre la fuente y no ejecutando el tipo, porque lo que se
/// quiere fijar es una propiedad del código: «aquí no se multiplica metros por
/// RPE» no es un valor que se pueda pedir, es algo que no está escrito. Es el
/// mismo recurso que `el_plan_firestore_guarda_sus_sesiones_test.dart`.
///
/// Control negativo (T005): añadir un getter que multiplique metros por RPE y
/// ver esta prueba en rojo.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/analisis/respuesta_a_sesion.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';

/// Quita comentarios y documentación: el cerrojo es sobre el código.
///
/// Sin esto, una frase de documentación que nombrara las dos cosas pondría la
/// prueba en rojo sin que nadie hubiera combinado nada, y una prueba que se
/// cae por la prosa se acaba desactivando.
String sinComentarios(String fuente) => fuente
    .split('\n')
    .where((linea) {
      final limpia = linea.trimLeft();
      return !limpia.startsWith('//') && !limpia.startsWith('///');
    })
    .join('\n');

void main() {
  const ruta = 'lib/dominio/analisis/respuesta_a_sesion.dart';

  late String codigo;

  setUpAll(() {
    // **Los finales de línea se normalizan**, y no es cosmético: este cerrojo
    // parte el cuerpo de la clase por la línea en blanco que separa sus
    // miembros, y en Windows git materializa el archivo con CRLF. Entonces
    // `split('\n\n')` no parte nada, el cuerpo entero sale como un solo
    // miembro, y la prueba se queda sin nada que examinar.
    //
    // Lo cazó su propio guardia contra pruebas vacías, en una `main` recién
    // fusionada: «no se examinó ningún miembro». Es exactamente para lo que
    // ese guardia está, y sin él este cerrojo habría pasado a verde sin
    // comprobar nada en todas las máquinas Windows del proyecto.
    codigo = sinComentarios(
      File(ruta).readAsStringSync().replaceAll('\r\n', '\n'),
    );
  });

  test('la prueba no pasa por vacía: el archivo existe y declara el tipo', () {
    expect(codigo, contains('class RespuestaASesion'));
    expect(codigo, contains('final Sesion sesion'));
    expect(codigo, contains('final RegistroDeSesion? registro'));
  });

  test('las dos cargas se leen por separado', () {
    final sesion = Sesion(id: 's1', objetivoTecnico: 'Viraje');
    final registro = RegistroDeSesion(
      nadadorId: 'n1',
      planId: 'p1',
      sesionId: 's1',
      versionDePlan: 'v1',
      realizada: true,
      registradoEn: DateTime(2026, 11, 10),
      rpePercibido: 7,
    );

    final respuesta = RespuestaASesion(sesion: sesion, registro: registro);

    expect(respuesta.sesion, same(sesion));
    expect(respuesta.registro, same(registro));
  });

  test('una sesión sin contestar no es un error: el registro es nulo', () {
    final respuesta = RespuestaASesion(sesion: Sesion(id: 's2'));

    expect(respuesta.registro, isNull);
    expect(respuesta.fueContestada, isFalse);
  });

  test('ningún miembro mira la sesión y el registro a la vez', () {
    // El cuerpo de la clase, partido en miembros por la línea en blanco que
    // los separa —el formato de `dart format`, que CI comprueba—.
    final desde = codigo.indexOf('class RespuestaASesion');
    final cuerpo = codigo.substring(desde);
    final miembros = cuerpo.split('\n\n');

    var mirados = 0;

    for (final miembro in miembros) {
      // El constructor nombra los dos campos porque los recibe. Recibirlos no
      // es combinarlos.
      if (miembro.contains('RespuestaASesion({')) continue;
      // Las declaraciones de campo nombran uno cada una.
      if (miembro.trimLeft().startsWith('final ')) continue;

      final esMiembro = miembro.contains(' get ') || miembro.contains('(');
      if (!esMiembro) continue;

      mirados++;

      final mira =
          miembro.contains('sesion.') ||
          RegExp(r'\bsesion\b').hasMatch(miembro);
      final miraElRegistro = RegExp(r'\bregistro\b').hasMatch(miembro);

      expect(
        mira && miraElRegistro,
        isFalse,
        reason:
            'este miembro mira la sesión y el registro a la vez, y el '
            'principio VIII dice que la carga externa y la interna no se '
            'combinan en un mismo indicador:\n$miembro',
      );
    }

    // Sin esto la prueba pasaría con un archivo sin miembros, que es el
    // defecto que la 009 encontró dos veces: un cerrojo que no cierra nada.
    expect(
      mirados,
      greaterThan(0),
      reason: 'no se examinó ningún miembro: la prueba estaría pasando vacía',
    );
  });
}
