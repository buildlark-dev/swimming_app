/// Garantías A5 y A6 — ante la duda, menor; y nadie se queda menor para
/// siempre.
///
/// Esta es la pregunta más consecuente de la feature: de ella depende si a una
/// familia se le pide consentimiento. Equivocarse no se ve en pantalla, se ve
/// cuando alguien pregunta por qué los datos de una niña de doce años salieron
/// del teléfono sin que nadie autorizara nada.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/edad.dart';

void main() {
  final hoy = DateTime(2026, 10, 21);

  group('A5 — ante la duda, menor', () {
    test('sin fecha y sin declaración, hace falta acudiente', () {
      // El error de pedir un consentimiento que no hacía falta se arregla; el
      // de no pedirlo, no.
      expect(
        necesitaAcudiente(
          nacimiento: null,
          declaraSerMayorDeEdad: null,
          referencia: hoy,
        ),
        isTrue,
        reason: 'No saber la edad no es saber que es mayor',
      );
    });

    test('sin fecha, la declaración de ser mayor vale', () {
      // Es el respaldo para las cuentas creadas antes de esta feature, que
      // solo tienen eso.
      expect(
        necesitaAcudiente(
          nacimiento: null,
          declaraSerMayorDeEdad: true,
          referencia: hoy,
        ),
        isFalse,
      );
    });

    test('sin fecha, declarar ser menor también vale', () {
      expect(
        necesitaAcudiente(
          nacimiento: null,
          declaraSerMayorDeEdad: false,
          referencia: hoy,
        ),
        isTrue,
      );
    });

    test('la fecha manda sobre la declaración', () {
      // Alguien que declaró ser mayor y cuya fecha dice que no. La respuesta
      // prudente es pedir el consentimiento: una declaración es lo que alguien
      // escribió, y una fecha de nacimiento es un dato.
      expect(
        necesitaAcudiente(
          nacimiento: DateTime(2014, 3, 10),
          declaraSerMayorDeEdad: true,
          referencia: hoy,
        ),
        isTrue,
        reason: 'Declarar ser mayor no convierte a nadie en mayor',
      );
    });

    test('y también cuando la fecha dice que sí es mayor', () {
      expect(
        necesitaAcudiente(
          nacimiento: DateTime(1990, 3, 10),
          declaraSerMayorDeEdad: false,
          referencia: hoy,
        ),
        isFalse,
      );
    });

    test('no se supone la edad de nadie', () {
      expect(edadA(null, hoy), isNull);
      expect(esMenorA(null, hoy), isNull);
    });
  });

  group('A6 — nadie se queda menor para siempre', () {
    // Un número guardado envejece: quien se registra con 17 figuraría como
    // menor el resto de su vida. Por eso se guarda la fecha y se recalcula.
    final cumpleDieciocho = DateTime(2008, 6, 15);

    test('el día antes de cumplir 18, menor', () {
      expect(
        necesitaAcudiente(
          nacimiento: cumpleDieciocho,
          declaraSerMayorDeEdad: null,
          referencia: DateTime(2026, 6, 14),
        ),
        isTrue,
      );
    });

    test('el día que cumple 18, ya no', () {
      expect(
        necesitaAcudiente(
          nacimiento: cumpleDieciocho,
          declaraSerMayorDeEdad: null,
          referencia: DateTime(2026, 6, 15),
        ),
        isFalse,
        reason: 'Y nadie ha escrito nada: se recalcula de la fecha',
      );
    });

    test('el mismo perfil, dos respuestas, sin que nadie lo actualice', () {
      // Es la garantía entera en una línea.
      final nacimiento = cumpleDieciocho;
      final antes = necesitaAcudiente(
        nacimiento: nacimiento,
        declaraSerMayorDeEdad: null,
        referencia: DateTime(2026, 6, 14),
      );
      final despues = necesitaAcudiente(
        nacimiento: nacimiento,
        declaraSerMayorDeEdad: null,
        referencia: DateTime(2026, 6, 15),
      );

      expect(antes, isNot(despues));
    });
  });

  group('la edad se calcula bien en los bordes', () {
    test('el día del cumpleaños ya cuenta', () {
      expect(edadA(DateTime(2000, 10, 21), DateTime(2026, 10, 21)), 26);
      expect(edadA(DateTime(2000, 10, 22), DateTime(2026, 10, 21)), 25);
    });

    test('un 29 de febrero', () {
      // Nacer en año bisiesto no es un caso de prueba exótico: hay una persona
      // cada 1461.
      expect(edadA(DateTime(2008, 2, 29), DateTime(2026, 2, 28)), 17);
      expect(edadA(DateTime(2008, 2, 29), DateTime(2026, 3, 1)), 18);
    });

    test('recién nacido', () {
      expect(edadA(DateTime(2026, 10, 21), DateTime(2026, 10, 21)), 0);
    });
  });

  group('la mayoría de edad está en un solo sitio', () {
    test('son 18', () {
      // Si algún día la app distingue por país, este número deja de ser una
      // constante y esa es una decisión con consecuencias.
      expect(mayoriaDeEdad, 18);
    });
  });
}
