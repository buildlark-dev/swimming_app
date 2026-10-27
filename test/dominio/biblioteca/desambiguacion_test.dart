import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';

import '../notacion/ayuda_pruebas.dart';

/// Regla de desambiguación (sección 7): algunos ejercicios comparten nombre
/// entre estilos. Al usarlos hay que indicar el estilo entre paréntesis.
void main() {
  late Analizador analizador;
  late Biblioteca biblioteca;

  setUpAll(() {
    biblioteca = cargarBibliotecaReal();
    analizador = Analizador(biblioteca: biblioteca);
  });

  group('nombres que se repiten entre estilos', () {
    test('FLECHA sin estilo es ambiguo', () {
      final resultado = biblioteca.buscar('FLECHA');

      expect(resultado, isA<EjercicioAmbiguo>());
      final ambiguo = resultado as EjercicioAmbiguo;
      expect(
        ambiguo.estilosPosibles.length,
        greaterThanOrEqualTo(2),
        reason: 'FLECHA existe en varios estilos',
      );
    });

    test('FLECHA (Espalda) se resuelve sin ambigüedad', () {
      final resultado = biblioteca.buscar('FLECHA (Espalda)');

      expect(resultado, isA<EjercicioEncontrado>());
      final encontrado = resultado as EjercicioEncontrado;
      expect(encontrado.ejercicio.estilo, Estilo.espalda);
    });

    test('FLECHA con el estilo aparte también se resuelve', () {
      final resultado = biblioteca.buscar('FLECHA', estilo: Estilo.pecho);

      expect(resultado, isA<EjercicioEncontrado>());
      expect((resultado as EjercicioEncontrado).ejercicio.estilo, Estilo.pecho);
    });

    test('ROLIDO sin estilo es ambiguo', () {
      expect(biblioteca.buscar('ROLIDO'), isA<EjercicioAmbiguo>());
    });

    test('ROLIDO CON 1 BRAZO sin estilo es ambiguo', () {
      expect(biblioteca.buscar('ROLIDO CON 1 BRAZO'), isA<EjercicioAmbiguo>());
    });

    test('un ejercicio de un solo estilo no exige desambiguación', () {
      // VADEO solo existe en Libre.
      expect(biblioteca.buscar('VADEO'), isA<EjercicioEncontrado>());
    });
  });

  group('el analizador marca la ambigüedad como pendiente', () {
    test('una serie con FLECHA sin estilo queda pendiente', () {
      final resultado = analizador.analizar('200 FLECHA');

      expect(resultado.pendientes, hasLength(1));
      expect(resultado.pendientes.first.motivo, MotivoPendiente.ambiguo);
    });

    test(
      'el aviso dice en qué estilos existe, sin elegir por el entrenador',
      () {
        final resultado = analizador.analizar('200 FLECHA');

        final detalle = resultado.pendientes.first.detalle;
        expect(detalle, contains('Indique el estilo'));
        expect(detalle.toLowerCase(), contains('libre'));
      },
    );

    test('con el estilo indicado no queda pendiente', () {
      final resultado = analizador.analizar('200 E FLECHA');

      expect(
        resultado.pendientes,
        isEmpty,
        reason: 'El estilo E (Espalda) resuelve la ambigüedad',
      );
      expect(resultado.series.first.ejercicio?.estilo, Estilo.espalda);
    });

    test('los metros se cuentan aunque el ejercicio quede ambiguo', () {
      final resultado = analizador.analizar('4x50 FLECHA');
      expect(resultado.metros, 200);
    });
  });

  group('forma de escritura en el plan', () {
    test('un ejercicio ambiguo se guarda con el estilo entre paréntesis', () {
      final resultado = biblioteca.buscar('FLECHA', estilo: Estilo.espalda);
      final ejercicio = (resultado as EjercicioEncontrado).ejercicio;

      expect(ejercicio.nombreParaPlan, 'FLECHA (Espalda)');
      expect(ejercicio.requiereDesambiguacion, isTrue);
    });

    test('un ejercicio único se guarda sin paréntesis', () {
      final resultado = biblioteca.buscar('VADEO');
      final ejercicio = (resultado as EjercicioEncontrado).ejercicio;

      expect(ejercicio.nombreParaPlan, 'VADEO');
      expect(ejercicio.requiereDesambiguacion, isFalse);
    });
  });
}
