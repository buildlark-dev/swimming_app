/// Garantía P25 — el componente acentuado sale de la fase, y **cuadra con ella
/// por construcción**.
///
/// `ValidacionPeticion` ya rechaza un componente que apunta a velocidad en una
/// fase que no le asigna volumen. Derivar el componente *de* la fase hace que
/// esa comprobación pase por construcción y no por suerte, que es el mismo
/// listón que el principio III pone a los planes generados.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/validacion_peticion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/peticiones/componente_por_fase.dart';

void main() {
  final lunes = DateTime(2026, 11, 2);

  PeticionGeneracion peticionCon({
    required Categoria categoria,
    required FaseAtr? fase,
    required String componente,
  }) => PeticionGeneracion(
    categoria: categoria,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
    faseAtr: fase,
    componenteAcentuado: componente,
    diasDisponibles: [lunes, lunes.add(const Duration(days: 2))],
    longitudPiscina: 25,
    duracionSesionMinutos: 90,
  );

  List<Impedimento> impedimentosDe(PeticionGeneracion peticion) =>
      const ValidacionPeticion().validar(peticion);

  group('P25 — lo derivado pasa la comprobación del motor', () {
    test('cada fase da un componente que el motor acepta', () {
      for (final fase in FaseAtr.values) {
        final componente = componenteParaFase(
          fase: fase,
          categoria: Categoria.competitivo,
        );

        final problemas = impedimentosDe(
          peticionCon(
            categoria: Categoria.competitivo,
            fase: fase,
            componente: componente,
          ),
        ).where((i) => i.campo == 'componenteAcentuado');

        expect(
          problemas,
          isEmpty,
          reason:
              'El componente «$componente» derivado de ${fase.nombre} no pasa '
              'la validación del motor',
        );
      }
    });

    test('**control negativo**: velocidad en Acumulación sí lo rechaza', () {
      // Si esto no fallara, la prueba de arriba estaría pasando porque la
      // comprobación no mira, no porque lo derivado cuadre.
      final problemas = impedimentosDe(
        peticionCon(
          categoria: Categoria.competitivo,
          fase: FaseAtr.acumulacion,
          componente: 'Velocidad pura',
        ),
      ).where((i) => i.campo == 'componenteAcentuado');

      expect(problemas, isNotEmpty);
    });

    test('y Acumulación nunca deriva un componente de velocidad', () {
      final componente = componenteParaFase(
        fase: FaseAtr.acumulacion,
        categoria: Categoria.competitivo,
      ).toLowerCase();

      expect(componente, isNot(contains('velocidad')));
      expect(componente, isNot(contains('sprint')));
    });
  });

  group('sin fase, el componente sale de la categoría', () {
    test('Iniciación y Tecnificación tienen el suyo, y no está vacío', () {
      for (final categoria in Categoria.values.where((c) => !c.usaAtr)) {
        final componente = componenteParaFase(fase: null, categoria: categoria);

        expect(componente.trim(), isNotEmpty);

        final problemas = impedimentosDe(
          peticionCon(
            categoria: categoria,
            fase: null,
            componente: componente,
          ),
        ).where((i) => i.campo == 'componenteAcentuado');

        expect(problemas, isEmpty, reason: categoria.nombre);
      }
    });

    test('**control negativo**: un componente vacío sí lo rechaza', () {
      final problemas = impedimentosDe(
        peticionCon(
          categoria: Categoria.iniciacion,
          fase: null,
          componente: '   ',
        ),
      ).where((i) => i.campo == 'componenteAcentuado');

      expect(problemas, isNotEmpty);
    });
  });

  test('es total: cualquier combinación devuelve algo legible', () {
    for (final categoria in Categoria.values) {
      for (final fase in [null, ...FaseAtr.values]) {
        expect(
          componenteParaFase(fase: fase, categoria: categoria).trim(),
          isNotEmpty,
          reason: '${categoria.nombre} / ${fase?.nombre ?? 'sin fase'}',
        );
      }
    }
  });
}
