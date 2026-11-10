/// El esqueleto temporal propuesto (M1, M2, M6, FR-004, FR-006).
///
/// **Escrito antes de `lib/dominio/macrociclo/esqueleto_propuesto.dart`.** Es
/// una regla de entrenamiento: decide cuántos bloques tiene una temporada y
/// qué fase es cada uno, sin que el entrenador esté delante. El principio III
/// se aplica entero, y las fronteras llevan su control negativo (T020).
///
/// Las fronteras **no están elegidas a mano**: salen del tope de la ventana
/// publicada de cada fase, `FaseAtr.semanasSegunIssurin`. Hay una prueba que lo
/// fija, para que nadie las sustituya por un número suelto más adelante.
///
/// El esqueleto se cuenta **hacia atrás** desde la competencia: Realización al
/// final, Transformación antes, Acumulación rellenando lo que quede. Es el
/// orden en que el modelo está definido, y la posición del taper es la menos
/// negociable de las tres.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

void main() {
  final hoy = DateTime(2026, 11, 4);

  EsqueletoPropuesto esqueleto({
    int? competenciaEnDias = 98,
    Categoria categoria = Categoria.competitivo,
  }) => esqueletoParaMacrociclo(
    fechaDeCompetencia: competenciaEnDias == null
        ? null
        : hoy.add(Duration(days: competenciaEnDias)),
    hoy: hoy,
    categoria: categoria,
  );

  group('un macrociclo de catorce semanas', () {
    test('sale con tres bloques, en el orden del modelo', () {
      final bloques = esqueleto().bloques;

      expect(bloques, hasLength(3));
      expect(bloques[0].fase, FaseAtr.acumulacion);
      expect(bloques[1].fase, FaseAtr.transformacion);
      expect(bloques[2].fase, FaseAtr.realizacion);
    });

    test('Realización va la última y termina la víspera', () {
      // El ancla sigue siendo la competencia: el macrociclo se cuenta hacia
      // atrás desde ella, no hacia delante desde hoy, o la fecha de competir
      // sería una consecuencia del plan en lugar de su punto de partida.
      //
      // **Pero la preparación termina la víspera**, porque el día de la
      // competencia no se entrena: se compite. Lo pidió el entrenador tras
      // ver en el recorrido que el camino de la nadadora acababa en «Viernes
      // 1/1» y el 1/1 era la carrera.
      final bloques = esqueleto().bloques;
      expect(bloques.last.hasta, hoy.add(const Duration(days: 97)));
    });

    test('el primer bloque empieza hoy', () {
      expect(esqueleto().bloques.first.desde, hoy);
    });

    test('los bloques son contiguos y no dejan huecos', () {
      // Un hueco sería una parte de la preparación sin fase y sin sesiones.
      // `EstructuraConfirmada` lo rechaza al confirmar; aquí se comprueba que
      // la propuesta no lo produce, que es antes.
      final bloques = esqueleto().bloques;
      for (var i = 1; i < bloques.length; i++) {
        expect(
          bloques[i].desde,
          bloques[i - 1].hasta.add(const Duration(days: 1)),
          reason: 'el bloque $i no empieza al día siguiente del anterior',
        );
      }
    });

    test('cada bloque dice por qué salió así, en semanas', () {
      // M2 y FR-006: un bloque cuya razón no se puede leer es metodología
      // decidida en silencio.
      for (final bloque in esqueleto().bloques) {
        expect(bloque.porQue, isNotEmpty);
        expect(bloque.porQue, contains('semana'));
        expect(bloque.porQue, contains(bloque.fase!.nombre));
      }
    });
  });

  group('las fronteras salen de la ventana publicada', () {
    test('Realización dura el tope de su ventana, no un número suelto', () {
      // Issurin da 8-15 días para el bloque de realización, que
      // `semanasSegunIssurin` expresa como 1-2 semanas. El esqueleto toma el
      // **tope**, que son 2 semanas: es también el taper del macrociclo real
      // del entrenador, 14 semanas con 2 de afinación.
      final (_, topeDeRealizacion) = FaseAtr.realizacion.semanasSegunIssurin;
      final realizacion = esqueleto().bloques.last;

      final dias =
          realizacion.hasta.difference(realizacion.desde).inDays + 1;
      expect(dias, topeDeRealizacion * 7);
    });

    test('Transformación dura el tope de la suya', () {
      final (_, topeDeTransformacion) =
          FaseAtr.transformacion.semanasSegunIssurin;
      final transformacion = esqueleto().bloques[1];

      final dias =
          transformacion.hasta.difference(transformacion.desde).inDays + 1;
      expect(dias, topeDeTransformacion * 7);
    });

    test('Acumulación se queda con lo que sobre', () {
      // Es la que absorbe la longitud del macrociclo, porque es la general: lo
      // que no es afinación ni transformación es base.
      final bloques = esqueleto().bloques;
      final total = bloques.last.hasta.difference(bloques.first.desde).inDays + 1;
      final acumulacion =
          bloques.first.hasta.difference(bloques.first.desde).inDays + 1;

      // Hoy y la víspera incluidas: el día de competir no se entrena.
      expect(total, 98);
      expect(acumulacion, 98 - 14 - 28);
    });
  });

  group('macrociclos cortos', () {
    test('a quince días sale un solo bloque de Realización', () {
      final bloques = esqueleto(competenciaEnDias: 15).bloques;

      expect(bloques, hasLength(1));
      expect(bloques.single.fase, FaseAtr.realizacion);
      expect(bloques.single.desde, hoy);
      expect(bloques.single.hasta, hoy.add(const Duration(days: 14)));
    });

    test('a trece días sale Realización de dos semanas justas, sin avisos', () {
      final propuesto = esqueleto(competenciaEnDias: 13);

      expect(propuesto.bloques, hasLength(1));
      expect(propuesto.bloques.single.semanas, 2);
      expect(
        propuesto.avisos,
        isEmpty,
        reason: 'dos semanas de Realización caben en la ventana publicada',
      );
    });

    test('un resto de menos de una semana no se queda como bloque suelto', () {
      // A 19 días el macrociclo cubre 19 —hoy y la víspera incluidas— y tras
      // las 2 semanas de taper quedan 5. Un bloque de 5 días llamado
      // «Transformación» sería una etiqueta puesta sobre nada: se queda
      // dentro del bloque vecino.
      final bloques = esqueleto(competenciaEnDias: 19).bloques;

      expect(bloques, hasLength(1));
      expect(bloques.single.desde, hoy);
      expect(bloques.single.hasta, hoy.add(const Duration(days: 18)));
    });

    test('a partir de una semana de resto sí aparece el segundo bloque', () {
      // El control de la prueba de arriba: que no pase por absorberlo todo.
      // A 21 días el macrociclo cubre 21, y tras el taper el resto son 7
      // justos. Siete días son un bloque.
      final bloques = esqueleto(competenciaEnDias: 21).bloques;

      expect(bloques, hasLength(2));
      expect(bloques.first.fase, FaseAtr.transformacion);
      expect(bloques.last.fase, FaseAtr.realizacion);
    });

    test('a un día no hay esqueleto, y se dice en lugar de reventar', () {
      // **Cambió con la decisión del entrenador.** Antes salía un bloque de
      // dos días, porque el día de la carrera contaba como entrenamiento.
      // Ahora no se entrena ese día, así que queda uno solo, y un bloque de
      // un día no es un bloque: la invariante lo rechaza y tiene razón.
      //
      // Lo que no puede pasar es que la función deje de ser total: no hay
      // esqueleto, y se explica.
      final propuesto = esqueleto(competenciaEnDias: 1);
      expect(propuesto.bloques, isEmpty);
      expect(propuesto.porQue, contains('mañana'));
      expect(
        propuesto.porQue,
        isNot(contains('Exception')),
        reason: 'la razón tiene que poder leerse',
      );
    });
  });

  group('categorías que no usan ATR', () {
    test('Iniciación sale con un bloque sin fase', () {
      // M6. Nula no es un hueco por rellenar: el motor prohíbe la fase aquí.
      final propuesto = esqueleto(categoria: Categoria.iniciacion);

      expect(propuesto.bloques, hasLength(1));
      expect(propuesto.bloques.single.fase, isNull);
    });

    test('y la razón lo explica en lugar de dejarlo en blanco', () {
      final propuesto = esqueleto(categoria: Categoria.tecnificacion);

      expect(propuesto.bloques.single.porQue, contains('Tecnificación'));
      expect(propuesto.bloques.single.porQue, contains('ATR'));
    });

    test('nunca avisa de una ventana que no le aplica', () {
      // Comparar un bloque sin fase con las ventanas de Issurin sería medirlo
      // con una regla de otro deporte y de otra categoría.
      expect(esqueleto(categoria: Categoria.iniciacion).avisos, isEmpty);
    });
  });

  group('cuando no hay esqueleto que proponer', () {
    test('sin fecha de competencia', () {
      final propuesto = esqueleto(competenciaEnDias: null);

      expect(propuesto.hayEsqueleto, isFalse);
      expect(propuesto.bloques, isEmpty);
      expect(propuesto.porQue, contains('fecha'));
    });

    test('con la competencia hoy', () {
      // De hoy no se deriva una estructura: no hay nada que preparar.
      final propuesto = esqueleto(competenciaEnDias: 0);

      expect(propuesto.hayEsqueleto, isFalse);
      expect(propuesto.porQue, isNotEmpty);
    });

    test('con la competencia ya pasada', () {
      final propuesto = esqueleto(competenciaEnDias: -10);

      expect(propuesto.hayEsqueleto, isFalse);
      expect(propuesto.porQue, contains('pas'));
    });

    test('y en los tres casos la razón se puede leer y no está en jerga', () {
      for (final dias in <int?>[null, 0, -10]) {
        final propuesto = esqueleto(competenciaEnDias: dias);
        expect(propuesto.porQue.trim(), isNotEmpty);
        expect(propuesto.porQue, isNot(contains('null')));
      }
    });
  });

  group('es una función total', () {
    test('para cualquier día y cualquier categoría hay respuesta legible', () {
      // Igual que `faseParaCompetencia` en la feature 008: «sin esqueleto» es
      // una respuesta, no una excepción. Una función parcial aquí obligaría a
      // cada pantalla a decidir qué hacer cuando no hay respuesta, y de esas
      // decisiones repartidas salen las pantallas en blanco.
      for (final categoria in Categoria.values) {
        for (var dias = -30; dias <= 400; dias++) {
          final propuesto = esqueletoParaMacrociclo(
            fechaDeCompetencia: hoy.add(Duration(days: dias)),
            hoy: hoy,
            categoria: categoria,
          );

          expect(propuesto.porQue.trim(), isNotEmpty);

          for (final bloque in propuesto.bloques) {
            expect(bloque.porQue.trim(), isNotEmpty);
            expect(bloque.hasta.isAfter(bloque.desde), isTrue);
          }

          if (propuesto.hayEsqueleto) {
            expect(propuesto.bloques.first.desde, hoy);
            // La víspera: el día de competir no se entrena.
            expect(
              propuesto.bloques.last.hasta,
              hoy.add(Duration(days: dias - 1)),
            );
          }
        }
      }
    });

    test('la hora del día no le quita un bloque al esqueleto', () {
      // La misma trampa que `_diasEnteros` evita en la 008, y se mide **en la
      // frontera**, que es el único sitio donde se nota: a 20 días justos
      // sobran 7 tras el taper y aparece el segundo bloque; a 19 se absorbe.
      //
      // Hoy por la noche y la competencia por la mañana son 20 días por fecha
      // y 19 días y pico por horas. Contando horas, el esqueleto **pierde un
      // bloque entero** según cuándo se abrió la app.
      //
      // **La primera versión de esta prueba no vigilaba nada**: comparaba dos
      // esqueletos de 14 semanas, y ahí las fechas de los bloques se calculan
      // hacia atrás desde la competencia, así que salían iguales con horas y
      // sin ellas. El control negativo de T020 lo destapó.
      final deNocheAManana = esqueletoParaMacrociclo(
        fechaDeCompetencia: DateTime(2026, 11, 25, 7),
        hoy: DateTime(2026, 11, 4, 22),
        categoria: Categoria.competitivo,
      );
      final aMediodia = esqueletoParaMacrociclo(
        fechaDeCompetencia: DateTime(2026, 11, 25, 12),
        hoy: DateTime(2026, 11, 4, 12),
        categoria: Categoria.competitivo,
      );

      expect(deNocheAManana.bloques, hasLength(2));
      expect(deNocheAManana.diasHastaLaCompetencia, 21);
      expect(aMediodia.bloques, hasLength(2));

      for (var i = 0; i < aMediodia.bloques.length; i++) {
        expect(deNocheAManana.bloques[i].fase, aMediodia.bloques[i].fase);
        expect(deNocheAManana.bloques[i].desde, aMediodia.bloques[i].desde);
        expect(deNocheAManana.bloques[i].hasta, aMediodia.bloques[i].hasta);
      }
    });
  });

  group('lo que falta en la ficha (M7, regla R3)', () {
    const completa = Nadador(
      id: 'n-ana',
      nombre: 'Ana María Restrepo',
      categoria: Categoria.competitivo,
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '200 Libre',
    );

    test('con la ficha completa no falta nada', () {
      expect(faltasParaElMacrociclo(completa), isEmpty);
    });

    test('sin categoría se dice qué falta', () {
      // Se construye sin categoría en lugar de con `copiarCon(categoria:
      // null)`: `copiarCon` conserva lo que había cuando recibe nulo, así que
      // esa versión de la prueba habría medido una ficha completa.
      const sinCategoria = Nadador(
        id: 'n-ana',
        nombre: 'Ana María Restrepo',
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '200 Libre',
      );

      expect(
        faltasParaElMacrociclo(sinCategoria).map((f) => f.campo),
        contains('categoria'),
      );
    });

    test('sin prueba objetivo se dice qué falta', () {
      // El macrociclo se construye **hacia** una prueba. Sin saber cuál,
      // modelar la prueba es modelar algo sin nombre.
      final faltas = faltasParaElMacrociclo(
        completa.copiarCon(pruebaObjetivo: ''),
      );
      expect(faltas.map((f) => f.campo), contains('pruebaObjetivo'));
    });

    test('cada falta se puede leer, no es un código', () {
      final faltas = faltasParaElMacrociclo(
        const Nadador(nombre: '', pruebaObjetivo: ''),
      );
      expect(faltas, isNotEmpty);
      for (final falta in faltas) {
        expect(falta.descripcion.trim(), isNotEmpty);
        expect(falta.descripcion.length, greaterThan(10));
      }
    });
  });
}

