/// Garantía A7 — la edad no toca la metodología.
///
/// **La categoría se declara por habilidades, nunca por la edad** (sección 11.1
/// de la metodología 3.6.0). Un niño de nueve años y un adulto pueden entrenar
/// los dos en Iniciación, y la app no está para contradecir eso.
///
/// La feature 006 introduce la fecha de nacimiento en el perfil, y con ella la
/// tentación: está ahí, es un número, y algún día alguien escribirá
/// `if (edad < 12)` en el generador porque le parecerá razonable. Esta prueba
/// existe para que ese día alguien tenga que leer por qué no.
///
/// **Se escribió antes de que el perfil existiera**, a propósito. Escrita
/// después habría descrito lo que saliera; escrita antes, dice lo que queremos.
/// Es la misma disciplina que la frontera del tema de la feature 005, que al
/// escribirse antes cazó tamaños de letra que nadie había buscado.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Las carpetas donde la edad **no** puede aparecer.
  ///
  /// Son las que deciden qué entrena un nadador. Que la edad entre aquí sería
  /// que la app empieza a planificar por edad, que es justo lo que la
  /// metodología no hace.
  const prohibidas = <String>[
    'lib/dominio/generacion/',
    'lib/dominio/metodologia/',
    'lib/dominio/auditoria/',
    'lib/dominio/calculo/',
  ];

  /// Lo que delata una lectura de la edad.
  final patron = RegExp(
    r'\b(fechaNacimiento|edadEn|esMenorEn|declaraSerMayorDeEdad|'
    r'necesitaAcudienteEn|esMenorDeEdad)\b',
  );

  List<({String archivo, int linea, String texto})> infracciones() {
    final encontradas = <({String archivo, int linea, String texto})>[];

    for (final carpeta in prohibidas) {
      final directorio = Directory(carpeta);
      if (!directorio.existsSync()) continue;

      for (final archivo in directorio
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lineas = archivo.readAsLinesSync();

        for (var i = 0; i < lineas.length; i++) {
          // Los comentarios explican; no deciden nada.
          final limpia = lineas[i].trimLeft();
          if (limpia.startsWith('//')) continue;

          if (patron.hasMatch(lineas[i])) {
            encontradas.add((
              archivo: archivo.path.replaceAll(r'\', '/'),
              linea: i + 1,
              texto: lineas[i].trim(),
            ));
          }
        }
      }
    }

    return encontradas;
  }

  group('A7 — la edad no entra donde se decide qué entrena alguien', () {
    test('ninguna carpeta de decisión metodológica lee la edad', () {
      final encontradas = infracciones();

      expect(
        encontradas,
        isEmpty,
        reason: 'La categoría se declara **por habilidades**, no por la edad '
            '(sección 11.1). Si esto que estás escribiendo necesita saber la '
            'edad para decidir qué entrena alguien, la decisión está mal, no '
            'la prueba.\n\n'
            '${encontradas.map((i) => '${i.archivo}:${i.linea}  ${i.texto}').join('\n')}',
      );
    });
  });

  group('la prueba no pasa por vacía', () {
    test('las carpetas que vigila existen de verdad', () {
      // Si alguien las renombrara, esta prueba pasaría mirando a la nada.
      for (final carpeta in prohibidas) {
        expect(
          Directory(carpeta).existsSync(),
          isTrue,
          reason: '$carpeta no existe. O se renombró, y hay que actualizar '
              'esta lista, o la prueba lleva tiempo sin vigilar nada',
        );
      }
    });

    test('el patrón reconoce una lectura de la edad', () {
      expect(patron.hasMatch('if (nadador.edadEn(hoy)! < 12) {'), isTrue);
      expect(patron.hasMatch('final menor = perfil.esMenorDeEdad(ahora);'),
          isTrue);
      expect(patron.hasMatch('if (nadador.categoria == Categoria.infantil) {'),
          isFalse);
    });

    test('hay archivos que mirar', () {
      final total = prohibidas
          .map(Directory.new)
          .where((d) => d.existsSync())
          .expand((d) => d.listSync(recursive: true))
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .length;

      expect(
        total,
        greaterThan(10),
        reason: 'Si no hay archivos, la prueba aprueba cualquier cosa',
      );
    });
  });
}
