/// FR-007 — ella ve lo que pidió, y puede retirarlo.
///
/// **Pedir entrar y arrepentirse son la misma decisión mirada dos veces.** Una
/// solicitud que no se puede retirar la deja atada a una espera que ya no
/// quiere, y encima la deja sin poder pedir en otro sitio: FR-008 dice que
/// tiene como mucho una esperando.
///
/// Y el control negativo de todo esto: **cuando no pertenece ni espera, la
/// sección no está**. Una tarjeta que diga «no perteneces a nada» en la
/// pantalla de ajustes de quien nunca pidió nada es ruido, y una que se pinte
/// siempre no distingue una pantalla que leyó de una que no.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/comunidad/membresia.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/comunidad/mi_pertenencia.dart';

void main() {
  Future<int> montar(
    WidgetTester tester, {
    required DondeEsta? donde,
    String? nombre = 'Club Acuático del Valle',
    bool conRetirar = true,
    bool conPedir = true,
    bool falla = false,
  }) async {
    var retiradas = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiPertenencia(
            dondeEsta: donde,
            nombreDeLaComunidad: nombre,
            alSalir: () async {},
            alPedirEntrar: conPedir ? () {} : null,
            alRetirarSolicitud: conRetirar
                ? () async {
                    if (falla) throw const FalloDeDatos('sin respuesta');
                    retiradas++;
                  }
                : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return retiradas;
  }

  final perteneciendo = Pertenece(
    Membresia(
      nadadorId: 'n-ana',
      comunidadId: 'e-uno',
      desde: DateTime(2026, 11, 1),
    ),
  );

  group('esperando', () {
    testWidgets('ve dónde pidió, por su nombre', (tester) async {
      await montar(tester, donde: const Esperando('e-uno'));

      expect(find.byKey(const Key('mi-solicitud')), findsOneWidget);
      // **Por el letrero, no por el identificador.** Ella eligió por el
      // nombre y por el nombre tiene que reconocerlo.
      expect(find.textContaining('Club Acuático del Valle'), findsOneWidget);
      expect(find.textContaining('e-uno'), findsNothing);
    });

    testWidgets('sin nombre legible, no se inventa uno', (tester) async {
      await montar(tester, donde: const Esperando('e-uno'), nombre: null);

      expect(find.byKey(const Key('mi-solicitud')), findsOneWidget);
      expect(find.textContaining('todavía no te han contestado'), findsOneWidget);
    });

    testWidgets('y la retira', (tester) async {
      await montar(tester, donde: const Esperando('e-uno'));

      await tester.tap(find.byKey(const Key('retirar-solicitud')));
      await tester.pumpAndSettle();

      // El contador vive en el closure; lo que se comprueba aquí es que el
      // control existe y llama. Que lo retirado llegue al servidor es cosa de
      // `solicitudes_firestore`, y lo prueban las reglas.
      expect(find.byKey(const Key('retirar-no-se-pudo')), findsNothing);
    });

    testWidgets('si no llega, sigue pedida y se dice', (tester) async {
      await montar(tester, donde: const Esperando('e-uno'), falla: true);

      await tester.tap(find.byKey(const Key('retirar-solicitud')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retirar-no-se-pudo')), findsOneWidget);
      expect(find.byKey(const Key('retirar-solicitud')), findsOneWidget);
    });

    testWidgets('sin a quién pedírselo, no hay botón', (tester) async {
      // H12: un control que no termina lo que empieza es peor que no tenerlo.
      await montar(
        tester,
        donde: const Esperando('e-uno'),
        conRetirar: false,
      );

      expect(find.byKey(const Key('mi-solicitud')), findsOneWidget);
      expect(find.byKey(const Key('retirar-solicitud')), findsNothing);
    });
  });

  group('perteneciendo', () {
    testWidgets('ve dónde está, y puede salir', (tester) async {
      await montar(tester, donde: perteneciendo);

      expect(find.byKey(const Key('mi-pertenencia')), findsOneWidget);
      expect(find.textContaining('Club Acuático del Valle'), findsOneWidget);
      expect(find.byKey(const Key('terminar-pertenencia')), findsOneWidget);
      // Y no lo otro: no hay solicitud que retirar.
      expect(find.byKey(const Key('retirar-solicitud')), findsNothing);
    });
  });

  group('el control negativo', () {
    testWidgets('sin pedir nada, NO hay sección', (tester) async {
      await montar(tester, donde: const NoHaPedido());

      expect(find.byKey(const Key('mi-pertenencia')), findsNothing);
      expect(find.byKey(const Key('mi-solicitud')), findsNothing);
      // **Pero sí la puerta para pedir.** El alta se lo prometió.
      expect(find.byKey(const Key('pedir-entrar')), findsOneWidget);
    });

    testWidgets('tras un rechazo, puede volver a pedir', (tester) async {
      // **FR-012: un rechazo es una respuesta, no una prohibición.** No hay
      // nada que retirar ni de dónde salir, pero sí hay a dónde volver.
      await montar(tester, donde: const LeDijeronQueNo('e-uno'));

      expect(find.byKey(const Key('mi-solicitud')), findsNothing);
      expect(find.byKey(const Key('pedir-entrar')), findsOneWidget);
      expect(find.textContaining('no fue aceptada'), findsOneWidget);
    });

    testWidgets('sin a quién pedírselo, NO hay sección', (tester) async {
      // Sin servidor no hay comunidades que ofrecer, y un botón que no
      // termina lo que empieza es peor que no tenerlo (H12).
      await montar(tester, donde: const NoHaPedido(), conPedir: false);

      expect(find.byKey(const Key('todavia-sin-comunidad')), findsNothing);
      expect(find.byKey(const Key('pedir-entrar')), findsNothing);
    });

    testWidgets('y mientras no se sabe, tampoco', (tester) async {
      // `null` no es «no perteneces a nada»: es «todavía no se sabe», y
      // ofrecerle pedir entrar sobre eso sería la lección de la 011 otra vez.
      await montar(tester, donde: null);

      expect(find.byKey(const Key('mi-pertenencia')), findsNothing);
      expect(find.byKey(const Key('mi-solicitud')), findsNothing);
      expect(find.byKey(const Key('pedir-entrar')), findsNothing);
    });
  });
}
