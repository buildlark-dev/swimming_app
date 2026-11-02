import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/entidades/ciclo_vida_plan.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

import 'ayuda_planes.dart';

/// Regla de aprobación (FR-022, FR-023) y ciclo de vida del plan
/// (FR-024 a FR-026).
void main() {
  late ConstructorPlanes constructor;
  late Auditoria auditoria;
  late CicloVidaPlan ciclo;

  setUpAll(() {
    constructor = ConstructorPlanes();
  });

  setUp(() {
    auditoria = Auditoria();
    ciclo = CicloVidaPlan(
      auditoria: auditoria,
      versionMetodologia: '3.4',
      ahora: () => DateTime(2026, 9, 25),
    );
  });

  Justificacion justificar(String criterioId) => Justificacion(
    criterioId: criterioId,
    texto: 'Descenso deliberado por afinación previa a competencia',
    fecha: DateTime(2026, 9, 25),
  );

  group('un plan limpio', () {
    test('se puede aprobar', () {
      final plan = constructor.planAcumulacionCorrecto();

      expect(
        auditoria.puedeAprobarse(plan),
        isTrue,
        reason: auditoria
            .impedimentosPara(plan)
            .map((i) => i.toString())
            .join('\n'),
      );
    });

    test('al aprobar estampa la versión de metodología y la fecha', () {
      final plan = constructor.planAcumulacionCorrecto();
      final resultado = ciclo.aprobar(plan);

      expect(resultado, isA<TransicionHecha>());
      final aprobado = (resultado as TransicionHecha).plan;

      expect(aprobado.estado, EstadoPlan.aprobado);
      expect(aprobado.versionMetodologia, '3.4');
      expect(aprobado.fechaAprobacion, DateTime(2026, 9, 25));
    });
  });

  group('criterios bloqueantes', () {
    test('un ejercicio ajeno a la Biblioteca impide aprobar', () {
      final sesion = constructor.sesionDeTexto(
        '2000 EJERCICIO INVENTADO',
        zona: Zona.a1,
      );
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
      );

      expect(auditoria.puedeAprobarse(plan), isFalse);
    });

    test('ni siquiera con justificación escrita', () {
      final sesion = constructor.sesionDeTexto(
        '2000 EJERCICIO INVENTADO',
        zona: Zona.a1,
      );
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
        justificaciones: [justificar('C01_biblioteca')],
      );

      expect(
        auditoria.puedeAprobarse(plan),
        isFalse,
        reason: 'La regla R2 no admite excepción',
      );
    });

    test('el impedimento nombra el criterio y trae la observación', () {
      final sesion = constructor.sesionDeTexto(
        '2000 EJERCICIO INVENTADO',
        zona: Zona.a1,
      );
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
      );

      final impedimentos = auditoria.impedimentosPara(plan);
      expect(impedimentos, isNotEmpty);
      expect(impedimentos.first.motivo, contains('no negociable'));
    });
  });

  group('criterios justificables', () {
    test('sin justificación no se puede aprobar', () {
      final sesion = constructor.sesionConZonas(const {Zona.a1: 1400});
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
      );

      final impedimentos = auditoria.impedimentosPara(plan);
      expect(impedimentos, isNotEmpty);
      expect(
        impedimentos.any((i) => i.motivo.contains('Falta justificación')),
        isTrue,
      );
    });

    test('una justificación vacía no habilita la aprobación', () {
      final sesion = constructor.sesionConZonas(const {Zona.a1: 1400});
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
        justificaciones: [
          Justificacion(
            criterioId: 'C05_volumen_categoria',
            texto: '   ',
            fecha: DateTime(2026, 9, 25),
          ),
        ],
      );

      expect(auditoria.puedeAprobarse(plan), isFalse);
    });

    test('con todas las justificaciones escritas sí se aprueba', () {
      final sesion = constructor.sesionConZonas(const {Zona.a1: 1400});
      var plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
      );

      // Se justifican todos los criterios justificables que quedaron en rojo.
      final enRojo = auditoria.evaluar(plan).justificablesEnRojo;
      plan = plan.copiarCon(
        justificaciones: enRojo.map((c) => justificar(c.id)).toList(),
      );

      expect(
        auditoria.puedeAprobarse(plan),
        isTrue,
        reason: auditoria
            .impedimentosPara(plan)
            .map((i) => i.toString())
            .join('\n'),
      );
    });
  });

  group('sesiones incompletas', () {
    test('impiden aprobar aunque la auditoría esté en verde', () {
      final sesion = constructor.sesionConZonas(const {
        Zona.a1: 1200,
        Zona.a2: 500,
        Zona.a3: 200,
        Zona.at: 100,
      }, completa: false);
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
      );

      final impedimentos = auditoria.impedimentosPara(plan);
      expect(impedimentos.any((i) => i.motivo.contains('incompletas')), isTrue);
    });
  });

  group('inmutabilidad del plan aprobado', () {
    test('un plan aprobado no se puede volver a aprobar', () {
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        estado: EstadoPlan.aprobado,
      );

      expect(auditoria.puedeAprobarse(plan), isFalse);
    });

    test('el estado aprobado es inmutable', () {
      expect(EstadoPlan.aprobado.esInmutable, isTrue);
      expect(EstadoPlan.publicado.esInmutable, isTrue);
      expect(EstadoPlan.borrador.esInmutable, isFalse);
    });
  });

  group('publicación', () {
    test('solo se publica lo aprobado', () {
      final borrador = constructor.planAcumulacionCorrecto();
      final resultado = ciclo.publicar(borrador);

      expect(resultado, isA<TransicionRechazada>());
    });

    test('un plan aprobado se publica', () {
      final plan = constructor.planAcumulacionCorrecto();
      final aprobado = (ciclo.aprobar(plan) as TransicionHecha).plan;
      final publicado = ciclo.publicar(aprobado);

      expect(publicado, isA<TransicionHecha>());
      expect((publicado as TransicionHecha).plan.estado, EstadoPlan.publicado);
    });
  });

  group('versionado (FR-025)', () {
    test('editar un plan aprobado crea una versión nueva en borrador', () {
      final plan = constructor.planAcumulacionCorrecto();
      final aprobado = (ciclo.aprobar(plan) as TransicionHecha).plan;

      final nueva = ciclo.crearVersionDesde(aprobado);

      expect(nueva.estado, EstadoPlan.borrador);
      expect(nueva.versionAnteriorId, aprobado.id);
    });

    test('el plan aprobado queda intacto', () {
      final plan = constructor.planAcumulacionCorrecto();
      final aprobado = (ciclo.aprobar(plan) as TransicionHecha).plan;

      ciclo.crearVersionDesde(aprobado);

      expect(aprobado.estado, EstadoPlan.aprobado);
      expect(aprobado.versionMetodologia, '3.4');
    });

    test('la versión nueva no hereda el sello de aprobación', () {
      final plan = constructor.planAcumulacionCorrecto();
      final aprobado = (ciclo.aprobar(plan) as TransicionHecha).plan;
      final nueva = ciclo.crearVersionDesde(aprobado);

      expect(nueva.versionMetodologia, isNull);
      expect(nueva.fechaAprobacion, isNull);
    });

    test('la versión nueva conserva el contenido del plan', () {
      final plan = constructor.planAcumulacionCorrecto();
      final aprobado = (ciclo.aprobar(plan) as TransicionHecha).plan;
      final nueva = ciclo.crearVersionDesde(aprobado);

      expect(nueva.sesiones.length, aprobado.sesiones.length);
      expect(nueva.microciclos.length, aprobado.microciclos.length);
      expect(nueva.metros, aprobado.metros);
    });
  });

  group('la tabla de auditoría siempre está disponible', () {
    test('se puede consultar en cualquier momento, no solo al aprobar', () {
      final plan = constructor.planAcumulacionCorrecto();
      final resultado = auditoria.evaluar(plan);

      expect(resultado.criterios, hasLength(11));
      for (final criterio in resultado.criterios) {
        expect(
          criterio.observacion,
          isNotEmpty,
          reason: '${criterio.id} no explica su veredicto',
        );
      }
    });
  });
}
