/// Garantías H17 y H18 — los cuatro números del entrenador.
///
/// Las definiciones de `data-model.md` no son aproximadas, y por eso se fijan
/// aquí:
///
/// - **en uso**: `publicado`, con asignación, y cuyo nadador asignado tiene
///   **algún** registro. Asignado y sin tocar no es en uso.
/// - **esperando aprobación**: en `borrador` y **sin nada que impida firmarlo**.
///   Un borrador con bloqueos no espera su firma: espera corrección.
/// - **aprobados sin asignar**: en `aprobado` y sin ninguna asignación.
///
/// Y H18: contar lo que espera aprobación no es aprobarlo. Ningún número de
/// esta pantalla mueve un plan de estado.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/hub/resumen_del_entrenador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

void main() {
  final hoy = DateTime(2026, 10, 27);

  Plan plan(String id, EstadoPlan estado) => Plan(
    id: id,
    nombre: 'Microciclo $id',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    estado: estado,
    versionMetodologia: '3.6.0',
  );

  Asignacion asignacion(String planId, String nadadorId) =>
      Asignacion(planId: planId, nadadorId: nadadorId, asignadaEn: hoy);

  /// Con el juicio sobre la auditoría inyectado, para poder contar sin montar
  /// un plan que cumpla los once criterios. Que el juicio de verdad sea la
  /// auditoría lo comprueba la última prueba de este archivo.
  ResumenDelEntrenador resumen({
    List<Plan> planes = const [],
    List<Asignacion> asignaciones = const [],
    Set<String> conRegistros = const {},
    bool listo = true,
  }) => ResumenDelEntrenador.de(
    planes: planes,
    asignaciones: asignaciones,
    nadadoresConRegistros: conRegistros,
    listoParaFirmar: (_) => listo,
  );

  group('sin nada', () {
    test('los cuatro números son cero', () {
      final r = resumen();

      expect(r.planesGenerados, 0);
      expect(r.esperandoAprobacion, 0);
      expect(r.aprobadosSinAsignar, 0);
      expect(r.enUso, 0);
    });
  });

  group('planes generados', () {
    test('cuenta todos, en cualquier estado', () {
      final r = resumen(
        planes: [
          plan('p1', EstadoPlan.borrador),
          plan('p2', EstadoPlan.aprobado),
          plan('p3', EstadoPlan.publicado),
        ],
      );

      expect(r.planesGenerados, 3);
    });
  });

  group('esperando aprobación', () {
    test('un borrador sin nada que lo impida, sí', () {
      final r = resumen(planes: [plan('p1', EstadoPlan.borrador)]);
      expect(r.esperandoAprobacion, 1);
    });

    test('un borrador con bloqueos, no: ese espera corrección', () {
      final r = resumen(
        planes: [plan('p1', EstadoPlan.borrador)],
        listo: false,
      );
      expect(r.esperandoAprobacion, 0);
    });

    test('lo ya aprobado no espera aprobación', () {
      final r = resumen(
        planes: [
          plan('p1', EstadoPlan.aprobado),
          plan('p2', EstadoPlan.publicado),
        ],
      );
      expect(r.esperandoAprobacion, 0);
    });
  });

  group('aprobados sin asignar', () {
    test('un aprobado sin asignación, sí', () {
      final r = resumen(planes: [plan('p1', EstadoPlan.aprobado)]);
      expect(r.aprobadosSinAsignar, 1);
    });

    test('un aprobado con asignación, no', () {
      final r = resumen(
        planes: [plan('p1', EstadoPlan.aprobado)],
        asignaciones: [asignacion('p1', 'n1')],
      );
      expect(r.aprobadosSinAsignar, 0);
    });

    test('un borrador sin asignar no cuenta aquí', () {
      final r = resumen(planes: [plan('p1', EstadoPlan.borrador)]);
      expect(r.aprobadosSinAsignar, 0);
    });
  });

  group('en uso', () {
    test('publicado, asignado, y el nadador ha respondido algo: sí', () {
      final r = resumen(
        planes: [plan('p1', EstadoPlan.publicado)],
        asignaciones: [asignacion('p1', 'n1')],
        conRegistros: {'n1'},
      );
      expect(r.enUso, 1);
    });

    test('**asignado y sin tocar no es en uso**', () {
      final r = resumen(
        planes: [plan('p1', EstadoPlan.publicado)],
        asignaciones: [asignacion('p1', 'n1')],
      );
      expect(
        r.enUso,
        0,
        reason: 'Un plan que nadie ha tocado está asignado, no en uso',
      );
    });

    test('publicado sin asignar no es en uso', () {
      final r = resumen(
        planes: [plan('p1', EstadoPlan.publicado)],
        conRegistros: {'n1'},
      );
      expect(r.enUso, 0);
    });

    test('un aprobado no es en uso aunque su nadador tenga registros', () {
      final r = resumen(
        planes: [plan('p1', EstadoPlan.aprobado)],
        asignaciones: [asignacion('p1', 'n1')],
        conRegistros: {'n1'},
      );
      expect(r.enUso, 0);
    });

    test('se cuenta el plan una vez, aunque lo usen dos nadadores', () {
      final r = resumen(
        planes: [plan('p1', EstadoPlan.publicado)],
        asignaciones: [asignacion('p1', 'n1'), asignacion('p1', 'n2')],
        conRegistros: {'n1', 'n2'},
      );
      expect(r.enUso, 1);
    });

    test('basta con que uno de sus nadadores haya respondido', () {
      final r = resumen(
        planes: [plan('p1', EstadoPlan.publicado)],
        asignaciones: [asignacion('p1', 'n1'), asignacion('p1', 'n2')],
        conRegistros: {'n2'},
      );
      expect(r.enUso, 1);
    });
  });

  group('el juicio sobre la auditoría', () {
    test('por omisión es la auditoría de verdad, no un «sí» fijo', () {
      // Un borrador vacío no tiene con qué cumplir los criterios, así que no
      // está listo para firmar. Si esto diera 1, alguien habría puesto el
      // juicio en `true` por omisión y el número diría que todo espera firma.
      final r = ResumenDelEntrenador.de(
        planes: [plan('p1', EstadoPlan.borrador)],
        asignaciones: const [],
        nadadoresConRegistros: const {},
      );

      expect(
        r.esperandoAprobacion,
        0,
        reason: 'Sin sesiones no hay plan que firmar, y la auditoría lo sabe',
      );
    });
  });
}
