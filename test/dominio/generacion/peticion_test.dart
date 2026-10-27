import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/ritmos.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

/// Campos de `PeticionGeneracion` según `data-model.md`, y la estimación de
/// duración de `ritmos.dart`.
void main() {
  PeticionGeneracion base({
    Categoria categoria = Categoria.precompetitivo,
    List<DateTime>? dias,
    List<DateTime> sinServicio = const [],
    List<String> diagnostico = const [],
  }) {
    return PeticionGeneracion(
      categoria: categoria,
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '100 Libre',
      faseAtr: categoria.usaAtr ? FaseAtr.acumulacion : null,
      componenteAcentuado: 'Técnica de eficiencia',
      diasDisponibles:
          dias ??
          [DateTime(2026, 10, 5), DateTime(2026, 10, 7), DateTime(2026, 10, 9)],
      fechasSinServicio: sinServicio,
      longitudPiscina: 25,
      duracionSesionMinutos: 90,
      diagnosticoTecnico: diagnostico,
    );
  }

  group('días efectivos', () {
    test('sin festivos son todos los declarados', () {
      expect(base().diasEfectivos, hasLength(3));
    });

    test('un festivo descuenta un día', () {
      final peticion = base(sinServicio: [DateTime(2026, 10, 7)]);
      expect(peticion.diasEfectivos, hasLength(2));
    });

    test('un festivo fuera de la semana no descuenta nada', () {
      final peticion = base(sinServicio: [DateTime(2026, 12, 25)]);
      expect(peticion.diasEfectivos, hasLength(3));
    });

    test('compara por día, no por hora', () {
      final peticion = base(sinServicio: [DateTime(2026, 10, 7, 18, 30)]);
      expect(peticion.diasEfectivos, hasLength(2));
    });
  });

  group('diagnóstico', () {
    test('sin diagnóstico se declara como tal', () {
      expect(base().tieneDiagnostico, isFalse);
    });

    test('con diagnóstico se declara como tal', () {
      expect(base(diagnostico: ['agarre del agua']).tieneDiagnostico, isTrue);
    });
  });

  group('huella: misma petición, misma huella', () {
    test('dos peticiones iguales tienen la misma huella', () {
      expect(base().huella, base().huella);
    });

    test('cambiar el componente acentuado cambia la huella', () {
      final otra = base().copiarCon(componenteAcentuado: 'Ritmo competitivo');
      expect(otra.huella, isNot(base().huella));
    });

    test('cambiar la categoría cambia la huella', () {
      expect(
        base(categoria: Categoria.competitivo).huella,
        isNot(base().huella),
      );
    });

    test('un festivo cambia la huella porque cambia los días efectivos', () {
      final otra = base(sinServicio: [DateTime(2026, 10, 7)]);
      expect(otra.huella, isNot(base().huella));
    });
  });

  group('fase ATR', () {
    test('las categorías con ATR la llevan', () {
      expect(base().faseAtr, FaseAtr.acumulacion);
    });

    test('sinFase la quita, porque copiarCon no puede poner nulo', () {
      expect(base().sinFase().faseAtr, isNull);
    });

    test('las categorías sin ATR nacen sin fase', () {
      expect(base(categoria: Categoria.iniciacion).faseAtr, isNull);
    });
  });

  group('estimación de duración', () {
    test('2.000 m no caben en 20 minutos en Precompetitivo', () {
      const estimacion = EstimacionDuracion(Categoria.precompetitivo);
      expect(estimacion.cabe(2000, 20), isFalse);
    });

    test('2.000 m sí caben en 90 minutos en Precompetitivo', () {
      const estimacion = EstimacionDuracion(Categoria.precompetitivo);
      expect(estimacion.cabe(2000, 90), isTrue);
    });

    test('cada categoría tiene su ritmo declarado', () {
      for (final categoria in Categoria.values) {
        expect(
          ritmoMedioMetrosPorMinuto[categoria],
          isNotNull,
          reason: 'Falta el ritmo de ${categoria.nombre}',
        );
      }
    });

    test('el ritmo crece con la categoría', () {
      expect(
        ritmoMedioMetrosPorMinuto[Categoria.iniciacion]!,
        lessThan(ritmoMedioMetrosPorMinuto[Categoria.altoRendimiento]!),
      );
    });

    test('el supuesto está descrito para poder mostrarlo', () {
      expect(descripcionDelSupuesto, contains('No es una regla'));
    });
  });
}
