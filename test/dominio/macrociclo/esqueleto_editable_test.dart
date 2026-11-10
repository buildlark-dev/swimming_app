/// M3, FR-005 — lo que el entrenador cambia produce una estructura válida.
///
/// **Una propuesta que no se puede cambiar es una decisión**, y aquí es donde
/// «editable» deja de ser una palabra. Los bloques son contiguos y contados
/// hacia atrás, así que cambiar uno recoloca la cadena entera: sin esto,
/// editar la duración de Transformación dejaría un hueco entre ella y
/// Acumulación, y `EstructuraConfirmada` lo rechazaría al confirmar.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

void main() {
  final competencia = DateTime(2027, 2, 10);

  EstructuraConfirmada confirmar(List<BloqueConfirmado> bloques) =>
      EstructuraConfirmada(
        modeloDeLaPrueba: '200 libre.',
        modeloDelNadador: 'Crol dominante.',
        bloques: bloques,
        confirmadaEn: DateTime(2026, 11, 4),
        diasPorSemana: const [1, 3, 5],
        duracionSesionMinutos: 90,
        longitudPiscina: 25,
      );

  test('lo recompuesto se puede confirmar: contiguo y sin huecos', () {
    // La prueba que de verdad importa: no es que las fechas cuadren a ojo, es
    // que `EstructuraConfirmada` las acepte. Sus invariantes son el juez.
    final bloques = recomponerElEsqueleto(
      bloques: const [
        (fase: FaseAtr.acumulacion, semanas: 6),
        (fase: FaseAtr.transformacion, semanas: 4),
        (fase: FaseAtr.realizacion, semanas: 2),
      ],
      fechaDeCompetencia: competencia,
    );

    expect(() => confirmar(bloques), returnsNormally);
  });

  test('el último bloque sigue terminando pegado a la competencia', () {
    // El ancla no se mueve. Alargar la preparación la hace **empezar antes**,
    // no acabar después: lo que él decide es cuánto dura, no cuándo compite.
    final cortos = recomponerElEsqueleto(
      bloques: const [(fase: FaseAtr.realizacion, semanas: 2)],
      fechaDeCompetencia: competencia,
    );
    final largos = recomponerElEsqueleto(
      bloques: const [
        (fase: FaseAtr.acumulacion, semanas: 10),
        (fase: FaseAtr.realizacion, semanas: 2),
      ],
      fechaDeCompetencia: competencia,
    );

    // La víspera: el día de competir no se entrena, también cuando los
    // bloques los pone él a mano.
    final vispera = competencia.subtract(const Duration(days: 1));
    expect(cortos.last.hasta, vispera);
    expect(largos.last.hasta, vispera);
    expect(largos.first.desde.isBefore(cortos.first.desde), isTrue);
  });

  test('cambiar las semanas de un bloque cambia su duración', () {
    final deDos = recomponerElEsqueleto(
      bloques: const [(fase: FaseAtr.realizacion, semanas: 2)],
      fechaDeCompetencia: competencia,
    );
    final deCuatro = recomponerElEsqueleto(
      bloques: const [(fase: FaseAtr.realizacion, semanas: 4)],
      fechaDeCompetencia: competencia,
    );

    expect(deDos.single.semanas, 2);
    expect(deCuatro.single.semanas, 4);
  });

  test('cambiar la fase de un bloque cambia su fase y su razón', () {
    final comoTransformacion = recomponerElEsqueleto(
      bloques: const [(fase: FaseAtr.transformacion, semanas: 3)],
      fechaDeCompetencia: competencia,
    ).single;

    expect(comoTransformacion.fase, FaseAtr.transformacion);
    expect(comoTransformacion.porQue, contains('Transformación'));
  });

  test('la razón dice que las puso él, no la app', () {
    // Si siguiera diciendo «las últimas 2 semanas antes de la competencia»
    // cuando él las cambió a cuatro, la app se estaría atribuyendo una
    // decisión suya. Y al revés: el entrenador leería una justificación que
    // no es la de nadie.
    final bloques = recomponerElEsqueleto(
      bloques: const [
        (fase: FaseAtr.acumulacion, semanas: 6),
        (fase: FaseAtr.realizacion, semanas: 4),
      ],
      fechaDeCompetencia: competencia,
    );

    for (final bloque in bloques) {
      expect(bloque.porQue, contains('entrenador'));
    }
  });

  test('quitar un bloque deja una estructura de dos, confirmable', () {
    final bloques = recomponerElEsqueleto(
      bloques: const [
        (fase: FaseAtr.transformacion, semanas: 4),
        (fase: FaseAtr.realizacion, semanas: 2),
      ],
      fechaDeCompetencia: competencia,
    );

    expect(bloques, hasLength(2));
    expect(() => confirmar(bloques), returnsNormally);
  });

  test('añadir un cuarto bloque también', () {
    // Nada obliga a que sean tres. La metodología da tres fases, no tres
    // bloques: un macrociclo largo puede repetir Acumulación.
    final bloques = recomponerElEsqueleto(
      bloques: const [
        (fase: FaseAtr.acumulacion, semanas: 5),
        (fase: FaseAtr.acumulacion, semanas: 5),
        (fase: FaseAtr.transformacion, semanas: 4),
        (fase: FaseAtr.realizacion, semanas: 2),
      ],
      fechaDeCompetencia: competencia,
    );

    expect(bloques, hasLength(4));
    expect(() => confirmar(bloques), returnsNormally);
  });

  test('un bloque sin fase, para las categorías que no usan ATR', () {
    final bloques = recomponerElEsqueleto(
      bloques: const [(fase: null, semanas: 8)],
      fechaDeCompetencia: competencia,
    );

    expect(bloques.single.fase, isNull);
    expect(bloques.single.porQue, contains('Sin fase'));
    expect(() => confirmar(bloques), returnsNormally);
  });

  test('sin bloques devuelve vacío en lugar de reventar', () {
    // La pantalla puede quedarse sin bloques mientras el entrenador los
    // reordena. Que eso lance una excepción a media edición sería un fallo de
    // la app, no una invariante: `EstructuraConfirmada` ya rechaza confirmar
    // una estructura vacía, que es donde la regla tiene que vivir.
    expect(
      recomponerElEsqueleto(bloques: const [], fechaDeCompetencia: competencia),
      isEmpty,
    );
  });

  test('lo propuesto y lo recompuesto con las mismas semanas coinciden', () {
    // El control de que esto no es una segunda forma de calcular el
    // esqueleto, que sería una segunda metodología por la puerta de atrás.
    final hoy = DateTime(2026, 11, 4);
    final propuesto = esqueletoParaMacrociclo(
      // 98 días hasta la carrera son 97 de preparación: catorce semanas
      // justas hasta la víspera, que es lo que el entrenador recompone.
      fechaDeCompetencia: hoy.add(const Duration(days: 98)),
      hoy: hoy,
      categoria: Categoria.competitivo,
    );

    final recompuesto = recomponerElEsqueleto(
      bloques: [
        for (final bloque in propuesto.bloques)
          (fase: bloque.fase, semanas: bloque.semanas),
      ],
      fechaDeCompetencia: hoy.add(const Duration(days: 98)),
    );

    for (var i = 0; i < propuesto.bloques.length; i++) {
      expect(recompuesto[i].fase, propuesto.bloques[i].fase);
      expect(recompuesto[i].hasta, propuesto.bloques[i].hasta);
      expect(recompuesto[i].desde, propuesto.bloques[i].desde);
    }
  });
}
