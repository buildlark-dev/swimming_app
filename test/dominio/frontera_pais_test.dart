/// Garantía A16 — el país no decide nada.
///
/// El país se pide **para que el club sepa de dónde viene cada nadador**, y
/// para nada más (FR-007). Ese es su uso declarado, y el principio V exige que
/// tenga uno: «no se recolecta ningún dato que no tenga un uso declarado en la
/// feature que lo pide».
///
/// **Por qué una prueba y no un comentario.** Un dato que solo informa es
/// exactamente el que alguien usará dentro de seis meses para una condición
/// rápida —un texto distinto, una unidad distinta, una regla distinta— y nadie
/// lo notará. La feature 005 lo aprendió con el color de error: una regla sin
/// prueba es una buena intención, y en seis meses vuelve a estar como estaba.
///
/// Si algún día el país **sí** tiene que decidir algo —la ley aplicable, por
/// ejemplo, el día que la app salga de Colombia de verdad—, eso es una
/// decisión con consecuencias y merece tomarse a la vista, borrando esta
/// prueba a propósito.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Guardar, leer y mostrar el país está bien. **Decidir con él, no.**
  ///
  /// Por eso se permiten los archivos donde el dato vive y viaja, y se vigila
  /// todo lo demás.
  const permitidos = <String>[
    'lib/dominio/cuentas/perfil.dart', // donde vive
    'lib/datos/', // donde se guarda y se lee
    'lib/ui/alta/paso_pais.dart', // donde se pregunta
  ];

  /// Lo que delata que el país entró en una decisión.
  ///
  /// No basta con buscar la palabra: aparecerá legítimamente al guardarla y al
  /// mostrarla. Lo que delata es **compararla**.
  final patron = RegExp(
    r'\bpais\b\s*(==|!=)|'
    r'(==|!=)\s*\bpais\b|'
    r'\bpais\b\s*\.\s*(contains|startsWith|endsWith)|'
    r'switch\s*\(\s*\w*[Pp]ais\w*\s*\)',
  );

  List<({String archivo, int linea, String texto})> infracciones() {
    final encontradas = <({String archivo, int linea, String texto})>[];
    final raiz = Directory('lib');
    if (!raiz.existsSync()) return encontradas;

    for (final archivo in raiz
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final ruta = archivo.path.replaceAll(r'\', '/');
      if (permitidos.any(ruta.contains)) continue;

      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final limpia = lineas[i].trimLeft();
        if (limpia.startsWith('//')) continue;

        if (patron.hasMatch(lineas[i])) {
          encontradas.add((
            archivo: ruta,
            linea: i + 1,
            texto: lineas[i].trim(),
          ));
        }
      }
    }

    return encontradas;
  }

  group('A16 — con el país no se decide nada', () {
    test('ningún archivo compara el país', () {
      final encontradas = infracciones();

      expect(
        encontradas,
        isEmpty,
        reason: 'El país se pide para que el club sepa de dónde viene cada '
            'nadador, y para nada más (FR-007). Si lo que estás escribiendo '
            'necesita decidir según el país, eso es una decisión nueva con '
            'consecuencias: tómala a la vista y borra esta prueba a '
            'propósito.\n\n'
            '${encontradas.map((i) => '${i.archivo}:${i.linea}  ${i.texto}').join('\n')}',
      );
    });
  });

  group('la prueba no pasa por vacía', () {
    test('el patrón reconoce una decisión por país', () {
      expect(patron.hasMatch("if (perfil.pais == 'CO') {"), isTrue);
      expect(patron.hasMatch("if ('CO' != pais) {"), isTrue);
      expect(patron.hasMatch('switch (elPais) {'), isTrue);
    });

    test('el patrón deja pasar guardar y mostrar', () {
      // Estos son los usos legítimos, y si los cazara nadie podría guardar el
      // dato que la feature pide.
      expect(patron.hasMatch("'pais': perfil.pais,"), isFalse);
      expect(patron.hasMatch('Text(perfil.pais ?? "Sin decir")'), isFalse);
      expect(patron.hasMatch('final pais = json["pais"] as String?;'), isFalse);
    });

    test('hay archivos que mirar', () {
      final total = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .length;

      expect(total, greaterThan(50));
    });
  });
}
