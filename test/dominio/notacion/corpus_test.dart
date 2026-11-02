import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';

import 'ayuda_pruebas.dart';

/// Corpus de series reales del entrenador, tomadas de la sección 14 del
/// documento normativo.
///
/// Cada caso declara el resultado estructurado esperado. Es la red que sujeta
/// al analizador: cualquier cambio que rompa una de estas lecturas rompe una
/// serie que el entrenador ya escribió en la vida real.
class CasoCorpus {
  const CasoCorpus(
    this.texto, {
    required this.metros,
    this.repeticiones,
    this.distancia,
    this.implementos = const <Implemento>[],
    this.modificadores = const <Modificador>[],
    this.tiempoSalida,
    this.estilo,
    this.conEjercicio,
  });

  final String texto;
  final int metros;
  final int? repeticiones;
  final int? distancia;
  final List<Implemento> implementos;
  final List<Modificador> modificadores;
  final Duration? tiempoSalida;
  final Estilo? estilo;
  final String? conEjercicio;
}

const corpus = <CasoCorpus>[
  CasoCorpus('200 N', metros: 200, repeticiones: 1, distancia: 200),
  CasoCorpus(
    '4x100 AL SNK PN / 2\'',
    metros: 400,
    repeticiones: 4,
    distancia: 100,
    implementos: [Implemento.aletas, Implemento.snorkel],
    modificadores: [Modificador.patada],
    tiempoSalida: Duration(minutes: 2),
  ),
  CasoCorpus(
    '8x50 (1L 1Estilo 1>4)',
    metros: 400,
    repeticiones: 8,
    distancia: 50,
  ),
  CasoCorpus(
    '200 PULL PL (75N=25 Prog)',
    metros: 200,
    repeticiones: 1,
    distancia: 200,
    implementos: [Implemento.pullBuoy, Implemento.palas],
  ),
  CasoCorpus(
    '400 AL (75 Estilo − 25 UW)',
    metros: 400,
    repeticiones: 1,
    distancia: 400,
    implementos: [Implemento.aletas],
  ),
  CasoCorpus(
    '200 AL (25m Pn E FLECHA + 75 N)',
    metros: 200,
    repeticiones: 1,
    distancia: 200,
    implementos: [Implemento.aletas],
  ),
  CasoCorpus(
    '200 PU/Pp E (50 c/brazo)',
    metros: 200,
    repeticiones: 1,
    distancia: 200,
  ),
  CasoCorpus(
    '300 REC Pp TEC L',
    metros: 300,
    repeticiones: 1,
    distancia: 300,
    implementos: [Implemento.palasPequenas],
    modificadores: [Modificador.recuperacion],
  ),
  CasoCorpus('100 E', metros: 100, distancia: 100, estilo: Estilo.espalda),
];

/// Series del documento normativo que **deben** quedar marcadas como
/// pendientes, porque el propio documento se aparta de su Biblioteca.
const corpusConDiscrepancia = <CasoCorpus>[
  CasoCorpus(
    '200 AL CAMBIO POSI', // nombre retirado en 3.4.1
    metros: 200,
    implementos: [Implemento.aletas],
  ),
];

