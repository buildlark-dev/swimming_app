import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/hub/destino.dart';
import 'package:natacion_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:natacion_app/ui/editor/pantalla_editor.dart';
import 'package:natacion_app/ui/generacion/pantalla_peticion.dart';

void main() {
  // rootBundle cachea la carga del recurso entre pruebas del mismo archivo. Si
  // una prueba termina con la carga a medias, las siguientes heredan ese
  // estado y nunca ven la app.
  setUp(() {
    rootBundle.clear();
    // La app real lee el almacén del dispositivo al arrancar: el resumen del
    // entrenador cuenta quién ha respondido, y sin servidor eso sale de aquí.
    SharedPreferences.setMockInitialValues({});
  });

  /// Abre la app y espera a que la Biblioteca Oficial termine de cargar.
  ///
  /// No se usa `pumpAndSettle`: el indicador de carga anima sin fin y nunca
  /// llegaría a estabilizarse.
  Future<void> abrirApp(WidgetTester tester) async {
    await tester.pumpWidget(const AppNatacion());

    for (var intento = 0; intento < 20; intento++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  /// Va al destino `Generar`, donde viven el generador y el editor.
  ///
  /// La app abre en `Home` desde la feature 007 (decisión D3), así que llegar
  /// al generador cuesta un toque. **Lo que estas pruebas comprueban no
  /// cambia**: cambia cómo se llega (FR-033).
  Future<void> irAGenerar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('destino-generar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Cambia al editor, que es el segundo segmento de `Generar`.
  ///
  /// Antes era una pestaña propia. Está dentro de `Generar` para que un plan
  /// recién generado se revise sin cambiar de destino (FR-009).
  Future<void> irAlEditor(WidgetTester tester) async {
    await irAGenerar(tester);
    await tester.tap(find.text('Editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('mientras carga la biblioteca muestra el indicador',
      (tester) async {
    await tester.pumpWidget(const AppNatacion());

    // Sin biblioteca no se puede comprobar la regla de no invención, así que
    // nada se muestra hasta tenerla.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('cargada la biblioteca, el generador está a un toque',
      (tester) async {
    await abrirApp(tester);
    await irAGenerar(tester);

    expect(find.byType(PantallaPeticion), findsOneWidget);
    expect(find.text('Generar microciclo'), findsOneWidget);
  });

  testWidgets('el generador pide los datos del protocolo de inicio',
      (tester) async {
    await abrirApp(tester);
    await irAGenerar(tester);

    expect(find.text('El nadador o el grupo'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Diagnóstico y limitaciones'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );

    expect(find.text('La semana'), findsOneWidget);
    expect(find.text('Diagnóstico y limitaciones'), findsOneWidget);
  });

  testWidgets('el generador avisa de que las lesiones no modifican el plan',
      (tester) async {
    await abrirApp(tester);
    await irAGenerar(tester);

    await tester.dragUntilVisible(
      find.textContaining('NO modifican el plan'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );

    expect(
      find.textContaining('NO modifican el plan'),
      findsOneWidget,
      reason: 'El principio IV prohíbe simular criterio clínico',
    );
  });

  testWidgets('la app tiene los cinco destinos, y Home al centro',
      (tester) async {
    // **Esta prueba afirmaba la barra que la feature 007 cambia a propósito.**
    // Antes contaba tres pestañas —`Generar`, `Editor`, `Nadadores`—, que eran
    // los trozos que se fueron construyendo y no los recorridos que existen.
    // Comprueba más de lo que comprobaba: los cinco destinos, su orden, y que
    // la app abre en el del centro.
    await abrirApp(tester);

    for (final destino in Destino.values) {
      expect(
        find.byKey(Key('destino-${destino.name}')),
        findsOneWidget,
        reason: 'Falta el destino ${destino.etiqueta}',
      );
    }

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      Destino.home.posicion,
      reason: 'La app abre en Home, que ocupa la posición central',
    );
  });

  testWidgets('en modo local se elige el recorrido a propósito',
      (tester) async {
    // Sin servidor no hay rol que consultar, y cada destino tendría dos
    // contenidos candidatos. Adivinarlo sería peor que preguntarlo
    // (decisión D13).
    await abrirApp(tester);

    expect(find.byKey(const Key('recorrido-en-modo-local')), findsOneWidget);
    expect(find.byKey(const Key('aviso-modo-local')), findsOneWidget);
  });

  testWidgets('se puede pasar al editor', (tester) async {
    await abrirApp(tester);
    await irAlEditor(tester);

    expect(find.byType(PantallaEditor), findsOneWidget);
    expect(find.text('Editor de sesión'), findsOneWidget);
  });

  testWidgets('el editor muestra las tres partes de la sesión',
      (tester) async {
    await abrirApp(tester);
    await irAlEditor(tester);

    expect(find.text('Inicial'), findsWidgets);
    expect(find.text('Central'), findsWidgets);
    expect(find.text('Final'), findsWidgets);
  });

  testWidgets('una sesión recién abierta se declara incompleta',
      (tester) async {
    await abrirApp(tester);
    await irAlEditor(tester);

    await tester.dragUntilVisible(
      find.text('Sesión incompleta'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );

    expect(find.text('Sesión incompleta'), findsOneWidget);
  });

  testWidgets('al escribir una serie se calculan los metros', (tester) async {
    await abrirApp(tester);
    await irAlEditor(tester);

    await tester.enterText(find.byType(TextField).last, '4x100 AL / 2\'');
    await tester.pump();

    expect(find.textContaining('400 m'), findsWidgets);
  });
}
