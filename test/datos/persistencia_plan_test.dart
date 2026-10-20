import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// FR-032 y FR-033 — guardar y recuperar no altera lo que el entrenador firmó.
///
/// Hasta esta feature los planes vivían en memoria: generar un microciclo
/// completo y perderlo al recargar convertía el trabajo del entrenador en algo
/// que no se le podía confiar a la app.
void main() {
  Plan plan({EstadoPlan estado = EstadoPlan.aprobado}) => Plan(
        id: 'p1',
        nombre: 'Microciclo de base aeróbica',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '800 Libre',
        estado: estado,
        versionMetodologia: '3.6.0',
        fechaAprobacion: DateTime(2026, 10, 1),
        microciclos: const [
          Microciclo(
            id: 'm1',
            nombre: 'Semana 1',
            orden: 1,
            objetivo: 'Economía de nado',
          ),
        ],
        sesiones: [
          for (var i = 1; i <= 3; i++)
            Sesion(
              id: 's$i',
              microcicloId: 'm1',
              fecha: DateTime(2026, 10, i),
              objetivoTecnico: 'Técnica de eficiencia',
              objetivoFisiologico: 'Base aeróbica',
              partes: [
                Parte(
                  tipo: TipoParte.inicial,
                  series: const [
                    Serie(
                      repeticiones: 8,
                      distancia: 50,
                      zona: Zona.a1,
                      estilo: Estilo.libre,
                    ),
                  ],
                ),
                const Parte(tipo: TipoParte.central),
                const Parte(tipo: TipoParte.cierre),
              ],
            ),
        ],
      );

  String serializado(Plan p) => jsonEncode(planAJson(p, conSesiones: true));

  group('FR-032 — ida y vuelta, byte a byte', () {
    test('guardar y recuperar no altera un byte', () async {
      final original = plan();
      final antes = serializado(original);

      final repo = RepositorioPlanesMemoria();
      await repo.guardarAprobado(original, const {});
      final recuperado = await repo.obtener('p1');

      expect(recuperado, isNotNull);
      expect(
        serializado(recuperado!),
        antes,
        reason: 'Si esto falla, el entrenador ya no puede saber que lo que '
            'firmó sigue siendo lo que hay',
      );
    });

    test('la versión de metodología sellada sobrevive', () async {
      final repo = RepositorioPlanesMemoria();
      await repo.guardarAprobado(plan(), const {});

      final recuperado = await repo.obtener('p1');
      expect(recuperado!.versionMetodologia, '3.6.0');
      expect(recuperado.fechaAprobacion, DateTime(2026, 10, 1));
    });

    test('las sesiones y sus series vuelven enteras', () async {
      final repo = RepositorioPlanesMemoria();
      await repo.guardarAprobado(plan(), const {});

      final recuperado = await repo.obtener('p1');
      expect(recuperado!.sesiones, hasLength(3));
      expect(recuperado.sesiones.first.partes.first.series.first.distancia, 50);
    });
  });

  group('FR-033 — persistir no es aprobar', () {
    test('un borrador guardado sigue siendo borrador', () async {
      final repo = RepositorioPlanesMemoria();
      final id = await repo.guardarBorrador(plan(estado: EstadoPlan.borrador));

      final recuperado = await repo.obtener(id);
      expect(
        recuperado!.estado,
        EstadoPlan.borrador,
        reason: 'Guardar es guardar. Aprobar es la firma del entrenador, y es '
            'un paso suyo (principio IV)',
      );
    });
  });

  group('FR-035 — la entrega también sobrevive', () {
    test('las asignaciones se recuperan después de guardarlas', () async {
      final repo = RepositorioAsignacionesMemoria();
      await repo.asignar(
        Asignacion(planId: 'p1', nadadorId: 'n1', asignadaEn: DateTime(2026, 10, 15)),
      );

      expect((await repo.listar()), hasLength(1));
      expect((await repo.deNadador('n1')).single.planId, 'p1');
    });

    test('entregar dos veces el mismo plan a la misma persona no duplica', () async {
      final repo = RepositorioAsignacionesMemoria();
      final asignacion = Asignacion(
        planId: 'p1',
        nadadorId: 'n1',
        asignadaEn: DateTime(2026, 10, 15),
      );

      await repo.asignar(asignacion);
      await repo.asignar(asignacion);

      expect(
        await repo.listar(),
        hasLength(1),
        reason: 'El identificador es determinista: dos entregas escriben el '
            'mismo documento. No por una comprobación que alguien pueda '
            'olvidar, sino porque no hay otro documento que escribir',
      );
    });

    test('retirar un plan no se lleva las demás asignaciones', () async {
      final repo = RepositorioAsignacionesMemoria();
      for (final n in ['n1', 'n2']) {
        await repo.asignar(
          Asignacion(planId: 'p1', nadadorId: n, asignadaEn: DateTime(2026, 10, 15)),
        );
      }

      await repo.retirar('p1', 'n1');

      expect((await repo.dePlan('p1')).single.nadadorId, 'n2');
    });
  });

  group('el nadador conserva lo que declaró', () {
    test('la declaración de mayoría de edad va y vuelve', () async {
      final repo = RepositorioNadadoresMemoria();
      final id = await repo.guardar(
        const Nadador(
          nombre: 'Perfil de prueba',
          categoria: Categoria.iniciacion,
          estiloObjetivo: Estilo.libre,
          declaraSerMayorDeEdad: true,
        ),
      );

      final recuperado = await repo.obtener(id);
      expect(recuperado!.declaraSerMayorDeEdad, isTrue);
    });

    test('sin declarar nada vuelve como nulo, no como falso', () async {
      // `null` significa «todavía no lo declaró», que no es lo mismo que ser
      // menor. Convertirlo en `false` al guardar sería inventar una
      // declaración que nadie hizo.
      final repo = RepositorioNadadoresMemoria();
      final id = await repo.guardar(
        const Nadador(
          nombre: 'Sin declarar',
          categoria: Categoria.iniciacion,
          estiloObjetivo: Estilo.libre,
        ),
      );

      expect((await repo.obtener(id))!.declaraSerMayorDeEdad, isNull);
    });
  });
}
