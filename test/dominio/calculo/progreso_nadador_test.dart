import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/dominio/calculo/sesion_del_dia.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// Progreso del nadador: historial y adherencia.
///
/// El entrenador eligió el alcance al aclarar la especificación: historial más
/// adherencia **como recuento**, sin gráficas (FR-005a a FR-005c).
void main() {
  Sesion sesion({
    required String id,
    required DateTime fecha,
    String microcicloId = 'm1',
    int metros = 2000,
  }) => Sesion(
    id: id,
    microcicloId: microcicloId,
    fecha: fecha,
    objetivoTecnico: 'Técnica de eficiencia',
    objetivoFisiologico: 'Base aeróbica',
    partes: [
      Parte(
        tipo: TipoParte.inicial,
        series: [Serie(distancia: metros, zona: Zona.a1, estilo: Estilo.libre)],
      ),
      const Parte(tipo: TipoParte.central),
      const Parte(tipo: TipoParte.cierre),
    ],
  );

  RegistroDeSesion registro({
    required String sesionId,
    required bool realizada,
    int? rpe,
    ReporteDeMolestia? molestia,
  }) => RegistroDeSesion(
    nadadorId: 'n1',
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: '3.5.0',
    realizada: realizada,
    registradoEn: DateTime(2026, 10, 14),
    rpePercibido: rpe,
    molestia: molestia,
  );

  Plan planDe(List<Sesion> sesiones, {List<Microciclo>? microciclos}) => Plan(
    id: 'p1',
    nombre: 'Microciclo de prueba',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '800 Libre',
    microciclos:
        microciclos ??
        const [
          Microciclo(
            id: 'm1',
            nombre: 'Base aeróbica',
            orden: 1,
            objetivo: 'Economía de nado',
          ),
        ],
    sesiones: sesiones,
  );

  group('historial (FR-005a)', () {
    test('de la más reciente a la más antigua', () {
      final plan = planDe([
        sesion(id: 's1', fecha: DateTime(2026, 10, 5)),
        sesion(id: 's2', fecha: DateTime(2026, 10, 12)),
        sesion(id: 's3', fecha: DateTime(2026, 10, 8)),
      ]);

      final progreso = ProgresoDelNadador(plan: plan, registros: const []);

      expect(progreso.historial.map((h) => h.sesion.id), ['s2', 's3', 's1']);
    });

    test('las sesiones sin respuesta también aparecen', () {
      final plan = planDe([sesion(id: 's1', fecha: DateTime(2026, 10, 5))]);
      final progreso = ProgresoDelNadador(plan: plan, registros: const []);

      expect(progreso.historial, hasLength(1));
      expect(progreso.historial.first.tieneRespuesta, isFalse);
    });

    test('la carga externa y la interna viajan juntas pero separadas', () {
      final plan = planDe([sesion(id: 's1', fecha: DateTime(2026, 10, 5))]);
      final progreso = ProgresoDelNadador(
        plan: plan,
        registros: [registro(sesionId: 's1', realizada: true, rpe: 7)],
      );

      final entrada = progreso.historial.first;

      // Dos campos, no un resumen de los dos (principio VIII).
      expect(entrada.sesion.metros, 2000);
      expect(entrada.registro!.rpePercibido, 7);
    });
  });

  group('adherencia (FR-005b)', () {
    Plan planDeSeis() => planDe([
      for (var i = 1; i <= 6; i++)
        sesion(id: 's$i', fecha: DateTime(2026, 10, i)),
    ]);

    test('cuatro de seis realizadas dan «4 de 6»', () {
      final progreso = ProgresoDelNadador(
        plan: planDeSeis(),
        registros: [
          for (var i = 1; i <= 4; i++)
            registro(sesionId: 's$i', realizada: true),
        ],
      );

      expect(
        progreso.adherenciaDelPlan,
        const Adherencia(realizadas: 4, programadas: 6),
      );
      expect(progreso.adherenciaDelPlan.descripcion, '4 de 6');
    });

    test('un registro con realizada en falso no suma', () {
      final progreso = ProgresoDelNadador(
        plan: planDeSeis(),
        registros: [registro(sesionId: 's1', realizada: false)],
      );

      expect(progreso.adherenciaDelPlan.realizadas, 0);
    });

    test('sin registros, cero de las programadas', () {
      final progreso = ProgresoDelNadador(
        plan: planDeSeis(),
        registros: const [],
      );
      expect(progreso.adherenciaDelPlan.descripcion, '0 de 6');
    });

    test('también por semana, que es el microciclo del entrenador', () {
      final plan = planDe(
        [
          sesion(id: 's1', fecha: DateTime(2026, 10, 1)),
          sesion(id: 's2', fecha: DateTime(2026, 10, 3)),
          sesion(id: 's3', fecha: DateTime(2026, 10, 8), microcicloId: 'm2'),
        ],
        microciclos: const [
          Microciclo(id: 'm1', nombre: 'Semana 1', orden: 1, objetivo: 'Base'),
          Microciclo(id: 'm2', nombre: 'Semana 2', orden: 2, objetivo: 'Base'),
        ],
      );

      final progreso = ProgresoDelNadador(
        plan: plan,
        registros: [registro(sesionId: 's1', realizada: true)],
      );

      expect(progreso.adherenciaPorSemana['m1']!.descripcion, '1 de 2');
      expect(progreso.adherenciaPorSemana['m2']!.descripcion, '0 de 1');
    });

    test('un plan vacío no divide por cero', () {
      final progreso = ProgresoDelNadador(
        plan: planDe([]),
        registros: const [],
      );
      expect(progreso.adherenciaDelPlan.porcentaje, 0);
    });
  });

  group('SC-011 — la adherencia cuenta sesiones y nada más', () {
    test('el recuento no cambia al variar el RPE', () {
      final plan = planDe([
        for (var i = 1; i <= 6; i++)
          sesion(id: 's$i', fecha: DateTime(2026, 10, i)),
      ]);

      final suaves = ProgresoDelNadador(
        plan: plan,
        registros: [
          for (var i = 1; i <= 4; i++)
            registro(sesionId: 's$i', realizada: true, rpe: 3),
        ],
      );

      final duras = ProgresoDelNadador(
        plan: plan,
        registros: [
          for (var i = 1; i <= 4; i++)
            registro(sesionId: 's$i', realizada: true, rpe: 9),
        ],
      );

      expect(
        suaves.adherenciaDelPlan,
        duras.adherenciaDelPlan,
        reason:
            'El principio VIII prohíbe combinar carga externa e interna en '
            'un mismo indicador. Una adherencia que ponderara por intensidad '
            'sería exactamente ese indicador',
      );
    });

    test('el recuento no cambia al variar los metros programados', () {
      final cortas = planDe([
        for (var i = 1; i <= 6; i++)
          sesion(id: 's$i', fecha: DateTime(2026, 10, i), metros: 800),
      ]);

      final largas = planDe([
        for (var i = 1; i <= 6; i++)
          sesion(id: 's$i', fecha: DateTime(2026, 10, i), metros: 5000),
      ]);

      final registros = [
        for (var i = 1; i <= 4; i++) registro(sesionId: 's$i', realizada: true),
      ];

      expect(
        ProgresoDelNadador(
          plan: cortas,
          registros: registros,
        ).adherenciaDelPlan,
        ProgresoDelNadador(
          plan: largas,
          registros: registros,
        ).adherenciaDelPlan,
        reason:
            'Es un indicador deliberadamente aburrido. Si alguien lo '
            '«mejora» ponderando por volumen, esta prueba se entera',
      );
    });
  });

  group('SC-006 — la molestia se encuentra sin leerlo todo', () {
    test('las sesiones con molestia se listan aparte', () {
      final plan = planDe([
        for (var i = 1; i <= 5; i++)
          sesion(id: 's$i', fecha: DateTime(2026, 10, i)),
      ]);

      final progreso = ProgresoDelNadador(
        plan: plan,
        registros: [
          registro(sesionId: 's1', realizada: true),
          registro(
            sesionId: 's3',
            realizada: true,
            molestia: const ReporteDeMolestia(
              descripcion: 'Pinchazo',
              zonaDelCuerpo: 'hombro derecho',
            ),
          ),
          registro(sesionId: 's4', realizada: true),
        ],
      );

      expect(progreso.conMolestia, hasLength(1));
      expect(progreso.conMolestia.first.sesion.id, 's3');
    });
  });

  group('qué toca hoy (FR-002)', () {
    final plan = planDe([
      sesion(id: 's1', fecha: DateTime(2026, 10, 12)),
      sesion(id: 's2', fecha: DateTime(2026, 10, 14)),
      sesion(id: 's3', fecha: DateTime(2026, 10, 16)),
    ]);

    test('hay sesión hoy', () {
      final hoy = queTocaHoy(plan, DateTime(2026, 10, 14, 6, 30));
      expect(hoy, isA<SesionDeHoy>());
      expect((hoy as SesionDeHoy).sesion.id, 's2');
    });

    test('la hora no influye: el día es el día', () {
      final tarde = queTocaHoy(plan, DateTime(2026, 10, 14, 23, 50));
      expect(tarde, isA<SesionDeHoy>());
    });

    test('sin sesión hoy, dice cuál es la siguiente y cuándo', () {
      final hoy = queTocaHoy(plan, DateTime(2026, 10, 15));

      expect(hoy, isA<SinSesionHoy>());
      final sin = hoy as SinSesionHoy;
      expect(sin.siguiente.id, 's3');
      expect(sin.diasDesde(DateTime(2026, 10, 15)), 1);
    });

    test('terminado el plan, lo dice en lugar de dejar la pantalla vacía', () {
      expect(
        queTocaHoy(plan, DateTime(2026, 11, 1)),
        isA<SinSesionesPorDelante>(),
      );
    });

    test('las sesiones sin fecha no se suponen', () {
      // No se puede decir que tocan hoy ni que tocan mañana, y adivinarlo
      // sería inventar (regla R3).
      final sinFechas = planDe([
        Sesion(
          id: 'x',
          microcicloId: 'm1',
          objetivoTecnico: 'Técnica',
          objetivoFisiologico: 'Base',
          partes: const [
            Parte(tipo: TipoParte.inicial),
            Parte(tipo: TipoParte.central),
            Parte(tipo: TipoParte.cierre),
          ],
        ),
      ]);

      expect(
        queTocaHoy(sinFechas, DateTime(2026, 10, 14)),
        isA<SinSesionesPorDelante>(),
      );
    });

    test('un plan sin sesiones no rompe nada', () {
      expect(
        queTocaHoy(planDe([]), DateTime(2026, 10, 14)),
        isA<SinSesionesPorDelante>(),
      );
    });
  });
}
