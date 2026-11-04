/// Garantías H6, H14, H15 y FR-031 — el recorrido del nadador.
///
/// Y el cerrojo de T067, que es el que más importa de este archivo: **un
/// nadador con cuenta llega a su sesión sin tocar nada**.
///
/// Hasta aquí no llegaba. Su recorrido montaba el selector de perfil del
/// entrenador, y `EstadoNadador` solo recibía un perfil cuando alguien elegía
/// un chip de esa lista. Para un nadador, pedir la lista de nadadores es una
/// lectura que las reglas deniegan, así que lo que veía era «Todavía no hay
/// perfiles. Crea uno en la pestaña Nadadores» —un mensaje escrito para el
/// entrenador, sobre una pestaña que él no tiene— y su plan no aparecía nunca.
///
/// Funcionaba en modo local y en las pruebas, donde el selector sí lista
/// perfiles. Por eso nadie lo había visto.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/hub/destino.dart';
import 'package:natacion_app/ui/nadador/perfil_activo.dart';

import 'ayuda_hub.dart';

void main() {
  group('la barra', () {
    testWidgets('H1 — ve los cinco destinos', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.nadador));

      for (final destino in Destino.values) {
        expect(
          find.text(destino.etiqueta),
          findsWidgets,
          reason: 'Falta ${destino.etiqueta}',
        );
      }
    });

    testWidgets('H3 — y aterriza en Home', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.nadador));

      expect(find.byKey(const Key('home-nadador')), findsOneWidget);
    });
  });

  group('H6 — nada del taller del entrenador', () {
    testWidgets('no hay generador, ni editor, ni panel de nadadores', (
      tester,
    ) async {
      await abrirHub(tester, await montarHub(rol: Rol.nadador));

      // Recorre los cinco destinos, no solo el que abre.
      for (final destino in Destino.values) {
        await tester.tap(find.text(destino.etiqueta).last);
        await tester.pumpAndSettle();

        for (final delEntrenador in [
          'Generar microciclo',
          'Editor de sesión',
          'Nadadores',
          'Entregar',
        ]) {
          expect(
            find.text(delEntrenador),
            findsNothing,
            reason:
                '«$delEntrenador» apareció en ${destino.etiqueta}, y es '
                'del entrenador',
          );
        }
      }
    });

    testWidgets('**ni el selector de perfil**', (tester) async {
      // Es la herramienta del entrenador para abrir la app como uno de sus
      // nadadores. En el recorrido del nadador le hablaba de una pestaña que
      // no tiene, y encima desbordaba 82 píxeles a 360 puntos.
      await abrirHub(tester, await montarHub(rol: Rol.nadador));

      expect(find.byType(SelectorDePerfil), findsNothing);
      expect(
        find.textContaining('Crea uno en la pestaña Nadadores'),
        findsNothing,
      );
    });
  });

  group('T067 — llega a lo suyo sin tocar nada', () {
    testWidgets('su plan aparece solo, por su cuenta', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.nadador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
        ),
      );

      // En Home ya sabe cuántas le han entregado: eso solo puede saberlo si su
      // perfil y su plan se abrieron sin que ella eligiera nada.
      expect(find.textContaining('de 3'), findsWidgets);
    });

    testWidgets('y en Ver Plan está su sesión del día', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.nadador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
        ),
      );

      await tester.tap(find.text(Destino.verPlan.etiqueta).last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Técnica de eficiencia'), findsWidgets);
    });

    testWidgets('una cuenta sin perfil asociado no estalla', (tester) async {
      await abrirHub(
        tester,
        await montarHub(rol: Rol.nadador, nadadorIdDeLaCuenta: null),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home-nadador')), findsOneWidget);
    });
  });

  group('H14 y H15 — su Home', () {
    testWidgets('dice entregadas y cumplidas', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.nadador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
          registros: [registroDePrueba(sesionId: 's0', realizada: true)],
        ),
      );

      expect(find.text('1 de 3'), findsOneWidget);
    });

    testWidgets('dice de cuándo son los datos', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.nadador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
        ),
      );

      expect(find.byKey(const Key('home-de-cuando')), findsOneWidget);
    });

    testWidgets('sin plan todavía, lo dice en lugar de quedarse vacío', (
      tester,
    ) async {
      await abrirHub(tester, await montarHub(rol: Rol.nadador));

      expect(find.byKey(const Key('home-sin-plan')), findsOneWidget);
    });

    testWidgets('lo primero es su sesión de hoy, con el camino a Ver Plan', (
      tester,
    ) async {
      // Decisión D3: `Home` le cuesta al nadador el toque que hoy no paga.
      // Esto es lo que lo compensa, y por eso es un cerrojo y no un detalle.
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.nadador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
        ),
      );

      final camino = find.byKey(const Key('home-ir-a-ver-plan'));
      expect(camino, findsOneWidget);

      await tester.tap(camino);
      await tester.pumpAndSettle();

      expect(find.textContaining('Técnica de eficiencia'), findsWidgets);
    });
  });

  group('FR-031 — su Análisis es «Mi progreso»', () {
    testWidgets('tiene contenido, no un «todavía no»', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.nadador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
        ),
      );

      await tester.tap(find.text(Destino.analisis.etiqueta).last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('todavia-no')), findsNothing);
      expect(find.textContaining('Mi progreso'), findsWidgets);
    });
  });

  group('su Generar ya no dice «todavía no» (feature 008)', () {
    testWidgets('el hueco que la 007 dejó está lleno', (tester) async {
      // Era un `TodaviaNo` con su texto y sin un solo control, porque un
      // destino que no hace nada no debe tener botones que parezcan hacer
      // algo. La feature 008 lo llenó, que es para lo que el hueco estaba.
      await abrirHub(tester, await montarHub(rol: Rol.nadador));

      await tester.tap(find.text(Destino.generar.etiqueta).last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('todavia-no')), findsNothing);
    });

    testWidgets('sin servidor lo dice, en lugar de ofrecer una lista vacía', (
      tester,
    ) async {
      // En las pruebas del HUB no hay repositorio de peticiones, que es lo
      // mismo que pasa en modo local: no hay a quién mandarle nada.
      await abrirHub(tester, await montarHub(rol: Rol.nadador));

      await tester.tap(find.text(Destino.generar.etiqueta).last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peticion-sin-servidor')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
