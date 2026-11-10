/// Garantías H4, H5, H6 y H13 — el reparto por rol.
///
/// **Este es el cerrojo que sustituye a un riesgo escrito.** Lo que había en
/// `main.dart` eran dos listas paralelas recorridas con un mismo índice, con
/// este aviso al lado: «hacerlo con dos listas paralelas y un índice compartido
/// es la forma clásica de acabar enseñando el editor al pulsar "Mi progreso"».
/// Con tres pestañas y un rol era un riesgo; con cinco destinos y dos
/// recorridos se duplica.
///
/// Con el reparto en una tabla del dominio, «ningún contenido del otro rol
/// aparece en un recorrido» pasa de ser algo que hay que mirar pantalla por
/// pantalla a ser una propiedad comprobable sin pintar nada.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/hub/destino.dart';

void main() {
  /// Lo que le toca a un rol, destino por destino.
  Map<Destino, QueHay> recorridoDe(Rol rol) => {
    for (final destino in Destino.values) destino: reparto(destino, rol),
  };

  group('el reparto', () {
    test('H4 — cada destino y cada rol tienen exactamente una respuesta', () {
      for (final rol in Rol.values) {
        for (final destino in Destino.values) {
          final queHay = reparto(destino, rol);
          expect(
            queHay,
            anyOf(isA<Contiene>(), isA<TodaviaNo>()),
            reason: '$destino para $rol no tiene respuesta',
          );
        }
      }
    });

    test(
      'H5 — ningún contenido aparece en los dos recorridos, salvo Ajustes',
      () {
        Set<Contenido> contenidosDe(Rol rol) => {
          for (final queHay in recorridoDe(rol).values)
            if (queHay is Contiene) queHay.contenido,
        };

        final compartidos = contenidosDe(
          Rol.entrenador,
        ).intersection(contenidosDe(Rol.nadador));

        expect(
          compartidos,
          {Contenido.ajustes},
          reason:
              'Ajustes es la cuenta de quien está dentro, así que es el '
              'mismo contenido con datos distintos. Cualquier otro compartido '
              'significa que un recorrido se metió en el otro',
        );
      },
    );

    test('H6 — el nadador no tiene nada del taller del entrenador', () {
      final suyos = recorridoDe(Rol.nadador).values;

      for (final prohibido in [
        Contenido.generadorYEditor,
        Contenido.planesDelEntrenador,
        Contenido.homeDelEntrenador,
      ]) {
        expect(
          suyos.any((q) => q is Contiene && q.contenido == prohibido),
          isFalse,
          reason: '$prohibido no es del nadador',
        );
      }
    });

    test('H6 — el entrenador no tiene el recorrido del nadador', () {
      final suyos = recorridoDe(Rol.entrenador).values;

      for (final prohibido in [
        Contenido.miMacrociclo,
        Contenido.miProgreso,
        Contenido.homeDelNadador,
      ]) {
        expect(
          suyos.any((q) => q is Contiene && q.contenido == prohibido),
          isFalse,
          reason: '$prohibido no es del entrenador',
        );
      }
    });

    test('H13 — ya solo queda un «todavía no»', () {
      // Eran dos. La feature 008 llenó el `Generar` del nadador, que es para
      // lo que el hueco estaba: el reparto es una función total y «todavía no»
      // era una respuesta, no un sitio vacío. Queda el Análisis del
      // entrenador, que espera a la 010.
      final esperando = <String>[
        for (final rol in Rol.values)
          for (final destino in Destino.values)
            if (reparto(destino, rol) is TodaviaNo)
              '${destino.name}/${rol.name}',
      ];

      expect(
        esperando..sort(),
        ['analisis/entrenador'],
        reason:
            'El Análisis del nadador NO es uno de ellos: lleva dentro «Mi '
            'progreso» de la feature 003 (FR-031)',
      );
    });

    test('H13 — y dice qué feature lo trae', () {
      final analisisDelEntrenador = reparto(Destino.analisis, Rol.entrenador);

      expect((analisisDelEntrenador as TodaviaNo).feature, '010');
      expect(analisisDelEntrenador.loQueLlegara, isNotEmpty);
    });

    test('el Generar del nadador es su petición (feature 008)', () {
      expect(
        reparto(Destino.generar, Rol.nadador),
        isA<Contiene>().having(
          (c) => c.contenido,
          'contenido',
          Contenido.peticionDelNadador,
        ),
      );
    });

    test('FR-031 — el Análisis del nadador es «Mi progreso»', () {
      expect(
        reparto(Destino.analisis, Rol.nadador),
        isA<Contiene>().having(
          (c) => c.contenido,
          'contenido',
          Contenido.miProgreso,
        ),
      );
    });

    test('el Ver Plan de cada rol es lo suyo', () {
      expect(
        (reparto(Destino.verPlan, Rol.nadador) as Contiene).contenido,
        // Desde la feature 009 es su macrociclo entero. Su sesión de hoy no
        // desapareció: es lo que esa pantalla enseña cuando no tiene ninguno,
        // y por eso dejó de ser el contenido de un destino.
        Contenido.miMacrociclo,
      );
      expect(
        (reparto(Destino.verPlan, Rol.entrenador) as Contiene).contenido,
        Contenido.planesDelEntrenador,
      );
    });

    test('todo contenido declarado le toca a alguien', () {
      // Un contenido que no aparece en ningún recorrido es código muerto, y
      // peor: es una pantalla que alguien construyó y nadie puede abrir.
      final repartidos = {
        for (final rol in Rol.values)
          for (final queHay in recorridoDe(rol).values)
            if (queHay is Contiene) queHay.contenido,
      };

      expect(repartidos, containsAll(Contenido.values));
    });
  });
}
