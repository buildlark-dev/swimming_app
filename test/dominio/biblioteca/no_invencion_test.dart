import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';

import '../notacion/ayuda_pruebas.dart';

/// Regla R2 de la metodología: no invención.
///
/// Solo pueden usarse ejercicios de la Biblioteca Oficial. Y algo igual de
/// importante: la app **no corrige ni sugiere**. Sugerir un nombre parecido
/// sería inventar por aproximación.
void main() {
  late Analizador analizador;
  late Biblioteca biblioteca;

  setUpAll(() {
    biblioteca = cargarBibliotecaReal();
    analizador = Analizador(biblioteca: biblioteca);
  });

  group('la biblioteca se cargó', () {
    test('tiene ejercicios de los cuatro estilos', () {
      expect(biblioteca.cantidad, greaterThan(50));
      for (final estilo in [
        Estilo.libre,
        Estilo.espalda,
        Estilo.pecho,
        Estilo.mariposa,
      ]) {
        expect(
          biblioteca.porEstilo(estilo),
          isNotEmpty,
          reason: 'No hay ejercicios de ${estilo.nombre}',
        );
      }
    });
  });

  group('rechazo de ejercicios ajenos', () {
    test('un nombre inventado queda fuera de la biblioteca', () {
      final resultado = analizador.analizar('200 AL PATADA DE FUEGO');

      expect(resultado.pendientes, hasLength(1));
      expect(
        resultado.pendientes.first.motivo,
        MotivoPendiente.ejercicioFueraDeBiblioteca,
      );
    });

    test('NO se sugiere ningún nombre parecido', () {
      // "PUNTO MUERTO" existe; "PUNTO MUERTE" no. La app no debe proponer el
      // primero: sugerir por aproximación es inventar.
      final resultado = analizador.analizar('200 PUNTO MUERTE');

      expect(resultado.pendientes, isNotEmpty);
      final detalle = resultado.pendientes.first.detalle.toLowerCase();
      expect(detalle, isNot(contains('quizá')));
      expect(detalle, isNot(contains('quiso decir')));
      expect(detalle, isNot(contains('punto muerto')));
    });

    test('una diferencia de una letra no se perdona', () {
      final resultado = analizador.analizar('200 PUÑO');

      expect(
        resultado.pendientes,
        isNotEmpty,
        reason: 'El ejercicio real se llama PUÑOS, en plural',
      );
    });

    test('el nombre exacto sí se acepta', () {
      final resultado = analizador.analizar('200 PUNTO MUERTO');

      expect(resultado.pendientes, isEmpty);
      expect(resultado.series.first.ejercicio?.nombreBase, 'PUNTO MUERTO');
      expect(resultado.series.first.esTecnica, isTrue);
    });

    test('la búsqueda ignora mayúsculas y espacios de más, nada más', () {
      final porMayusculas = biblioteca.buscar('punto muerto');
      final porEspacios = biblioteca.buscar('PUNTO   MUERTO');
      final porTildes = biblioteca.buscar('PUNTO MUERTÓ');

      expect(porMayusculas, isA<EjercicioEncontrado>());
      expect(porEspacios, isA<EjercicioEncontrado>());
      expect(
        porTildes,
        isA<EjercicioNoEncontrado>(),
        reason: 'Una tilde de más cambia el nombre; no se corrige sola',
      );
    });
  });

  group('metros y técnica', () {
    test('un nado completo no cuenta como trabajo técnico', () {
      final resultado = analizador.analizar('400 N');
      expect(resultado.series.first.esTecnica, isFalse);
    });

    test('una serie con ejercicio de biblioteca sí cuenta como técnica', () {
      final resultado = analizador.analizar('200 VADEO');
      expect(resultado.series.first.esTecnica, isTrue);
    });

    test(
      'los metros se cuentan aunque el ejercicio esté fuera de biblioteca',
      () {
        final resultado = analizador.analizar('4x100 EJERCICIO IMAGINARIO');

        expect(
          resultado.metros,
          400,
          reason:
              'El volumen es un hecho aritmético, independiente de que el '
              'ejercicio sea válido',
        );
        expect(resultado.pendientes, isNotEmpty);
      },
    );
  });
}
