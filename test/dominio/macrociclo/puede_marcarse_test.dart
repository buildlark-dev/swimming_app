/// M24, M25, M28, FR-024, FR-025 — la regla es sobre la fecha, no sobre el
/// orden.
///
/// **Es la decisión del entrenador del 2026-11-04, y el motivo está en la
/// sección 4, paso 8.** El reajuste se hace sobre datos de adherencia. Una
/// regla que impidiera a un nadador registrar una sesión que de verdad nadó
/// haría que la app mintiera sobre lo que pasó, y entonces el reajuste estaría
/// modelando una ficción. La versión honesta enseña el hueco en lugar de negar
/// el hecho.
///
/// Escrito antes de `lib/dominio/macrociclo/puede_marcarse.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/puede_marcarse.dart';

void main() {
  final hoy = DateTime(2026, 11, 18);

  Sesion sesion(DateTime? fecha) =>
      Sesion(id: 's1', microcicloId: 'mc-1', fecha: fecha);

  group('la de hoy sí', () {
    test('la sesión de hoy se puede marcar', () {
      expect(puedeMarcarse(sesion: sesion(hoy), hoy: hoy).si, isTrue);
    });

    test('a las 23:00 de hoy también', () {
      // La sesión está fechada a las 00:00 y el nadador abre la app por la
      // noche. Comparando instantes, la sesión de hoy «ya pasó» —da igual—,
      // pero la de mañana a las 00:00 estaría «dentro de menos de un día» y
      // se podría marcar. Por eso se compara por fecha entera.
      expect(
        puedeMarcarse(
          sesion: sesion(DateTime(2026, 11, 18)),
          hoy: DateTime(2026, 11, 18, 23),
        ).si,
        isTrue,
      );
    });

    test('a las 00:30 de hoy también', () {
      expect(
        puedeMarcarse(
          sesion: sesion(DateTime(2026, 11, 18, 19)),
          hoy: DateTime(2026, 11, 18, 0, 30),
        ).si,
        isTrue,
      );
    });
  });

  group('la de ayer sí, pase lo que pase (M25, FR-025)', () {
    test('una sesión pasada se puede marcar', () {
      final resultado = puedeMarcarse(
        sesion: sesion(DateTime(2026, 11, 16)),
        hoy: hoy,
      );
      expect(resultado.si, isTrue);
    });

    test('una de hace un mes también: un día saltado no es una puerta '
        'cerrada', () {
      // M27. La regla no sabe nada del orden a propósito: si supiera, alguien
      // podría hacerla depender de él.
      expect(
        puedeMarcarse(sesion: sesion(DateTime(2026, 10, 12)), hoy: hoy).si,
        isTrue,
      );
    });
  });

  group('la de mañana no, y se explica (M24, FR-024)', () {
    test('una sesión de mañana no se puede marcar', () {
      final resultado = puedeMarcarse(
        sesion: sesion(DateTime(2026, 11, 19)),
        hoy: hoy,
      );

      expect(resultado.si, isFalse);
      expect(resultado, isA<TodaviaNo>());
    });

    test('y el nadador lee por qué, en español y sin jerga', () {
      final resultado = puedeMarcarse(
        sesion: sesion(DateTime(2026, 11, 19)),
        hoy: hoy,
      );

      expect(resultado.comoSeLeExplica, 'Todavía no llega ese día');
    });

    test('una de dentro de un mes tampoco', () {
      expect(
        puedeMarcarse(sesion: sesion(DateTime(2026, 12, 18)), hoy: hoy).si,
        isFalse,
      );
    });

    test('mañana a las 00:01 tampoco, aunque falte poco', () {
      // **La frontera.** Comparando instantes, a las 23:59 de hoy la sesión de
      // mañana está a dos minutos y «casi» se puede marcar. Por fecha entera,
      // mañana es mañana.
      expect(
        puedeMarcarse(
          sesion: sesion(DateTime(2026, 11, 19, 0, 1)),
          hoy: DateTime(2026, 11, 18, 23, 59),
        ).si,
        isFalse,
      );
    });
  });

  group('sin fecha no se adivina (M28)', () {
    test('una sesión sin día asignado no se puede marcar', () {
      final resultado = puedeMarcarse(sesion: sesion(null), hoy: hoy);

      expect(resultado.si, isFalse);
      expect(resultado, isA<SinFecha>());
    });

    test('y se dice eso, no «todavía no llega»', () {
      // Son dos cosas distintas y confundirlas deja al nadador esperando un
      // día que no existe. `Sesion.fecha` es nulo de verdad en el dominio, así
      // que este no es un caso defensivo: es un caso.
      final resultado = puedeMarcarse(sesion: sesion(null), hoy: hoy);

      expect(resultado.comoSeLeExplica, 'Esta sesión no tiene día asignado');
      expect(resultado.comoSeLeExplica, isNot(contains('Todavía no llega')));
    });
  });

  group('es una función total', () {
    test('para cualquier fecha hay respuesta y se puede leer', () {
      // **Las sesiones a las 19:00 y el nadador abriendo la app a las 07:00.**
      //
      // Con las dos a medianoche, comparar instantes y comparar fechas dan lo
      // mismo y el barrido no vigila la guarda. Lo destapó el control negativo
      // de T057: la primera versión de este barrido usaba las 00:00 y seguía
      // verde con `fecha.isAfter(hoy)` puesto a pelo.
      //
      // Con estas horas, el día de hoy distingue: por instantes la sesión de
      // esta tarde «todavía no llegó», y eso es falso.
      final porLaManana = DateTime(2026, 11, 18, 7);

      for (var dias = -400; dias <= 400; dias++) {
        final resultado = puedeMarcarse(
          sesion: sesion(DateTime(2026, 11, 18, 19).add(Duration(days: dias))),
          hoy: porLaManana,
        );

        expect(
          resultado.si,
          dias <= 0,
          reason: 'con la sesión a $dias días la respuesta no cuadra',
        );
        if (!resultado.si) {
          expect(resultado.comoSeLeExplica.trim(), isNotEmpty);
        }
      }
    });

    test('la explicación nunca está vacía cuando dice que no', () {
      for (final resultado in [
        puedeMarcarse(sesion: sesion(DateTime(2027, 1, 1)), hoy: hoy),
        puedeMarcarse(sesion: sesion(null), hoy: hoy),
      ]) {
        expect(resultado.comoSeLeExplica.trim(), isNotEmpty);
        expect(resultado.comoSeLeExplica, isNot(contains('null')));
      }
    });
  });
}
