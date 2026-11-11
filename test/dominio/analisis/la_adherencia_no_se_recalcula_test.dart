/// La adherencia **se lee de donde ya se calcula**, y aquí no se vuelve a
/// calcular.
///
/// `ProgresoEnElMacrociclo` la calcula desde la feature 009, contando sesiones
/// y nada más: no pondera por metros ni por RPE, porque el principio VIII
/// prohíbe combinar carga externa e interna en un mismo indicador.
///
/// Un segundo cálculo aquí sería una segunda metodología por la puerta de
/// atrás (principio I): dos números con el mismo nombre que pueden discrepar,
/// y el entrenador sin forma de saber cuál está leyendo. Así que esta prueba
/// fija dos cosas: que el número coincide, y que en esta fuente **no hay
/// aritmética sobre lo hecho y lo pendiente**.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/analisis/lectura_del_nadador.dart';
import 'package:natacion_app/dominio/macrociclo/progreso_en_el_macrociclo.dart';

import 'dobles_de_analisis.dart';

void main() {
  const ruta = 'lib/dominio/analisis/lectura_del_nadador.dart';

  test('la adherencia de la lectura es la de ProgresoEnElMacrociclo', () async {
    final plan = mesociclo(
      id: 'plan-1',
      sesiones: [
        sesionDe(id: 's1', fecha: DateTime(2026, 11, 2)),
        sesionDe(id: 's2', fecha: DateTime(2026, 11, 4)),
        sesionDe(id: 's3', fecha: DateTime(2026, 11, 6)),
      ],
    );

    final hechos = [
      registroDe(sesionId: 's1', planId: 'plan-1'),
      registroDe(sesionId: 's2', planId: 'plan-1', realizada: false),
    ];

    final registros = RegistrosDeMentira();
    for (final registro in hechos) {
      registros.sembrar(registro);
    }

    final hoy = DateTime(2026, 11, 10);

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [plan],
      registros: registros,
      planes: PlanesDeMentira([plan]),
      hoy: hoy,
    );

    final esperado = ProgresoEnElMacrociclo(
      mesociclos: [plan],
      registros: hechos,
      hoy: hoy,
    ).adherencia;

    expect(lectura.progreso.adherencia, esperado);
    expect(lectura.progreso.adherencia.descripcion, '1 de 3');
  });

  test('la fuente no hace aritmética sobre lo hecho y lo pendiente', () {
    final codigo = File(ruta)
        .readAsLinesSync()
        .where((linea) {
          final limpia = linea.trimLeft();
          return !limpia.startsWith('//') && !limpia.startsWith('///');
        })
        .join('\n');

    // Que la prueba no pase por vacía.
    expect(codigo, contains('ProgresoEnElMacrociclo'));
    expect(codigo, contains('leerAlNadador'));

    for (final prohibido in <String>[
      'hechas.length',
      'pendientes.length',
      'Adherencia(',
      'realizadas:',
      'programadas:',
    ]) {
      expect(
        codigo.contains(prohibido),
        isFalse,
        reason:
            '«$prohibido» en $ruta es un segundo cálculo de la adherencia, y '
            'un segundo cálculo es una segunda metodología (principio I)',
      );
    }
  });
}
