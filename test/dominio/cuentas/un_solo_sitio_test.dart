/// Garantía A4 — un solo sitio decide si alguien es menor.
///
/// Desde esta feature hay **dos datos** que podrían contestar la pregunta: la
/// fecha de nacimiento, que la 006 introduce, y la declaración que la 004
/// guardaba. Dos datos con dos cálculos son dos sitios donde equivocarse, y
/// equivocarse aquí significa **no pedir un consentimiento que hacía falta**.
///
/// El inventario de la tarea T002 encontró que ya había un solo sitio —estaba
/// dentro de `Nadador`—, así que en lugar de escribir un segundo cálculo «para
/// el perfil» se extrajo el que existía a `dominio/cuentas/edad.dart`. `Perfil`
/// y `Nadador` contestan con el mismo código, no con dos que se parecen.
///
/// Esta prueba existe para que siga siendo así dentro de seis meses, cuando
/// alguien necesite saber si alguien es menor y tenga la fecha delante.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';

void main() {
  /// El único archivo autorizado a comparar una edad con la mayoría de edad.
  const elSitio = 'lib/dominio/cuentas/edad.dart';

  /// Lo que delata un cálculo propio: comparar algo con 18, o restar años.
  final patron = RegExp(
    r'<\s*18\b|>=\s*18\b|>\s*17\b|'
    r'\.year\s*-\s*\w*[Nn]acimiento|'
    r'mayoriaDeEdad\s*(<|>|<=|>=)',
  );

  test('A4 — nadie más calcula la mayoría de edad', () {
    final infracciones = <String>[];

    for (final archivo in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final ruta = archivo.path.replaceAll(r'\', '/');
      if (ruta.endsWith(elSitio)) continue;

      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final limpia = lineas[i].trimLeft();
        if (limpia.startsWith('//')) continue;

        if (patron.hasMatch(lineas[i])) {
          infracciones.add('$ruta:${i + 1}  ${lineas[i].trim()}');
        }
      }
    }

    expect(
      infracciones,
      isEmpty,
      reason: 'Esto calcula la mayoría de edad por su cuenta. Pregúntale a '
          '`$elSitio`: si hay dos respuestas, un día serán distintas, y el día '
          'que lo sean alguien se habrá quedado sin que le pidan el '
          'consentimiento.\n\n'
          '${infracciones.join('\n')}',
    );
  });

  group('y los dos que preguntan contestan lo mismo', () {
    final hoy = DateTime(2026, 10, 21);

    test('un menor, visto desde el perfil y desde el nadador', () {
      final nacimiento = DateTime(2014, 3, 10);

      final perfil = Perfil(nombre: 'Ana', fechaNacimiento: nacimiento);
      final nadador = Nadador(nombre: 'Ana', fechaNacimiento: nacimiento);

      expect(perfil.necesitaAcudienteEn(hoy), isTrue);
      expect(nadador.necesitaAcudienteEn(hoy), isTrue);
    });

    test('un adulto, igual', () {
      final nacimiento = DateTime(1990, 3, 10);

      final perfil = Perfil(nombre: 'Ana', fechaNacimiento: nacimiento);
      final nadador = Nadador(nombre: 'Ana', fechaNacimiento: nacimiento);

      expect(perfil.necesitaAcudienteEn(hoy), isFalse);
      expect(nadador.necesitaAcudienteEn(hoy), isFalse);
    });

    test('el día del cumpleaños, los dos cambian a la vez', () {
      final nacimiento = DateTime(2008, 6, 15);
      final vispera = DateTime(2026, 6, 14);
      final cumple = DateTime(2026, 6, 15);

      final perfil = Perfil(nombre: 'Ana', fechaNacimiento: nacimiento);
      final nadador = Nadador(nombre: 'Ana', fechaNacimiento: nacimiento);

      expect(perfil.necesitaAcudienteEn(vispera), isTrue);
      expect(nadador.necesitaAcudienteEn(vispera), isTrue);
      expect(perfil.necesitaAcudienteEn(cumple), isFalse);
      expect(nadador.necesitaAcudienteEn(cumple), isFalse);
    });
  });

  group('la prueba no pasa por vacía', () {
    test('el patrón reconoce un cálculo propio', () {
      expect(patron.hasMatch('if (edad < 18) return true;'), isTrue);
      expect(patron.hasMatch('final mayor = anos >= 18;'), isTrue);
      expect(
        patron.hasMatch('var edad = hoy.year - fechaNacimiento.year;'),
        isTrue,
      );
    });

    test('deja pasar preguntar al sitio correcto', () {
      expect(patron.hasMatch('return necesitaAcudiente(...);'), isFalse);
      expect(patron.hasMatch('final menor = esMenorA(fecha, hoy);'), isFalse);
    });

    test('el sitio autorizado existe y tiene el cálculo', () {
      final fuente = File(elSitio).readAsStringSync();

      expect(fuente, contains('mayoriaDeEdad'));
      expect(
        patron.hasMatch(fuente),
        isTrue,
        reason: 'Si el cálculo ya no está aquí, se habrá ido a otro sitio y '
            'esta prueba estaría vigilando una casa vacía',
      );
    });
  });
}
