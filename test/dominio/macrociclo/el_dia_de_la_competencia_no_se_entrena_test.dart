/// El día de la competencia no se entrena.
///
/// **Visto en el recorrido del Pixel 7 y decidido por el entrenador.** Con la
/// competencia en un día de piscina, la derivación ponía una sesión **el mismo
/// día de la carrera**: el camino de la nadadora terminaba en «Viernes 1/1», y
/// el 1/1 era la competencia.
///
/// La última sesión es la de **antes**, y la preparación termina la víspera.
///
/// **Se corrige en el esqueleto, donde se reparten los bloques, y no quitando
/// ese día al final.** Sacarlo después dejaba la última semana con dos días de
/// piscina en lugar de tres, y el motor la rechaza con razón: la frecuencia de
/// la categoría es una regla de la metodología, no un detalle del calendario.
/// Lo que cambia es que hay un día menos de preparación, que es la verdad.
///
/// La derivación conserva además su propia guarda, por si un bloque llegara al
/// día de competir por otro camino —el entrenador editando el esqueleto a
/// mano—: ahí preferimos que lo diga a que le programe entrenamiento el día de
/// la carrera.
///
/// Esto recorre **el camino real**, de la fecha a las sesiones, porque el
/// defecto vivía en la junta entre el esqueleto y la derivación y una
/// estructura escrita a mano se la salta.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/macrociclo/derivar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  Biblioteca biblioteca() => Biblioteca.desdeJson(
    jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  const ficha = Nadador(
    id: 'n-ana',
    nombre: 'Ana María Restrepo',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '800 Libre',
  );

  /// Del día de la competencia a las sesiones, por el camino de la app.
  ///
  /// `diasPorSemana` incluye **el día de la semana en que cae la carrera**: si
  /// no, el defecto no puede aparecer y la prueba pasaría sola.
  List<DateTime> sesionesHacia(
    DateTime competencia, {
    required DateTime hoy,
    required List<int> diasPorSemana,
  }) {
    expect(
      diasPorSemana,
      contains(competencia.weekday),
      reason: 'sin la carrera en un día de piscina esto no comprueba nada',
    );

    final esqueleto = esqueletoParaMacrociclo(
      fechaDeCompetencia: competencia,
      hoy: hoy,
      categoria: ficha.categoria!,
    );
    expect(esqueleto.bloques, isNotEmpty);

    final resultado = derivarMacrociclo(
      estructura: EstructuraConfirmada(
        modeloDeLaPrueba: 'Prueba objetivo: 800 Libre.',
        modeloDelNadador: 'Estilo objetivo: Libre.',
        bloques: esqueleto.bloques,
        confirmadaEn: hoy,
        diasPorSemana: diasPorSemana,
        duracionSesionMinutos: 90,
        longitudPiscina: 25,
      ),
      ficha: ficha,
      biblioteca: biblioteca(),
      versionMetodologia: '3.6.0',
      nombre: 'Hacia 800 Libre',
      fechaDeCompetencia: competencia,
    );

    expect(
      resultado,
      isA<MacrocicloDerivado>(),
      reason: 'la derivación no llegó a producir nada que mirar',
    );

    return [
      for (final mesociclo in (resultado as MacrocicloDerivado).mesociclos)
        for (final sesion in mesociclo.sesiones)
          if (sesion.fecha != null) sesion.fecha!,
    ]..sort();
  }

  // Viernes.
  final competencia = DateTime(2027, 1, 1);
  final hoy = DateTime(2026, 11, 2);
  const lunesMiercolesViernes = [1, 3, 5];

  test('no hay sesión el día de la competencia', () {
    final fechas = sesionesHacia(
      competencia,
      hoy: hoy,
      diasPorSemana: lunesMiercolesViernes,
    );

    expect(
      fechas,
      isNot(contains(competencia)),
      reason: 'se le pedía entrenar el día que compite',
    );
  });

  test('la última sesión es la de antes', () {
    final fechas = sesionesHacia(
      competencia,
      hoy: hoy,
      diasPorSemana: lunesMiercolesViernes,
    );

    expect(fechas, isNotEmpty);
    expect(fechas.last.isBefore(competencia), isTrue);
  });

  test('y sigue habiendo semanas completas hasta el final', () {
    // Quitar ese día no puede costar sesiones: el bloque se reparte sobre la
    // víspera, no se le arranca un día al último microciclo. Tres días de
    // piscina por semana, todas las semanas.
    final fechas = sesionesHacia(
      competencia,
      hoy: hoy,
      diasPorSemana: lunesMiercolesViernes,
    );

    expect(
      fechas.length % 3,
      0,
      reason: 'alguna semana se quedó corta al sacar el día de la carrera',
    );
  });

  test('el miércoles anterior sigue estando', () {
    // El control de la de arriba: que no se haya ido media semana con él.
    final fechas = sesionesHacia(
      competencia,
      hoy: hoy,
      diasPorSemana: lunesMiercolesViernes,
    );

    expect(fechas, contains(DateTime(2026, 12, 30)));
  });

  test('con la carrera en domingo, que también es de piscina, igual', () {
    // El mismo caso en otro día de la semana: lo que se quita es el día de
    // competir, no un viernes.
    final domingo = DateTime(2027, 1, 3);
    final fechas = sesionesHacia(
      domingo,
      hoy: hoy,
      diasPorSemana: const [1, 3, 7],
    );

    expect(fechas, isNot(contains(domingo)));
    expect(fechas, isNotEmpty);
  });
}
