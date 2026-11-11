/// M8, M9, M11, M12 — la derivación del macrociclo.
///
/// **El determinismo se comprueba derivando dos veces y comparando**, nunca
/// contra un fichero de referencia. Un fichero esconderia justo el fallo que
/// importa —una entrada leída del reloj en lugar de la estructura confirmada—,
/// porque la referencia se habría generado con el mismo reloj. Con dos
/// derivaciones, esa entrada cambia entre una y otra y la prueba lo ve. Es la
/// trampa que la feature 008 dejó escrita.
///
/// Escrito antes de `lib/dominio/macrociclo/derivar_macrociclo.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/derivar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

void main() {
  final hoy = DateTime(2026, 11, 4);
  final competencia = hoy.add(const Duration(days: 98));

  Biblioteca biblioteca() => Biblioteca.desdeJson(
    jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  const ficha = Nadador(
    id: 'n-ana',
    nombre: 'Ana María Restrepo',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
    diagnosticoTecnico: ['pierde el agarre al fatigarse'],
  );

  EstructuraConfirmada estructura({
    Categoria categoria = Categoria.precompetitivo,
    List<int> dias = const [1, 3, 5],
  }) {
    final propuesto = esqueletoParaMacrociclo(
      fechaDeCompetencia: competencia,
      hoy: hoy,
      categoria: categoria,
    );

    return EstructuraConfirmada(
      modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
      modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
      bloques: propuesto.bloques,
      confirmadaEn: hoy,
      diasPorSemana: dias,
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    );
  }

  ResultadoDerivacion derivacion({
    EstructuraConfirmada? cual,
    Nadador deQuien = ficha,
  }) => derivarMacrociclo(
    estructura: cual ?? estructura(),
    ficha: deQuien,
    biblioteca: biblioteca(),
    versionMetodologia: '3.6.0',
    nombre: 'Hacia el Departamental',
    fechaDeCompetencia: competencia,
  );

  MacrocicloDerivado derivar({
    EstructuraConfirmada? cual,
    Nadador deQuien = ficha,
  }) {
    final resultado = derivacion(cual: cual, deQuien: deQuien);
    // Si el motor no pudo, la prueba tiene que decir **por qué** en lugar de
    // reventar con un error de tipo que no explica nada.
    if (resultado is DerivacionImposible) {
      fail(
        'no se pudo derivar en ${resultado.enQueBloque}: '
        '${resultado.impedimentos.map((i) => i.explicacion).join(' · ')}',
      );
    }
    return resultado as MacrocicloDerivado;
  }

  group('lo que sale de una confirmación', () {
    test('un mesociclo por bloque, en el orden del esqueleto', () {
      final derivado = derivar();

      expect(derivado.mesociclos, hasLength(3));
      expect(derivado.mesociclos[0].faseAtr, FaseAtr.acumulacion);
      expect(derivado.mesociclos[1].faseAtr, FaseAtr.transformacion);
      expect(derivado.mesociclos[2].faseAtr, FaseAtr.realizacion);
    });

    test('cada mesociclo lleva su posición en el macrociclo', () {
      final derivado = derivar();
      for (var i = 0; i < derivado.mesociclos.length; i++) {
        expect(derivado.mesociclos[i].ordenEnElMacrociclo, i);
      }
    });

    test('cada mesociclo tiene sus microciclos y sus sesiones', () {
      // M8: mesociclos, microciclos y sesiones **de una vez**. Un mesociclo
      // sin sesiones sería una etiqueta, y el nadador la abriría vacía.
      for (final mesociclo in derivar().mesociclos) {
        expect(mesociclo.microciclos, isNotEmpty);
        expect(mesociclo.sesiones, isNotEmpty);
        expect(mesociclo.metros, greaterThan(0));
      }
    });

    test('las semanas del mesociclo salen de los días del bloque', () {
      // 57 días de Acumulación son **8** microciclos y no 9: el día que sobra
      // se suma a la última semana en lugar de quedarse como microciclo de un
      // día, que no es una semana de entrenamiento y en el que el motor
      // repartiría el volumen de una.
      final mesociclos = derivar().mesociclos;

      expect(mesociclos[0].microciclos, hasLength(8));
      expect(mesociclos[1].microciclos, hasLength(4));
      expect(mesociclos[2].microciclos, hasLength(2));
    });

    test('un macrociclo de catorce semanas son catorce llamadas al motor', () {
      // 8 + 4 + 2. Importa porque corren en el teléfono del entrenador, no en
      // una prueba: si la derivación bloquea la interfaz, se notará allí.
      expect(derivar().llamadasAlMotor, 14);
    });

    test('las sesiones caen en los días que él declaró', () {
      // Tres días a la semana: lunes, miércoles y viernes.
      for (final mesociclo in derivar().mesociclos) {
        for (final sesion in mesociclo.sesiones) {
          expect(
            sesion.fecha!.weekday,
            isIn(const [1, 3, 5]),
            reason: 'una sesión cayó en un día sin piscina',
          );
        }
      }
    });

    test('ninguna sesión se sale del macrociclo', () {
      for (final mesociclo in derivar().mesociclos) {
        for (final sesion in mesociclo.sesiones) {
          expect(sesion.fecha!.isBefore(hoy), isFalse);
          expect(
            sesion.fecha!.isAfter(competencia),
            isFalse,
            reason: 'hay una sesión programada después de competir',
          );
        }
      }
    });

    test('el microciclo nombra su objetivo, no su posición', () {
      // La metodología exige nombrar por el componente acentuado: «técnica de
      // eficiencia», no «Acumulación 1». `Microciclo.nombraElObjetivoReal` ya
      // lo comprueba, y el criterio de auditoría lo mira.
      for (final mesociclo in derivar().mesociclos) {
        for (final microciclo in mesociclo.microciclos) {
          expect(
            microciclo.nombraElObjetivoReal,
            isTrue,
            reason: 'el microciclo «${microciclo.nombre}» solo dice dónde está',
          );
        }
      }
    });
  });

  group('nada se firma por el camino', () {
    test('el macrociclo y todos sus mesociclos nacen en borrador', () {
      // M13, FR-015: nace `borrador` y pasa la auditoría de la sección 16
      // antes de poder firmarse, como cualquier otra salida automática.
      final derivado = derivar();

      expect(
        derivado.macrocicloConLosIds(const ['a', 'b', 'c']).estado,
        EstadoPlan.borrador,
      );
      for (final mesociclo in derivado.mesociclos) {
        expect(mesociclo.estado, EstadoPlan.borrador);
      }
    });

    test('todos los mesociclos se declaran generados, no escritos a mano', () {
      for (final mesociclo in derivar().mesociclos) {
        expect(mesociclo.origen, OrigenPlan.automatico);
      }
    });

    test('ninguno sale de una petición de nadador', () {
      // Un mesociclo de macrociclo y un borrador de petición son dos cosas, y
      // la cola del entrenador los distingue por `peticionId`.
      for (final mesociclo in derivar().mesociclos) {
        expect(mesociclo.peticionId, isNull);
      }
    });
  });

  group('la versión de metodología (M11, FR-011, SC-002)', () {
    test('el macrociclo la lleva', () {
      expect(
        derivar().macrocicloConLosIds(const ['a', 'b', 'c']).versionMetodologia,
        '3.6.0',
      );
    });

    test('y cada mesociclo también, el 100% de ellos', () {
      for (final mesociclo in derivar().mesociclos) {
        expect(mesociclo.versionMetodologia, '3.6.0');
      }
    });
  });

  group('determinismo (M12, SC-003)', () {
    test('derivar dos veces da el mismo macrociclo', () {
      // **Dos derivaciones, no un fichero.** Lo que se compara es el JSON
      // completo de cada mesociclo, sesiones incluidas: si algo se leyera del
      // reloj, del azar o del orden de un mapa, aquí se vería.
      final estructuraFija = estructura();

      final primera = derivar(cual: estructuraFija);
      final segunda = derivar(cual: estructuraFija);

      expect(primera.mesociclos, hasLength(segunda.mesociclos.length));

      for (var i = 0; i < primera.mesociclos.length; i++) {
        expect(
          jsonEncode(planAJson(primera.mesociclos[i], conSesiones: true)),
          jsonEncode(planAJson(segunda.mesociclos[i], conSesiones: true)),
          reason: 'el mesociclo $i no salió igual las dos veces',
        );
      }

      const ids = ['a', 'b', 'c'];
      expect(
        jsonEncode(macrocicloAJson(primera.macrocicloConLosIds(ids))),
        jsonEncode(macrocicloAJson(segunda.macrocicloConLosIds(ids))),
      );
    });

    test('dos estructuras iguales dan macrociclos iguales', () {
      // El control de la prueba de arriba: que no pase por comparar la misma
      // instancia consigo misma. Aquí las estructuras son dos objetos
      // distintos con los mismos datos.
      final primera = derivar(cual: estructura());
      final segunda = derivar(cual: estructura());

      for (var i = 0; i < primera.mesociclos.length; i++) {
        expect(
          jsonEncode(planAJson(primera.mesociclos[i], conSesiones: true)),
          jsonEncode(planAJson(segunda.mesociclos[i], conSesiones: true)),
        );
      }
    });

    test('cambiar los días de la semana cambia el resultado', () {
      // El control de que la comparación no es trivial: si la derivación
      // ignorara la estructura, dos estructuras distintas darían lo mismo y
      // las pruebas de determinismo pasarían sin significar nada.
      //
      // **Lo que cambia son las fechas, no el número de sesiones.** El motor
      // toma cuántas sesiones hace una semana de `categoria.sesionesPorSemana`
      // —es la metodología la que lo dice—, y los días declarados le dicen
      // **cuándo**. La primera versión de esta prueba comparaba el número y
      // salían 24 las dos veces.
      final lunesMiercolesViernes = derivar(
        cual: estructura(dias: const [1, 3, 5]),
      );
      final martesJuevesSabado = derivar(
        cual: estructura(dias: const [2, 4, 6]),
      );

      final unos = lunesMiercolesViernes.mesociclos.first.sesiones
          .map((s) => s.fecha)
          .toList();
      final otros = martesJuevesSabado.mesociclos.first.sesiones
          .map((s) => s.fecha)
          .toList();

      expect(unos, isNot(otros));
      expect(unos.map((f) => f!.weekday).toSet(), {1, 3, 5});
      expect(otros.map((f) => f!.weekday).toSet(), {2, 4, 6});
    });
  });

  group('categorías sin ATR', () {
    test('sale un solo mesociclo y sin fase', () {
      // M6: el motor prohíbe la fase aquí, así que un mesociclo con fase
      // habría sido rechazado al generar.
      final derivado = derivar(
        cual: estructura(categoria: Categoria.iniciacion, dias: const [2, 4]),
        deQuien: const Nadador(
          id: 'n-leo',
          nombre: 'Leonardo Mesa',
          categoria: Categoria.iniciacion,
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '25 Libre',
        ),
      );

      expect(derivado.mesociclos, hasLength(1));
      expect(derivado.mesociclos.single.faseAtr, isNull);
      expect(derivado.mesociclos.single.sesiones, isNotEmpty);
    });
  });
}
