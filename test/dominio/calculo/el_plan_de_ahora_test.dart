/// Cuál de sus planes es **el de ahora**.
///
/// Hallazgo del recorrido de la 010 en el Pixel 7, y de los que importan
/// porque el síntoma no se parece a la causa.
///
/// El HUB elegía el plan del nadador como *el último de sus asignaciones
/// publicadas*. Hasta la feature 009 eso quería decir «el plan que le
/// entregaron», porque tenía uno. Desde que existen los macrociclos **cada
/// mesociclo es un plan asignado**, así que «el último» pasó a ser el que la
/// consulta devolviera de último — en el recorrido, el Mesociclo 3, que empieza
/// en febrero de 2027.
///
/// Lo que ella veía: «Hoy no hay sesión» un día que sí tenía, «Sesiones
/// cumplidas: 0 de 6» sobre un macrociclo de 39, y un historial de sesiones de
/// dentro de tres meses. Y lo que no veía: **ninguna sesión sobre la que
/// preguntarle a su entrenador**, porque todas estaban por llegar.
///
/// Lo peor no es que estuviera mal, es que estaba mal **de forma arbitraria**:
/// dependía del orden de los identificadores en Firestore.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/calculo/el_plan_de_ahora.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  final hoy = DateTime(2026, 11, 11);

  Plan plan(String id, {DateTime? desde, DateTime? hasta}) => Plan(
    id: id,
    nombre: id,
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    estado: EstadoPlan.publicado,
    fechaInicio: desde,
    fechaFin: hasta,
  );

  final mesociclo1 = plan(
    'meso-1',
    desde: DateTime(2026, 11, 6),
    hasta: DateTime(2027, 1, 4),
  );
  final mesociclo2 = plan(
    'meso-2',
    desde: DateTime(2027, 1, 6),
    hasta: DateTime(2027, 2, 1),
  );
  final mesociclo3 = plan(
    'meso-3',
    desde: DateTime(2027, 2, 3),
    hasta: DateTime(2027, 2, 15),
  );

  test('el que contiene hoy, aunque no sea el último de la lista', () {
    // El orden es el que devuelve la consulta, que no es ningún orden.
    expect(
      elPlanDeAhora([mesociclo2, mesociclo3, mesociclo1], hoy)?.id,
      'meso-1',
      reason:
          'esto es el defecto entero: el último de la lista era el Mesociclo '
          '3, que empieza en febrero',
    );
  });

  test('el primer día cuenta, y el último también', () {
    expect(elPlanDeAhora([mesociclo1], DateTime(2026, 11, 6))?.id, 'meso-1');
    expect(elPlanDeAhora([mesociclo1], DateTime(2027, 1, 4))?.id, 'meso-1');
  });

  test('se compara por fecha, no por instante', () {
    // Sin esto, el plan que empieza hoy «todavía no habría empezado» para quien
    // abre la app por la mañana. Es la misma regla que ProgresoEnElMacrociclo.
    expect(
      elPlanDeAhora([mesociclo1], DateTime(2026, 11, 6, 7, 30))?.id,
      'meso-1',
    );
    expect(
      elPlanDeAhora([mesociclo1], DateTime(2027, 1, 4, 23, 59))?.id,
      'meso-1',
    );
  });

  test('antes de empezar, el siguiente que empieza', () {
    expect(
      elPlanDeAhora([mesociclo3, mesociclo2], DateTime(2026, 12, 1))?.id,
      'meso-2',
      reason:
          'en un hueco entre bloques, lo que le toca mirar es lo que viene, '
          'no lo que venga de último en la lista',
    );
  });

  test('después de terminarlo todo, el último que terminó', () {
    expect(
      elPlanDeAhora([
        mesociclo1,
        mesociclo3,
        mesociclo2,
      ], DateTime(2027, 6, 1))?.id,
      'meso-3',
    );
  });

  test('sin fechas se queda con el último, que es lo que había antes', () {
    // Un plan de la feature 003 puede no tener fechas de bloque. No se
    // adivinan: se conserva el comportamiento anterior.
    final sinFechas = [plan('a'), plan('b')];

    expect(elPlanDeAhora(sinFechas, hoy)?.id, 'b');
  });

  test('uno con fechas gana a uno sin ellas, si contiene hoy', () {
    expect(elPlanDeAhora([mesociclo1, plan('suelto')], hoy)?.id, 'meso-1');
  });

  test('con la lista vacía no hay plan', () {
    expect(elPlanDeAhora(const [], hoy), isNull);
  });

  test('si dos contienen hoy, el que empezó más tarde', () {
    final viejo = plan(
      'viejo',
      desde: DateTime(2026, 10, 1),
      hasta: DateTime(2026, 12, 1),
    );

    expect(
      elPlanDeAhora([viejo, mesociclo1], hoy)?.id,
      'meso-1',
      reason: 'el que empezó más tarde es en el que está trabajando ahora',
    );
  });
}
