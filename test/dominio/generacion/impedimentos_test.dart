import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

import '../notacion/ayuda_pruebas.dart';

/// Historia US3: la app no entrega nunca un plan que incumple.
///
/// La regla R3 de la metodología prohíbe planificar con datos faltantes. Un
/// generador que rellena huecos con suposiciones produce planes que parecen
/// válidos y no lo son, que es peor que no generar.
void main() {
  late Generador generador;

  setUpAll(() {
    generador = Generador(
      biblioteca: cargarBibliotecaReal(),
      indice: cargarIndiceReal(),
    );
  });

  PeticionGeneracion valida() => PeticionGeneracion(
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '100 Libre',
    faseAtr: FaseAtr.acumulacion,
    componenteAcentuado: 'Técnica de eficiencia',
    diasDisponibles: [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 7),
      DateTime(2026, 10, 9),
    ],
    longitudPiscina: 25,
    duracionSesionMinutos: 120,
  );

  GeneracionImposible fallar(PeticionGeneracion peticion) {
    final resultado = generador.generar(peticion);
    expect(
      resultado,
      isA<GeneracionImposible>(),
      reason: 'Debería haber sido imposible generar',
    );
    return resultado as GeneracionImposible;
  }

  group('la petición válida sí genera', () {
    test('para tener un punto de comparación', () {
      expect(generador.generar(valida()), isA<MicrocicloGenerado>());
    });
  });

  group('datos que faltan', () {
    test('sin prueba objetivo no genera', () {
      final fallo = fallar(valida().copiarCon(pruebaObjetivo: '   '));

      expect(fallo.tiene(TipoImpedimento.datoFaltante), isTrue);
      expect(fallo.resumen, contains('prueba objetivo'));
    });

    test('sin componente acentuado no genera', () {
      final fallo = fallar(valida().copiarCon(componenteAcentuado: ''));

      expect(fallo.tiene(TipoImpedimento.datoFaltante), isTrue);
      expect(fallo.resumen, contains('componente acentuado'));
    });

    test('sin días disponibles no genera', () {
      final fallo = fallar(valida().copiarCon(diasDisponibles: []));

      expect(fallo.tiene(TipoImpedimento.datoFaltante), isTrue);
    });

    test('una categoría con ATR sin fase declarada no genera', () {
      final fallo = fallar(valida().sinFase());

      expect(fallo.tiene(TipoImpedimento.datoFaltante), isTrue);
      expect(fallo.resumen, contains('ATR'));
    });

    test('una longitud de piscina que no es 25 ni 50 no genera', () {
      final fallo = fallar(valida().copiarCon(longitudPiscina: 33));

      expect(fallo.resumen, contains('25 o 50'));
    });
  });

  group('los impedimentos se acumulan', () {
    test('faltando varios datos se devuelven todos a la vez', () {
      final fallo = fallar(
        valida().copiarCon(
          pruebaObjetivo: '',
          componenteAcentuado: '',
          duracionSesionMinutos: 0,
        ),
      );

      expect(
        fallo.impedimentos.length,
        greaterThanOrEqualTo(3),
        reason: 'El entrenador los ve de una vez, no de uno en uno',
      );
    });

    test('cada impedimento nombra el campo que lo origina', () {
      final fallo = fallar(
        valida().copiarCon(pruebaObjetivo: '', componenteAcentuado: ''),
      );

      final campos = fallo.impedimentos.map((i) => i.campo).toSet();
      expect(campos, contains('pruebaObjetivo'));
      expect(campos, contains('componenteAcentuado'));
    });
  });

  group('datos que se contradicen', () {
    test('Precompetitivo con dos días no genera', () {
      final fallo = fallar(
        valida().copiarCon(
          diasDisponibles: [DateTime(2026, 10, 5), DateTime(2026, 10, 7)],
        ),
      );

      expect(fallo.tiene(TipoImpedimento.frecuenciaImposible), isTrue);
      expect(fallo.resumen, contains('3 sesiones'));
    });

    test('los festivos cuentan para la contradicción', () {
      final fallo = fallar(
        valida().copiarCon(fechasSinServicio: [DateTime(2026, 10, 7)]),
      );

      expect(fallo.tiene(TipoImpedimento.frecuenciaImposible), isTrue);
      expect(fallo.resumen, contains('festivos'));
    });

    test('una categoría sin ATR con fase declarada no genera', () {
      final fallo = fallar(
        valida().copiarCon(
          categoria: Categoria.iniciacion,
          diasDisponibles: [DateTime(2026, 10, 5), DateTime(2026, 10, 7)],
        ),
      );

      expect(fallo.tiene(TipoImpedimento.faseNoAdmisible), isTrue);
      expect(fallo.resumen, contains('no usa el modelo ATR'));
    });

    test('una sesión demasiado corta no genera', () {
      final fallo = fallar(valida().copiarCon(duracionSesionMinutos: 20));

      expect(fallo.tiene(TipoImpedimento.duracionInsuficiente), isTrue);
      expect(fallo.resumen, contains('1800 m'));
    });

    test('acentuar velocidad en Acumulación no genera', () {
      final fallo = fallar(
        valida().copiarCon(componenteAcentuado: 'Velocidad específica'),
      );

      expect(fallo.tiene(TipoImpedimento.componenteIncoherente), isTrue);
    });

    test('pero sí en Realización, que le asigna volumen', () {
      final peticion = valida().copiarCon(
        faseAtr: FaseAtr.realizacion,
        componenteAcentuado: 'Velocidad específica',
      );

      expect(generador.generar(peticion), isA<MicrocicloGenerado>());
    });
  });

  group('nada queda a medias (invariante 15)', () {
    test('un resultado imposible no trae plan', () {
      final resultado = generador.generar(
        valida().copiarCon(pruebaObjetivo: ''),
      );

      expect(resultado, isA<GeneracionImposible>());
      expect(
        resultado,
        isNot(isA<MicrocicloGenerado>()),
        reason: 'Es una de dos cosas, nunca las dos',
      );
    });

    test('la explicación trae números concretos', () {
      final fallo = fallar(
        valida().copiarCon(
          diasDisponibles: [DateTime(2026, 10, 5), DateTime(2026, 10, 7)],
        ),
      );

      expect(
        fallo.resumen,
        contains('2 disponibles'),
        reason: 'No basta decir que falla: hay que decir cuánto falta',
      );
    });
  });

  group('supuestos marcados', () {
    test('el plan generado declara la estimación de ritmo', () {
      final resultado = generador.generar(valida()) as MicrocicloGenerado;

      expect(resultado.supuestos, isNotEmpty);
      expect(resultado.supuestos.first.descripcion, contains('Ritmo medio'));
    });
  });

  group('vacíos de biblioteca', () {
    test('un error diagnosticado sin ejercicio se reporta', () {
      final peticion = valida().copiarCon(
        diagnosticoTecnico: ['fatiga mental en competencia'],
      );

      final resultado = generador.generar(peticion) as MicrocicloGenerado;

      expect(
        resultado.vaciosDeBiblioteca,
        isNotEmpty,
        reason: 'Ese error no lo corrige ningún ejercicio de la Biblioteca',
      );
    });

    test('un error que sí tiene ejercicio no genera vacío', () {
      final peticion = valida().copiarCon(
        diagnosticoTecnico: ['agarre del agua'],
      );

      final resultado = generador.generar(peticion) as MicrocicloGenerado;

      expect(resultado.vaciosDeBiblioteca, isEmpty);
    });

    test('el vacío no se sustituye: el plan sigue teniendo técnica', () {
      final peticion = valida().copiarCon(
        diagnosticoTecnico: ['fatiga mental en competencia'],
      );

      final resultado = generador.generar(peticion) as MicrocicloGenerado;

      expect(
        resultado.plan.metrosTecnicos,
        greaterThan(0),
        reason: 'Se reporta el vacío, pero la sesión no se queda sin técnica',
      );
    });
  });
}
