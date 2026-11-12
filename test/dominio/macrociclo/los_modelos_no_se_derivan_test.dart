/// M4, FR-007 — el modelo de la prueba y el modelo del nadador son suyos.
///
/// **Esta es la prueba que sostiene la enmienda de la constitución v2.0.0.**
/// La enmienda dice que lo que se reserva al entrenador no es el número de
/// fases: es el punto de decisión. Y nombra cuál: modelar la prueba y modelar
/// al nadador, pasos 2 y 3 de la sección 4. Si el software pudiera rellenar
/// esos dos campos a partir de algo, la enmienda se habría usado para saltarse
/// una regla en lugar de para reformularla.
///
/// Se comprueba **sobre el código fuente**, no sobre una pantalla. Una prueba
/// de widget diría que hoy la pantalla no los rellena; esto dice que en el
/// dominio de la feature no hay por dónde. Es el mismo recurso que la feature
/// 008 usó para las pruebas de contrato contra el servidor: leer la fuente
/// cuando lo que se quiere fijar es una propiedad del código y no de una
/// ejecución.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';

void main() {
  const declaraLosModelos = 'lib/dominio/macrociclo/macrociclo.dart';

  List<File> dominioDelMacrociclo() => Directory('lib/dominio/macrociclo')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) {
        return f.path.endsWith('.dart') &&
            f.path.replaceAll(r'\', '/') != declaraLosModelos;
      })
      .toList();

  test('la carpeta del macrociclo existe y tiene archivos', () {
    // Para que esta prueba no pase por vacía si un día se mueve la carpeta.
    expect(dominioDelMacrociclo(), isNotEmpty);
  });

  test('ningún archivo del dominio nombra los dos modelos', () {
    // El único sitio del dominio que los menciona es donde se declaran, y ahí
    // solo se validan y se recortan. Ningún otro los escribe, los compone ni
    // los deriva.
    final infracciones = <String>[];

    for (final archivo in dominioDelMacrociclo()) {
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        // Los comentarios pueden hablar de ellos: de eso trata media
        // documentación de esta feature. Lo que no puede es haber código.
        final sinComentario =
            linea.trim().startsWith('///') || linea.trim().startsWith('//');
        if (sinComentario) continue;

        if (linea.contains('modeloDeLaPrueba') ||
            linea.contains('modeloDelNadador')) {
          infracciones.add('${archivo.path}:${i + 1}');
        }
      }
    }

    expect(
      infracciones,
      isEmpty,
      reason:
          'Los dos modelos los aporta el entrenador (FR-007, constitución '
          'v2.0.0). Si el dominio los escribe, los está derivando:\n'
          '${infracciones.join('\n')}',
    );
  });

  test('el dominio no construye una estructura confirmada', () {
    // Una `EstructuraConfirmada` **solo puede llegar de fuera del dominio**:
    // de la pantalla donde él la escribe. Si el dominio pudiera construir
    // una, podría confirmar una estructura sin que nadie la confirmara.
    final infracciones = <String>[];

    for (final archivo in dominioDelMacrociclo()) {
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i].trim();
        if (linea.startsWith('///') || linea.startsWith('//')) continue;
        if (linea.contains('EstructuraConfirmada(')) {
          infracciones.add('${archivo.path}:${i + 1}');
        }
      }
    }

    expect(infracciones, isEmpty, reason: infracciones.join('\n'));
  });

  test('la propuesta no recibe la ficha del nadador', () {
    // No es una cuestión de disciplina: `esqueletoParaMacrociclo` **no tiene
    // acceso** a la edad, la fecha de nacimiento, las marcas ni el
    // diagnóstico. Lo único que recibe de la ficha es la categoría, y solo
    // para saber si esa categoría usa fases ATR.
    //
    // Derivar la tolerancia a la fatiga o la motivación de la edad y la
    // categoría sería la app inventando lo único que la enmienda protegió.
    final fuente = File(
      'lib/dominio/macrociclo/esqueleto_propuesto.dart',
    ).readAsStringSync();

    final firma = fuente.substring(
      fuente.indexOf('EsqueletoPropuesto esqueletoParaMacrociclo({'),
      fuente.indexOf('}) {', fuente.indexOf('esqueletoParaMacrociclo({')),
    );

    expect(firma, contains('fechaDeCompetencia'));
    expect(firma, contains('hoy'));
    expect(firma, contains('categoria'));
    expect(firma, isNot(contains('Nadador')));
    expect(firma, isNot(contains('ficha')));
    expect(firma, isNot(contains('edad')));
    expect(firma, isNot(contains('marcas')));
    expect(firma, isNot(contains('diagnostico')));
  });

  test('la propuesta no devuelve ningún modelo', () {
    // Y tampoco los saca por la otra punta: `EsqueletoPropuesto` lleva
    // bloques, razón, avisos y días. Nada que se parezca a un modelo.
    final propuesto = esqueletoParaMacrociclo(
      fechaDeCompetencia: DateTime(2027, 2, 10),
      hoy: DateTime(2026, 11, 4),
      categoria: Categoria.competitivo,
    );

    // Si alguien añadiera un campo con un modelo pre-escrito, tendría que
    // tocar esta lista, y entonces la decisión sería visible en el diff.
    final fuente = File(
      'lib/dominio/macrociclo/esqueleto_propuesto.dart',
    ).readAsStringSync();
    final clase = fuente.substring(
      fuente.indexOf('class EsqueletoPropuesto'),
      fuente.indexOf('bool get hayEsqueleto'),
    );

    final campos = RegExp(
      r'final \w+<?\w*>?\?? (\w+);',
    ).allMatches(clase).map((m) => m.group(1)).toList();

    expect(campos, ['bloques', 'porQue', 'avisos', 'diasHastaLaCompetencia']);
    expect(propuesto.hayEsqueleto, isTrue);
  });
}
