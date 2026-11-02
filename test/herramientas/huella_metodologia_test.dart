import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/verificar_metodologia.dart';

/// La huella de un documento normativo mide **contenido**, no bytes en disco.
///
/// Esto falló de verdad, y falló en silencio durante dos versiones de
/// metodología. Git convierte los finales de línea al sacar los archivos del
/// repositorio: un clon en Windows recibe CRLF y uno en Linux recibe LF, para
/// el mismo contenido. El CI corre en Linux y aprobaba; el entrenador trabaja
/// en Windows y, al cambiar de rama, la puerta de calidad se caía diciendo que
/// un documento normativo había cambiado sin subir la versión.
///
/// No había cambiado nada. La herramienta medía la cosa equivocada.
void main() {
  late Directory temporal;

  setUp(() => temporal = Directory.systemTemp.createTempSync('huella'));
  tearDown(() => temporal.deleteSync(recursive: true));

  File escribir(String nombre, List<int> bytes) =>
      File('${temporal.path}/$nombre')..writeAsBytesSync(bytes);

  group('los finales de línea no cambian la huella', () {
    test('el mismo texto con CRLF y con LF da la misma huella', () {
      const texto = '# Sección 11\n\nIniciación: 500-800 m.\nDos por semana.\n';

      final conLf = escribir('lf.md', utf8.encode(texto));
      final conCrLf = escribir(
        'crlf.md',
        utf8.encode(texto.replaceAll('\n', '\r\n')),
      );

      expect(
        huellaDe(conCrLf),
        huellaDe(conLf),
        reason:
            'Una conversión de finales de línea no cambia ni una regla de '
            'entrenamiento. Si cambia la huella, la puerta avisa de algo que '
            'no pasó, y quien la vea aprenderá a ignorarla',
      );
    });

    test('la huella es la del contenido en LF', () {
      // El valor que se anota en el manifiesto tiene que poder calcularse sin
      // saber en qué sistema operativo se generó.
      const texto = 'Una línea\nOtra línea\n';
      final esperada = sha256.convert(utf8.encode(texto)).toString();

      final conCrLf = escribir(
        'doc.md',
        utf8.encode(texto.replaceAll('\n', '\r\n')),
      );

      expect(huellaDe(conCrLf), esperada);
    });
  });

  group('lo que sí tiene que detectar lo sigue detectando', () {
    test('cambiar una palabra cambia la huella', () {
      final antes = escribir(
        'antes.md',
        utf8.encode('Iniciación: 500-800 m\n'),
      );
      final despues = escribir(
        'despues.md',
        utf8.encode('Iniciación: 500-900 m\n'),
      );

      expect(huellaDe(despues), isNot(huellaDe(antes)));
    });

    test('cambiar un solo carácter cambia la huella', () {
      final antes = escribir('a.md', utf8.encode('A1 60-70 %FCmáx\n'));
      final despues = escribir('b.md', utf8.encode('A1 60-71 %FCmáx\n'));

      expect(huellaDe(despues), isNot(huellaDe(antes)));
    });

    test('añadir una línea en blanco cambia la huella', () {
      // Normalizar CRLF no es lo mismo que ignorar los saltos de línea. La
      // estructura del documento sigue formando parte de lo que se sella.
      final antes = escribir('c.md', utf8.encode('Uno\nDos\n'));
      final despues = escribir('d.md', utf8.encode('Uno\n\nDos\n'));

      expect(huellaDe(despues), isNot(huellaDe(antes)));
    });
  });

  group('los binarios se resumen tal cual', () {
    test('un .docx no se normaliza', () {
      // Dentro de un archivo comprimido, un 0x0D seguido de un 0x0A es dato,
      // no un final de línea. Normalizarlo lo corrompería y, peor, haría que
      // dos binarios distintos compartieran huella.
      final bytes = [0x50, 0x4B, 0x03, 0x04, 0x0D, 0x0A, 0x00, 0x01];
      final binario = escribir('biblioteca.docx', bytes);

      expect(huellaDe(binario), sha256.convert(bytes).toString());
    });

    test('dos binarios que solo difieren en un CRLF no comparten huella', () {
      final uno = escribir('uno.docx', [0x50, 0x4B, 0x0D, 0x0A, 0x01]);
      final otro = escribir('otro.docx', [0x50, 0x4B, 0x01]);

      expect(huellaDe(otro), isNot(huellaDe(uno)));
    });
  });

  group('un retorno de carro suelto es contenido, no formato', () {
    test('un \\r sin \\n detrás se conserva', () {
      final conRetorno = escribir('r.md', [65, 13, 66]); // A \r B
      final sinRetorno = escribir('sin.md', [65, 66]); // A B

      expect(
        huellaDe(conRetorno),
        isNot(huellaDe(sinRetorno)),
        reason:
            'Solo se normaliza la secuencia CRLF. Borrar todo \\r sería '
            'quitar contenido del documento normativo',
      );
    });
  });

  group('el documento normativo de verdad', () {
    test('su huella coincide con la que declara el manifiesto', () {
      // La comprobación que la herramienta hace en la puerta de calidad, aquí
      // como prueba, para que un fallo salga en `flutter test` y no solo al
      // acordarse de correr la herramienta.
      final manifiesto =
          jsonDecode(
                File('docs/metodologia/metodologia.json').readAsStringSync(),
              )
              as Map<String, dynamic>;

      for (final entrada in manifiesto['documentos'] as List<dynamic>) {
        final documento = entrada as Map<String, dynamic>;
        final ruta = documento['ruta'] as String;
        final archivo = File(ruta);

        expect(
          archivo.existsSync(),
          isTrue,
          reason: '$ruta no está en el árbol',
        );
        expect(
          huellaDe(archivo),
          documento['sha256'],
          reason:
              'La huella de $ruta no coincide. O cambió una regla de '
              'entrenamiento sin subir la versión, o la huella se anotó mal',
        );
      }
    });
  });
}
