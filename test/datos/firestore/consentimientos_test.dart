/// Leer la constancia no puede morirse por la forma de un documento.
///
/// **Lo encontró el teléfono.** En el emulador de Android, `Ajustes` de un
/// nadador se quedaba girando para siempre. El documento de consentimiento
/// tenía la fecha guardada como texto y no como marca de tiempo —el sembrador
/// la escribía así—, y el `as Timestamp?` reventaba con un `TypeError`, que es
/// un `Error` y no una `Exception`: se escapaba del `catch` por tipo, subía
/// hasta la carga de la pantalla y la dejaba sin terminar.
///
/// Que el sembrador lo escribiera mal es una causa; **que una fecha con otra
/// forma deje a una persona sin sus derechos de la Ley 1581 es el defecto**.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/firestore/consentimientos.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';

void main() {
  group('la constancia se arma con lo que haya', () {
    test('una fecha en texto no tumba la lectura', () {
      final constancia = constanciaDesde({
        'vigente': true,
        'alcances': ['datosDeEntrenamiento'],
        'versionDelTexto': 'v1',
        'otorgadoEn': '2026-10-28T14:32:00.000Z',
      });

      expect(constancia.vigente, isTrue);
      expect(constancia.alcances, contains(Alcance.datosDeEntrenamiento));
      expect(constancia.versionDelTexto, 'v1');
    });

    test('y si la fecha no se entiende, se queda sin fecha, no sin constancia', () {
      final constancia = constanciaDesde({
        'vigente': true,
        'otorgadoEn': 42,
      });

      expect(constancia.vigente, isTrue);
      expect(
        constancia.otorgadoEn,
        isNull,
        reason:
            'Inventar una fecha para una constancia de consentimiento sería '
            'peor que no tenerla: es un dato legal',
      );
    });

    test('un documento vacío no afirma que hubo consentimiento', () {
      expect(constanciaDesde(const {}).vigente, isFalse);
    });
  });
}
