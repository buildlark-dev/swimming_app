/// Completar el perfil **no cambia el rol** (FR-024).
///
/// Es el fallo que más caro saldría de toda la feature. La cuenta del
/// entrenador es una de las que no tienen perfil, así que la primera vez que
/// entre después de desplegar esto recorrerá los pasos del alta. Si al terminar
/// saliera como nadador, se quedaría sin poder aprobar ni publicar nada, y el
/// único camino de vuelta es el comando administrativo.
///
/// Lo que lo garantiza no es una comprobación en tiempo de ejecución: es **que
/// el alta no toca el rol en absoluto**. El rol vive en un custom claim del
/// token, lo pone el servidor al crearse la cuenta, y solo lo cambia la
/// operación administrativa. `guardarPerfil` escribe en `usuarios/{uid}` y no
/// se acerca a la autenticación.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String leer(String ruta) => File(ruta).readAsStringSync();

  /// Usos **de código** del rol, no la palabra.
  ///
  /// «Tu entrenador» sale en el texto que lee el nadador, y eso está bien. Lo
  /// que no puede haber es nada que lea o escriba el rol.
  ///
  /// Se define una sola vez: si el control de abajo probara un patrón distinto
  /// del que se usa arriba, estaría aprobando otra prueba.
  final patron = RegExp(
    r'\bRol\.|\bRol\s|\brol\s*[:=]|\.rol\b|asignarRol|'
    r'setCustomUserClaims|esEntrenador',
  );

  group('FR-024 — el alta no se acerca al rol', () {
    test('ningún archivo del alta lo lee ni lo escribe', () {
      final culpables = <String>[];

      for (final archivo in Directory('lib/ui/alta')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lineas = archivo.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final limpia = lineas[i].trimLeft();
          if (limpia.startsWith('//') || limpia.startsWith('///')) continue;

          if (patron.hasMatch(lineas[i])) {
            culpables.add(
              '${archivo.path.replaceAll(r'\', '/')}:${i + 1}  '
              '${lineas[i].trim()}',
            );
          }
        }
      }

      expect(
        culpables,
        isEmpty,
        reason: 'El alta no tiene nada que decir sobre el rol. Si una cuenta '
            'de entrenador completara su perfil y saliera como nadadora, se '
            'quedaría sin poder aprobar ni publicar, y el único camino de '
            'vuelta es el comando administrativo.\n\n'
            '${culpables.join('\n')}',
      );
    });

    test('la operación del servidor tampoco toca la autenticación', () {
      final codigo = leer('firebase/functions/src/perfil.ts');

      expect(
        codigo.contains('setCustomUserClaims'),
        isFalse,
        reason: 'Guardar un nombre no puede cambiar quién eres',
      );
      expect(codigo.contains('getAuth'), isFalse);
    });

    test('y escribe con merge, para no borrar el vínculo con el nadador', () {
      // `usuarios/{uid}` lleva el `nadadorId` que el servidor puso cuando el
      // entrenador asoció la cuenta a un perfil. Un `set` sin `merge` lo
      // borraría, y el nadador se quedaría sin sus planes.
      final codigo = leer('firebase/functions/src/perfil.ts');

      expect(codigo, contains('merge: true'));
    });
  });

  group('la prueba no pasa por vacía', () {
    test('hay archivos de alta que mirar', () {
      final cuantos = Directory('lib/ui/alta')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .length;

      expect(cuantos, greaterThanOrEqualTo(6));
    });

    test('el patrón caza un uso de código y deja pasar el texto', () {
      expect(patron.hasMatch('if (cuenta.rol == Rol.entrenador) {'), isTrue);
      expect(patron.hasMatch('await getAuth().setCustomUserClaims(...)'),
          isTrue);

      // Lo que el nadador lee, y que tiene que seguir pudiéndose escribir.
      expect(
        patron.hasMatch("const Text('Es lo que verá tu entrenador.'),"),
        isFalse,
      );
      expect(patron.hasMatch('await servidor.guardarPerfil(...)'), isFalse);
    });
  });
}
