/// Garantía A15 — toda pantalla está en el banco que se mide.
///
/// `test/ui/tema/ayuda_pantallas.dart` es la lista que leen cinco pruebas: el
/// tamaño de letra al 200%, las áreas pulsables, el modo oscuro, las cifras
/// tabulares y los retratos. **Una pantalla que no está en esa lista no la mide
/// nadie.**
///
/// La feature 005 lo aprendió dos veces, las dos caras:
///
/// - La tabla de distribución se salía **50 píxeles en un teléfono de 360
///   puntos con la letra normal**, y nadie lo había visto porque las pruebas de
///   widget miden en una ventana de 800.
/// - Y cuando el banco montaba un plan **sin fase ATR**, media pantalla del plan
///   no se pintaba en ninguna prueba: al añadir la fase aparecieron dos
///   desbordes más que llevaban ahí desde la feature 002.
///
/// La lección no es de maquetación: **un banco solo mide los caminos que
/// monta**. Esta prueba vigila la mitad que se puede automatizar —que la
/// pantalla esté en la lista—; que se monte con contenido realista sigue siendo
/// cosa de quien la añade.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Lo que cuenta como pantalla: una clase que se llama `PantallaAlgo`.
  ///
  /// Los paneles y los trozos sueltos viajan dentro de ellas y se miden con
  /// ellas, así que no hace falta listarlos aparte.
  final declaracion = RegExp(r'^class (Pantalla\w+)\s', multiLine: true);

  List<String> pantallasDeLaApp() {
    final encontradas = <String>[];
    final raiz = Directory('lib/ui');
    if (!raiz.existsSync()) return encontradas;

    for (final archivo in raiz
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final coincidencia
          in declaracion.allMatches(archivo.readAsStringSync())) {
        encontradas.add(coincidencia.group(1)!);
      }
    }

    return encontradas..sort();
  }

  test('A15 — toda pantalla de lib/ui/ está en el banco', () {
    final banco = File('test/ui/tema/ayuda_pantallas.dart').readAsStringSync();

    final fuera = pantallasDeLaApp()
        .where((pantalla) => !banco.contains(pantalla))
        .toList();

    expect(
      fuera,
      isEmpty,
      reason: 'Estas pantallas no las mide nadie: ni al 200% de letra, ni en '
          'áreas pulsables, ni en oscuro. Añádelas a '
          '`test/ui/tema/ayuda_pantallas.dart` **con contenido realista**: un '
          'texto corto nunca desborda, y lo que desborda es el contenido de '
          'verdad.\n\n'
          '${fuera.join('\n')}',
    );
  });

  group('la prueba no pasa por vacía', () {
    test('encuentra las pantallas que ya existen', () {
      final pantallas = pantallasDeLaApp();

      expect(
        pantallas,
        contains('PantallaAcceso'),
        reason: 'Si no encuentra ni la de acceso, el patrón está mal y esta '
            'prueba aprueba cualquier cosa',
      );
      expect(pantallas.length, greaterThanOrEqualTo(7));
    });

    test('el banco existe y nombra pantallas', () {
      final banco =
          File('test/ui/tema/ayuda_pantallas.dart').readAsStringSync();

      expect(banco, contains('PantallaMedible'));
      expect(banco, contains('PantallaAcceso'));
    });
  });
}
