/// Garantías H1, H2 y H3 — la barra.
///
/// Cinco destinos, en un orden, con `Home` al centro, y el mismo orden para los
/// dos roles. Se comprueba aquí, en el dominio, porque es una propiedad de una
/// estructura de datos y no de una pantalla: si hubiera que pintar algo para
/// saberlo, cada cambio de maquetación podría romperlo sin que nadie se enterara.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/hub/destino.dart';

void main() {
  group('los destinos', () {
    test('H1 — son exactamente cinco', () {
      expect(Destino.values, hasLength(5));
    });

    test('H1 — en este orden y con estas etiquetas', () {
      expect(Destino.values.map((d) => d.etiqueta).toList(), [
        'Generar',
        'Ver Plan',
        'Home',
        'Análisis',
        'Ajustes',
      ]);
    });

    test('H2 — Home ocupa la posición central', () {
      expect(Destino.home.posicion, 2);

      // Y «central» de verdad: dos a cada lado.
      final antes = Destino.values.where((d) => d.posicion < 2).length;
      final despues = Destino.values.where((d) => d.posicion > 2).length;
      expect(antes, despues);
    });

    test('las posiciones van de 0 a 4, sin huecos y sin repetir', () {
      expect(Destino.values.map((d) => d.posicion).toList(), [0, 1, 2, 3, 4]);
    });

    test('ninguna etiqueta está vacía ni lleva espacios de sobra', () {
      for (final destino in Destino.values) {
        expect(destino.etiqueta, isNotEmpty);
        expect(destino.etiqueta, destino.etiqueta.trim());
      }
    });
  });
}
