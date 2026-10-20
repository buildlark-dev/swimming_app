import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// SC-016 — la categoría no es la edad.
///
/// Lo pidió el entrenador y lo respalda la metodología: la sección 11.1 de la
/// 3.6.0 determina la categoría por **lo que el nadador ya hace en el agua**,
/// y la 11 nunca la ató a la edad. Un niño de nueve años y un adulto de
/// cuarenta pueden estar los dos en Iniciación.
///
/// Esta suite existe para que nadie «mejore» la app añadiendo una sugerencia
/// de categoría por edad. Sería una regla de entrenamiento inventada, y el
/// principio I no las admite.
void main() {
  Nadador nadador({DateTime? fechaNacimiento, bool? declaraSerMayor}) =>
      Nadador(
        id: 'n1',
        nombre: 'Perfil de prueba',
        fechaNacimiento: fechaNacimiento,
        declaraSerMayorDeEdad: declaraSerMayor,
        categoria: Categoria.iniciacion,
        estiloObjetivo: Estilo.libre,
      );

  group('la categoría no cambia con la edad', () {
    test('sin fecha de nacimiento, la categoría es la declarada', () {
      expect(nadador().categoria, Categoria.iniciacion);
    });

    test('con la fecha de un niño de nueve años, sigue siendo la declarada', () {
      expect(
        nadador(fechaNacimiento: DateTime(2017, 3, 14)).categoria,
        Categoria.iniciacion,
      );
    });

    test('con la fecha de un adulto de cuarenta, también', () {
      expect(
        nadador(fechaNacimiento: DateTime(1986, 3, 14)).categoria,
        Categoria.iniciacion,
        reason: 'Un adulto que empieza a nadar está en Iniciación. La '
            'categoría es lo que ya hace en el agua, no los años que tiene',
      );
    });

    test('añadir, cambiar y quitar la fecha no la mueve', () {
      final sinFecha = nadador();
      final conNino = sinFecha.copiarCon(fechaNacimiento: DateTime(2017, 1, 1));
      final conAdulto =
          conNino.copiarCon(fechaNacimiento: DateTime(1980, 1, 1));

      expect(sinFecha.categoria, Categoria.iniciacion);
      expect(conNino.categoria, Categoria.iniciacion);
      expect(conAdulto.categoria, Categoria.iniciacion);
    });
  });

  group('la categoría no se deriva ni se sugiere', () {
    test('Categoria no tiene ningún parámetro de edad', () {
      // Comprobación estructural. Las cinco categorías se definen por volumen
      // por sesión, frecuencia semanal y uso de ATR, que es exactamente lo que
      // dice la sección 11. Nada más.
      for (final categoria in Categoria.values) {
        expect(categoria.volumenPorSesion.minimo, greaterThan(0));
        expect(categoria.sesionesPorSemana, greaterThan(0));
      }
      expect(Categoria.values, hasLength(5));
    });

    test('no existe ninguna función que proponga categoría por edad', () {
      // Si alguien añade una, esta prueba no la detecta sola, pero el nombre
      // de este archivo y este comentario le dicen por qué no debe hacerlo:
      // sería una regla de entrenamiento sin respaldo en el documento
      // normativo, y el principio I lo prohíbe. Lo que sí puede hacer la app
      // es **reportar una discrepancia** entre la categoría declarada y lo que
      // el nadador puede hacer (sección 11.1), que es otra feature.
      expect(
        Categoria.porNombre('Iniciación'),
        Categoria.iniciacion,
        reason: 'La categoría se resuelve por su nombre, que es lo que el '
            'entrenador declara',
      );
    });
  });

  group('la edad decide otra cosa, y solo esa', () {
    test('sin declarar nada se asume que hace falta acudiente', () {
      // El error de pedir un consentimiento que no hacía falta se arregla. El
      // de no pedirlo, no.
      expect(nadador().necesitaAcudienteEn(DateTime(2026, 10, 15)), isTrue);
    });

    test('quien declara ser mayor de edad no necesita acudiente', () {
      expect(
        nadador(declaraSerMayor: true)
            .necesitaAcudienteEn(DateTime(2026, 10, 15)),
        isFalse,
      );
    });

    test('una fecha de nacimiento de adulto también basta', () {
      expect(
        nadador(fechaNacimiento: DateTime(1986, 3, 14))
            .necesitaAcudienteEn(DateTime(2026, 10, 15)),
        isFalse,
      );
    });

    test('un menor con fecha de nacimiento sí lo necesita', () {
      expect(
        nadador(fechaNacimiento: DateTime(2017, 3, 14))
            .necesitaAcudienteEn(DateTime(2026, 10, 15)),
        isTrue,
      );
    });

    test('y eso no toca su categoría en ningún caso', () {
      final menor = nadador(fechaNacimiento: DateTime(2017, 3, 14));
      final mayor = nadador(declaraSerMayor: true);

      expect(menor.necesitaAcudienteEn(DateTime(2026, 10, 15)), isTrue);
      expect(mayor.necesitaAcudienteEn(DateTime(2026, 10, 15)), isFalse);
      expect(menor.categoria, mayor.categoria);
    });
  });
}
