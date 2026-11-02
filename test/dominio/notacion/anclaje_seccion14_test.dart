import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';

/// Prueba de anclaje: el ejemplo completo de la sección 14 del documento
/// normativo (miércoles 14, técnica de espalda) debe dar 3.600 m.
///
/// Es el resultado que el entrenador ya conoce. Si esto no cuadra, el error
/// contaminaría la auditoría, la aprobación y todo lo demás, así que es el
/// punto de parada declarado en `tasks.md`.
void main() {
  late Analizador analizador;

  setUpAll(() {
    final json =
        jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
            as Map<String, dynamic>;
    analizador = Analizador(biblioteca: Biblioteca.desdeJson(json));
  });

  group('ejemplo de la sección 14', () {
    const inicial =
        '200 N + 200 AL CAMBIO POSI + 200 PULL PL (75N=25 Prog) '
        '+ 400 AL (75 Estilo − 25 UW) + 4x100 AL SNK PN / 2\' '
        '+ 8x50 (1L 1Estilo 1>4)';

    const central =
        '200 AL Pn (1L 50-E) + 100 E\n'
        '200 AL (Coord brazada cada 5\'\') + 100 E\n'
        '200 AL (ROLIDO-Brazada) + 100 E\n'
        '200 PU/Pp E (50 c/brazo) + 100 E\n'
        '200 AL (25m Pn E FLECHA + 75 N) + 100 E';

    const cierre = '300 REC Pp TEC L';

    test('la parte inicial suma 1.800 m', () {
      final resultado = analizador.analizar(inicial);
      expect(
        resultado.metros,
        1800,
        reason:
            'Series interpretadas:\n'
            '${resultado.series.map((s) => '  $s').join('\n')}\n'
            'Pendientes:\n'
            '${resultado.pendientes.map((p) => '  $p').join('\n')}',
      );
    });

    test('la parte central suma 1.500 m', () {
      final resultado = analizador.analizar(central);
      expect(
        resultado.metros,
        1500,
        reason:
            'Series interpretadas:\n'
            '${resultado.series.map((s) => '  $s').join('\n')}\n'
            'Pendientes:\n'
            '${resultado.pendientes.map((p) => '  $p').join('\n')}',
      );
    });

    test('la parte final suma 300 m', () {
      final resultado = analizador.analizar(cierre);
      expect(resultado.metros, 300);
    });

    test('la sesión completa suma 3.600 m', () {
      final total =
          analizador.analizar(inicial).metros +
          analizador.analizar(central).metros +
          analizador.analizar(cierre).metros;
      expect(
        total,
        3600,
        reason:
            'Es el total que el documento normativo declara para esta '
            'sesión. Una diferencia aquí invalida todo lo que se construya '
            'encima.',
      );
    });
  });

  group('garantía fundamental del analizador', () {
    test('nunca lanza excepción, por disparatada que sea la entrada', () {
      const entradas = [
        '',
        '   ',
        '((((',
        '4x',
        'x100',
        '///',
        'ñ@#\$%',
        '200 200 200 200',
        'AAAAA BBBBB CCCCC',
        '4x100 / ',
        '\n\n\n',
      ];

      for (final entrada in entradas) {
        expect(
          () => analizador.analizar(entrada),
          returnsNormally,
          reason: 'Falló con la entrada: "$entrada"',
        );
      }
    });

    test('devuelve siempre un resultado, aunque sea vacío', () {
      final resultado = analizador.analizar('!!!!');
      expect(resultado.series, isNotNull);
      expect(resultado.pendientes, isNotNull);
    });
  });
}
