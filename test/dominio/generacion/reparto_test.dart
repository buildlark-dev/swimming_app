import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/generacion/reparto.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// Invariantes 1, 2 y 7 de `data-model.md`, y la regla de redondeo de
/// `contracts/generacion.md`.
///
/// **El reparto es el cimiento de la feature.** Si no cierra exacto o no es
/// determinista, todas las distribuciones que se apoyen en él arrastrarán el
/// error sin que se note en pantalla.
void main() {
  group('la suma cierra exacta (invariante 1)', () {
    test('un reparto de porcentajes que suman 100 devuelve el total', () {
      final reparto = repartirPorRestoMayor(
        unidades: 240,
        porcentajes: const {'A1': 60, 'A2': 25, 'A3': 10, 'AT': 5},
        orden: const ['A1', 'A2', 'A3', 'AT'],
      );

      expect(reparto.values.fold(0, (a, b) => a + b), 240);
    });

    test('también cuando los porcentajes no reparten redondo', () {
      final reparto = repartirPorRestoMayor(
        unidades: 7,
        porcentajes: const {'A': 33, 'B': 33, 'C': 34},
        orden: const ['A', 'B', 'C'],
      );

      expect(reparto.values.fold(0, (a, b) => a + b), 7);
    });

    test('con muchas unidades y porcentajes incómodos', () {
      for (final unidades in [1, 3, 7, 13, 97, 241, 1103]) {
        final reparto = repartirPorRestoMayor(
          unidades: unidades,
          porcentajes: const {'A1': 30, 'A2': 35, 'A3': 15, 'AT': 15, 'Max': 5},
          orden: const ['A1', 'A2', 'A3', 'AT', 'Max'],
        );

        expect(
          reparto.values.fold(0, (a, b) => a + b),
          unidades,
          reason: 'Falló con $unidades unidades',
        );
      }
    });

    test('cero unidades reparte cero a todos', () {
      final reparto = repartirPorRestoMayor(
        unidades: 0,
        porcentajes: const {'A1': 60, 'A2': 40},
        orden: const ['A1', 'A2'],
      );

      expect(reparto.values.every((v) => v == 0), isTrue);
    });
  });

  group('no aparecen ni desaparecen metros', () {
    test('una clave con 0% recibe 0 unidades', () {
      final reparto = repartirPorRestoMayor(
        unidades: 100,
        porcentajes: const {'A1': 60, 'A2': 40, 'Vel': 0},
        orden: const ['A1', 'A2', 'Vel'],
      );

      expect(reparto['Vel'], 0);
    });

    test('ninguna clave recibe una cantidad negativa', () {
      final reparto = repartirPorRestoMayor(
        unidades: 3,
        porcentajes: const {'A1': 25, 'A2': 25, 'A3': 25, 'AT': 25},
        orden: const ['A1', 'A2', 'A3', 'AT'],
      );

      expect(reparto.values.every((v) => v >= 0), isTrue);
    });
  });

  group('determinismo (invariante 7)', () {
    test('repetir el reparto da exactamente lo mismo', () {
      Map<String, int> hacer() => repartirPorRestoMayor(
        unidades: 241,
        porcentajes: const {
          'A1': 25,
          'A2': 25,
          'A3': 15,
          'AT': 10,
          'Max': 15,
          'Vel': 10,
        },
        orden: const ['A1', 'A2', 'A3', 'AT', 'Max', 'Vel'],
      );

      expect(hacer(), hacer());
      expect(hacer(), hacer());
    });

    test(
      'el orden de las claves del mapa de entrada no cambia el resultado',
      () {
        final unOrden = repartirPorRestoMayor(
          unidades: 7,
          porcentajes: const {'A': 33, 'B': 33, 'C': 34},
          orden: const ['A', 'B', 'C'],
        );
        final otroOrden = repartirPorRestoMayor(
          unidades: 7,
          porcentajes: const {'C': 34, 'B': 33, 'A': 33},
          orden: const ['A', 'B', 'C'],
        );

        expect(
          unOrden,
          otroOrden,
          reason: 'El desempate lo fija el parámetro `orden`, no el mapa',
        );
      },
    );
  });

  group('desempate por orden fijo', () {
    test('con restos iguales, el sobrante va al primero del orden', () {
      // 1 unidad entre dos al 50%: ambos tienen resto 0,5.
      final reparto = repartirPorRestoMayor(
        unidades: 1,
        porcentajes: const {'A1': 50, 'A2': 50},
        orden: const ['A1', 'A2'],
      );

      expect(reparto['A1'], 1);
      expect(reparto['A2'], 0);
    });

    test('invertir el orden invierte a quién le toca', () {
      final reparto = repartirPorRestoMayor(
        unidades: 1,
        porcentajes: const {'A1': 50, 'A2': 50},
        orden: const ['A2', 'A1'],
      );

      expect(reparto['A2'], 1);
      expect(reparto['A1'], 0);
    });

    test('el orden de zonas de la metodología es el que se usa', () {
      expect(ordenDeZonas, [
        Zona.a1,
        Zona.a2,
        Zona.a3,
        Zona.at,
        Zona.resistenciaIntensiva,
        Zona.velocidad,
        Zona.explosivo,
      ]);
    });

    test('el orden cubre las siete zonas, sin olvidar ninguna', () {
      expect(
        ordenDeZonas.toSet(),
        Zona.values.toSet(),
        reason:
            'Una zona fuera del orden de desempate no recibiría metros y '
            'el reparto dejaría de cerrar exacto',
      );
    });
  });

  group('reparto de zonas con las constantes reales', () {
    test('Acumulación sobre 240 unidades da 144/60/24/12', () {
      final reparto = repartirZonas(
        unidades: 240,
        porcentajes: const {
          Zona.a1: 60,
          Zona.a2: 25,
          Zona.a3: 10,
          Zona.at: 5,
          Zona.resistenciaIntensiva: 0,
          Zona.velocidad: 0,
        },
      );

      expect(reparto[Zona.a1], 144);
      expect(reparto[Zona.a2], 60);
      expect(reparto[Zona.a3], 24);
      expect(reparto[Zona.at], 12);
      expect(reparto[Zona.resistenciaIntensiva], 0);
      expect(reparto[Zona.velocidad], 0);
    });

    test('la suma coincide con las unidades pedidas', () {
      final reparto = repartirZonas(
        unidades: 241,
        porcentajes: const {
          Zona.a1: 25,
          Zona.a2: 25,
          Zona.a3: 15,
          Zona.at: 10,
          Zona.resistenciaIntensiva: 15,
          Zona.velocidad: 10,
        },
      );

      expect(reparto.values.fold(0, (a, b) => a + b), 241);
    });
  });

  group('cuantización a metros (invariante 2)', () {
    test('convierte unidades a metros múltiplos de la longitud de piscina', () {
      expect(aMetros(144, 25), 3600);
      expect(aMetros(144, 50), 7200);
    });

    test('el total en unidades sale de dividir por la longitud', () {
      expect(aUnidades(6000, 25), 240);
      expect(aUnidades(6000, 50), 120);
    });

    test('un volumen que no es múltiplo se rechaza', () {
      expect(() => aUnidades(6010, 25), throwsArgumentError);
    });

    test('cuantizar lleva al múltiplo más cercano', () {
      expect(cuantizar(2010, 25), 2000);
      expect(cuantizar(2015, 25), 2025);
      expect(cuantizar(2010, 50), 2000);
      expect(cuantizar(2030, 50), 2050);
    });
  });
}
