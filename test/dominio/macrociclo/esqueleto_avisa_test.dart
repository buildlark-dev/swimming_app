/// M5 y FR-012 — un bloque fuera de lo publicado **avisa y no suspende**.
///
/// La sección 12 de la metodología lo dice con nombres: Issurin (2010) es
/// literatura de otros deportes, el estudio de caso de un nadador de 400
/// estilos usa fases específicas que no caben en sus 2-4 semanas, Maglischo da
/// taper de 1-3 semanas, y un estudio de cohorte de 20 años asocia el
/// rendimiento máximo a macrociclos de 14-15 semanas. El macrociclo real del
/// entrenador tiene 14 semanas con 2 de afinación: coincide con la natación y
/// se aparta de Issurin.
///
/// Así que la app **avisa, con la fuente a la vista, y decide él**.
///
/// **Las pruebas que importan aquí son las que exigen que el aviso aparezca.**
/// El control negativo de T020 lo demostró: con un `continue` que mataba todos
/// los avisos, las dos pruebas que había —ambas comprobando que la lista
/// estaba vacía— seguían en verde. Una suite que solo comprueba ausencias pasa
/// entera cuando la función no hace nada.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

void main() {
  final hoy = DateTime(2026, 11, 4);

  EsqueletoPropuesto esqueleto({
    required int competenciaEnDias,
    Categoria categoria = Categoria.competitivo,
  }) => esqueletoParaMacrociclo(
    fechaDeCompetencia: hoy.add(Duration(days: competenciaEnDias)),
    hoy: hoy,
    categoria: categoria,
  );

  group('el aviso aparece', () {
    test('un macrociclo de catorce semanas avisa de su Acumulación', () {
      // 99 días: 14 de taper, 28 de transformación y 57 de base. Esas 9
      // semanas de Acumulación se salen de las 2-6 que publica Issurin, y es
      // justo el caso que la sección 12 discute.
      final propuesto = esqueleto(competenciaEnDias: 98);

      expect(propuesto.avisos, hasLength(1));
      expect(propuesto.avisos.single, contains('Acumulación'));
    });

    test('el aviso trae la fuente y el rango publicado', () {
      // Un aviso sin la fuente sería la app diciendo «esto está mal» sin
      // poder discutirlo. Con la fuente es información.
      final aviso = esqueleto(competenciaEnDias: 98).avisos.single;

      expect(aviso, contains('Issurin'));
      expect(aviso, contains('2010'));
      final (minimo, maximo) = FaseAtr.acumulacion.semanasSegunIssurin;
      expect(aviso, contains('$minimo a $maximo'));
      expect(aviso, contains('natación'));
    });

    test('y aun así el esqueleto sale completo: avisa, no suspende', () {
      // **Esto es la mitad que importa de M5.** Un aviso que además impidiera
      // generar sería la app decidiendo metodología con literatura de otro
      // deporte.
      final propuesto = esqueleto(competenciaEnDias: 98);

      expect(propuesto.avisos, isNotEmpty);
      expect(propuesto.hayEsqueleto, isTrue);
      expect(propuesto.bloques, hasLength(3));
    });

    test('un macrociclo muy largo avisa de más de un bloque', () {
      // A 300 días la Acumulación se dispara y sigue siendo un solo aviso por
      // bloque: no se acumulan avisos del mismo.
      final propuesto = esqueleto(competenciaEnDias: 300);

      expect(propuesto.avisos, hasLength(1));
      expect(propuesto.bloques, hasLength(3));
    });
  });

  group('el aviso no aparece cuando no toca', () {
    test('dos semanas de Realización solas no avisan', () {
      expect(esqueleto(competenciaEnDias: 13).avisos, isEmpty);
    });

    test('un bloque sin fase no se mide con la ventana de Issurin', () {
      // Medir un bloque de Iniciación con la regla de las fases ATR sería
      // medirlo con la regla de otra categoría.
      expect(
        esqueleto(
          competenciaEnDias: 98,
          categoria: Categoria.iniciacion,
        ).avisos,
        isEmpty,
      );
    });
  });

  group('lo que el entrenador edita se mide igual (C7)', () {
    EstructuraConfirmada conRealizacionDe(int semanas) =>
        EstructuraConfirmada(
          modeloDeLaPrueba: '200 libre: umbral alto.',
          modeloDelNadador: 'Crol dominante.',
          bloques: [
            BloqueConfirmado(
              fase: FaseAtr.realizacion,
              desde: hoy,
              hasta: hoy.add(Duration(days: semanas * 7 - 1)),
              porQue: 'Realización, $semanas semanas, puestas por él.',
            ),
          ],
          confirmadaEn: hoy,
          diasPorSemana: const [1, 3, 5],
          duracionSesionMinutos: 90,
          longitudPiscina: 25,
        );

    test('una Realización de cuatro semanas se señala', () {
      // El caso exacto de C7 en el quickstart: él la pone a cuatro, Issurin
      // publica 1-2, y la app lo dice.
      final estructura = conRealizacionDe(4);

      expect(estructura.bloquesFueraDeLaVentana, hasLength(1));
      expect(
        estructura.bloquesFueraDeLaVentana.single.fase,
        FaseAtr.realizacion,
      );
    });

    test('y la estructura se construye igual: se confirma y se genera', () {
      // Si `EstructuraConfirmada` rechazara el bloque, el aviso sería un
      // bloqueo con otro nombre.
      expect(() => conRealizacionDe(4), returnsNormally);
    });

    test('una Realización de dos semanas no se señala', () {
      expect(conRealizacionDe(2).bloquesFueraDeLaVentana, isEmpty);
    });
  });
}
