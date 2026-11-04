/// Garantía P7 — una lista que no puede llevar a nada no se enseña.
///
/// El motor parte de la ficha: la categoría da los rangos de volumen y la
/// frecuencia, y sin ella no hay plan que generar. Enseñar las seis preguntas
/// a quien no tiene ficha sería dejarle contestar para nada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

import 'ayuda_peticion.dart';

void main() {
  group('sin ficha de nadador', () {
    testWidgets('se le dice que su entrenador no lo ha inscrito', (
      tester,
    ) async {
      await montarPeticion(tester, ficha: null, nadadorId: null);

      expect(find.byKey(const Key('peticion-sin-ficha')), findsOneWidget);
      expect(find.byKey(const Key('lista-de-preguntas')), findsNothing);
    });

    testWidgets('con vínculo pero sin ficha guardada, lo mismo', (
      tester,
    ) async {
      await montarPeticion(tester, ficha: null);

      expect(find.byKey(const Key('peticion-sin-ficha')), findsOneWidget);
    });
  });

  group('con la ficha a medias', () {
    testWidgets('sin categoría, se dice que falta completarla', (tester) async {
      await montarPeticion(
        tester,
        ficha: const Nadador(
          id: 'n-ana',
          nombre: 'Ana María Restrepo',
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '200 Libre',
        ),
      );

      expect(
        find.byKey(const Key('peticion-ficha-incompleta')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('lista-de-preguntas')), findsNothing);
    });

    testWidgets('sin prueba objetivo, igual', (tester) async {
      await montarPeticion(
        tester,
        ficha: const Nadador(
          id: 'n-ana',
          nombre: 'Ana María Restrepo',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '',
        ),
      );

      expect(
        find.byKey(const Key('peticion-ficha-incompleta')),
        findsOneWidget,
      );
    });

    testWidgets('y el aviso dice a quién le toca arreglarlo', (tester) async {
      await montarPeticion(
        tester,
        ficha: const Nadador(
          id: 'n-ana',
          nombre: 'Ana María Restrepo',
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '200 Libre',
        ),
      );

      expect(find.textContaining('entrenador'), findsWidgets);
    });

    testWidgets('**control negativo**: con la ficha completa sí aparece', (
      tester,
    ) async {
      await montarPeticion(tester);

      expect(find.byKey(const Key('lista-de-preguntas')), findsOneWidget);
      expect(find.byKey(const Key('peticion-ficha-incompleta')), findsNothing);
      expect(find.byKey(const Key('peticion-sin-ficha')), findsNothing);
    });
  });

  group('nada se queda girando', () {
    testWidgets('al terminar de cargar siempre hay algo que leer', (
      tester,
    ) async {
      // La portada del entrenador y los Ajustes de un nadador se quedaron
      // girando para siempre en la feature 007, cada uno por su motivo. Es el
      // defecto que más veces ha salido en este proyecto.
      for (final ficha in <Nadador?>[
        null,
        anaDePrueba,
        const Nadador(id: 'n-ana', nombre: 'Ana', pruebaObjetivo: ''),
      ]) {
        await montarPeticion(tester, ficha: ficha);

        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Girar para siempre no se distingue de estar tardando',
        );
      }
    });
  });
}
