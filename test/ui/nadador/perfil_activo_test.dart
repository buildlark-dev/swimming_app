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
        ),
        isNull,
        reason: 'Un plan aprobado todavía no es de nadie. Publicarlo y '
            'asignarlo es lo que lo convierte en el entrenamiento de alguien',
      );
    });

    test('un publicado y asignado sí le llega', () {
      expect(
        planDe(
          nadador,
          [plan(id: 'p1', estado: EstadoPlan.publicado)],
          [asignacion('p1', 'n1')],
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
        ),
        isNull,
      );
    });

    test('un publicado sin asignar no es de nadie', () {
      final planes = [plan(id: 'p1', estado: EstadoPlan.publicado)];

      expect(planDe(nadador, planes, const []), isNull);
      expect(planDe(otro, planes, const []), isNull);
    });

    test('un plan puede ser de varios a la vez', () {
      final planes = [plan(id: 'p1', estado: EstadoPlan.publicado)];
      final asignaciones = [asignacion('p1', 'n1'), asignacion('p1', 'n2')];

      expect(planDe(nadador, planes, asignaciones)?.id, 'p1');
      expect(planDe(otro, planes, asignaciones)?.id, 'p1');
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

      expect(planDe(nadador, planes, asignaciones)?.id, 'nuevo');
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

      expect(planDe(nadador, planes, asignaciones)?.id, 'publicado');
    });
  });

  group('casos límite', () {
    test('sin planes no hay nada que entregar', () {
      expect(planDe(nadador, const [], const []), isNull);
    });

    test('una asignación sin su plan no inventa uno', () {
      // Puede pasar si el entrenador borra un borrador que nunca se publicó.
      expect(
        planDe(nadador, const [], [asignacion('fantasma', 'n1')]),
        isNull,
      );
    });

    test('un perfil sin identificador no recibe nada, y no revienta', () {
      expect(
        planDe(
          const Nadador(nombre: 'Sin id'),
          [plan(id: 'p1', estado: EstadoPlan.publicado)],
          [asignacion('p1', 'n1')],
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
}
