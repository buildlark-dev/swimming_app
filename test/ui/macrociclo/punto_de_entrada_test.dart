/// Por dónde se empieza un macrociclo (T043).
///
/// La acción vive **en la ficha del nadador**, porque un macrociclo es de un
/// nadador y eso es lo primero que hay que saber. Y no aparece cuando no hay
/// dónde guardarlo: un control que lleva a una pantalla que no puede terminar
/// lo que empieza está prohibido desde la feature 007 (H12).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/ui/nadadores/pantalla_perfiles.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  const ana = Nadador(
    id: 'n-ana',
    nombre: 'Ana María Restrepo',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
  );

  Future<RepositorioNadadoresMemoria> conAna() async {
    final repo = RepositorioNadadoresMemoria();
    await repo.guardar(ana);
    return repo;
  }

  Future<void> abrir(
    WidgetTester tester, {
    void Function(Nadador)? alEmpezar,
    void Function(Nadador)? alVerSuMacrociclo,
    Set<String> quienTieneMacrociclo = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: PantallaPerfiles(
          repositorio: await conAna(),
          alEmpezarUnMacrociclo: alEmpezar,
          alVerSuMacrociclo: alVerSuMacrociclo,
          quienTieneMacrociclo: quienTieneMacrociclo,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('con sitio donde guardarlo, la ficha ofrece empezarlo', (
    tester,
  ) async {
    await abrir(tester, alEmpezar: (_) {});

    expect(
      find.byKey(const Key('empezar-macrociclo-n-ana')),
      findsOneWidget,
    );
  });

  testWidgets('y pulsarlo pasa ese nadador y no otro', (tester) async {
    // Que llegue **el nadador de esa tarjeta** es la mitad que se rompe en
    // silencio: con dos fichas en la lista, pasar siempre la primera dejaría
    // al entrenador planificándole la temporada a otro.
    Nadador? recibido;
    await abrir(tester, alEmpezar: (quien) => recibido = quien);

    await tester.tap(find.byKey(const Key('empezar-macrociclo-n-ana')));
    await tester.pumpAndSettle();

    expect(recibido?.id, 'n-ana');
  });

  testWidgets('sin sitio donde guardarlo no se ofrece nada', (tester) async {
    // Ni deshabilitado como señuelo (H12).
    await abrir(tester);

    expect(find.byKey(const Key('empezar-macrociclo-n-ana')), findsNothing);
    expect(find.textContaining('macrociclo'), findsNothing);
  });
  // --- Y por dónde se VUELVE (C11 a C13) ---------------------------------
  //
  // **El recorrido en el Pixel 7 se paró aquí.** Entregado el macrociclo de
  // Ana, el entrenador salió de la pantalla de revisión y no hubo forma de
  // volver: su ficha ofrecía «Empezar un macrociclo» y nada más, igual que la
  // de una nadadora que no tiene ninguno, y en «Planes» los tres mesociclos
  // salían como tres planes sueltos sin nada que dijera que son un macrociclo.
  //
  // No es solo que bloqueara tres pasos del recorrido. **El reajuste existe
  // para hacerse después** (M30, FR-029): el entrenador mira cómo respondió el
  // nadador y entonces decide. Eso pasa días o semanas más tarde, en otra
  // sesión de la app. Un control al que solo se llega mientras creas el
  // macrociclo no puede cumplir eso, por bien que funcione.

  testWidgets('la ficha de quien ya tiene macrociclo ofrece abrirlo', (
    tester,
  ) async {
    await abrir(
      tester,
      alEmpezar: (_) {},
      alVerSuMacrociclo: (_) {},
      quienTieneMacrociclo: const {'n-ana'},
    );

    expect(find.byKey(const Key('ver-macrociclo-n-ana')), findsOneWidget);
    expect(find.text('Ver su macrociclo'), findsOneWidget);
  });

  testWidgets('y sigue pudiendo empezar otro', (tester) async {
    // Un nadador termina un ciclo y empieza el siguiente. La app no se lo
    // impide.
    await abrir(
      tester,
      alEmpezar: (_) {},
      alVerSuMacrociclo: (_) {},
      quienTieneMacrociclo: const {'n-ana'},
    );

    expect(find.byKey(const Key('empezar-macrociclo-n-ana')), findsOneWidget);
    expect(find.byKey(const Key('ver-macrociclo-n-ana')), findsOneWidget);
  });

  testWidgets('quien no tiene macrociclo no ve el control de abrirlo', (
    tester,
  ) async {
    // Lo de siempre: un control que no lleva a ninguna parte está prohibido
    // (H12). Y aquí sería peor que inútil, porque diría que hay un macrociclo.
    await abrir(
      tester,
      alEmpezar: (_) {},
      alVerSuMacrociclo: (_) {},
      quienTieneMacrociclo: const {},
    );

    expect(find.byKey(const Key('ver-macrociclo-n-ana')), findsNothing);
    expect(find.text('Ver su macrociclo'), findsNothing);
  });

  testWidgets('y pulsarlo pasa ese nadador', (tester) async {
    Nadador? recibido;
    await abrir(
      tester,
      alEmpezar: (_) {},
      alVerSuMacrociclo: (quien) => recibido = quien,
      quienTieneMacrociclo: const {'n-ana'},
    );

    await tester.tap(find.byKey(const Key('ver-macrociclo-n-ana')));
    await tester.pumpAndSettle();

    expect(recibido?.id, 'n-ana');
  });

  testWidgets('sin sitio donde guardarlo tampoco se ofrece abrirlo', (
    tester,
  ) async {
    // Sin servidor no hay macrociclo que abrir, por mucho que el conjunto
    // dijera que sí.
    await abrir(tester, quienTieneMacrociclo: const {'n-ana'});

    expect(find.byKey(const Key('ver-macrociclo-n-ana')), findsNothing);
  });
}