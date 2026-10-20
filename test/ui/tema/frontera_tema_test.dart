import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garantías V1 y V2 — el tema vive en un solo sitio.
///
/// `lib/ui/tema/paleta.dart` es el **único archivo del proyecto** autorizado a
/// contener un literal de color. Lo mismo para los tamaños de letra y los
/// espaciados en sus archivos.
///
/// **Esta prueba se escribió antes que la paleta, a propósito.** Escrita
/// antes, dice lo que queremos; escrita después, habría descrito lo que
/// saliera. Un cerrojo instalado al final encaja con lo que ya hay.
///
/// Por qué una prueba y no un lint: no existe uno que diga «este widget usa un
/// color literal en lugar del tema», y escribirlo seria una dependencia y una
/// pieza de infraestructura para lo que esto resuelve. Hay precedente en este
/// proyecto: la frontera del dominio del principio II se vigila igual desde la
/// feature 001, y ya cazó un `firebase_auth` colado en `main.dart`.
///
/// **Lo que esta prueba admite**: lee texto, no entiende Dart. Quien quiera
/// esquivarla puede. No es un cerrojo contra un adversario; es una red contra
/// el descuido, que es lo que de verdad pasa.
///
/// Contrato: `specs/005-tema-visual/contracts/sistema_visual.md`.
void main() {
  /// Archivo, línea y el texto que la delata.
  ({String archivo, int linea, String texto})? infraccionEn(
    File archivo,
    RegExp patron,
  ) {
    final lineas = archivo.readAsLinesSync();

    for (var i = 0; i < lineas.length; i++) {
      final linea = lineas[i];

      // Los comentarios documentan; no pintan nada.
      final limpia = linea.trimLeft();
      if (limpia.startsWith('//') || limpia.startsWith('///')) continue;

      if (patron.hasMatch(linea)) {
        return (
          archivo: archivo.path.replaceAll(r'\', '/'),
          linea: i + 1,
          texto: linea.trim(),
        );
      }
    }

    return null;
  }

  List<String> infraccionesCon({
    required RegExp patron,
    required List<String> permitidos,
  }) {
    final encontradas = <String>[];

    for (final entrada in Directory('lib').listSync(recursive: true)) {
      if (entrada is! File || !entrada.path.endsWith('.dart')) continue;

      final ruta = entrada.path.replaceAll(r'\', '/');
      if (permitidos.any(ruta.endsWith)) continue;

      // Generado por flutterfire: no se edita a mano y define el proyecto de
      // Firebase, no la apariencia.
      if (ruta.endsWith('lib/firebase_options.dart')) continue;

      final falta = infraccionEn(entrada, patron);
      if (falta != null) {
        encontradas.add('${falta.archivo}:${falta.linea} -> ${falta.texto}');
      }
    }

    return encontradas;
  }

  group('V1 — solo paleta.dart define colores', () {
    test('ningún otro archivo de lib/ contiene un literal de color', () {
      final infracciones = infraccionesCon(
        // Color(0x...), Colors.loQueSea, y los constructores con canales.
        patron: RegExp(
          r'Color\(0x|Colors\.[a-zA-Z]|Color\.fromARGB|Color\.fromRGBO',
        ),
        permitidos: const ['lib/ui/tema/paleta.dart'],
      );

      expect(
        infracciones,
        isEmpty,
        reason: 'Un color escrito a mano es un color que no se adapta al modo '
            'oscuro, que nadie comprueba contra el contraste y que hay que '
            'buscar para cambiar. Pásalo a lib/ui/tema/paleta.dart.\n\n'
            '${infracciones.join('\n')}',
      );
    });
  });

  group('V2 — los tamaños y los espaciados tampoco se escriben a mano', () {
    test('ningún archivo de lib/ fija un tamaño de letra literal', () {
      final infracciones = infraccionesCon(
        patron: RegExp(r'fontSize:\s*[0-9]'),
        permitidos: const ['lib/ui/tema/tipografia.dart'],
      );

      expect(
        infracciones,
        isEmpty,
        reason: 'El tamaño de letra sale de la escala tipográfica, que es lo '
            'que permite respetar el ajuste del sistema.\n\n'
            '${infracciones.join('\n')}',
      );
    });
  });

  group('la prueba no pasa por vacía', () {
    test('lib/ tiene bastantes archivos como para que esto signifique algo',
        () {
      final archivos = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .length;

      expect(
        archivos,
        greaterThan(50),
        reason: 'Si lib/ estuviera casi vacío, no encontrar infracciones no '
            'demostraría nada',
      );
    });

    test('el patrón de color caza lo que tiene que cazar', () {
      // Comprobación del propio patrón, para que la tarea T004 no dependa de
      // acordarse de hacerla a mano.
      final patron = RegExp(
        r'Color\(0x|Colors\.[a-zA-Z]|Color\.fromARGB|Color\.fromRGBO',
      );

      for (final delator in [
        'const Color(0xFF123456)',
        'color: Colors.red,',
        'Color.fromARGB(255, 1, 2, 3)',
        'Color.fromRGBO(1, 2, 3, 1)',
      ]) {
        expect(patron.hasMatch(delator), isTrue, reason: 'No cazó: $delator');
      }

      for (final inocente in [
        'final esquema = Theme.of(context).colorScheme;',
        'color: esquema.primary,',
        'Paleta.marinoProfundo',
      ]) {
        expect(
          patron.hasMatch(inocente),
          isFalse,
          reason: 'Falso positivo: $inocente',
        );
      }
    });
  });
}
