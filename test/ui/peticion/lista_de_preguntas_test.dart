/// Garantías P1 a P6 — la lista corta del nadador.
///
/// Es corta por necesidad y no por comodidad: de los once datos obligatorios
/// de la sección 5 del prompt maestro, **el nadador solo puede responder
/// cinco y confirmar dos**. Lo demás está en su ficha, sale de sus sesiones o
/// es criterio del entrenador, y preguntárselo sería pedirle que opine sobre
/// lo que no le toca.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/ui/peticion/peticion_del_nadador.dart';

import 'ayuda_peticion.dart';

void main() {
  group('P1 — seis preguntas, ni una más', () {
    testWidgets('las seis están, cada una con su clave', (tester) async {
      await montarPeticion(tester);

      for (final pregunta in [
        'pregunta-estilo',
        'pregunta-prueba',
        'pregunta-competencia',
        'pregunta-dias',
        'pregunta-duracion',
        'pregunta-piscina',
      ]) {
        expect(
          find.byKey(Key(pregunta)),
          findsOneWidget,
          reason: 'Falta «$pregunta»',
        );
      }
    });

    testWidgets('y no hay una séptima', (tester) async {
      await montarPeticion(tester);

      final preguntas = tester
          .widgetList(find.byType(Pregunta))
          .length;

      expect(
        preguntas,
        6,
        reason:
            'Añadir una séptima pregunta es un cambio del contrato P1, no un '
            'detalle de implementación',
      );
    });
  });

  group('P6 — lo que NO se le pregunta', () {
    testWidgets('ni categoría, ni fase, ni componente, ni diagnóstico, ni molestias', (
      tester,
    ) async {
      await montarPeticion(tester);

      // Cada una de estas cinco ausencias es un requisito. La categoría la
      // asigna el entrenador; la fase y el componente se derivan; el
      // diagnóstico es observación suya; las molestias salen de las sesiones.
      for (final palabra in [
        'Categoría',
        'categoría',
        'Fase',
        'ATR',
        'Acumulación',
        'Transformación',
        'componente',
        'Diagnóstico',
        'diagnóstico',
        'molesta',
        'molestia',
        'duele',
        'dolor',
      ]) {
        expect(
          find.textContaining(palabra),
          findsNothing,
          reason: '«$palabra» no es del nadador y no se le pregunta',
        );
      }
    });
  });

  group('P2 — el estilo y la prueba vienen de su ficha', () {
    testWidgets('empiezan contestados con lo que el entrenador puso', (
      tester,
    ) async {
      await montarPeticion(tester);

      expect(find.text('Libre'), findsWidgets);
      expect(find.text('200 Libre'), findsWidgets);
    });

    testWidgets('y los puede cambiar para esta petición', (tester) async {
      final peticiones = await montarPeticion(tester);

      await tester.tap(find.text('Espalda').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('enviar-peticion')));
      await tester.pumpAndSettle();

      expect(peticiones.enviadas.single.estiloObjetivo.nombre, 'Espalda');
    });
  });

  group('P3 — se contesta tocando, sin escribir', () {
    testWidgets('no hay ni un campo de texto en la lista', (tester) async {
      await montarPeticion(tester);

      expect(
        find.byType(TextField),
        findsNothing,
        reason:
            'Algunos de los que responden esto tienen nueve años: escribir '
            'es una barrera, no un detalle',
      );
      expect(find.byType(TextFormField), findsNothing);
    });
  });

  group('P4 — «no lo sé» es una respuesta', () {
    testWidgets('está, y se puede elegir', (tester) async {
      await montarPeticion(tester);

      expect(find.byKey(const Key('no-se-cuando-compito')), findsOneWidget);
    });

    testWidgets('y elegirla no impide enviar', (tester) async {
      final peticiones = await montarPeticion(tester);

      await tester.tap(find.byKey(const Key('no-se-cuando-compito')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('enviar-peticion')));
      await tester.pumpAndSettle();

      expect(peticiones.enviadas, hasLength(1));
      expect(peticiones.enviadas.single.fechaDeCompetencia, isNull);
    });
  });

  group('FR-004 — no se envía a medias, y se dice qué falta', () {
    testWidgets('sin días elegidos, el botón no manda', (tester) async {
      final peticiones = await montarPeticion(tester);

      // Se quitan los días que vienen propuestos.
      for (final dia in ['dia-1', 'dia-3']) {
        final chip = find.byKey(Key(dia));
        if (chip.evaluate().isNotEmpty) {
          await tester.tap(chip);
          await tester.pumpAndSettle();
        }
      }

      await tester.tap(find.byKey(const Key('enviar-peticion')));
      await tester.pumpAndSettle();

      expect(peticiones.enviadas, isEmpty);
      expect(find.byKey(const Key('falta-algo')), findsOneWidget);
      expect(
        find.textContaining('día'),
        findsWidgets,
        reason: 'Decir que falta algo sin decir qué no sirve de nada',
      );
    });
  });

  group('lo enviado es lo contestado', () {
    testWidgets('las seis respuestas viajan tal cual', (tester) async {
      final peticiones = await montarPeticion(tester);

      await tester.tap(find.byKey(const Key('enviar-peticion')));
      await tester.pumpAndSettle();

      final respuestas = peticiones.enviadas.single;

      expect(respuestas.pruebaObjetivo, '200 Libre');
      expect(respuestas.longitudPiscina, anyOf(25, 50));
      expect(respuestas.duracionSesionMinutos, inInclusiveRange(30, 180));
      expect(respuestas.diasDisponibles, isNotEmpty);
    });

    testWidgets('y al enviarla, la pantalla pasa a decir en qué va', (
      tester,
    ) async {
      await montarPeticion(tester);

      await tester.tap(find.byKey(const Key('enviar-peticion')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('estado-de-mi-peticion')), findsOneWidget);
      expect(
        find.text(EstadoDePeticion.esperando.comoLoLeeElNadador),
        findsOneWidget,
      );
    });
  });

  group('si el envío falla, se dice', () {
    testWidgets('**no se da por enviada** lo que no salió', (tester) async {
      // El fallo que esta app ya cometió dos veces es el contrario: quedarse
      // girando o dar algo por hecho. Aquí lo que no salió se dice.
      final peticiones = await montarPeticion(
        tester,
        alEnviarFalla: StateError('sin red'),
      );

      await tester.tap(find.byKey(const Key('enviar-peticion')));
      await tester.pumpAndSettle();

      expect(peticiones.enviadas, isEmpty);
      expect(find.byKey(const Key('no-se-pudo-enviar')), findsOneWidget);
      expect(find.byKey(const Key('estado-de-mi-peticion')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
