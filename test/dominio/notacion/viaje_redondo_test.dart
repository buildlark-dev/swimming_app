import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';
import 'package:natacion_app/dominio/notacion/renderizador.dart';

import 'ayuda_pruebas.dart';

/// El viaje redondo: generar → renderizar → releer → comparar.
///
/// Es la prueba que demuestra que el texto que el entrenador ve corresponde a
/// lo que el generador calculó. **Si falla, el entrenador vería una cosa y la
/// auditoría evaluaría otra**, que es justo lo que el principio I prohíbe.
void main() {
  late Generador generador;
  late Analizador analizador;
  const renderizador = Renderizador();

  setUpAll(() {
    final biblioteca = cargarBibliotecaReal();
    generador = Generador(biblioteca: biblioteca, indice: cargarIndiceReal());
    analizador = Analizador(biblioteca: biblioteca);
  });

  PeticionGeneracion peticionPara(
    Categoria categoria,
    FaseAtr? fase,
    int piscina,
  ) {
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
    );
  }

  group('una serie renderizada se relee igual', () {
    test('nado completo con zona', () {
      const serie = Serie(distancia: 300, estilo: Estilo.libre);
      final texto = renderizador.serie(serie);
      final leida = analizador.analizar(texto);

      expect(leida.metros, 300);
      expect(leida.pendientes, isEmpty, reason: texto);
    });

    test('repeticiones con implementos y tiempo', () {
      const serie = Serie(
        repeticiones: 4,
        distancia: 100,
        implementos: [Implemento.aletas, Implemento.snorkel],
        modificadores: [Modificador.patada],
        tiempoSalida: Duration(minutes: 2),
        estilo: Estilo.libre,
      );

      final texto = renderizador.serie(serie);
      final leida = analizador.analizar(texto);

      expect(leida.metros, 400, reason: texto);
      expect(leida.pendientes, isEmpty, reason: texto);

      final recuperada = leida.series.first;
      expect(recuperada.repeticiones, 4);
      expect(recuperada.distancia, 100);
      expect(recuperada.implementos, contains(Implemento.aletas));
      expect(recuperada.implementos, contains(Implemento.snorkel));
      expect(recuperada.modificadores, contains(Modificador.patada));
      expect(recuperada.tiempoSalida, const Duration(minutes: 2));
    });

    test('un tiempo con minutos y segundos', () {
      const serie = Serie(
        repeticiones: 6,
        distancia: 100,
        tiempoSalida: Duration(minutes: 1, seconds: 40),
        estilo: Estilo.libre,
      );

      final leida = analizador.analizar(renderizador.serie(serie));

      expect(
        leida.series.first.tiempoSalida,
        const Duration(minutes: 1, seconds: 40),
      );
    });

    test('un hipóxico conserva cada cuántas brazadas', () {
      const serie = Serie(
        repeticiones: 4,
        distancia: 50,
        modificadores: [Modificador.hipoxico],
        respiracionCada: 5,
        estilo: Estilo.libre,
      );

      final leida = analizador.analizar(renderizador.serie(serie));

      expect(leida.series.first.respiracionCada, 5);
    });
  });

  group('los casos que dieron problemas en la feature 001', () {
    test('un ejercicio ambiguo se escribe con su estilo', () {
      final biblioteca = cargarBibliotecaReal();
      final flecha = biblioteca.todos.firstWhere(
        (e) => e.nombreBase == 'FLECHA' && e.requiereDesambiguacion,
      );

      final serie = Serie(
        distancia: 200,
        ejercicio: flecha,
        estilo: flecha.estilo,
      );
      final texto = renderizador.serie(serie);
      final leida = analizador.analizar(texto);

      expect(texto, contains('('));
      expect(
        leida.pendientes,
        isEmpty,
        reason: 'El texto "$texto" no debe dejar ambigüedad',
      );
    });

    test('un nombre con + se relee entero', () {
      final biblioteca = cargarBibliotecaReal();
      final conMas = biblioteca.todos.firstWhere(
        (e) => e.nombreBase.contains('+'),
      );

      final serie = Serie(
        distancia: 200,
        ejercicio: conMas,
        estilo: conMas.estilo,
      );
      final leida = analizador.analizar(renderizador.serie(serie));

      expect(leida.metros, 200);
    });

    test('una etiqueta de bloque técnico se relee como tal', () {
      const serie = Serie(
        distancia: 300,
        bloqueTecnico: Estilo.libre,
        estilo: Estilo.libre,
      );

      final texto = renderizador.serie(serie);
      final leida = analizador.analizar(texto);

      expect(texto, contains('TEC L'));
      expect(leida.pendientes, isEmpty);
      expect(leida.series.first.esTecnica, isTrue);
    });

    test('los nombres de nado son los permitidos', () {
      for (final estilo in [
        Estilo.libre,
        Estilo.espalda,
        Estilo.pecho,
        Estilo.mariposa,
      ]) {
        final serie = Serie(distancia: 200, estilo: estilo);
        final texto = renderizador.serie(serie);

        expect(texto, contains('Nado ${estilo.nombre}'));
        expect(analizador.analizar(texto).pendientes, isEmpty);
      }
    });
  });

  group('el viaje redondo de un microciclo completo', () {
    for (final categoria in Categoria.values) {
      final fase = categoria.usaAtr ? FaseAtr.acumulacion : null;

      for (final piscina in [25, 50]) {
        final etiqueta = '${categoria.nombre} · piscina $piscina';

        test('$etiqueta: los metros coinciden, 0 m de diferencia', () {
          final resultado = generador.generar(
            peticionPara(categoria, fase, piscina),
          );
          final plan = (resultado as MicrocicloGenerado).plan;

          for (final sesion in plan.sesiones) {
            for (final parte in sesion.partes) {
              if (parte.series.isEmpty) continue;

              final texto = renderizador.series(parte.series);
              final releida = analizador.analizar(texto);

              expect(
                releida.metros,
                parte.metros,
                reason: '$etiqueta, parte ${parte.tipo.nombre}:\n$texto',
              );
            }
          }
        });

        test('$etiqueta: no queda ningún fragmento pendiente', () {
          final resultado = generador.generar(
            peticionPara(categoria, fase, piscina),
          );
          final plan = (resultado as MicrocicloGenerado).plan;

          for (final sesion in plan.sesiones) {
            for (final parte in sesion.partes) {
              if (parte.series.isEmpty) continue;

              final texto = renderizador.series(parte.series);
              final releida = analizador.analizar(texto);

              expect(
                releida.pendientes,
                isEmpty,
                reason:
                    '$etiqueta:\n$texto\n'
                    '${releida.pendientes.map((p) => p.toString()).join('\n')}',
              );
            }
          }
        });

        test('$etiqueta: las zonas se conservan', () {
          final resultado = generador.generar(
            peticionPara(categoria, fase, piscina),
          );
          final plan = (resultado as MicrocicloGenerado).plan;

          for (final sesion in plan.sesiones) {
            for (final parte in sesion.partes) {
              if (parte.series.isEmpty) continue;

              final releida = analizador.analizar(
                renderizador.series(parte.series),
              );

              final originales = parte.series.map((s) => s.zona).toList();
              final recuperadas = releida.series.map((s) => s.zona).toList();

              expect(recuperadas, originales, reason: etiqueta);
            }
          }
        });
      }
    }
  });

  group('el texto original de la sesión es el renderizado', () {
    test('cada parte guarda su texto listo para el editor', () {
      final resultado = generador.generar(
        peticionPara(Categoria.precompetitivo, FaseAtr.acumulacion, 25),
      );
      final plan = (resultado as MicrocicloGenerado).plan;

      for (final sesion in plan.sesiones) {
        for (final parte in sesion.partes) {
          if (parte.series.isEmpty) continue;

          expect(
            parte.textoOriginal,
            isNotEmpty,
            reason: 'El editor necesita el texto para mostrarlo',
          );
          expect(analizador.analizar(parte.textoOriginal).metros, parte.metros);
        }
      }
    });
  });
}
