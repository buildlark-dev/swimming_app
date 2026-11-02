import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/metodologia/modelo_tid.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:flutter_test/flutter_test.dart';

/// Invariantes de las constantes de la metodología.
///
/// No prueban código propio sino la transcripción de las tablas del documento
/// normativo. Una transcripción equivocada aquí se propaga a toda la auditoría.
void main() {
  group('fases ATR', () {
    test('cada fase distribuye exactamente el 100% del volumen', () {
      for (final fase in FaseAtr.values) {
        expect(
          fase.sumaDistribucion,
          100,
          reason: '${fase.nombre} suma ${fase.sumaDistribucion}%, no 100%',
        );
      }
    });

    test('cada fase lleva el modelo que la literatura le asocia', () {
      expect(FaseAtr.acumulacion.modelo, ModeloTid.piramidal);
      expect(FaseAtr.transformacion.modelo, ModeloTid.umbral);
      expect(FaseAtr.realizacion.modelo, ModeloTid.polarizado);
    });

    test('el reparto fino de cada fase cabe en su envolvente publicado', () {
      // Es la regla que separa lo que está publicado de lo que es criterio del
      // entrenador: él elige el desglose entre las siete zonas, pero no puede
      // salirse del rango que la literatura da para su modelo.
      for (final fase in FaseAtr.values) {
        expect(
          fase.repartoCabeEnElModelo,
          isTrue,
          reason:
              '${fase.nombre} declara '
              'Z1 ${fase.prescritoParaTid(ZonaTid.z1)}% · '
              'Z2 ${fase.prescritoParaTid(ZonaTid.z2)}% · '
              'Z3 ${fase.prescritoParaTid(ZonaTid.z3)}%, '
              'fuera del envolvente ${fase.modelo.nombre}',
        );
      }
    });

    test('Acumulación es piramidal: Z1 78 · Z2 15 · Z3 7, y 50% técnico', () {
      const fase = FaseAtr.acumulacion;
      expect(fase.prescritoParaTid(ZonaTid.z1), 78);
      expect(fase.prescritoParaTid(ZonaTid.z2), 15);
      expect(
        fase.prescritoParaTid(ZonaTid.z3),
        7,
        reason:
            'Puntos medios de Filipas et al. 2022. Acumulación ahora lleva '
            'Z3: la tabla anterior no pedía ninguno',
      );
      expect(fase.porcentajeTecnico, 50);
    });

    test(
      'Transformación es de umbral: Z1 65 · Z2 25 · Z3 10, y 30% técnico',
      () {
        const fase = FaseAtr.transformacion;
        expect(fase.prescritoParaTid(ZonaTid.z1), 65);
        expect(fase.prescritoParaTid(ZonaTid.z2), 25);
        expect(fase.prescritoParaTid(ZonaTid.z3), 10);
        expect(fase.porcentajeTecnico, 30);
      },
    );

    test('Realización es polarizada: Z1 81 · Z2 4 · Z3 15, y 20% técnico', () {
      const fase = FaseAtr.realizacion;
      expect(fase.prescritoParaTid(ZonaTid.z1), 81);
      expect(
        fase.prescritoParaTid(ZonaTid.z2),
        4,
        reason: 'Polarizado significa poco trabajo en la zona intermedia',
      );
      expect(fase.prescritoParaTid(ZonaTid.z3), 15);
      expect(fase.porcentajeTecnico, 20);
    });

    test('las cifras de las fases salen de ensayos hechos en nadadores', () {
      // Pla et al. 2019: polarizado 81/4/15 y umbral 65/25/10.
      expect(FaseAtr.transformacion.modelo.fuente, contains('Pla'));
      expect(FaseAtr.realizacion.modelo.fuente, contains('Pla'));
      expect(
        FaseAtr.acumulacion.modelo.fuente,
        contains('Filipas'),
        reason: 'Toda cifra que la app exija debe poder citarse',
      );
    });

    test('el trabajo técnico decrece de Acumulación a Realización', () {
      expect(
        FaseAtr.acumulacion.porcentajeTecnico,
        greaterThan(FaseAtr.transformacion.porcentajeTecnico),
      );
      expect(
        FaseAtr.transformacion.porcentajeTecnico,
        greaterThan(FaseAtr.realizacion.porcentajeTecnico),
      );
    });

    test('la técnica nunca desaparece: ninguna fase la deja en cero', () {
      for (final fase in FaseAtr.values) {
        expect(
          fase.porcentajeTecnico,
          greaterThan(0),
          reason:
              'La técnica debe estar presente toda la temporada '
              '(sección 3 de la metodología)',
        );
      }
    });
  });

  group('zonas de intensidad', () {
    test('las bandas son contiguas y no se solapan', () {
      const conBanda = [
        Zona.a1,
        Zona.a2,
        Zona.a3,
        Zona.at,
        Zona.resistenciaIntensiva,
      ];
      for (var i = 0; i < conBanda.length - 1; i++) {
        final actual = conBanda[i].banda!;
        final siguiente = conBanda[i + 1].banda!;
        expect(
          actual.maximo,
          siguiente.minimo,
          reason:
              '${conBanda[i].abreviatura} termina en ${actual.maximo} '
              'pero ${conBanda[i + 1].abreviatura} empieza en '
              '${siguiente.minimo}',
        );
      }
    });

    test('un porcentaje de frecuencia cae en una sola zona', () {
      for (final porcentaje in [60, 65, 70, 75, 80, 84, 85, 90, 92, 100]) {
        final coincidencias = Zona.values
            .where((z) => z.banda != null && z.banda!.contiene(porcentaje))
            .toList();
        expect(
          coincidencias.length,
          1,
          reason:
              '$porcentaje% cae en ${coincidencias.length} zonas: '
              '${coincidencias.map((z) => z.abreviatura).join(', ')}',
        );
      }
    });

    test('Velocidad se controla por ritmo, no por frecuencia cardíaca', () {
      expect(Zona.velocidad.seControlaPorRitmo, isTrue);
      expect(Zona.velocidad.banda, isNull);
    });

    test('Máx no tiene techo', () {
      expect(Zona.resistenciaIntensiva.banda!.maximo, isNull);
      expect(Zona.resistenciaIntensiva.banda!.contiene(100), isTrue);
    });

    test('reconoce la abreviatura escrita con y sin tilde', () {
      expect(Zona.porAbreviatura('A1'), Zona.a1);
      expect(Zona.porAbreviatura('at'), Zona.at);
      expect(Zona.porAbreviatura('Máx'), Zona.resistenciaIntensiva);
      expect(Zona.porAbreviatura('Max'), Zona.resistenciaIntensiva);
      expect(Zona.porAbreviatura('Vel'), Zona.velocidad);
      expect(Zona.porAbreviatura('A7'), isNull);
    });
  });

  group('categorías', () {
    test('Iniciación y Tecnificación no usan ATR', () {
      expect(Categoria.iniciacion.usaAtr, isFalse);
      expect(Categoria.tecnificacion.usaAtr, isFalse);
    });

    test('de Precompetitivo en adelante se usa ATR', () {
      expect(Categoria.precompetitivo.usaAtr, isTrue);
      expect(Categoria.competitivo.usaAtr, isTrue);
      expect(Categoria.altoRendimiento.usaAtr, isTrue);
    });

    test('los rangos de volumen son los de la sección 11', () {
      expect(Categoria.iniciacion.volumenPorSesion.minimo, 500);
      expect(Categoria.iniciacion.volumenPorSesion.maximo, 800);
      expect(Categoria.precompetitivo.volumenPorSesion.minimo, 1800);
      expect(Categoria.precompetitivo.volumenPorSesion.maximo, 2200);
      expect(Categoria.altoRendimiento.volumenPorSesion.maximo, 6000);
    });

    test('los extremos del rango son válidos', () {
      final rango = Categoria.precompetitivo.volumenPorSesion;
      expect(rango.contiene(1800), isTrue, reason: 'el mínimo está dentro');
      expect(rango.contiene(2200), isTrue, reason: 'el máximo está dentro');
      expect(rango.contiene(1799), isFalse);
      expect(rango.contiene(2201), isFalse);
    });

    test('la desviación indica cuántos metros sobran o faltan', () {
      final rango = Categoria.precompetitivo.volumenPorSesion;
      expect(rango.desviacion(2000), 0);
      expect(rango.desviacion(1400), -400, reason: 'faltan 400 m al mínimo');
      expect(
        rango.desviacion(2600),
        400,
        reason: 'sobran 400 m sobre el máximo',
      );
    });

    test('solo Tecnificación tiene alternancia obligatoria de estilos', () {
      final conAlternancia = Categoria.values
          .where((c) => c.tieneAlternanciaObligatoria)
          .toList();
      expect(conAlternancia, [Categoria.tecnificacion]);
    });

    test('la frecuencia semanal es la de la sección 11', () {
      expect(Categoria.iniciacion.sesionesPorSemana, 2);
      expect(Categoria.precompetitivo.sesionesPorSemana, 3);
      expect(Categoria.competitivo.sesionesPorSemana, 5);
      expect(Categoria.altoRendimiento.sesionesPorSemana, 10);
    });
  });

  group('priorización de estilos', () {
    test('Libre reparte 80-85% Libre y 15-20% Espalda', () {
      final prioridad = PriorizacionEstilos.para(Estilo.libre)!;
      expect(prioridad.rangoObjetivo.minimo, 80);
      expect(prioridad.rangoObjetivo.maximo, 85);
      expect(prioridad.rangoComplementario.minimo, 15);
      expect(prioridad.estilosComplementarios, [Estilo.espalda]);
    });

    test('Pecho y Mariposa reparten mitad y mitad', () {
      for (final estilo in [Estilo.pecho, Estilo.mariposa]) {
        final prioridad = PriorizacionEstilos.para(estilo)!;
        expect(prioridad.rangoObjetivo.minimo, 50);
        expect(prioridad.rangoObjetivo.maximo, 50);
        expect(prioridad.rangoComplementario.minimo, 50);
      }
    });

    test('los nombres de nado son los permitidos por la sección 8', () {
      expect(Estilo.libre.nombreDeNado, 'Nado Libre');
      expect(Estilo.espalda.nombreDeNado, 'Nado Espalda');
      expect(Estilo.combinado.nombreDeNado, 'Nado CI');
    });
  });

  group('reparto de la sesión', () {
    test('las tres partes suman el 100% del volumen', () {
      final suma = TipoParte.values.fold(
        0,
        (total, parte) => total + parte.porcentajePrescrito,
      );
      expect(suma, 100);
    });

    test('la parte central se divide en pre-set 10% y principal 40%', () {
      expect(
        porcentajePreSet + porcentajeSeriePrincipal,
        TipoParte.central.porcentajePrescrito,
      );
    });
  });
}
