/// Quién contó una molestia **se ve desde la lista**, sin abrir a nadie
/// (FR-010, SC-004).
///
/// Es la diferencia entre un reporte que llega y uno que está guardado. Con
/// diez nadadores, un dato que solo aparece al entrar en cada ficha pide diez
/// visitas para encontrar una: el principio VIII dice que el reporte **llega
/// al entrenador**, y eso no se cumple con que esté escrito en alguna parte.
///
/// Y se pregunta con **una consulta**, no una por nadador. Es la decisión D10
/// de la feature 008 con otro nombre: la lista la pinta el entrenador, y el
/// número de nadadores crece.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  Future<void> sembrarDiez() async {
    for (var i = 0; i < 10; i++) {
      await repos.nadadores.guardar(
        Nadador(
          id: 'n-$i',
          nombre: 'Nadador $i',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
        ),
      );
    }
  }

  testWidgets('con diez nadadores y una molestia, la lista la señala', (
    tester,
  ) async {
    conPantallaAlta(tester);

    await sembrarDiez();

    await tester.pumpWidget(
      montarAnalisis(repos: repos, molestias: MolestiasSembradas({'n-7'})),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reporto-molestia-n-7')), findsOneWidget);

    // Y solo ella. Una marca que sale en todos no señala a nadie.
    for (var i = 0; i < 10; i++) {
      if (i == 7) continue;
      expect(
        find.byKey(Key('reporto-molestia-n-$i')),
        findsNothing,
        reason: 'n-$i no contó ninguna molestia',
      );
    }
  });

  testWidgets('la marca se ve sin abrir a nadie', (tester) async {
    conPantallaAlta(tester);

    await sembrarDiez();

    await tester.pumpWidget(
      montarAnalisis(repos: repos, molestias: MolestiasSembradas({'n-7'})),
    );
    await tester.pumpAndSettle();

    // La lectura de nadie está montada: solo la lista.
    expect(find.byKey(const Key('lectura-de-n-7')), findsNothing);
    expect(find.byKey(const Key('reporto-molestia-n-7')), findsOneWidget);
  });

  testWidgets('la marca no reordena la lista ni la pone primera', (
    tester,
  ) async {
    conPantallaAlta(tester);

    await sembrarDiez();

    await tester.pumpWidget(
      montarAnalisis(repos: repos, molestias: MolestiasSembradas({'n-7'})),
    );
    await tester.pumpAndSettle();

    // **Señalar no es ordenar por gravedad.** El principio IV reserva al
    // entrenador la decisión sobre el entrenamiento, y una lista que pusiera
    // arriba «la que más urge» estaría tomando la primera mitad de esa
    // decisión por él.
    double arribaDe(String id) =>
        tester.getTopLeft(find.byKey(Key('nadador-en-analisis-$id'))).dy;

    expect(arribaDe('n-0'), lessThan(arribaDe('n-7')));
  });

  testWidgets('sin lector de molestias no se marca a nadie, en lugar de '
      'decir que nadie contó nada', (tester) async {
    conPantallaAlta(tester);

    await sembrarDiez();

    // Sin servidor no hay a quién preguntar. Lo que no se puede hacer es
    // enseñar la lista limpia como si eso fuera una respuesta.
    await tester.pumpWidget(montarAnalisis(repos: repos));
    await tester.pumpAndSettle();

    for (var i = 0; i < 10; i++) {
      expect(find.byKey(Key('reporto-molestia-n-$i')), findsNothing);
    }
  });
}
