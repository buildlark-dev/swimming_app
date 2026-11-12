/// Garantías P21, P22 y P23 — la fase se deriva contando hacia atrás.
///
/// **Esta es la única regla de entrenamiento nueva de la feature 008**, y por
/// eso llega con su prueba antes que su implementación (principio III). Las
/// fronteras salen de las duraciones de bloque que la sección 12 de la
/// metodología cita —Issurin 2010: Realización 8-15 días, Transformación 2-4
/// semanas, Acumulación 2-6— y de la decisión D3 de `research.md`: se toma el
/// **límite superior** de cada ventana publicada.
///
/// Por qué el superior y no el inferior, que es lo que el entrenador confirmó
/// en T065: con el inferior, un nadador a diez días de competir caería en
/// Transformación, **dentro de la ventana de afinación publicada**, que es el
/// error que cuesta una competencia.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/peticiones/fase_por_fecha.dart';

void main() {
  final hoy = DateTime(2026, 11, 2);

  DateTime enDias(int dias) => hoy.add(Duration(days: dias));

  FaseDerivada derivar(
    int? dias, {
    Categoria categoria = Categoria.competitivo,
  }) => faseParaCompetencia(
    fechaDeCompetencia: dias == null ? null : enDias(dias),
    hoy: hoy,
    categoria: categoria,
  );

  group('P21 — las tres fases, por días hasta la competencia', () {
    test('a 1 día, Realización', () {
      expect(derivar(1).fase, FaseAtr.realizacion);
    });

    test('a 15 días, todavía Realización', () {
      // Frontera superior de la ventana publicada de Realización (8-15 días).
      expect(derivar(15).fase, FaseAtr.realizacion);
    });

    test('a 16 días, ya Transformación', () {
      expect(derivar(16).fase, FaseAtr.transformacion);
    });

    test('a 43 días, todavía Transformación', () {
      // 15 de Realización + 28 de Transformación (4 semanas, el superior).
      expect(derivar(43).fase, FaseAtr.transformacion);
    });

    test('a 44 días, Acumulación', () {
      expect(derivar(44).fase, FaseAtr.acumulacion);
    });

    test('a mucho tiempo, Acumulación', () {
      expect(derivar(200).fase, FaseAtr.acumulacion);
    });
  });

  group('P23 — una fecha que no sirve no es una fecha', () {
    test('hoy mismo no deriva fase', () {
      expect(derivar(0).fase, isNull);
    });

    test('una competencia que ya pasó tampoco', () {
      // Derivar «Realización» de algo que ya ocurrió sería rellenar un hueco
      // con una suposición, que es lo que la regla R3 prohíbe.
      expect(derivar(-3).fase, isNull);
    });

    test('sin fecha, sin fase', () {
      expect(derivar(null).fase, isNull);
    });
  });

  group('P22 — donde el motor prohíbe fase, no hay fase', () {
    test('Iniciación no usa ATR, aunque haya fecha', () {
      expect(derivar(20, categoria: Categoria.iniciacion).fase, isNull);
    });

    test('Tecnificación tampoco', () {
      expect(derivar(10, categoria: Categoria.tecnificacion).fase, isNull);
    });

    test('y las que sí lo usan, sí', () {
      for (final categoria in Categoria.values.where((c) => c.usaAtr)) {
        expect(
          derivar(20, categoria: categoria).fase,
          isNotNull,
          reason: '${categoria.nombre} usa ATR y el motor exige fase',
        );
      }
    });
  });

  group('la razón se dice siempre, y se puede leer', () {
    test('con fase, dice cuántos días faltan', () {
      final derivada = derivar(24);

      expect(derivada.diasHastaLaCompetencia, 24);
      expect(derivada.porQue, contains('24'));
      expect(derivada.porQue, contains(FaseAtr.transformacion.nombre));
    });

    test('sin fecha, dice que no hay fecha', () {
      final derivada = derivar(null);

      expect(derivada.diasHastaLaCompetencia, isNull);
      expect(derivada.porQue, isNotEmpty);
      expect(derivada.porQue.toLowerCase(), contains('fecha'));
    });

    test('sin ATR, dice que esa categoría no la usa', () {
      final derivada = derivar(20, categoria: Categoria.iniciacion);

      expect(derivada.porQue, contains(Categoria.iniciacion.nombre));
    });

    test('**nunca viene vacía**', () {
      // Una fase derivada sin razón visible sería criterio delegado por la
      // puerta de atrás (P26). Que la razón exista es parte de la regla.
      for (final dias in [null, -5, 0, 1, 15, 16, 43, 44, 300]) {
        for (final categoria in Categoria.values) {
          final derivada = derivar(dias, categoria: categoria);
          expect(
            derivada.porQue.trim(),
            isNotEmpty,
            reason: 'dias=$dias categoria=${categoria.nombre}',
          );
        }
      }
    });
  });

  group('es una función total: nunca se queda sin respuesta', () {
    test('cualquier día y cualquier categoría devuelven algo', () {
      for (var dias = -30; dias <= 120; dias++) {
        for (final categoria in Categoria.values) {
          expect(
            () => derivar(dias, categoria: categoria),
            returnsNormally,
            reason: 'dias=$dias categoria=${categoria.nombre}',
          );
        }
      }
    });

    test('la hora del día no cambia la fase', () {
      // Si la derivación restara `DateTime` crudos, una competencia a las 23h
      // y otra a las 2h del mismo día darían fases distintas en la frontera.
      final tarde = faseParaCompetencia(
        fechaDeCompetencia: DateTime(2026, 11, 17, 23, 59),
        hoy: DateTime(2026, 11, 2, 0, 1),
        categoria: Categoria.competitivo,
      );
      final temprano = faseParaCompetencia(
        fechaDeCompetencia: DateTime(2026, 11, 17, 0, 1),
        hoy: DateTime(2026, 11, 2, 23, 59),
        categoria: Categoria.competitivo,
      );

      expect(tarde.fase, temprano.fase);
      expect(
        tarde.diasHastaLaCompetencia,
        temprano.diasHastaLaCompetencia,
        reason: 'Los días se cuentan por fecha, no por horas transcurridas',
      );
    });
  });
}
