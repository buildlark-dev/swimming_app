import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/auditoria/tolerancia.dart';
import 'package:natacion_app/dominio/generacion/presupuesto.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/metodologia/modelo_tid.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// Las treinta combinaciones de categoría, fase y longitud de piscina, más el
/// anclaje de Precompetitivo.
///
/// Es la prueba que demuestra que lo generado **cumple por construcción**, que
/// es la exigencia que la constitución 1.1.0 añadió al principio III.
void main() {
  PeticionGeneracion peticionPara(
    Categoria categoria,
    FaseAtr? fase,
    int piscina,
  ) {
    return PeticionGeneracion(
      categoria: categoria,
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '100 Libre',
      faseAtr: fase,
      componenteAcentuado: 'Técnica de eficiencia',
      diasDisponibles: List.generate(
        categoria.sesionesPorSemana,
        (i) => DateTime(2026, 10, 5 + i),
      ),
      longitudPiscina: piscina,
      duracionSesionMinutos: 240,
    );
  }

  group('anclaje: Precompetitivo en Acumulación', () {
    late Presupuesto presupuesto;

    setUp(() {
      presupuesto = calcularPresupuesto(
        peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
      );
    });

    test('2.000 m por sesión', () {
      expect(presupuesto.volumenPorSesion, 2000);
    });

    test('tres sesiones', () {
      expect(presupuesto.sesiones, 3);
    });

    test('6.000 m de microciclo', () {
      expect(presupuesto.volumenTotal, 6000);
    });

    test(
      'la distribución es A1 3.300 · A2 1.375 · A3 600 · AT 300 · Máx 425',
      () {
        expect(presupuesto.metrosPorZona[Zona.a1], 3300);
        expect(presupuesto.metrosPorZona[Zona.a2], 1375);
        expect(presupuesto.metrosPorZona[Zona.a3], 600);
        expect(presupuesto.metrosPorZona[Zona.at], 300);
        expect(presupuesto.metrosPorZona[Zona.resistenciaIntensiva], 425);
        expect(presupuesto.metrosPorZona[Zona.velocidad], 0);
        expect(presupuesto.metrosPorZona[Zona.explosivo], 0);
      },
    );

    test('agrupada en tres zonas, cae en el envolvente piramidal', () {
      // Z1 = A1 + A2 · Z2 = A3 + AT · Z3 = el resto.
      final z1 =
          presupuesto.metrosPorZona[Zona.a1]! +
          presupuesto.metrosPorZona[Zona.a2]!;
      final z2 =
          presupuesto.metrosPorZona[Zona.a3]! +
          presupuesto.metrosPorZona[Zona.at]!;
      final z3 =
          presupuesto.metrosPorZona[Zona.resistenciaIntensiva]! +
          presupuesto.metrosPorZona[Zona.velocidad]! +
          presupuesto.metrosPorZona[Zona.explosivo]!;

      final total = presupuesto.volumenTotal;
      final modelo = FaseAtr.acumulacion.modelo;

      expect(modelo, ModeloTid.piramidal);
      expect(modelo.rangoDe(ZonaTid.z1).contiene(z1 * 100 / total), isTrue);
      expect(modelo.rangoDe(ZonaTid.z2).contiene(z2 * 100 / total), isTrue);
      expect(
        modelo.rangoDe(ZonaTid.z3).contiene(z3 * 100 / total),
        isTrue,
        reason:
            'Acumulación ahora lleva Z3: el modelo piramidal publicado '
            'prescribe del 6 al 10%, y la tabla anterior no pedía ninguno',
      );
    });

    test('el trabajo técnico es el 50% prescrito para Acumulación', () {
      expect(presupuesto.metrosTecnicos, 3000);
      expect(presupuesto.porcentajeTecnico, 50.0);
    });

    test('las tres sesiones reparten 2.000 m cada una', () {
      expect(presupuesto.metrosPorSesion, [2000, 2000, 2000]);
    });
  });

  group('las treinta combinaciones', () {
    for (final categoria in Categoria.values) {
      final fases = categoria.usaAtr ? FaseAtr.values : <FaseAtr?>[null];

      for (final fase in fases) {
        for (final piscina in [25, 50]) {
          final etiqueta =
              '${categoria.nombre} · '
              '${fase?.nombre ?? 'sin ATR'} · piscina $piscina';

          test('$etiqueta: el volumen cae dentro del rango', () {
            final p = calcularPresupuesto(
              peticionPara(categoria, fase, piscina),
            );

            expect(
              categoria.volumenPorSesion.contiene(p.volumenPorSesion),
              isTrue,
              reason:
                  '${p.volumenPorSesion} m fuera de '
                  '${categoria.volumenPorSesion}',
            );
          });

          test('$etiqueta: el reparto por zonas cierra exacto', () {
            final p = calcularPresupuesto(
              peticionPara(categoria, fase, piscina),
            );

            final suma = p.metrosPorZona.values.fold(0, (a, b) => a + b);
            expect(suma, p.volumenTotal);
          });

          test('$etiqueta: el reparto por sesión cierra exacto', () {
            final p = calcularPresupuesto(
              peticionPara(categoria, fase, piscina),
            );

            expect(p.metrosPorSesion.fold(0, (a, b) => a + b), p.volumenTotal);
            expect(p.metrosPorSesion, hasLength(categoria.sesionesPorSemana));
          });

          test('$etiqueta: toda cantidad es múltiplo de la piscina', () {
            final p = calcularPresupuesto(
              peticionPara(categoria, fase, piscina),
            );

            for (final metros in p.metrosPorZona.values) {
              expect(metros % piscina, 0, reason: '$metros m no es múltiplo');
            }
            for (final metros in p.metrosPorSesion) {
              expect(metros % piscina, 0);
            }
            expect(p.metrosTecnicos % piscina, 0);
          });

          if (fase != null) {
            test('$etiqueta: ninguna zona se desvía más que la tolerancia', () {
              final p = calcularPresupuesto(
                peticionPara(categoria, fase, piscina),
              );

              for (final zona in Zona.values) {
                final real = p.porcentajeDe(zona);
                final prescrito = fase.prescritoPara(zona).toDouble();
                expect(
                  Tolerancia.predeterminada.admite(real - prescrito),
                  isTrue,
                  reason:
                      '${zona.abreviatura}: '
                      '${real.toStringAsFixed(2)}% frente a $prescrito%',
                );
              }
            });

            test('$etiqueta: el técnico coincide con el de la fase', () {
              final p = calcularPresupuesto(
                peticionPara(categoria, fase, piscina),
              );

              expect(
                Tolerancia.predeterminada.admite(
                  p.porcentajeTecnico - fase.porcentajeTecnico,
                ),
                isTrue,
                reason:
                    '${p.porcentajeTecnico.toStringAsFixed(2)}% frente a '
                    '${fase.porcentajeTecnico}%',
              );
            });
          }
        }
      }
    }
  });

  group('reparto de estilos', () {
    test('con objetivo Libre, cae dentro de 80-85% y 15-20%', () {
      final p = calcularPresupuesto(
        peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
      );

      final pctLibre = p.porcentajeDeEstilo(Estilo.libre);
      final pctEspalda = p.porcentajeDeEstilo(Estilo.espalda);

      expect(pctLibre, greaterThanOrEqualTo(80));
      expect(pctLibre, lessThanOrEqualTo(85));
      expect(pctEspalda, greaterThanOrEqualTo(15));
      expect(pctEspalda, lessThanOrEqualTo(20));
    });

    test('la suma de estilos es el volumen total', () {
      final p = calcularPresupuesto(
        peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
      );

      expect(p.metrosPorEstilo.values.fold(0, (a, b) => a + b), p.volumenTotal);
    });

    test('con objetivo Pecho, reparte mitad y mitad', () {
      final peticion = peticionPara(
        Categoria.precompetitivo,
        FaseAtr.acumulacion,
        25,
      ).copiarCon(estiloObjetivo: Estilo.pecho);

      final p = calcularPresupuesto(peticion);

      expect(p.porcentajeDeEstilo(Estilo.pecho), closeTo(50, 1));
    });
  });

  group('categorías sin ATR', () {
    test('Iniciación trabaja todo el volumen en A1', () {
      final p = calcularPresupuesto(
        peticionPara(Categoria.iniciacion, null, 25),
      );

      expect(p.metrosPorZona[Zona.a1], p.volumenTotal);
      expect(p.metrosPorZona[Zona.at], 0);
    });

    test('Tecnificación da 900 m por sesión y dos sesiones', () {
      final p = calcularPresupuesto(
        peticionPara(Categoria.tecnificacion, null, 25),
      );

      expect(p.volumenPorSesion, 900);
      expect(p.sesiones, 2);
      expect(p.volumenTotal, 1800);
    });
  });

  group('determinismo del presupuesto', () {
    test('la misma petición da el mismo presupuesto', () {
      final peticion = peticionPara(
        Categoria.competitivo,
        FaseAtr.transformacion,
        25,
      );

      final uno = calcularPresupuesto(peticion);
      final dos = calcularPresupuesto(peticion);

      expect(uno.metrosPorZona, dos.metrosPorZona);
      expect(uno.metrosPorSesion, dos.metrosPorSesion);
      expect(uno.metrosTecnicos, dos.metrosTecnicos);
    });
  });
}
