/// Lo que el nadador contestó antes de un reajuste **sigue siendo suyo**, y el
/// entrenador también lo lee.
///
/// Un reajuste crea una versión nueva del mesociclo: plan nuevo, identificador
/// nuevo. Los registros apuntan al plan donde se escribieron, así que un lector
/// que solo mire el plan actual encuentra cero, pinta la pantalla y enseña las
/// sesiones sin marcar. No falla nada. Eso es el defecto `b7a5120` de la
/// feature 009, encontrado en el Pixel 7 y no por una prueba.
///
/// Control negativo (T009): cambiar `registrosDelLinaje` por un
/// `obtenerDePlan` sobre los planes actuales y ver esta prueba en rojo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/analisis/lectura_del_nadador.dart';

import 'dobles_de_analisis.dart';

void main() {
  final lunes = DateTime(2026, 11, 2);
  final miercoles = DateTime(2026, 11, 4);

  test('una respuesta escrita en la versión anterior se encuentra', () async {
    final vieja = mesociclo(
      id: 'plan-v1',
      sesiones: [
        sesionDe(id: 's1', fecha: lunes),
        sesionDe(id: 's2', fecha: miercoles),
      ],
    );

    // La nueva, tras el reajuste. **Conserva los identificadores de sesión**:
    // sin eso, leer el linaje traería los registros y no habría forma de
    // emparejarlos con las sesiones que el entrenador tiene delante.
    final nueva = mesociclo(
      id: 'plan-v2',
      versionAnteriorId: 'plan-v1',
      sesiones: [
        sesionDe(id: 's1', fecha: lunes),
        sesionDe(id: 's2', fecha: miercoles),
      ],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(
        registroDe(
          sesionId: 's1',
          planId: 'plan-v1',
          rpe: 8,
          observaciones: 'Me costó el último 200',
        ),
      );

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [nueva],
      registros: registros,
      planes: PlanesDeMentira([vieja, nueva]),
      hoy: DateTime(2026, 11, 10),
    );

    final porSesion = {for (final r in lectura.respuestas) r.sesion.id: r};

    expect(
      porSesion['s1']!.registro,
      isNotNull,
      reason:
          'la respuesta se escribió en plan-v1 y la nadadora está en plan-v2: '
          'si esto es nulo, la lectura no recorrió el linaje',
    );
    expect(porSesion['s1']!.registro!.rpePercibido, 8);
    expect(porSesion['s1']!.registro!.observaciones, 'Me costó el último 200');

    // Y se intentó de verdad: se preguntó por las dos versiones.
    expect(registros.pedidos, containsAll(<String>['plan-v2', 'plan-v1']));
  });

  test('lo contestado en la versión nueva manda sobre lo viejo', () async {
    final vieja = mesociclo(
      id: 'plan-v1',
      sesiones: [sesionDe(id: 's1', fecha: lunes)],
    );
    final nueva = mesociclo(
      id: 'plan-v2',
      versionAnteriorId: 'plan-v1',
      sesiones: [sesionDe(id: 's1', fecha: lunes)],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(registroDe(sesionId: 's1', planId: 'plan-v1', rpe: 3))
      ..sembrar(registroDe(sesionId: 's1', planId: 'plan-v2', rpe: 9));

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [nueva],
      registros: registros,
      planes: PlanesDeMentira([vieja, nueva]),
      hoy: DateTime(2026, 11, 10),
    );

    expect(
      lectura.respuestas.single.registro!.rpePercibido,
      9,
      reason: 'su última palabra es la de la versión más nueva',
    );
  });

  test('la adherencia cuenta lo contestado antes del reajuste', () async {
    final vieja = mesociclo(
      id: 'plan-v1',
      sesiones: [
        sesionDe(id: 's1', fecha: lunes),
        sesionDe(id: 's2', fecha: miercoles),
      ],
    );
    final nueva = mesociclo(
      id: 'plan-v2',
      versionAnteriorId: 'plan-v1',
      sesiones: [
        sesionDe(id: 's1', fecha: lunes),
        sesionDe(id: 's2', fecha: miercoles),
      ],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(registroDe(sesionId: 's1', planId: 'plan-v1'))
      ..sembrar(registroDe(sesionId: 's2', planId: 'plan-v1'));

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [nueva],
      registros: registros,
      planes: PlanesDeMentira([vieja, nueva]),
      hoy: DateTime(2026, 11, 10),
    );

    expect(
      lectura.progreso.adherencia.descripcion,
      '2 de 2',
      reason:
          'si el linaje no se leyera, el reajuste le dejaría al entrenador un '
          '0 de 2 sobre una nadadora que entrenó las dos',
    );
  });
}
