import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/ui/nadador/perfil_activo.dart';

/// Tarea T006: el camino por el que un plan llega al nadador.
///
/// **Esta tarea estuvo marcada como hecha sin estarlo.** Las pruebas de la
/// feature pasaban porque inyectaban el plan directamente en el estado; lo que
/// no existía era el camino en la app real.
///
/// Desde la feature 004 el camino tiene **dos piezas independientes**: que el
/// plan esté publicado, y que exista una asignación para ese nadador. El plan
/// ya no lleva dentro la lista de los suyos, porque un plan aprobado es
/// inmutable y porque las reglas de acceso no saben recorrer listas.
void main() {
  final hoyDePrueba = DateTime(2026, 10, 20);

  Plan plan({required String id, required EstadoPlan estado}) => Plan(
    id: id,
    nombre: 'Microciclo $id',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '800 Libre',
    estado: estado,
    sesiones: const [],
  );

  Asignacion asignacion(String planId, String nadadorId) => Asignacion(
    planId: planId,
    nadadorId: nadadorId,
    asignadaEn: DateTime(2026, 10, 15),
  );

  const nadador = Nadador(id: 'n1', nombre: 'Perfil de prueba');
  const otro = Nadador(id: 'n2', nombre: 'Otro perfil');

  group('FR-001 — solo lo publicado es del nadador', () {
    test('un borrador asignado no le llega', () {
      expect(
        planDe(
          nadador,
          [plan(id: 'p1', estado: EstadoPlan.borrador)],
          [asignacion('p1', 'n1')],
          hoy: hoyDePrueba,
        ),
        isNull,
      );
    });

    test('un aprobado asignado tampoco: aprobar no es entregar', () {
      expect(
        planDe(
          nadador,
          [plan(id: 'p1', estado: EstadoPlan.aprobado)],
          [asignacion('p1', 'n1')],
          hoy: hoyDePrueba,
        ),
        isNull,
        reason:
            'Un plan aprobado todavía no es de nadie. Publicarlo y '
            'asignarlo es lo que lo convierte en el entrenamiento de alguien',
      );
    });

    test('un publicado y asignado sí le llega', () {
      expect(
        planDe(
          nadador,
          [plan(id: 'p1', estado: EstadoPlan.publicado)],
          [asignacion('p1', 'n1')],
          hoy: hoyDePrueba,
        )?.id,
        'p1',
      );
    });
  });

  group('cada quien ve lo suyo', () {
    test('un publicado asignado a otro no le llega', () {
      expect(
        planDe(
          nadador,
          [plan(id: 'p1', estado: EstadoPlan.publicado)],
          [asignacion('p1', 'n2')],
          hoy: hoyDePrueba,
        ),
        isNull,
      );
    });

    test('un publicado sin asignar no es de nadie', () {
      final planes = [plan(id: 'p1', estado: EstadoPlan.publicado)];

      expect(planDe(nadador, planes, const [], hoy: hoyDePrueba), isNull);
      expect(planDe(otro, planes, const [], hoy: hoyDePrueba), isNull);
    });

    test('un plan puede ser de varios a la vez', () {
      final planes = [plan(id: 'p1', estado: EstadoPlan.publicado)];
      final asignaciones = [asignacion('p1', 'n1'), asignacion('p1', 'n2')];

      expect(planDe(nadador, planes, asignaciones, hoy: hoyDePrueba)?.id, 'p1');
      expect(planDe(otro, planes, asignaciones, hoy: hoyDePrueba)?.id, 'p1');
    });
  });

  group('con varios planes', () {
    test('se queda con el último, que es el que está entrenando', () {
      final planes = [
        plan(id: 'viejo', estado: EstadoPlan.publicado),
        plan(id: 'nuevo', estado: EstadoPlan.publicado),
      ];
      final asignaciones = [
        asignacion('viejo', 'n1'),
        asignacion('nuevo', 'n1'),
      ];

      expect(
        planDe(nadador, planes, asignaciones, hoy: hoyDePrueba)?.id,
        'nuevo',
      );
    });

    test('ignora los que no están publicados aunque sean posteriores', () {
      final planes = [
        plan(id: 'publicado', estado: EstadoPlan.publicado),
        plan(id: 'borrador', estado: EstadoPlan.borrador),
      ];
      final asignaciones = [
        asignacion('publicado', 'n1'),
        asignacion('borrador', 'n1'),
      ];

      expect(
        planDe(nadador, planes, asignaciones, hoy: hoyDePrueba)?.id,
        'publicado',
      );
    });
  });

  group('casos límite', () {
    test('sin planes no hay nada que entregar', () {
      expect(planDe(nadador, const [], const [], hoy: hoyDePrueba), isNull);
    });

    test('una asignación sin su plan no inventa uno', () {
      // Puede pasar si el entrenador borra un borrador que nunca se publicó.
      expect(
        planDe(nadador, const [], [
          asignacion('fantasma', 'n1'),
        ], hoy: hoyDePrueba),
        isNull,
      );
    });

    test('un perfil sin identificador no recibe nada, y no revienta', () {
      expect(
        planDe(
          const Nadador(nombre: 'Sin id'),
          [plan(id: 'p1', estado: EstadoPlan.publicado)],
          [asignacion('p1', 'n1')],
          hoy: hoyDePrueba,
        ),
        isNull,
      );
    });
  });

  group('la asignación es un documento propio', () {
    test('su identificador es determinista: entregar dos veces no duplica', () {
      expect(
        asignacion('p1', 'n1').id,
        Asignacion.idDeterminista(planId: 'p1', nadadorId: 'n1'),
      );
      expect(asignacion('p1', 'n1').id, 'p1|n1');
    });

    test('dos asignaciones del mismo par son la misma', () {
      expect(asignacion('p1', 'n1'), asignacion('p1', 'n1'));
      expect(asignacion('p1', 'n1'), isNot(asignacion('p1', 'n2')));
    });
  });

  group('de varios entregados, el de ahora', () {
    // Hallazgo del recorrido de la 010. Hasta la feature 009 un nadador tenía
    // un plan entregado y «el último» quería decir «el suyo». Desde que hay
    // macrociclos, **cada mesociclo es un plan asignado**, así que «el último»
    // pasó a ser el que la consulta devolviera de último: a Ana le tocó el
    // Mesociclo 3, que empezaba tres meses más tarde, y su Home le decía «Hoy
    // no hay sesión» un día que sí tenía.
    Plan mesociclo(String id, DateTime desde, DateTime hasta) => Plan(
      id: id,
      nombre: id,
      categoria: Categoria.precompetitivo,
      estiloObjetivo: Estilo.libre,
      estado: EstadoPlan.publicado,
      fechaInicio: desde,
      fechaFin: hasta,
    );

    final meso1 = mesociclo(
      'meso-1',
      DateTime(2026, 10, 5),
      DateTime(2026, 11, 29),
    );
    final meso2 = mesociclo(
      'meso-2',
      DateTime(2026, 12, 1),
      DateTime(2026, 12, 27),
    );
    final meso3 = mesociclo(
      'meso-3',
      DateTime(2027, 1, 4),
      DateTime(2027, 1, 17),
    );

    test('gana el que contiene hoy, no el último de la lista', () {
      expect(
        planDe(
          nadador,
          [meso2, meso3, meso1],
          [
            asignacion('meso-1', 'n1'),
            asignacion('meso-2', 'n1'),
            asignacion('meso-3', 'n1'),
          ],
          hoy: hoyDePrueba,
        )?.id,
        'meso-1',
      );
    });

    test('un plan suelto de la feature 003 no desplaza al de hoy', () {
      expect(
        planDe(
          nadador,
          [meso1, plan(id: 'suelto', estado: EstadoPlan.publicado)],
          [asignacion('meso-1', 'n1'), asignacion('suelto', 'n1')],
          hoy: hoyDePrueba,
        )?.id,
        'meso-1',
        reason:
            'el plan sin fechas es el que la 003 entregaba; el que dice '
            'cuándo empieza y cuándo acaba manda sobre él',
      );
    });
  });
}
