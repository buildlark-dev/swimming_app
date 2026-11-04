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
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: PantallaPerfiles(
          repositorio: await conAna(),
          alEmpezarUnMacrociclo: alEmpezar,
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
}
