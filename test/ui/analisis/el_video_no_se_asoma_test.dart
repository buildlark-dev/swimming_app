/// El vídeo **no se asoma a la interfaz** (FR-023).
///
/// El campo existe en el modelo y la puerta existe en las reglas; ninguno de
/// los dos se usa. Eso fue la decisión Q1 del entrenador —dejarlo listo desde
/// ya, aunque no sea obligatorio subirlo— y el motivo lo dejó escrito la
/// feature 004 sobre los alcances: descubrir más tarde que hace falta un
/// consentimiento distinto significaría volver a pedírselo a cada familia.
///
/// Lo que **no** se puede hacer es insinuarlo. Un control que la app no puede
/// cumplir es una promesa que no debería hacer, y «pronto podrás subir un
/// vídeo» es exactamente eso. Así que la palabra no aparece en ninguna
/// pantalla, y esta prueba lo convierte en algo que el sistema comprueba en
/// lugar de algo que hay que recordar al escribir la siguiente pantalla.
///
/// Es la misma forma que `test/dominio/arquitectura_test.dart` usa para la
/// frontera del dominio, y por la misma razón: una regla que se vigila sola.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ninguna pantalla menciona el vídeo', () {
    final carpeta = Directory('lib/ui');
    expect(
      carpeta.existsSync(),
      isTrue,
      reason: 'no se encontró lib/ui; ¿cambió la estructura?',
    );

    final menciones = <String>[];
    var archivosLeidos = 0;

    for (final entrada in carpeta.listSync(recursive: true)) {
      if (entrada is! File || !entrada.path.endsWith('.dart')) continue;

      archivosLeidos++;

      final lineas = entrada.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        final limpia = linea.trimLeft();

        // Los comentarios pueden nombrarlo: explicar por qué no está es parte
        // de que no esté. Lo que se vigila es el código y el texto visible.
        if (limpia.startsWith('//') || limpia.startsWith('///')) continue;

        final enMinusculas = linea.toLowerCase();
        if (enMinusculas.contains('video') || enMinusculas.contains('vídeo')) {
          menciones.add('${entrada.path}:${i + 1} -> ${linea.trim()}');
        }
      }
    }

    // Que la prueba no pase por vacía: la feature 005 aprendió que un banco
    // solo mide los caminos que monta.
    expect(
      archivosLeidos,
      greaterThan(20),
      reason: 'se leyeron $archivosLeidos archivos: la prueba estaría vacía',
    );

    expect(
      menciones,
      isEmpty,
      reason:
          'la interfaz no menciona el vídeo, no lo ofrece y no insinúa que '
          'llegará (FR-023). El campo y la puerta existen; la capacidad no, y '
          'un control que la app no puede cumplir es una promesa que no '
          'debería hacer',
    );
  });
}
