/// Que el cliente y el servidor hablen de lo mismo.
///
/// **Esta prueba existe por un fallo que ninguna otra podía ver.** El cliente
/// mandaba los datos del acudiente sueltos y el servidor los esperaba anidados
/// en `declaracion`. Resultado: un acudiente con el formulario entero relleno
/// y las dos casillas marcadas leía «Hace falta quién es usted y en qué calidad
/// actúa».
///
/// Había diez pruebas recorriendo el camino del acudiente y las diez pasaban,
/// porque **los dobles implementan la interfaz de Dart, no el cable**. Entre
/// `OperacionesDelServidor` y la función del servidor no había nada que
/// comprobara que los nombres coincidían.
///
/// Así que esto lee el código del servidor y comprueba que lo que el cliente
/// manda es lo que allí se desempaqueta. Es tosco y encuentra justo la clase de
/// error que cuesta tres rondas de despliegue.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';

void main() {
  final servidor =
      File('firebase/functions/src/consentimiento.ts').readAsStringSync();

  // Lo que `canjear` desempaqueta de `peticion.data`.
  final desde = servidor.indexOf('export const canjear');
  final bloqueDeCanje =
      servidor.substring(desde, servidor.indexOf('if (!token)', desde));

  group('canjear — el cuerpo que se manda es el que se lee', () {
    final cuerpo = cuerpoDeCanje(
      token: 'un-token',
      nombre: 'María Restrepo',
      documento: '43218765',
      calidad: 'madre',
      esRepresentanteLegal: true,
      menorFueOido: true,
      versionDelTexto: 'v1',
    );

    test('el token va en la raíz', () {
      expect(cuerpo['token'], 'un-token');
      expect(bloqueDeCanje, contains('token'));
    });

    test('**los datos del acudiente van dentro de `declaracion`**', () {
      // Es exactamente lo que estaba mal.
      expect(
        cuerpo['declaracion'],
        isA<Map<String, dynamic>>(),
        reason: 'El servidor hace `const { token, declaracion } = ...`',
      );
      expect(
        bloqueDeCanje,
        contains('declaracion'),
        reason: 'Si el servidor dejara de anidarlos, esto se entera aquí y no '
            'en el formulario de un acudiente',
      );
    });

    test('cada campo que el servidor exige va en el sitio correcto', () {
      final declaracion = cuerpo['declaracion'] as Map<String, dynamic>;

      // Los tres que el servidor comprueba antes de nada: sin ellos devuelve
      // «Hace falta quién es usted y en qué calidad actúa».
      for (final campo in ['nombre', 'documento', 'calidad']) {
        expect(
          declaracion[campo],
          isNotNull,
          reason: 'El servidor rechaza el canje sin «$campo»',
        );
        expect(
          bloqueDeCanje,
          contains(campo),
          reason: 'El servidor ya no lee «$campo»: el cliente lo manda de más',
        );
      }

      // Los que la ley pide declarar.
      expect(declaracion['esRepresentanteLegal'], isTrue);
      expect(declaracion['menorFueOido'], isTrue);
      expect(declaracion['versionDelTexto'], 'v1');

      for (final campo in [
        'esRepresentanteLegal',
        'menorFueOido',
        'versionDelTexto',
      ]) {
        expect(bloqueDeCanje, contains(campo));
      }
    });

    test('nada se manda suelto en la raíz', () {
      // Lo que hacía el cliente antes. Si vuelve a pasar, falla aquí.
      expect(cuerpo.keys.toSet(), {'token', 'declaracion'});
    });
  });

  group('la prueba no pasa por vacía', () {
    test('el archivo del servidor existe y tiene la función', () {
      expect(servidor, contains('export const canjear'));
      expect(bloqueDeCanje.length, greaterThan(100));
    });

    test('sabría ver un campo que el servidor no lee', () {
      expect(bloqueDeCanje, isNot(contains('inventadoQueNadieLee')));
    });
  });
}
