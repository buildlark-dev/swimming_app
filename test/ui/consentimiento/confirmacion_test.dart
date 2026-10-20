import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/ui/consentimiento/pantalla_confirmacion.dart';

/// La pantalla que abre el acudiente.
///
/// Es la única de esta app que lee alguien sin cuenta, y lo que se registra
/// ahí es el título que ampara tratar los datos de un menor. Lo que estas
/// pruebas vigilan no es que se vea bonita: es que **no se pueda autorizar sin
/// declarar lo que la norma exige declarar**.
void main() {
  DeclaracionDelAcudiente? registrada;
  String? aDevolver;

  setUp(() {
    registrada = null;
    aDevolver = null;
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaConfirmacion(
          textoInformativo: 'Texto informativo de prueba',
          versionDelTexto: 'v1',
          alConfirmar: (declaracion) async {
            registrada = declaracion;
            return aDevolver;
          },
        ),
      ),
    );
  }

  Future<void> rellenar(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('campo-nombre')), 'María Gómez');
    await tester.enterText(find.byKey(const Key('campo-documento')), '43123456');
    await tester.enterText(find.byKey(const Key('campo-calidad')), 'madre');
    await tester.pump();
  }

  Finder botonConfirmar() => find.byKey(const Key('boton-confirmar'));

  bool estaHabilitado(WidgetTester tester) =>
      tester.widget<FilledButton>(botonConfirmar()).onPressed != null;

  testWidgets('el texto informativo está delante, no detrás de un enlace',
      (tester) async {
    await abrir(tester);
    expect(find.byKey(const Key('texto-informativo')), findsOneWidget);
    expect(find.text('Texto informativo de prueba'), findsOneWidget);
  });

  testWidgets('las dos casillas empiezan sin marcar', (tester) async {
    // Premarcarlas sería un patrón oscuro. Sobre la autorización de datos de
    // un menor sería algo bastante peor que eso.
    await abrir(tester);

    final representante = tester.widget<CheckboxListTile>(
      find.byKey(const Key('casilla-representante')),
    );
    final oido = tester.widget<CheckboxListTile>(
      find.byKey(const Key('casilla-menor-oido')),
    );

    expect(representante.value, isFalse);
    expect(oido.value, isFalse);
  });

  testWidgets('sin las dos casillas no se puede autorizar', (tester) async {
    await abrir(tester);
    await rellenar(tester);

    expect(estaHabilitado(tester), isFalse);

    await tester.tap(find.byKey(const Key('casilla-representante')));
    await tester.pump();
    expect(
      estaHabilitado(tester),
      isFalse,
      reason: 'Declarar ser el representante no basta: el Decreto 1377 pide '
          'que el menor haya sido oído',
    );

    await tester.tap(find.byKey(const Key('casilla-menor-oido')));
    await tester.pump();
    expect(estaHabilitado(tester), isTrue);
  });

  testWidgets('con solo la casilla del menor tampoco', (tester) async {
    await abrir(tester);
    await rellenar(tester);

    await tester.tap(find.byKey(const Key('casilla-menor-oido')));
    await tester.pump();

    expect(estaHabilitado(tester), isFalse);
  });

  testWidgets('sin nombre, documento y calidad no se envía', (tester) async {
    await abrir(tester);

    await tester.tap(find.byKey(const Key('casilla-representante')));
    await tester.tap(find.byKey(const Key('casilla-menor-oido')));
    await tester.pump();

    await tester.ensureVisible(botonConfirmar());
    await tester.pump();
    await tester.tap(botonConfirmar());
    await tester.pump();

    expect(registrada, isNull);
    expect(find.text('Escriba su nombre'), findsOneWidget);
  });

  testWidgets('lo que se envía es lo que el acudiente declaró', (tester) async {
    await abrir(tester);
    await rellenar(tester);
    await tester.tap(find.byKey(const Key('casilla-representante')));
    await tester.tap(find.byKey(const Key('casilla-menor-oido')));
    await tester.pump();

    await tester.ensureVisible(botonConfirmar());
    await tester.pump();
    await tester.tap(botonConfirmar());
    await tester.pumpAndSettle();

    expect(registrada, isNotNull);
    expect(registrada!.nombre, 'María Gómez');
    expect(registrada!.documento, '43123456');
    expect(registrada!.calidad, 'madre');
    expect(registrada!.esRepresentanteLegal, isTrue);
    expect(registrada!.menorFueOido, isTrue);
    expect(
      registrada!.versionDelTexto,
      'v1',
      reason: 'Cada consentimiento consta bajo la versión del texto que su '
          'otorgante leyó (FR-018)',
    );
  });

  testWidgets('al quedar registrado se le dice, y se le dice qué hacer si no fue él',
      (tester) async {
    await abrir(tester);
    await rellenar(tester);
    await tester.tap(find.byKey(const Key('casilla-representante')));
    await tester.tap(find.byKey(const Key('casilla-menor-oido')));
    await tester.pump();

    await tester.ensureVisible(botonConfirmar());
    await tester.pump();
    await tester.tap(botonConfirmar());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirmacion-registrada')), findsOneWidget);
    expect(find.textContaining('avise al entrenador'), findsOneWidget);
  });

  testWidgets('si el servidor rechaza, se muestra y no se da por registrado',
      (tester) async {
    aDevolver = 'Este enlace no sirve.';

    await abrir(tester);
    await rellenar(tester);
    await tester.tap(find.byKey(const Key('casilla-representante')));
    await tester.tap(find.byKey(const Key('casilla-menor-oido')));
    await tester.pump();

    await tester.ensureVisible(botonConfirmar());
    await tester.pump();
    await tester.tap(botonConfirmar());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('error-de-confirmacion')), findsOneWidget);
    expect(find.byKey(const Key('confirmacion-registrada')), findsNothing);
  });

  testWidgets('se le recuerda que puede retirarla sin pasar por el entrenador',
      (tester) async {
    await abrir(tester);
    expect(find.textContaining('sin pasar por el entrenador'), findsOneWidget);
  });
}
