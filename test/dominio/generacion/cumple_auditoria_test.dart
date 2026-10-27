import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

import '../notacion/ayuda_pruebas.dart';

/// **La prueba que justifica la feature.**
///
/// El principio III, en su versión 1.1.0, exige que todo plan generado tenga
/// pruebas que demuestren que cumple la auditoría **por construcción, no por
/// casualidad**. Esto es eso.
void main() {
  late Generador generador;

  setUpAll(() {
    generador = Generador(
      biblioteca: cargarBibliotecaReal(),
      indice: cargarIndiceReal(),
    );
  });

  PeticionGeneracion peticionPara(
    Categoria categoria,
    FaseAtr? fase,
    int piscina, {
    List<String> diagnostico = const [],
  }) {
    final dias = categoria.sesionesPorSemana > 7
        ? (categoria.sesionesPorSemana / 2).ceil()
        : categoria.sesionesPorSemana;

    return PeticionGeneracion(
      categoria: categoria,
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '100 Libre',
      faseAtr: fase,
      componenteAcentuado: 'Técnica de eficiencia',
      diasDisponibles: List.generate(dias, (i) => DateTime(2026, 10, 5 + i)),
      longitudPiscina: piscina,
      duracionSesionMinutos: 240,
      diagnosticoTecnico: diagnostico,
    );
  }

  Plan generarPlan(PeticionGeneracion peticion) {
    final resultado = generador.generar(peticion);
    expect(
      resultado,
      isA<MicrocicloGenerado>(),
      reason: resultado is GeneracionImposible ? resultado.resumen : '',
    );
    return (resultado as MicrocicloGenerado).plan;
  }

  group('un plan generado nace como debe', () {
    test('en estado borrador', () {
      final plan = generarPlan(
        peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
      );
      expect(plan.estado, EstadoPlan.borrador);
    });

    test('marcado como generado automáticamente', () {
      final plan = generarPlan(
        peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
      );
      expect(plan.origen, OrigenPlan.automatico);
      expect(plan.origen.fueGenerado, isTrue);
    });

    test('con tantas sesiones como su categoría prescribe', () {
      for (final categoria in Categoria.values) {
        final plan = generarPlan(
          peticionPara(
            categoria,
            categoria.usaAtr ? FaseAtr.acumulacion : null,
            25,
          ),
        );

        expect(
          plan.sesiones,
          hasLength(categoria.sesionesPorSemana),
          reason: categoria.nombre,
        );
      }
    });

    test('con el microciclo nombrado por el componente acentuado', () {
      final plan = generarPlan(
        peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
      );

      expect(plan.microciclos.single.nombre, 'Técnica de eficiencia');
      expect(plan.microciclos.single.nombraElObjetivoReal, isTrue);
    });
  });

  group('cumple la auditoría por construcción', () {
    for (final categoria in Categoria.values) {
      final fases = categoria.usaAtr ? FaseAtr.values : <FaseAtr?>[null];

      for (final fase in fases) {
        for (final piscina in [25, 50]) {
          final etiqueta =
              '${categoria.nombre} · '
              '${fase?.nombre ?? 'sin ATR'} · piscina $piscina';

          test('$etiqueta: ningún criterio bloqueante en rojo', () {
            final plan = generarPlan(peticionPara(categoria, fase, piscina));
            final resultado = Auditoria().evaluar(plan);

            expect(
              resultado.bloqueantesEnRojo,
              isEmpty,
              reason: resultado.bloqueantesEnRojo
                  .map((c) => c.toString())
                  .join('\n'),
            );
          });

          test('$etiqueta: se evalúan los once criterios', () {
            final plan = generarPlan(peticionPara(categoria, fase, piscina));
            expect(Auditoria().evaluar(plan).criterios, hasLength(11));
          });
        }
      }
    }
  });

  group('las reglas absolutas nunca ceden', () {
    test('todas las series tienen zona asignada (invariante 9)', () {
      for (final categoria in Categoria.values) {
        final plan = generarPlan(
          peticionPara(
            categoria,
            categoria.usaAtr ? FaseAtr.transformacion : null,
            25,
          ),
        );

        for (final sesion in plan.sesiones) {
          for (final serie in sesion.todasLasSeries) {
            expect(
              serie.zona,
              isNotNull,
              reason: '${categoria.nombre}: serie sin zona',
            );
          }
        }
      }
    });

    test('ningún ejercicio queda fuera de la Biblioteca (invariante 10)', () {
      final plan = generarPlan(
        peticionPara(Categoria.competitivo, FaseAtr.realizacion, 25),
      );

      for (final sesion in plan.sesiones) {
        expect(
          sesion.todosLosPendientes,
          isEmpty,
          reason: 'Una sesión generada no puede tener fragmentos pendientes',
        );
      }
    });

    test('toda sesión está completa (invariante 11)', () {
      final plan = generarPlan(
        peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
      );

      for (final sesion in plan.sesiones) {
        expect(
          sesion.estaCompleta,
          isTrue,
          reason: sesion.faltas.map((f) => f.descripcion).join(', '),
        );
      }
    });

    test('el volumen de cada sesión cae en el rango de la categoría', () {
      for (final categoria in Categoria.values) {
        final plan = generarPlan(
          peticionPara(
            categoria,
            categoria.usaAtr ? FaseAtr.acumulacion : null,
            25,
          ),
        );

        for (final sesion in plan.sesiones) {
          expect(
            categoria.volumenPorSesion.contiene(sesion.metros),
            isTrue,
            reason:
                '${categoria.nombre}: ${sesion.metros} m fuera de '
                '${categoria.volumenPorSesion}',
          );
        }
      }
    });

    test('toda distancia es múltiplo de la piscina', () {
      for (final piscina in [25, 50]) {
        final plan = generarPlan(
          peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, piscina),
        );

        for (final sesion in plan.sesiones) {
          for (final serie in sesion.todasLasSeries) {
            expect(serie.distancia % piscina, 0);
          }
        }
      }
    });
  });

  group('determinismo (FR-024)', () {
    test('la misma petición produce el mismo plan', () {
      final peticion = peticionPara(
        Categoria.precompetitivo,
        FaseAtr.acumulacion,
        25,
      );

      final uno = generarPlan(peticion);
      final dos = generarPlan(peticion);

      expect(uno.metros, dos.metros);
      expect(uno.sesiones.length, dos.sesiones.length);

      for (var i = 0; i < uno.sesiones.length; i++) {
        expect(
          uno.sesiones[i].todasLasSeries.map((s) => s.toString()).toList(),
          dos.sesiones[i].todasLasSeries.map((s) => s.toString()).toList(),
        );
      }
    });

    test('cambiar el componente acentuado cambia el plan', () {
      final base = peticionPara(
        Categoria.precompetitivo,
        FaseAtr.acumulacion,
        25,
      );
      final otra = base.copiarCon(componenteAcentuado: 'Ritmo competitivo');

      expect(
        generarPlan(otra).microciclos.single.nombre,
        isNot(generarPlan(base).microciclos.single.nombre),
      );
    });
  });

  group('lesiones: avisan, no modifican', () {
    test('el plan con lesión declarada es idéntico al de sin ella', () {
      final sinLesion = peticionPara(
        Categoria.precompetitivo,
        FaseAtr.acumulacion,
        25,
      );
      final conLesion = sinLesion.copiarCon(lesiones: ['dolor de hombro']);

      expect(generarPlan(conLesion).metros, generarPlan(sinLesion).metros);
    });

    test('pero aparece como aviso', () {
      final peticion = peticionPara(
        Categoria.precompetitivo,
        FaseAtr.acumulacion,
        25,
      ).copiarCon(lesiones: ['dolor de hombro']);

      final resultado = generador.generar(peticion) as MicrocicloGenerado;

      expect(resultado.avisos, isNotEmpty);
      expect(resultado.avisos.first, contains('dolor de hombro'));
      expect(resultado.avisos.first, contains('NO se adaptó'));
    });
  });

  group('supuestos declarados', () {
    test('la estimación de ritmo se declara como supuesto', () {
      final resultado =
          generador.generar(
                peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
              )
              as MicrocicloGenerado;

      expect(resultado.supuestos, isNotEmpty);
      expect(resultado.supuestos.first.motivo, contains('No es una regla'));
    });
  });
}