// --- Control negativo (T020) --------------------------------------------
//
// | Guarda tocada                                        | Prueba que se puso roja |
// |------------------------------------------------------|-------------------------|
// | tope de la ventana + 1 día                           | «Realización dura el tope de su ventana…» |
// | tope de la ventana − 1 día                           | «Transformación dura el tope de la suya» |
// | `diasMinimosDeUnBloque` de 7 a 6                     | «un resto de menos de una semana…» |
// | Realización terminando un día antes de la competencia| «Realización va la última y termina el día…» |
// | `_diasEnteros` contando horas                        | «la hora del día no le quita un bloque…» |
// | fase puesta en la rama sin ATR                       | «Iniciación sale con un bloque sin fase» |
// | todos los avisos suprimidos                          | «un macrociclo de catorce semanas avisa de su Acumulación» (en `esqueleto_avisa_test.dart`) |
//
// **Dos de las siete se quedaron verdes al primer intento**, y las dos por el
// mismo motivo de fondo: medían algo insensible al fallo.
//
// 1. «La hora del día» comparaba dos macrociclos de 14 semanas. Ahí las fechas
//    de los bloques se cuentan hacia atrás desde la competencia, así que salen
//    iguales con horas y sin ellas. Ahora se mide **en la frontera de los 20
//    días**, donde contar horas le quita un bloque entero.
// 2. No había ninguna prueba que exigiera que un aviso **apareciera**: las dos
//    que había comprobaban que la lista estuviera vacía, y matar todos los
//    avisos las dejaba en verde. Es la misma trampa que la suite de reglas, y
//    se arregla igual: con casos positivos. Están en
//    `esqueleto_avisa_test.dart`.
