/// D7 — dónde está el nadador dentro del macrociclo.
///
/// **Se calcula al leer y no se guarda en ninguna parte.** Una copia guardada
/// sería una segunda cosa que puede discrepar de la primera, y la primera es
/// la que el nadador escribió. `ProgresoDelNadador` ya hace esto para un plan;
/// extenderlo un nivel hacia arriba es aritmética.
///
/// Escrito antes de `lib/dominio/macrociclo/progreso_en_el_macrociclo.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/progreso_en_el_macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

void main() {
  final hoy = DateTime(2026, 11, 18);

  Sesion sesion(String id, DateTime? fecha) =>
      Sesion(id: id, microcicloId: 'mc-1', fecha: fecha);

  RegistroDeSesion registro(
    String sesionId, {
    bool realizada = true,
    String planId = 'meso-1',
  }) => RegistroDeSesion(
    nadadorId: 'n-ana',
    planId: planId,
    sesionId: sesionId,
    versionDePlan: '3.6.0',
    realizada: realizada,
    registradoEn: hoy,
  );

  /// Tres mesociclos de dos semanas: uno pasado, uno en curso, uno futuro.
  List<Plan> mesociclos() => [
    Plan(
      id: 'meso-1',
      nombre: 'Mesociclo 1: Acumulación',
      categoria: Categoria.precompetitivo,
      estiloObjetivo: Estilo.libre,
      faseAtr: FaseAtr.acumulacion,
      fechaInicio: DateTime(2026, 11, 2),
      fechaFin: DateTime(2026, 11, 15),
      ordenEnElMacrociclo: 0,
      macrocicloId: 'macro-1',
      sesiones: [
        sesion('s1', DateTime(2026, 11, 2)),
        sesion('s2', DateTime(2026, 11, 4)),
        sesion('s3', DateTime(2026, 11, 6)),
      ],
    ),
    Plan(
      id: 'meso-2',
      nombre: 'Mesociclo 2: Transformación',
      categoria: Categoria.precompetitivo,
      estiloObjetivo: Estilo.libre,
      faseAtr: FaseAtr.transformacion,
      fechaInicio: DateTime(2026, 11, 16),
      fechaFin: DateTime(2026, 11, 29),
      ordenEnElMacrociclo: 1,
      macrocicloId: 'macro-1',
      sesiones: [
        sesion('s4', DateTime(2026, 11, 16)),
        sesion('s5', DateTime(2026, 11, 18)),
        sesion('s6', DateTime(2026, 11, 20)),
      ],
    ),
    Plan(
      id: 'meso-3',
      nombre: 'Mesociclo 3: Realización',
      categoria: Categoria.precompetitivo,
      estiloObjetivo: Estilo.libre,
      faseAtr: FaseAtr.realizacion,
      fechaInicio: DateTime(2026, 11, 30),
      fechaFin: DateTime(2026, 12, 13),
      ordenEnElMacrociclo: 2,
      macrocicloId: 'macro-1',
      sesiones: [
        sesion('s7', DateTime(2026, 11, 30)),
        sesion('s8', DateTime(2026, 12, 2)),
      ],
    ),
  ];

  ProgresoEnElMacrociclo progreso({
    List<RegistroDeSesion> registros = const [],
    List<Plan>? cuales,
    DateTime? cuando,
  }) => ProgresoEnElMacrociclo(
    mesociclos: cuales ?? mesociclos(),
    registros: registros,
    hoy: cuando ?? hoy,
  );

  group('dónde está hoy', () {
    test('el mesociclo actual es el que contiene hoy', () {
      expect(progreso().mesocicloActual?.id, 'meso-2');
    });

    test('la posición se lee como «2 de 3»', () {
      // Para que el nadador sepa dónde está sin contar tarjetas.
      expect(progreso().comoSeLee, '2 de 3');
    });

    test('antes de empezar, el actual es nulo y no el primero', () {
      // Suponer que ya empezó haría que la vista se abriera en una semana que
      // todavía no llegó.
      final antes = progreso(cuando: DateTime(2026, 10, 20));
      expect(antes.mesocicloActual, isNull);
      expect(antes.yaEmpezo, isFalse);
    });

    test('después de la última sesión, el actual es nulo y ya terminó', () {
      // El caso límite de la spec: se le dice que el ciclo acabó y que el
      // siguiente lo prepara su entrenador, en lugar de dejarle una pantalla
      // en blanco.
      final despues = progreso(cuando: DateTime(2026, 12, 20));
      expect(despues.mesocicloActual, isNull);
      expect(despues.yaTermino, isTrue);
    });

    test('un hueco entre mesociclos no inventa un actual', () {
      final conHueco = progreso(
        cuando: DateTime(2026, 11, 17),
        cuales: [mesociclos().first, mesociclos().last],
      );
      expect(conHueco.mesocicloActual, isNull);
      expect(conHueco.yaTermino, isFalse);
    });
  });

  group('lo hecho y lo pendiente', () {
    test('hechas son las que tienen registro marcado como realizada', () {
      final p = progreso(
        registros: [registro('s1'), registro('s2', realizada: false)],
      );

      expect(p.hechas, {'s1'});
    });

    test('pendientes son las pasadas sin marcar, en orden de fecha', () {
      // s1, s2, s3 y s4 ya pasaron. Con s1 hecha, quedan tres.
      final p = progreso(registros: [registro('s1')]);

      expect(p.pendientes.map((s) => s.id), ['s2', 's3', 's4']);
    });

    test('una sesión respondida con «no la hice» sigue pendiente', () {
      // El nadador dijo lo que pasó. Lo que pasó es que no la hizo, y eso es
      // justo lo que el reajuste necesita leer.
      final p = progreso(registros: [registro('s2', realizada: false)]);

      expect(p.pendientes.map((s) => s.id), contains('s2'));
    });

    test('la de hoy no cuenta como pendiente: el día no ha acabado', () {
      final p = progreso();
      expect(p.pendientes.map((s) => s.id), isNot(contains('s5')));
    });

    test('las futuras no cuentan como pendientes', () {
      final p = progreso();
      expect(p.pendientes.map((s) => s.id), isNot(contains('s6')));
      expect(p.pendientes.map((s) => s.id), isNot(contains('s7')));
    });

    test('la próxima es la primera de hoy en adelante sin marcar', () {
      expect(progreso().proxima?.id, 's5');
    });

    test('si la de hoy ya está hecha, la próxima es la siguiente', () {
      expect(progreso(registros: [registro('s5')]).proxima?.id, 's6');
    });

    test('al terminar el macrociclo no hay próxima', () {
      expect(progreso(cuando: DateTime(2026, 12, 20)).proxima, isNull);
    });

    test('una sesión sin fecha no es pendiente ni próxima', () {
      // No se adivina cuándo se iba a hacer. Aparece en su mesociclo y nada
      // más.
      final conSinFecha = [
        mesociclos().first.copiarCon(
          sesiones: [sesion('s1', DateTime(2026, 11, 2)), sesion('sx', null)],
        ),
        ...mesociclos().skip(1),
      ];
      final p = progreso(cuales: conSinFecha);

      expect(p.pendientes.map((s) => s.id), isNot(contains('sx')));
      expect(p.proxima?.id, isNot('sx'));
    });
  });

  group('la adherencia del macrociclo', () {
    test('cuenta sesiones y nada más', () {
      // Principio VIII: no se pondera por metros ni por RPE. Un indicador
      // deliberadamente aburrido, como el de la feature 003.
      final p = progreso(registros: [registro('s1'), registro('s4')]);

      expect(p.adherencia.realizadas, 2);
      expect(p.adherencia.programadas, 8);
      expect(p.adherencia.descripcion, '2 de 8');
    });

    test('por mesociclo, para que se vea dónde se cayó', () {
      final p = progreso(registros: [registro('s1'), registro('s2')]);

      expect(p.adherenciaPorMesociclo['meso-1']?.descripcion, '2 de 3');
      expect(p.adherenciaPorMesociclo['meso-2']?.descripcion, '0 de 3');
    });
  });

  group('no escribe nada', () {
    test('calcularlo dos veces da lo mismo y no muta sus entradas', () {
      // La garantía de D7 en lo que una prueba puede alcanzar: ni toca los
      // planes ni los registros que recibe.
      final planes = mesociclos();
      final registros = [registro('s1')];

      final primero = ProgresoEnElMacrociclo(
        mesociclos: planes,
        registros: registros,
        hoy: hoy,
      );
      final segundo = ProgresoEnElMacrociclo(
        mesociclos: planes,
        registros: registros,
        hoy: hoy,
      );

      expect(primero.hechas, segundo.hechas);
      expect(primero.pendientes.map((s) => s.id), segundo.pendientes.map((s) => s.id));
      expect(planes.first.sesiones, hasLength(3));
      expect(registros, hasLength(1));
    });

    test('las listas que devuelve no se pueden modificar por fuera', () {
      // Si fueran la lista interna, quien las recibiera podría cambiar el
      // progreso del nadador desde una pantalla.
      final p = progreso();
      expect(() => p.pendientes.add(sesion('sz', hoy)), throwsUnsupportedError);
    });
  });

  group('la hora del día no mueve nada', () {
    test('a las 23, la sesión de hoy sigue siendo la próxima', () {
      // Si se comparara por instantes, a las 23:00 la sesión de hoy —fechada
      // a las 00:00— quedaría «en el pasado»: pasaría a pendiente y la próxima
      // saltaría a la del jueves. El nadador vería el plan cambiar según la
      // hora a la que abriera la app.
      //
      // **Las afirmaciones son absolutas y no comparativas.** La primera
      // versión de esta prueba comparaba el progreso de las 7 con el de las 23
      // y no vigilaba nada: sin comparar por fecha, los dos se desplazan igual
      // y salen idénticos. El control negativo de T045 lo destapó.
      final noche = progreso(cuando: DateTime(2026, 11, 18, 23));

      expect(noche.proxima?.id, 's5');
      expect(noche.pendientes.map((s) => s.id), isNot(contains('s5')));
      expect(noche.mesocicloActual?.id, 'meso-2');
    });

    test('y a las 7 de la mañana, lo mismo', () {
      final manana = progreso(cuando: DateTime(2026, 11, 18, 7));

      expect(manana.proxima?.id, 's5');
      expect(manana.pendientes.map((s) => s.id), isNot(contains('s5')));
      expect(manana.mesocicloActual?.id, 'meso-2');
    });

    test('el último día del mesociclo todavía es ese mesociclo', () {
      // 29 de noviembre a las 20:00: `fechaFin` es el 29 a las 00:00. Con
      // instantes, el mesociclo ya habría terminado esa tarde.
      expect(
        progreso(cuando: DateTime(2026, 11, 29, 20)).mesocicloActual?.id,
        'meso-2',
      );
    });
  });
}
