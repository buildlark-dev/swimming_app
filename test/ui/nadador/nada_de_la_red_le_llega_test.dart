/// **Al nadador no le llega nada de la red** (FR-008).
///
/// Ni un error, ni un código de estado, ni cuántos intentos lleva, ni un botón
/// de reintentar. El reintento es trabajo de la app, y alguien mojado al borde
/// de una piscina no está ahí para diagnosticar conectividad.
///
/// Es una regla de la feature 003 —su contrato la escribe— y esta feature la
/// pone a prueba sobre el código en lugar de confiar en que se cumple, que es
/// la misma forma que la 010 usó para el vídeo.
///
/// **Lo que sí puede ver**: la frase de FR-017, palabra por palabra, que es una
/// buena noticia y no un error — «lo tuyo está guardado y saldrá solo».
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Lo que no puede aparecer en algo que el nadador lee.
  ///
  /// Se buscan en minúsculas y solo fuera de los comentarios: explicar por qué
  /// algo no está es parte de que no esté.
  const prohibido = <String, String>{
    'reintentar': 'un botón o un texto de reintentar: el reintento es de la app',
    'reintento': 'hablarle de reintentos es hablarle de fontanería',
    'statuscode': 'un código de estado no le dice nada a nadie mojado',
    'código de error': 'lo mismo, con otras palabras',
    'error de red': 'la falta de señal no es un error suyo',
    'sin internet': 'la app no le riñe por dónde entrena',
    'firebaseexception': 'una excepción de la librería no es un mensaje',
    'socketexception': 'ídem',
    'timeout': 'un plazo vencido es asunto interno',
  };

  test('ninguna pantalla del nadador le habla de la red', () {
    final carpeta = Directory('lib/ui/nadador');
    expect(
      carpeta.existsSync(),
      isTrue,
      reason: 'no se encontró lib/ui/nadador; ¿cambió la estructura?',
    );

    final hallazgos = <String>[];
    var archivosLeidos = 0;

    for (final entrada in carpeta.listSync(recursive: true)) {
      if (entrada is! File || !entrada.path.endsWith('.dart')) continue;

      archivosLeidos++;

      // Los finales de línea se normalizan: en Windows git materializa los
      // archivos con CRLF, y un cerrojo que parta por líneas tiene que leer lo
      // mismo en las dos plataformas. La feature 010 perdió uno por esto.
      final lineas = entrada
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .split('\n');

      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        final limpia = linea.trimLeft();
        if (limpia.startsWith('//') || limpia.startsWith('///')) continue;

        final enMinusculas = linea.toLowerCase();
        for (final entrada2 in prohibido.entries) {
          if (enMinusculas.contains(entrada2.key)) {
            hallazgos.add(
              '${entrada.path}:${i + 1} -> ${linea.trim()}\n'
              '    (${entrada2.value})',
            );
          }
        }
      }
    }

    // Que no pase por vacía, que es el defecto que la 009 encontró dos veces.
    expect(
      archivosLeidos,
      greaterThan(4),
      reason: 'se leyeron $archivosLeidos archivos: la prueba estaría vacía',
    );

    expect(
      hallazgos,
      isEmpty,
      reason:
          'esto le llega a una nadadora:\n${hallazgos.join('\n')}\n\n'
          'El contrato de la feature 003 es explícito: nunca un error de red, '
          'un código, un contador de reintentos ni un botón de reintentar.',
    );
  });

  test('y la frase que sí ve sigue intacta', () {
    final fuente = File(
      'lib/dominio/sincronizacion/bandeja_salida.dart',
    ).readAsStringSync();

    expect(
      fuente,
      contains(
        'Guardado el progreso, se enviará cuando tengas acceso a internet',
      ),
      reason:
          'FR-017 la exige al pie de la letra. Es lo único que la app le dice '
          'sobre el envío, y es una buena noticia: no se perdió nada',
    );
  });
}