void main() {
  late Analizador analizador;

  setUpAll(() {
    analizador = crearAnalizador();
  });

  group('corpus de series reales', () {
    for (final caso in corpus) {
      test('"${caso.texto}" son ${caso.metros} m', () {
        final resultado = analizador.analizar(caso.texto);
        expect(
          resultado.metros,
          caso.metros,
          reason:
              'Interpretado como: '
              '${resultado.series.map((s) => s.toString()).join(' | ')}',
        );
      });
    }

    test('las repeticiones y la distancia se separan bien', () {
      for (final caso in corpus) {
        if (caso.repeticiones == null) continue;
        final resultado = analizador.analizar(caso.texto);
        expect(resultado.series, isNotEmpty, reason: caso.texto);
        final serie = resultado.series.first;
        expect(serie.repeticiones, caso.repeticiones, reason: caso.texto);
        expect(serie.distancia, caso.distancia, reason: caso.texto);
      }
    });

    test('los implementos se reconocen', () {
      for (final caso in corpus) {
        if (caso.implementos.isEmpty) continue;
        final resultado = analizador.analizar(caso.texto);
        final serie = resultado.series.first;
        for (final implemento in caso.implementos) {
          expect(
            serie.implementos,
            contains(implemento),
            reason: '${caso.texto} debería llevar ${implemento.nombre}',
          );
        }
      }
    });

    test('los modificadores se reconocen', () {
      for (final caso in corpus) {
        if (caso.modificadores.isEmpty) continue;
        final resultado = analizador.analizar(caso.texto);
        final serie = resultado.series.first;
        for (final modificador in caso.modificadores) {
          expect(
            serie.modificadores,
            contains(modificador),
            reason: '${caso.texto} debería llevar ${modificador.nombre}',
          );
        }
      }
    });

    test('el tiempo de salida se lee tras la barra', () {
      final resultado = analizador.analizar('4x100 AL SNK PN / 2\'');
      expect(resultado.series.first.tiempoSalida, const Duration(minutes: 2));
    });

    test('un tiempo con minutos y segundos se lee completo', () {
      final resultado = analizador.analizar('4x100 / 1\'30"');
      expect(
        resultado.series.first.tiempoSalida,
        const Duration(minutes: 1, seconds: 30),
      );
    });

    test('el hipóxico recoge cada cuántas brazadas se respira', () {
      final resultado = analizador.analizar('4x50 Hyp 5');
      final serie = resultado.series.first;
      expect(serie.modificadores, contains(Modificador.hipoxico));
      expect(serie.respiracionCada, 5);
    });

    test('ninguna serie del corpus deja fragmentos sin interpretar', () {
      for (final caso in corpus) {
        final resultado = analizador.analizar(caso.texto);
        expect(
          resultado.pendientes,
          isEmpty,
          reason:
              '"${caso.texto}" dejó pendientes: '
              '${resultado.pendientes.map((p) => p.toString()).join(', ')}',
        );
      }
    });
  });

  group('discrepancia resuelta en la metodología 3.4.1', () {
    // HALLAZGO (2026-09-25), ya corregido: la sesión de ejemplo de la
    // sección 14 escribía "CAMBIO POSI" y la sección 19 definía
    // "CAMB POSIC". El entrenador confirmó que son el mismo ejercicio y el
    // nombre unificado es "CAMBIO POSIC", corregido en ambas secciones.
    //
    // Estas pruebas vigilan que el nombre unificado funcione y que los
    // antiguos NO se acepten: aceptarlos por compatibilidad sería corregir
    // por aproximación, que es lo que la regla R2 prohíbe.

    test('"CAMBIO POSIC", el nombre unificado, se reconoce', () {
      final resultado = analizador.analizar('200 AL CAMBIO POSIC');

      expect(resultado.metros, 200);
      expect(
        resultado.pendientes,
        isEmpty,
        reason: 'Es el nombre vigente en las secciones 14 y 19',
      );
      expect(resultado.series.first.ejercicio, isNotNull);
      expect(resultado.series.first.esTecnica, isTrue);
    });

    test('la sesión de la sección 14 ya no deja pendientes', () {
      final resultado = analizador.analizar('200 AL CAMBIO POSIC');
      expect(resultado.pendientes, isEmpty);
    });

    test('los nombres antiguos no se aceptan por compatibilidad', () {
      for (final antiguo in ['CAMBIO POSI', 'CAMB POSIC']) {
        final resultado = analizador.analizar('200 AL $antiguo');
        expect(
          resultado.pendientes,
          isNotEmpty,
          reason:
              '"$antiguo" ya no está en la Biblioteca. Aceptarlo sería '
              'corregir por aproximación, que la regla R2 prohíbe',
        );
      }
    });

    test('los metros se cuentan aunque el ejercicio quede pendiente', () {
      for (final caso in corpusConDiscrepancia) {
        final resultado = analizador.analizar(caso.texto);
        expect(resultado.metros, caso.metros, reason: caso.texto);
      }
    });
  });

  group('los cinco ejercicios ambiguos de la sección 7', () {
    // El entrenador confirmó que son ejercicios distintos, cada uno con su
    // forma de ejecución y su error a corregir. La lista de la sección 7 se
    // completó de tres a cinco en la versión 3.4.1.

    const ambiguos = [
      'FLECHA',
      'ROLIDO',
      'ROLIDO CON 1 BRAZO',
      '3+3 PATADA LATERAL',
      'PULGAR ROZA EL MUSLO',
    ];

    for (final nombre in ambiguos) {
      test('"$nombre" sin estilo queda marcado como ambiguo', () {
        final resultado = analizador.analizar('200 $nombre');

        expect(
          resultado.pendientes.any((p) => p.motivo.name == 'ambiguo'),
          isTrue,
          reason:
              'Existe en varios estilos: usarlo sin indicar cuál es '
              'ambiguo. Pendientes: '
              '${resultado.pendientes.map((p) => p.toString()).join(', ')}',
        );
      });
    }
  });

  group('la zona escrita no parte la serie (regresión)', () {
    // DEFECTO ENCONTRADO el 2026-09-29 por el viaje redondo de la feature 002.
    //
    // El patrón que detecta series numeradas (`1)`, `2)`) casaba también con el
    // `1)` de `(A1)` cuando le seguía un salto de línea, y partía la serie por
    // la mitad. Los metros seguían cuadrando —por eso no lo detectó ninguna
    // prueba de la feature 001—, pero la zona se perdía en silencio, que es
    // peor: el entrenador vería una serie sin zona sin saber por qué.

    test('una serie con zona seguida de salto de línea conserva la zona', () {
      final resultado = analizador.analizar('200 Nado Libre (A1)\n100 N');

      expect(resultado.series, hasLength(2));
      expect(
        resultado.series.first.zona?.abreviatura,
        'A1',
        reason: 'El "1)" de "(A1)" no puede partir la serie',
      );
    });

    test('los metros también cuadran', () {
      final resultado = analizador.analizar('200 Nado Libre (A1)\n100 N');
      expect(resultado.metros, 300);
    });

    test('varias zonas seguidas conservan todas la suya', () {
      final resultado = analizador.analizar(
        '200 N (A1)\n300 N (A2)\n100 N (AT)',
      );

      expect(resultado.series.map((s) => s.zona?.abreviatura).toList(), [
        'A1',
        'A2',
        'AT',
      ]);
    });

    test('la numeración de serie al principio de línea sí se quita', () {
      final resultado = analizador.analizar('1) 200 N\n2) 300 N');

      expect(resultado.series, hasLength(2));
      expect(resultado.metros, 500);
      expect(resultado.series.first.distancia, 200);
    });
  });

  group('notación en desuso', () {
    test('FC1 y FC2 se ignoran con aviso, sin bloquear', () {
      final resultado = analizador.analizar('200 N FC2');
      expect(resultado.metros, 200);
      expect(resultado.pendientes, isEmpty);
      expect(resultado.avisos, isNotEmpty);
      expect(resultado.avisos.first, contains('desuso'));
    });
  });
}
