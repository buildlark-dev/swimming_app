/// La lectura del entrenador: una sesión por sesión, contestada o no.
///
/// Es el cerrojo de FR-007 y de lo que la pantalla de US1 enseña. Dos cosas
/// que parecen la misma y no lo son:
///
/// - una nadadora que **no ha contestado nada** da una lectura con sus
///   sesiones y sin respuestas, y eso se dice con una frase;
/// - una lectura que **no se pudo leer** es otra cosa, y tiene su propio
///   cerrojo en `un_fallo_no_es_una_lectura_vacia_test.dart`.
///
/// Confundirlas le enseñaría al entrenador «no ha contestado» cuando lo que
/// pasó es que el servidor no respondió, y es sobre eso sobre lo que decide
/// qué programar después.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/analisis/lectura_del_nadador.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';

import 'dobles_de_analisis.dart';

void main() {
  final lunes = DateTime(2026, 11, 2);
  final miercoles = DateTime(2026, 11, 4);
  final viernes = DateTime(2026, 11, 6);

  test(
    'sin registros: una lectura con sus sesiones y ninguna respuesta',
    () async {
      final plan = mesociclo(
        id: 'plan-1',
        sesiones: [
          sesionDe(id: 's1', fecha: lunes),
          sesionDe(id: 's2', fecha: miercoles),
        ],
      );

      final lectura = await leerAlNadador(
        nadador: ana(),
        mesociclos: [plan],
        registros: RegistrosDeMentira(),
        planes: PlanesDeMentira([plan]),
        hoy: DateTime(2026, 11, 10),
      );

      expect(lectura.respuestas, hasLength(2));
      expect(lectura.respuestas.every((r) => !r.fueContestada), isTrue);
      expect(lectura.noHaContestadoNada, isTrue);
    },
  );

  test('una respuesta por sesión, contestada o no', () async {
    final plan = mesociclo(
      id: 'plan-1',
      sesiones: [
        sesionDe(id: 's1', fecha: lunes),
        sesionDe(id: 's2', fecha: miercoles),
        sesionDe(id: 's3', fecha: viernes),
      ],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(registroDe(sesionId: 's1', planId: 'plan-1', rpe: 7))
      ..sembrar(registroDe(sesionId: 's2', planId: 'plan-1', realizada: false));

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [plan],
      registros: registros,
      planes: PlanesDeMentira([plan]),
      hoy: DateTime(2026, 11, 10),
    );

    expect(lectura.respuestas, hasLength(3));
    expect(lectura.noHaContestadoNada, isFalse);

    final porSesion = {for (final r in lectura.respuestas) r.sesion.id: r};

    expect(porSesion['s1']!.registro!.rpePercibido, 7);

    // **«No la hice» no es «no contestó».** El registro existe y dice que no.
    expect(porSesion['s2']!.fueContestada, isTrue);
    expect(porSesion['s2']!.dijoQueNo, isTrue);

    // Y esta es la ausencia de un dato, no un dato.
    expect(porSesion['s3']!.fueContestada, isFalse);
    expect(porSesion['s3']!.dijoQueNo, isFalse);
  });

  test('las sesiones vienen de la más reciente a la más antigua', () async {
    final plan = mesociclo(
      id: 'plan-1',
      sesiones: [
        sesionDe(id: 's1', fecha: lunes),
        sesionDe(id: 's3', fecha: viernes),
        sesionDe(id: 's2', fecha: miercoles),
        sesionDe(id: 's-sin-fecha', fecha: null),
      ],
    );

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [plan],
      registros: RegistrosDeMentira(),
      planes: PlanesDeMentira([plan]),
      hoy: DateTime(2026, 11, 10),
    );

    expect(
      lectura.respuestas.map((r) => r.sesion.id).toList(),
      ['s3', 's2', 's1', 's-sin-fecha'],
      reason:
          'lo último que nadó es lo primero que el entrenador quiere leer, y '
          'una sesión sin fecha va al final porque no se adivina cuándo fue',
    );
  });

  test('dos mesociclos se leen juntos, cada respuesta con su sesión', () async {
    final primero = mesociclo(
      id: 'plan-1',
      orden: 0,
      sesiones: [sesionDe(id: 's1', fecha: lunes)],
    );
    final segundo = mesociclo(
      id: 'plan-2',
      orden: 1,
      sesiones: [sesionDe(id: 's9', fecha: DateTime(2026, 12, 1))],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(registroDe(sesionId: 's1', planId: 'plan-1', rpe: 5))
      ..sembrar(registroDe(sesionId: 's9', planId: 'plan-2', rpe: 9));

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [primero, segundo],
      registros: registros,
      planes: PlanesDeMentira([primero, segundo]),
      hoy: DateTime(2026, 12, 5),
    );

    expect(lectura.respuestas, hasLength(2));
    expect(lectura.mesociclos, hasLength(2));

    final porSesion = {for (final r in lectura.respuestas) r.sesion.id: r};
    expect(porSesion['s1']!.registro!.rpePercibido, 5);
    expect(porSesion['s9']!.registro!.rpePercibido, 9);
  });

  test('un registro de otro nadador no entra en su lectura', () async {
    final plan = mesociclo(
      id: 'plan-1',
      sesiones: [sesionDe(id: 's1', fecha: lunes)],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(
        // Mismo plan, misma sesión, otro nadador.
        registroDe(sesionId: 's1', planId: 'plan-1', rpe: 7),
      );

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [plan],
      registros: registros,
      planes: PlanesDeMentira([plan]),
      hoy: DateTime(2026, 11, 10),
    );

    // El doble filtra por nadadorId igual que la consulta; esto fija que la
    // lectura pide los del nadador que se le pasó y no los de la colección.
    expect(lectura.respuestas.single.registro, isNotNull);
    expect(lectura.respuestas.single.registro!.nadadorId, 'n-ana');
  });

  test('conMolestia sale de tieneMolestia y de nada más', () async {
    final plan = mesociclo(
      id: 'plan-1',
      sesiones: [
        sesionDe(id: 's1', fecha: lunes),
        sesionDe(id: 's2', fecha: miercoles),
        sesionDe(id: 's3', fecha: viernes),
      ],
    );

    final registros = RegistrosDeMentira()
      // Observaciones largas, sin molestia: no cuenta.
      ..sembrar(
        registroDe(
          sesionId: 's1',
          planId: 'plan-1',
          rpe: 9,
          observaciones: 'Me dolió hasta el alma, pero era cansancio',
        ),
      )
      // Una molestia de verdad.
      ..sembrar(
        registroDe(
          sesionId: 's2',
          planId: 'plan-1',
          molestia: const ReporteDeMolestia(
            descripcion: 'Hombro derecho al salir del viraje',
            zonaDelCuerpo: 'Hombro derecho',
          ),
        ),
      )
      // Un reporte vacío **no es un reporte**: `tieneMolestia` lo descarta
      // desde la feature 003, y aquí se confía en eso en lugar de repetirlo.
      ..sembrar(
        registroDe(
          sesionId: 's3',
          planId: 'plan-1',
          molestia: const ReporteDeMolestia(descripcion: '   '),
        ),
      );

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [plan],
      registros: registros,
      planes: PlanesDeMentira([plan]),
      hoy: DateTime(2026, 11, 10),
    );

    expect(
      lectura.conMolestia.map((r) => r.sesion.id).toList(),
      ['s2'],
      reason:
          'una observación que menciona dolor no es un reporte de molestia, y '
          'un reporte vacío tampoco: por eso el campo existe aparte',
    );
  });
}
