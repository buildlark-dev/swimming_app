/// Un fallo al leer **no es una lectura vacía**, y la diferencia importa.
///
/// «No ha contestado nada» y «no se pudo leer lo que contestó» le dicen cosas
/// opuestas a un entrenador que está decidiendo qué programar la semana que
/// viene. Lo primero es un dato; lo segundo es la ausencia de uno.
///
/// Es el defecto que la feature 009 entregó dos veces: un `catch` que devuelve
/// `const []` y una pantalla que se pinta perfecta y miente. Así que aquí el
/// fallo **sube**, y la pantalla de US1 lo dice con palabras (FR-008).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/analisis/lectura_del_nadador.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

import 'dobles_de_analisis.dart';

void main() {
  test('si no se pueden leer los registros, el fallo sube', () async {
    final plan = mesociclo(
      id: 'plan-1',
      sesiones: [sesionDe(id: 's1', fecha: DateTime(2026, 11, 2))],
    );

    await expectLater(
      leerAlNadador(
        nadador: ana(),
        mesociclos: [plan],
        registros: const RegistrosQueFallan(
          'No se pudieron leer los registros: permiso denegado',
        ),
        planes: PlanesDeMentira([plan]),
        hoy: DateTime(2026, 11, 10),
      ),
      throwsA(isA<FalloDeDatos>()),
    );
  });

  test('el fallo no se convierte en una lectura sin respuestas', () async {
    final plan = mesociclo(
      id: 'plan-1',
      sesiones: [
        sesionDe(id: 's1', fecha: DateTime(2026, 11, 2)),
        sesionDe(id: 's2', fecha: DateTime(2026, 11, 4)),
      ],
    );

    LecturaDelNadador? devuelta;
    Object? subio;

    try {
      devuelta = await leerAlNadador(
        nadador: ana(),
        mesociclos: [plan],
        registros: const RegistrosQueFallan(),
        planes: PlanesDeMentira([plan]),
        hoy: DateTime(2026, 11, 10),
      );
    } catch (error) {
      subio = error;
    }

    expect(
      devuelta,
      isNull,
      reason:
          'devolver una lectura con las sesiones y sin respuestas haría que '
          'una nadadora ilegible se leyera igual que una que no contestó',
    );
    expect(subio, isA<FalloDeDatos>());
  });
}
