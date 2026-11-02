import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/metodologia/modelo_tid.dart';
import 'package:natacion_app/dominio/metodologia/ritmos_competencia.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// Lo que la versión 3.5 cambió en las zonas, fijado contra sus fuentes.
///
/// Cada cifra de aquí sale de `docs/metodologia/fundamento_zonas.md`, donde está
/// con su cita. Si alguien las mueve sin mover la fuente, falla aquí.
void main() {
  group('siete zonas, no seis (decisión 2)', () {
    test('Velocidad y Explosivo son zonas distintas', () {
      expect(Zona.values, hasLength(7));
      expect(Zona.velocidad, isNot(Zona.explosivo));
    });

    test('se separan porque el sistema energético es distinto', () {
      // Swimming Canada: High-Intensity son hidratos; Explosive son fosfágenos.
      expect(Zona.velocidad.descripcion, contains('200'));
      expect(Zona.explosivo.descripcion, contains('descanso pasivo'));
    });

    test('las dos pertenecen a Z3 del modelo de tres', () {
      expect(Zona.velocidad.tid, ZonaTid.z3);
      expect(Zona.explosivo.tid, ZonaTid.z3);
    });
  });

  group('«Máx» ya no se llama VO₂ máx (decisión 1)', () {
    test('su nombre es resistencia intensiva', () {
      expect(Zona.resistenciaIntensiva.nombre, 'Resistencia intensiva');
    });

    test('ninguna zona dice VO2 ni VO₂ en su nombre ni descripción', () {
      // Swimming Canada define esa banda como ~ritmo 400 en esfuerzos largos
      // con descanso medio-bajo, que no es trabajo interválico de VO₂ máx.
      for (final zona in Zona.values) {
        final texto = '${zona.nombre} ${zona.descripcion}'.toUpperCase();
        expect(texto, isNot(contains('VO2')));
        expect(texto, isNot(contains('VO₂')));
        expect(texto, isNot(contains('VO 2')));
      }
    });

    test('la abreviatura sigue siendo Máx, que es lo que él escribe', () {
      // Cambiarla rompería su notación y los planes ya guardados, que
      // serializan la abreviatura.
      expect(Zona.resistenciaIntensiva.abreviatura, 'Máx');
      expect(Zona.porAbreviatura('Máx'), Zona.resistenciaIntensiva);
      expect(Zona.porAbreviatura('Max'), Zona.resistenciaIntensiva);
      expect(Zona.porAbreviatura('RI'), Zona.resistenciaIntensiva);
    });

    test('su descripción la ancla al ritmo 400 de la fuente', () {
      expect(Zona.resistenciaIntensiva.descripcion, contains('400'));
    });
  });

  group('anclaje por velocidad crítica (decisión 7)', () {
    const conRitmo = [
      Zona.a1,
      Zona.a2,
      Zona.a3,
      Zona.at,
      Zona.resistenciaIntensiva,
      Zona.velocidad,
    ];

    test('las bandas de ritmo son contiguas y sin solapamiento', () {
      for (var i = 0; i < conRitmo.length - 1; i++) {
        final actual = conRitmo[i].ritmo!;
        final siguiente = conRitmo[i + 1].ritmo!;
        expect(
          actual.maximo,
          siguiente.minimo,
          reason:
              '${conRitmo[i].abreviatura} termina en ${actual.maximo} '
              'pero ${conRitmo[i + 1].abreviatura} empieza en '
              '${siguiente.minimo}. Los bordes de Ginn se cerraron a propósito: '
              'sus niveles 3, 4 y 5 se solapaban en el 100%',
        );
      }
    });

    test('el 100% de velocidad crítica es la frontera de Z2 con Z3', () {
      // Es el punto que Scott (2024) define como límite inferior del dominio
      // severo, y lo que hace la auditoría objetiva.
      expect(Zona.at.ritmo!.maximo, 100);
      expect(Zona.resistenciaIntensiva.ritmo!.minimo, 100);
      expect(Zona.at.tid, ZonaTid.z2);
      expect(Zona.resistenciaIntensiva.tid, ZonaTid.z3);
    });

    test('solo el borde de A3 está marcado como interpolado', () {
      // Ginn no tiene A3: su sistema va A1, A2, AT, MVO2, LT/LP.
      expect(Zona.a3.ritmo!.interpolada, isTrue);
      for (final zona in conRitmo.where((z) => z != Zona.a3)) {
        expect(
          zona.ritmo!.interpolada,
          isFalse,
          reason:
              '${zona.abreviatura} sí está publicada: no debe marcarse '
              'como deducida',
        );
      }
    });

    test('Explosivo no se ancla a la velocidad crítica', () {
      // Ginn deja su nivel 6 fuera: «not based on CS, but represents maximal
      // velocity».
      expect(Zona.explosivo.ritmo, isNull);
      expect(Zona.explosivo.seControlaPorTecnica, isTrue);
    });

    test(
      'A1 empieza en el 75% de velocidad crítica, como el nivel 1 de Ginn',
      () {
        expect(Zona.a1.ritmo!.minimo, 75);
        expect(Zona.a1.ritmo!.maximo, 80);
      },
    );
  });

  group('los ritmos de competencia no son zonas (decisión 3)', () {
    test('RP8 cuenta como AT por defecto', () {
      expect(RitmoCompetencia.zonaDe('RP8'), Zona.at);
    });

    test('RP8 pasa a resistencia intensiva en el dominio severo', () {
      expect(
        RitmoCompetencia.zonaDe('RP8', enDominioSevero: true),
        Zona.resistenciaIntensiva,
      );
    });

    test('RP4 es resistencia intensiva: ~ritmo 400', () {
      expect(RitmoCompetencia.zonaDe('RP4'), Zona.resistenciaIntensiva);
    });

    test('RP2 y RP1 son velocidad', () {
      expect(RitmoCompetencia.zonaDe('RP2'), Zona.velocidad);
      expect(RitmoCompetencia.zonaDe('RP1'), Zona.velocidad);
    });

    test('RP15 es AT, y se escribe de las dos formas de la sección 9', () {
      expect(RitmoCompetencia.zonaDe('RP15'), Zona.at);
      expect(RitmoCompetencia.zonaDe('RP1500'), Zona.at);
    });

    test('solo RP8 depende del conjunto', () {
      // Es el único cuyo rango cruza el 100% de velocidad crítica.
      for (final ritmo in RitmoCompetencia.values) {
        expect(
          ritmo.dependeDelConjunto,
          ritmo == RitmoCompetencia.rp8,
          reason:
              '${ritmo.abreviatura} está en '
              '${ritmo.porcentajeCsMinimo}-${ritmo.porcentajeCsMaximo}% de CS',
        );
      }
    });

    test('los ritmos crecen en intensidad al bajar la distancia', () {
      final ordenados = [
        RitmoCompetencia.rp15,
        RitmoCompetencia.rp8,
        RitmoCompetencia.rp4,
        RitmoCompetencia.rp2,
        RitmoCompetencia.rp1,
      ];
      for (var i = 0; i < ordenados.length - 1; i++) {
        expect(
          ordenados[i + 1].porcentajeCsMinimo,
          greaterThan(ordenados[i].porcentajeCsMinimo),
          reason: 'Nadar 100 es más rápido que nadar 1500',
        );
        expect(ordenados[i + 1].distancia, lessThan(ordenados[i].distancia));
      }
    });

    test('el razonamiento se puede mostrar al entrenador', () {
      // Debe poder ver por qué la app contó sus 800 m donde los contó.
      final razon = RitmoCompetencia.rp8.razonamiento;
      expect(razon, contains('velocidad crítica'));
      expect(razon, contains('AT'));
      expect(razon, contains('Máx'));
    });

    test('se puede leer la columna de intensidad de sus hojas', () {
      // Formas reales del Macrociclo Precompetitivo Agosto.
      expect(Zona.porAbreviaturaORitmo('RP8'), Zona.at);
      expect(Zona.porAbreviaturaORitmo('A1'), Zona.a1);
      expect(Zona.porAbreviaturaORitmo('Máx'), Zona.resistenciaIntensiva);
    });

    test('un ritmo se distingue de una zona escrita de verdad', () {
      // `porAbreviatura` no traduce ritmos: así se puede saber si el entrenador
      // declaró una zona o si la app la dedujo.
      expect(Zona.porAbreviatura('RP8'), isNull);
      expect(Zona.porAbreviaturaORitmo('RP8'), isNotNull);
    });
  });

  group('los envolventes publicados (decisión 5c)', () {
    test('cada modelo cita su fuente', () {
      for (final modelo in ModeloTid.values) {
        expect(
          modelo.fuente,
          isNotEmpty,
          reason: 'Toda cifra que la app exija debe poder citarse',
        );
      }
    });

    test('los tres rangos de cada modelo admiten alguna reparto válido', () {
      // Si los mínimos sumaran más de 100 o los máximos menos de 100, el
      // envolvente sería imposible de cumplir.
      for (final modelo in ModeloTid.values) {
        final minimos = ZonaTid.values
            .map((t) => modelo.rangoDe(t).minimo)
            .fold(0, (a, b) => a + b);
        final maximos = ZonaTid.values
            .map((t) => modelo.rangoDe(t).maximo)
            .fold(0, (a, b) => a + b);

        expect(
          minimos,
          lessThanOrEqualTo(100),
          reason: '${modelo.nombre}: los mínimos suman $minimos',
        );
        expect(
          maximos,
          greaterThanOrEqualTo(100),
          reason: '${modelo.nombre}: los máximos suman $maximos',
        );
      }
    });

    test('polarizado tiene más Z3 que Z2, y umbral lo contrario', () {
      // Es lo que distingue los modelos, más allá de las cifras.
      expect(
        ModeloTid.polarizado.rangoDe(ZonaTid.z3).minimo,
        greaterThan(ModeloTid.polarizado.rangoDe(ZonaTid.z2).maximo),
      );
      expect(
        ModeloTid.umbral.rangoDe(ZonaTid.z2).minimo,
        greaterThan(ModeloTid.umbral.rangoDe(ZonaTid.z3).maximo),
      );
    });

    test('piramidal desciende: Z1 > Z2 > Z3', () {
      final m = ModeloTid.piramidal;
      expect(
        m.rangoDe(ZonaTid.z1).minimo,
        greaterThan(m.rangoDe(ZonaTid.z2).maximo),
      );
      expect(
        m.rangoDe(ZonaTid.z2).minimo,
        greaterThan(m.rangoDe(ZonaTid.z3).maximo),
      );
    });

    test('la Acumulación real del entrenador queda fuera del envolvente', () {
      // Su macrociclo tiene ~97% de Z1 en Acumulación. El máximo publicado para
      // el modelo piramidal es 81%. Queda registrado como dato, no como
      // reproche: es el hallazgo que la tabla anterior no sabía dar.
      final rango = FaseAtr.acumulacion.modelo.rangoDe(ZonaTid.z1);
      expect(rango.contiene(97), isFalse);
      expect(rango.desviacion(97), greaterThan(0));
    });
  });
}
