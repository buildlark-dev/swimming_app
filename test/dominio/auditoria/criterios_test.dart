import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/auditoria/criterio.dart';
import 'package:natacion_app/dominio/auditoria/criterios.dart';
import 'package:natacion_app/dominio/auditoria/tolerancia.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

import 'ayuda_planes.dart';

/// Cada criterio con dos pruebas: un plan que lo viola y otro que lo cumple.
///
/// Un criterio que nunca falla en las pruebas no está implementado
/// (principio III de la constitución).
void main() {
  late ConstructorPlanes constructor;

  setUpAll(() {
    constructor = ConstructorPlanes();
  });

  group('C01 biblioteca (bloqueante)', () {
    test('es bloqueante', () {
      expect(const CriterioBiblioteca().severidad, Severidad.bloqueante);
    });

    test('falla con un ejercicio ajeno a la Biblioteca', () {
      final sesion = constructor.sesionDeTexto(
        '2000 AL EJERCICIO INVENTADO',
        zona: Zona.a1,
      );
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      final veredicto = const CriterioBiblioteca().evaluar(plan);

      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('ajenas a la Biblioteca'));
      expect(veredicto.bloqueaAprobacion, isTrue);
    });

    test('falla con un ejercicio ambiguo sin estilo', () {
      final sesion = constructor.sesionDeTexto('2000 FLECHA', zona: Zona.a1);
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      expect(const CriterioBiblioteca().evaluar(plan).cumple, isFalse);
    });

    test('cumple con ejercicios reales de la Biblioteca', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioBiblioteca().evaluar(plan).cumple, isTrue);
    });
  });

  group('C07 nomenclatura (bloqueante)', () {
    test('es bloqueante', () {
      expect(const CriterioNomenclatura().severidad, Severidad.bloqueante);
    });

    test('falla con una forma de nado prohibida', () {
      final sesion = constructor.sesionDeTexto(
        '2000 Libre técnico',
        zona: Zona.a1,
      );
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      final veredicto = const CriterioNomenclatura().evaluar(plan);
      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('no admitidas'));
    });

    test('cumple con nomenclatura correcta', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioNomenclatura().evaluar(plan).cumple, isTrue);
    });
  });

  group('C08 zonas (bloqueante)', () {
    test('es bloqueante', () {
      expect(const CriterioZonas().severidad, Severidad.bloqueante);
    });

    test('falla si hay series sin zona asignada', () {
      final sesion = constructor.sesionDeTexto('2000 N');
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      final veredicto = const CriterioZonas().evaluar(plan);
      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('sin zona asignada'));
      expect(veredicto.observacion, contains('2000 m'));
    });

    test('falla si el plan no tiene series', () {
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: const [],
      );

      expect(const CriterioZonas().evaluar(plan).cumple, isFalse);
    });

    test('cumple cuando todas las series tienen zona', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioZonas().evaluar(plan).cumple, isTrue);
    });
  });

  group('C11 sin ambiguos (bloqueante)', () {
    test('es bloqueante', () {
      expect(const CriterioSinAmbiguos().severidad, Severidad.bloqueante);
    });

    test('falla con fragmentos sin interpretar', () {
      final sesion = constructor.sesionDeTexto('2000 ¿¿¿???', zona: Zona.a1);
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      expect(const CriterioSinAmbiguos().evaluar(plan).cumple, isFalse);
    });

    test('falla con sesiones incompletas', () {
      final sesion = constructor.sesionDeTexto(
        '2000 N',
        zona: Zona.a1,
        completa: false,
      );
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      expect(const CriterioSinAmbiguos().evaluar(plan).cumple, isFalse);
    });

    test('cumple con un plan limpio', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioSinAmbiguos().evaluar(plan).cumple, isTrue);
    });
  });

  group('C03 intensidades de fase (justificable)', () {
    test('es justificable', () {
      expect(
        const CriterioIntensidadesFase().severidad,
        Severidad.justificable,
      );
    });

    test('falla con todo el volumen en Z1, fuera del modelo piramidal', () {
      final plan = constructor.planConIntensidadesDesviadas();
      final veredicto = const CriterioIntensidadesFase().evaluar(plan);

      expect(veredicto.cumple, isFalse);
      expect(
        veredicto.observacion,
        contains('Z1'),
        reason: 'Se audita en las tres zonas con las que mide la literatura',
      );
      expect(
        veredicto.observacion,
        contains('Z3'),
        reason: 'El modelo piramidal pide del 6 al 10% de Z3',
      );
    });

    test('la observación cita la fuente del envolvente', () {
      final plan = constructor.planConIntensidadesDesviadas();
      final veredicto = const CriterioIntensidadesFase().evaluar(plan);

      expect(
        veredicto.observacion,
        contains('Filipas'),
        reason:
            'El entrenador tiene derecho a saber qué respalda lo que la '
            'app le exige: un rango citado, no un número elegido a mano',
      );
    });

    test('cumple cuando cae en el envolvente publicado', () {
      final plan = constructor.planAcumulacionCorrecto();
      final veredicto = const CriterioIntensidadesFase().evaluar(plan);

      expect(veredicto.cumple, isTrue, reason: veredicto.observacion);
      expect(veredicto.observacion, contains('Piramidal'));
    });

    test('no se puede evaluar si quedan metros sin zona', () {
      final sesion = constructor.sesionDeTexto('2000 N');
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      final veredicto = const CriterioIntensidadesFase().evaluar(plan);
      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('no es fiable'));
    });

    test('una categoría sin ATR cumple por no aplicar', () {
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        categoria: Categoria.iniciacion,
      );
      final sinFase = Plan(
        nombre: plan.nombre,
        categoria: Categoria.iniciacion,
        estiloObjetivo: plan.estiloObjetivo,
        sesiones: plan.sesiones,
        microciclos: plan.microciclos,
      );

      final veredicto = const CriterioIntensidadesFase().evaluar(sinFase);
      expect(veredicto.cumple, isTrue);
      expect(veredicto.observacion, contains('no usa el modelo ATR'));
    });
  });

  group('C02 y C04 trabajo técnico (justificables)', () {
    test('C04 falla con 32% técnico donde se prescribe 50%', () {
      final plan = constructor.planConPocaTecnica();
      final veredicto = const CriterioTecnicaFase().evaluar(plan);

      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('prescrito'));
      expect(veredicto.observacion, contains('puntos'));
    });

    test('C04 cumple con el porcentaje prescrito', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioTecnicaFase().evaluar(plan).cumple, isTrue);
    });

    test('C02 falla si no hay ningún trabajo técnico', () {
      final sesion = constructor.sesionConZonas(const {
        Zona.a1: 2000,
      }, metrosTecnicosPorZona: const {});
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      final veredicto = const CriterioTecnicaPrioritaria().evaluar(plan);
      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('toda la temporada'));
    });

    test('C02 cumple si hay más técnica de la prescrita', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioTecnicaPrioritaria().evaluar(plan).cumple, isTrue);
    });
  });

  group('C05 volumen por categoría (justificable)', () {
    test('es justificable, para admitir la afinación', () {
      expect(
        const CriterioVolumenCategoria().severidad,
        Severidad.justificable,
      );
    });

    test('falla con una sesión por debajo del rango', () {
      final sesion = constructor.sesionConZonas(const {Zona.a1: 1400});
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
      );

      final veredicto = const CriterioVolumenCategoria().evaluar(plan);
      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('1400 m'));
      expect(veredicto.observacion, contains('-400 m'));
    });

    test('falla si la frecuencia semanal no es la de la categoría', () {
      final sesion = constructor.sesionConZonas(const {Zona.a1: 2000});
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion],
      );

      final veredicto = const CriterioVolumenCategoria().evaluar(plan);
      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('frecuencia semanal'));
    });

    test('cumple con volumen y frecuencia correctos', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioVolumenCategoria().evaluar(plan).cumple, isTrue);
    });
  });

  group('C06 transferencia (justificable)', () {
    test('falla con un reparto de estilos muy alejado', () {
      final sesion = constructor.sesionConZonas(const {
        Zona.a1: 1200,
        Zona.a2: 800,
      }, estilo: Estilo.espalda);
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        sesiones: [sesion, sesion, sesion],
      );

      final veredicto = const CriterioTransferencia().evaluar(plan);
      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('Libre'));
    });

    test('cumple con el estilo objetivo dominante', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioTransferencia().evaluar(plan).cumple, isTrue);
    });
  });

  group('C09 modelamiento (justificable)', () {
    test('falla si el microciclo se nombra solo por su posición', () {
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        microciclos: const [
          Microciclo(
            id: 'm1',
            nombre: 'Acumulación 1',
            orden: 1,
            objetivo: 'Base',
          ),
        ],
      );

      final veredicto = const CriterioModelamiento().evaluar(plan);
      expect(veredicto.cumple, isFalse);
      expect(veredicto.observacion, contains('componente acentuado'));
    });

    test('falla si el plan no tiene microciclos', () {
      final plan = constructor.planAcumulacionCorrecto().copiarCon(
        microciclos: const [],
      );

      expect(const CriterioModelamiento().evaluar(plan).cumple, isFalse);
    });

    test('cumple con un nombre que describe el objetivo real', () {
      final plan = constructor.planAcumulacionCorrecto();
      expect(const CriterioModelamiento().evaluar(plan).cumple, isTrue);
    });
  });

  group('C10 drills y diagnóstico (justificable)', () {
    test('sin diagnóstico registrado, no se culpa al plan', () {
      final plan = constructor.planAcumulacionCorrecto();
      final veredicto = const CriterioDrillsDiagnostico().evaluar(plan);

      expect(veredicto.cumple, isTrue);
      expect(veredicto.observacion, contains('No hay diagnóstico'));
    });

    test('falla si ningún ejercicio ataca los errores diagnosticados', () {
      final plan = constructor.planAcumulacionCorrecto();
      const criterio = CriterioDrillsDiagnostico(
        diagnostico: ['patada de tijera en pecho'],
      );

      expect(criterio.evaluar(plan).cumple, isFalse);
    });

    test('cumple si algún ejercicio ataca un error diagnosticado', () {
      final plan = constructor.planAcumulacionCorrecto();
      // VADEO corrige "Falta de sensibilidad y agarre del agua".
      const criterio = CriterioDrillsDiagnostico(
        diagnostico: ['agarre del agua'],
      );

      expect(criterio.evaluar(plan).cumple, isTrue);
    });
  });

  group('tolerancia', () {
    test('admite desviaciones dentro de ±3 puntos', () {
      expect(Tolerancia.predeterminada.admite(2.9), isTrue);
      expect(Tolerancia.predeterminada.admite(-2.9), isTrue);
      expect(Tolerancia.predeterminada.admite(3.0), isTrue);
    });

    test('no admite justo fuera del margen', () {
      expect(Tolerancia.predeterminada.admite(3.1), isFalse);
      expect(Tolerancia.predeterminada.admite(-3.1), isFalse);
    });

    test(
      'una tolerancia más estricta rechaza lo que la predeterminada admite',
      () {
        const estricta = Tolerancia(1);
        expect(estricta.admite(2.0), isFalse);
        expect(Tolerancia.predeterminada.admite(2.0), isTrue);
      },
    );
  });

  group('la auditoría completa', () {
    test('devuelve siempre los once criterios', () {
      final plan = constructor.planAcumulacionCorrecto();
      final resultado = Auditoria().evaluar(plan);

      expect(resultado.criterios, hasLength(11));
    });

    test('cada criterio tiene identificador único', () {
      final plan = constructor.planAcumulacionCorrecto();
      final ids = Auditoria().evaluar(plan).criterios.map((c) => c.id).toSet();

      expect(ids, hasLength(11));
    });

    test('cuatro criterios son bloqueantes y siete justificables', () {
      final plan = constructor.planAcumulacionCorrecto();
      final criterios = Auditoria().evaluar(plan).criterios;

      expect(
        criterios.where((c) => c.severidad == Severidad.bloqueante).length,
        4,
      );
      expect(
        criterios.where((c) => c.severidad == Severidad.justificable).length,
        7,
      );
    });

    test('un plan correcto pasa los once', () {
      final plan = constructor.planAcumulacionCorrecto();
      final resultado = Auditoria().evaluar(plan);

      expect(
        resultado.todoEnVerde,
        isTrue,
        reason:
            'En rojo: '
            '${resultado.enRojo.map((c) => c.toString()).join('\n')}',
      );
    });
  });
}
