import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/calculo/agregacion_plan.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

import '../notacion/ayuda_pruebas.dart';

/// Escenario G14 de `quickstart.md` — criterio SC-009.
///
/// Compara lo generado contra un microciclo **real** del entrenador: la semana
/// del 04 al 08 de agosto del `Macrociclo - Precompetitivo Agosto`, hoja
/// «Sem 04-08 Ago».
///
/// **Se comparan rangos, no contenido.** No se espera que la app reproduzca
/// sus ejercicios: se espera que no se salga de donde él se mueve. Si lo
/// generado queda fuera de sus márgenes, o el generador está mal o la
/// tolerancia está mal calibrada.
void main() {
  late Generador generador;

  setUpAll(() {
    generador = Generador(
      biblioteca: cargarBibliotecaReal(),
      indice: cargarIndiceReal(),
    );
  });

  // Datos del microciclo real, leídos de la hoja del entrenador.
  const metrosPorSesionReal = 1900;
  const sesionesReales = 3;
  const totalSemanaReal = 5700;
  const faseReal = FaseAtr.acumulacion;
  const categoriaReal = Categoria.precompetitivo;

  PeticionGeneracion equivalente() => PeticionGeneracion(
    categoria: categoriaReal,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '800 Libre',
    faseAtr: faseReal,
    componenteAcentuado: 'Técnica de eficiencia y base aeróbica',
    diasDisponibles: [
      DateTime(2026, 8, 4),
      DateTime(2026, 8, 6),
      DateTime(2026, 8, 8),
    ],
    longitudPiscina: 25,
    duracionSesionMinutos: 90,
  );

  group('el microciclo real sirve de patrón', () {
    test('sus datos son los que declara la hoja', () {
      expect(metrosPorSesionReal * sesionesReales, totalSemanaReal);
      expect(
        categoriaReal.volumenPorSesion.contiene(metrosPorSesionReal),
        isTrue,
        reason: 'El microciclo real del entrenador cumple su propia categoría',
      );
      expect(categoriaReal.sesionesPorSemana, sesionesReales);
    });
  });

  group('lo generado cae en los márgenes del entrenador', () {
    test('mismo número de sesiones', () {
      final resultado = generador.generar(equivalente()) as MicrocicloGenerado;
      expect(resultado.plan.sesiones, hasLength(sesionesReales));
    });

    test('el volumen por sesión cae en el mismo rango de categoría', () {
      final resultado = generador.generar(equivalente()) as MicrocicloGenerado;

      for (final sesion in resultado.plan.sesiones) {
        expect(
          categoriaReal.volumenPorSesion.contiene(sesion.metros),
          isTrue,
          reason:
              'El entrenador nada $metrosPorSesionReal m por sesión; '
              'la app propone ${sesion.metros} m',
        );
      }
    });

    test('la diferencia con su volumen no pasa del 15%', () {
      final resultado = generador.generar(equivalente()) as MicrocicloGenerado;
      final generado = resultado.plan.sesiones.first.metros;

      final diferencia =
          (generado - metrosPorSesionReal).abs() * 100 / metrosPorSesionReal;

      expect(
        diferencia,
        lessThanOrEqualTo(15),
        reason:
            'Generado $generado m frente a los $metrosPorSesionReal m '
            'reales: ${diferencia.toStringAsFixed(1)}% de diferencia',
      );
    });

    test('el trabajo técnico ronda el 50% que él declara en su hoja', () {
      final resultado = generador.generar(equivalente()) as MicrocicloGenerado;

      // La hoja del entrenador declara «téc ~50%» en el total de cada sesión.
      expect(
        resultado.plan.porcentajeTecnico,
        closeTo(50, 5),
        reason: 'Su hoja declara técnica ~50% para esta fase',
      );
    });

    test('predomina el Libre en el volumen de nado, como en su semana', () {
      final resultado = generador.generar(equivalente()) as MicrocicloGenerado;
      final agregacion = AgregacionPlan(resultado.plan);

      final metrosLibre = agregacion.metrosPorEstilo[Estilo.libre] ?? 0;
      final porcentaje = metrosLibre * 100 / resultado.plan.metros;

      expect(
        porcentaje,
        greaterThanOrEqualTo(75),
        reason: 'Su serie central es «Libre dominante»',
      );
    });

    test('la distribución de zonas es la de Acumulación', () {
      final resultado = generador.generar(equivalente()) as MicrocicloGenerado;
      final agregacion = AgregacionPlan(resultado.plan);

      // Su hoja marca las sesiones como A1 y A1-A2: predominio aeróbico bajo.
      final pctA1 =
          agregacion.porcentajePorZona[agregacion
              .porcentajePorZona
              .keys
              .first] ??
          0;

      expect(
        pctA1,
        greaterThan(50),
        reason: 'Sus sesiones de Acumulación son A1 dominante',
      );
    });
  });

  group('lo generado es aprobable sin retoques', () {
    test('ninguna sesión queda incompleta', () {
      final resultado = generador.generar(equivalente()) as MicrocicloGenerado;

      for (final sesion in resultado.plan.sesiones) {
        expect(
          sesion.estaCompleta,
          isTrue,
          reason: sesion.faltas.map((f) => f.descripcion).join(', '),
        );
      }
    });

    test('cabe en los 90 minutos de sesión que él declara', () {
      expect(
        generador.generar(equivalente()),
        isA<MicrocicloGenerado>(),
        reason: 'Si esto falla, la estimación de ritmo está mal calibrada',
      );
    });
  });
}
