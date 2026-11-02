import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/auditoria/tolerancia.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/presupuesto.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/metodologia/validacion_fase.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

import '../notacion/ayuda_pruebas.dart';

/// Reglas propias de cada categoría y escala de precedencia.
void main() {
  late Generador generador;

  setUpAll(() {
    generador = Generador(
      biblioteca: cargarBibliotecaReal(),
      indice: cargarIndiceReal(),
    );
  });

  PeticionGeneracion peticion({
    required Categoria categoria,
    FaseAtr? fase,
    Estilo estilo = Estilo.libre,
    int piscina = 25,
    int duracion = 240,
    int? dias,
  }) {
    final cuantos =
        dias ??
        (categoria.sesionesPorSemana > 7
            ? (categoria.sesionesPorSemana / 2).ceil()
            : categoria.sesionesPorSemana);

    return PeticionGeneracion(
      categoria: categoria,
      estiloObjetivo: estilo,
      pruebaObjetivo: '100 Libre',
      faseAtr: fase,
      componenteAcentuado: 'Técnica de eficiencia',
      diasDisponibles: List.generate(cuantos, (i) => DateTime(2026, 10, 5 + i)),
      longitudPiscina: piscina,
      duracionSesionMinutos: duracion,
    );
  }

  group('regla de alternancia de Tecnificación', () {
    test('la sesión 1 es de Pecho y la 2 de Mariposa', () {
      final resultado =
          generador.generar(peticion(categoria: Categoria.tecnificacion))
              as MicrocicloGenerado;

      final estilos = resultado.plan.sesiones
          .map((s) => s.todasLasSeries.first.estilo)
          .toList();

      expect(estilos, [Estilo.pecho, Estilo.mariposa]);
    });

    test('el plan generado pasa la regla de alternancia', () {
      final resultado =
          generador.generar(peticion(categoria: Categoria.tecnificacion))
              as MicrocicloGenerado;

      final comprobacion = const ReglaAlternanciaTecnificacion().comprobar(
        resultado.plan,
      );

      expect(comprobacion.valida, isTrue, reason: comprobacion.motivo);
    });

    test('no se le asigna fase ATR', () {
      final resultado =
          generador.generar(peticion(categoria: Categoria.tecnificacion))
              as MicrocicloGenerado;

      expect(resultado.plan.faseAtr, isNull);
      expect(const ValidacionFase().admiteFase(resultado.plan).valida, isTrue);
    });
  });

  group('sesiones dobles en Alto Rendimiento', () {
    test('genera diez sesiones sobre cinco días', () {
      final resultado =
          generador.generar(
                peticion(
                  categoria: Categoria.altoRendimiento,
                  fase: FaseAtr.acumulacion,
                ),
              )
              as MicrocicloGenerado;

      expect(resultado.plan.sesiones, hasLength(10));
    });

    test('cada sesión cae dentro del rango de la categoría', () {
      final resultado =
          generador.generar(
                peticion(
                  categoria: Categoria.altoRendimiento,
                  fase: FaseAtr.acumulacion,
                ),
              )
              as MicrocicloGenerado;

      for (final sesion in resultado.plan.sesiones) {
        expect(
          Categoria.altoRendimiento.volumenPorSesion.contiene(sesion.metros),
          isTrue,
          reason: '${sesion.metros} m',
        );
      }
    });

    test('el microciclo suma 55.000 m', () {
      final resultado =
          generador.generar(
                peticion(
                  categoria: Categoria.altoRendimiento,
                  fase: FaseAtr.acumulacion,
                ),
              )
              as MicrocicloGenerado;

      expect(resultado.plan.metros, 55000);
    });
  });

  group('escala de precedencia: qué cede y qué no', () {
    test('nivel 3: el volumen de la categoría nunca cede', () {
      for (final categoria in Categoria.values) {
        for (final piscina in [25, 50]) {
          final p = calcularPresupuesto(
            peticion(
              categoria: categoria,
              fase: categoria.usaAtr ? FaseAtr.realizacion : null,
              piscina: piscina,
            ),
          );

          expect(
            categoria.volumenPorSesion.contiene(p.volumenPorSesion),
            isTrue,
            reason: '${categoria.nombre} p$piscina: ${p.volumenPorSesion} m',
          );
        }
      }
    });

    test('nivel 2: la estructura 40/50/10 nunca cede', () {
      final resultado =
          generador.generar(
                peticion(
                  categoria: Categoria.precompetitivo,
                  fase: FaseAtr.transformacion,
                ),
              )
              as MicrocicloGenerado;

      for (final sesion in resultado.plan.sesiones) {
        expect(sesion.partes, hasLength(3));
        expect(
          sesion.porcentajeDe(TipoParte.inicial),
          closeTo(40, 3),
          reason: 'La inicial debe rondar el 40%',
        );
        expect(sesion.porcentajeDe(TipoParte.cierre), closeTo(10, 3));
      }
    });

    test('nivel 4: el trabajo técnico no queda por debajo del prescrito', () {
      for (final fase in FaseAtr.values) {
        final p = calcularPresupuesto(
          peticion(categoria: Categoria.precompetitivo, fase: fase),
        );

        expect(
          p.porcentajeTecnico,
          greaterThanOrEqualTo(fase.porcentajeTecnico - 3),
          reason:
              '${fase.nombre}: '
              '${p.porcentajeTecnico.toStringAsFixed(1)}% frente a '
              '${fase.porcentajeTecnico}%',
        );
      }
    });

    test('nivel 5: las zonas ceden, pero dentro de la tolerancia', () {
      for (final fase in FaseAtr.values) {
        final p = calcularPresupuesto(
          peticion(categoria: Categoria.competitivo, fase: fase),
        );

        for (final zona in Zona.values) {
          expect(
            Tolerancia.predeterminada.admite(
              p.porcentajeDe(zona) - fase.prescritoPara(zona),
            ),
            isTrue,
            reason: '${fase.nombre} ${zona.abreviatura}',
          );
        }
      }
    });

    test('nivel 1: ningún plan generado usa un ejercicio ajeno', () {
      for (final fase in FaseAtr.values) {
        final resultado =
            generador.generar(
                  peticion(categoria: Categoria.precompetitivo, fase: fase),
                )
                as MicrocicloGenerado;

        for (final sesion in resultado.plan.sesiones) {
          expect(sesion.todosLosPendientes, isEmpty, reason: fase.nombre);
        }
      }
    });
  });

  group('la ubicación de zonas es preferencia, no imposición', () {
    test('Transformación cuadra aunque A1 no alcance para inicial y final', () {
      // A1 al 30% frente a inicial 40% + final 10% = 50%: la inicial tiene que
      // tomar de A2. Si esto falla, la regla volvió a ser una imposición.
      final resultado =
          generador.generar(
                peticion(
                  categoria: Categoria.precompetitivo,
                  fase: FaseAtr.transformacion,
                ),
              )
              as MicrocicloGenerado;

      expect(resultado.plan.sesiones, isNotEmpty);

      for (final sesion in resultado.plan.sesiones) {
        expect(
          sesion.parteDe(TipoParte.inicial).metros,
          greaterThan(0),
          reason: 'La inicial no puede quedar vacía',
        );
      }
    });

    test('Realización también cuadra', () {
      final resultado =
          generador.generar(
                peticion(
                  categoria: Categoria.precompetitivo,
                  fase: FaseAtr.realizacion,
                ),
              )
              as MicrocicloGenerado;

      expect(resultado.plan.metros, 6000);
    });
  });
}
