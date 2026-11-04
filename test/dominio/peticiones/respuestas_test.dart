/// Lo que el nadador responde, y lo que no se le pregunta.
///
/// Las restricciones están copiadas de `data-model.md` tal cual, para que no
/// queden a criterio de quien implemente.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';

void main() {
  final lunes = DateTime(2026, 11, 3);
  final miercoles = DateTime(2026, 11, 5);

  RespuestasDePeticion responder({
    String prueba = '200 Libre',
    DateTime? competencia,
    List<DateTime>? dias,
    int duracion = 90,
    int piscina = 25,
  }) => RespuestasDePeticion(
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: prueba,
    fechaDeCompetencia: competencia,
    diasDisponibles: dias ?? [lunes, miercoles],
    duracionSesionMinutos: duracion,
    longitudPiscina: piscina,
  );

  group('«no lo sé» es una respuesta válida a la fecha (FR-006)', () {
    test('sin fecha de competencia, se construye igual', () {
      expect(responder(competencia: null).fechaDeCompetencia, isNull);
    });

    test('con fecha, la guarda', () {
      final cuando = DateTime(2026, 11, 26);
      expect(responder(competencia: cuando).fechaDeCompetencia, cuando);
    });
  });

  group('la prueba objetivo no puede quedar vacía', () {
    test('vacía revienta', () {
      expect(() => responder(prueba: ''), throwsA(isA<RespuestaInvalida>()));
    });

    test('en blanco revienta', () {
      expect(() => responder(prueba: '   '), throwsA(isA<RespuestaInvalida>()));
    });
  });

  group('los días disponibles', () {
    test('al menos uno', () {
      expect(() => responder(dias: []), throwsA(isA<RespuestaInvalida>()));
    });

    test('sin repetir el mismo día', () {
      // Dos veces el lunes no son dos sesiones: es un lunes contado dos veces,
      // y el motor repartiría volumen sobre un día que no existe.
      expect(
        () => responder(dias: [lunes, lunes]),
        throwsA(isA<RespuestaInvalida>()),
      );
    });

    test('el mismo día a otra hora sigue siendo el mismo día', () {
      expect(
        () => responder(
          dias: [lunes, DateTime(lunes.year, lunes.month, lunes.day, 19)],
        ),
        throwsA(isA<RespuestaInvalida>()),
      );
    });

    test('**control negativo**: días distintos se construyen', () {
      expect(responder(dias: [lunes, miercoles]).diasDisponibles, hasLength(2));
    });
  });

  group('la duración de la sesión está entre 30 y 180 minutos', () {
    test('29 revienta', () {
      expect(() => responder(duracion: 29), throwsA(isA<RespuestaInvalida>()));
    });

    test('181 revienta', () {
      expect(() => responder(duracion: 181), throwsA(isA<RespuestaInvalida>()));
    });

    test('los dos extremos valen', () {
      expect(responder(duracion: 30).duracionSesionMinutos, 30);
      expect(responder(duracion: 180).duracionSesionMinutos, 180);
    });
  });

  group('la piscina es de 25 o de 50, y no hay tercera', () {
    test('33 revienta', () {
      expect(() => responder(piscina: 33), throwsA(isA<RespuestaInvalida>()));
    });

    test('25 y 50 valen', () {
      expect(responder(piscina: 25).longitudPiscina, 25);
      expect(responder(piscina: 50).longitudPiscina, 50);
    });
  });

  group('lo que NO lleva, que es un requisito y no un olvido', () {
    test('ni categoría, ni fase, ni componente, ni diagnóstico, ni molestias', () {
      // Si alguien añade uno de estos campos, esta prueba se lo dice. La
      // categoría es del entrenador (FR-003), la fase y el componente se
      // derivan (FR-014, FR-016), el diagnóstico es observación suya, y las
      // molestias se enlazan desde las sesiones, nunca se copian (FR-038).
      final campos = responder().toJson().keys.toSet();

      for (final prohibido in [
        'categoria',
        'faseAtr',
        'componenteAcentuado',
        'diagnosticoTecnico',
        'molestia',
        'molestias',
      ]) {
        expect(
          campos,
          isNot(contains(prohibido)),
          reason:
              '«$prohibido» no es del nadador, y guardarlo aquí lo convertiría '
              'en algo que él declaró',
        );
      }
    });

    test('y lleva exactamente los seis que sí son suyos', () {
      expect(responder().toJson().keys.toSet(), {
        'estiloObjetivo',
        'pruebaObjetivo',
        'fechaDeCompetencia',
        'diasDisponibles',
        'duracionSesionMinutos',
        'longitudPiscina',
      });
    });
  });

  test('ida y vuelta por JSON no pierde nada', () {
    final original = responder(competencia: DateTime(2026, 11, 26));
    final vuelta = RespuestasDePeticion.desdeJson(original.toJson());

    expect(vuelta.estiloObjetivo, original.estiloObjetivo);
    expect(vuelta.pruebaObjetivo, original.pruebaObjetivo);
    expect(vuelta.fechaDeCompetencia, original.fechaDeCompetencia);
    expect(vuelta.diasDisponibles, original.diasDisponibles);
    expect(vuelta.duracionSesionMinutos, original.duracionSesionMinutos);
    expect(vuelta.longitudPiscina, original.longitudPiscina);
  });
}
