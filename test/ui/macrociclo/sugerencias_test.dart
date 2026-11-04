/// M4, FR-008 — lo que se le ofrece de vuelta sale de su ficha y de nada más.
///
/// Las dos mitades importan, y la segunda es la que se puede romper sin que
/// nada falle: que **no haya nada más** en esos dos campos.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/ui/macrociclo/sugerencias.dart';

void main() {
  final ficha = Nadador(
    id: 'n-ana',
    nombre: 'Ana María Restrepo',
    fechaNacimiento: DateTime(2012, 3, 14),
    categoria: Categoria.competitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
    diagnosticoTecnico: const ['pierde el agarre al fatigarse'],
    marcas: [
      Marca(
        distancia: 200,
        estilo: Estilo.libre,
        tiempo: const Duration(minutes: 2, seconds: 31, milliseconds: 400),
        fecha: DateTime(2026, 9, 12),
      ),
      Marca(
        distancia: 200,
        estilo: Estilo.libre,
        tiempo: const Duration(minutes: 2, seconds: 38),
        fecha: DateTime(2026, 4, 2),
      ),
    ],
  );

  group('lo que sí se ofrece', () {
    test('la prueba objetivo que él anotó', () {
      expect(
        sugerenciasDesdeLaFicha(ficha).paraLaPrueba,
        contains('200 Libre'),
      );
    });

    test('la marca más reciente, no todas', () {
      final sugerido = sugerenciasDesdeLaFicha(ficha).paraLaPrueba;

      expect(sugerido, contains('2:31.40'));
      expect(
        sugerido,
        isNot(contains('2:38.00')),
        reason: 'una lista de marcas dentro de un campo de texto no es un '
            'modelo, es un volcado',
      );
    });

    test('el diagnóstico técnico que él observó', () {
      expect(
        sugerenciasDesdeLaFicha(ficha).paraElNadador,
        contains('pierde el agarre'),
      );
    });

    test('el estilo objetivo', () {
      expect(
        sugerenciasDesdeLaFicha(ficha).paraElNadador,
        contains('Libre'),
      );
    });
  });

  group('lo que NO se ofrece', () {
    test('nada sobre la edad ni la fecha de nacimiento', () {
      // Es el dato que más tienta: está en la ficha y parece inocuo. Pero de
      // la edad a «tolerancia a la fatiga» hay un paso, y ese paso es el que
      // la enmienda reservó al entrenador.
      final sugerido = sugerenciasDesdeLaFicha(ficha);

      for (final texto in [sugerido.paraLaPrueba, sugerido.paraElNadador]) {
        expect(texto, isNot(contains('2012')));
        expect(texto, isNot(contains('14 años')));
        expect(texto.toLowerCase(), isNot(contains('edad')));
      }
    });

    test('nada sobre la categoría', () {
      final sugerido = sugerenciasDesdeLaFicha(ficha);

      for (final texto in [sugerido.paraLaPrueba, sugerido.paraElNadador]) {
        expect(texto, isNot(contains('Competitivo')));
      }
    });

    test('ni una palabra sobre tolerancia, motivación o recuperación', () {
      // Los tres son del paso 3 de la sección 4 y ninguna fórmula los deriva.
      // Si aparecieran pre-escritos, el entrenador estaría firmando una
      // observación que no hizo.
      final sugerido = sugerenciasDesdeLaFicha(ficha);
      final todo =
          '${sugerido.paraLaPrueba}\n${sugerido.paraElNadador}'.toLowerCase();

      expect(todo, isNot(contains('toleran')));
      expect(todo, isNot(contains('motiva')));
      expect(todo, isNot(contains('recupera')));
    });

    test('con la ficha vacía se ofrece vacío, no un texto de relleno', () {
      // Un campo vacío es mejor que uno inventado: se ve que falta.
      final sugerido = sugerenciasDesdeLaFicha(
        const Nadador(nombre: 'Alguien nuevo'),
      );

      expect(sugerido.paraLaPrueba, isEmpty);
      expect(sugerido.paraElNadador, isEmpty);
      expect(sugerido.hayAlgoQueOfrecer, isFalse);
    });
  });

  test('el código solo lee los cuatro campos que puede leer', () {
    // Sobre la fuente, porque es una propiedad del código y no de una
    // ejecución: una prueba de datos solo dice que con **esta** ficha no sale
    // la edad. Esto dice que no hay por dónde.
    final fuente = File(
      'lib/ui/macrociclo/sugerencias.dart',
    ).readAsStringSync();

    final codigo = fuente
        .split('\n')
        .where((l) => !l.trim().startsWith('///') && !l.trim().startsWith('//'))
        .join('\n');

    for (final permitido in [
      'pruebaObjetivo',
      'marcas',
      'diagnosticoTecnico',
      'estiloObjetivo',
    ]) {
      expect(codigo, contains('ficha.$permitido'));
    }

    for (final prohibido in [
      'ficha.fechaNacimiento',
      'ficha.categoria',
      'ficha.edadEn',
      'ficha.esMenorEn',
      'ficha.declaraSerMayorDeEdad',
    ]) {
      expect(
        codigo,
        isNot(contains(prohibido)),
        reason: '$prohibido no es una observación del entrenador sobre el '
            'nadador: es un dato del que la app estaría deduciendo una',
      );
    }
  });
}
