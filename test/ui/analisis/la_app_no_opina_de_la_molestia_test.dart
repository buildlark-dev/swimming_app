/// La app **no opina** sobre la molestia (FR-011, principio IV).
///
/// El principio VIII dice que un reporte de dolor «NO DEBE resolverse de forma
/// automática», y el IV que la decisión sobre el entrenamiento no se delega.
/// Juntos dejan esta pantalla en un sitio muy concreto: enseña lo que ella
/// escribió, con su fecha, y se calla.
///
/// Lo que no puede haber, dicho por su nombre: severidad, puntuación, orden de
/// gravedad, «te sugerimos», y ningún control que cambie un plan desde aquí.
/// Un botón de «ajustar el plan» al lado de un dolor es la app proponiendo
/// conducta, aunque el texto no lo diga.
///
/// Se comprueba de dos maneras —el texto pintado y la fuente— porque cada una
/// deja pasar lo que la otra atrapa: el texto no ve un control deshabilitado,
/// y la fuente no ve una palabra que llegue de un dato.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  /// Palabras con las que una app opina.
  const opinando = <String>[
    'severidad',
    'gravedad',
    'leve',
    'moderad',
    'grave',
    'sugerimos',
    'sugerencia',
    'recomendamos',
    'recomendación',
    'deberías',
    'te conviene',
    'riesgo de lesión',
    'reduce la carga',
    'baja el volumen',
    'descansa',
    'consulta a',
  ];

  testWidgets('lo pintado no propone nada', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(conMolestia(sesionId: 's2', planId: 'plan-1'));

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    final pintado = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' | ');

    expect(pintado, contains('molestia'));

    for (final palabra in opinando) {
      expect(
        pintado,
        isNot(contains(palabra)),
        reason:
            '«$palabra» en la pantalla es la app opinando sobre un dolor, y '
            'el principio IV no delega eso',
      );
    }
  });

  testWidgets('no hay ningún control que cambie un plan desde aquí', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(conMolestia(sesionId: 's2', planId: 'plan-1'));

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    // Ni activo ni deshabilitado: un control deshabilitado es un señuelo, y
    // la feature 007 lo prohibió por eso (H12).
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  test('la fuente de las dos pantallas no lleva ninguna opinión', () {
    const rutas = <String>[
      'lib/ui/analisis/pantalla_analisis.dart',
      'lib/ui/analisis/lectura_de_un_nadador.dart',
      'lib/ui/analisis/sesion_y_respuesta.dart',
    ];

    for (final ruta in rutas) {
      // Sin comentarios: el cerrojo es sobre lo que se pinta, y los
      // comentarios de estos archivos nombran justamente lo que no hacen.
      final codigo = File(ruta)
          .readAsLinesSync()
          .where((linea) {
            final limpia = linea.trimLeft();
            return !limpia.startsWith('//') && !limpia.startsWith('///');
          })
          .join('\n')
          .toLowerCase();

      expect(codigo.length, greaterThan(500), reason: '$ruta está vacío');

      for (final palabra in opinando) {
        expect(
          codigo.contains(palabra),
          isFalse,
          reason: '«$palabra» en $ruta es la app opinando sobre un dolor',
        );
      }
    }
  });

  testWidgets('las molestias se enseñan por fecha y no por importancia', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    repos.registros
      ..sembrar(
        conMolestia(
          sesionId: 's1',
          planId: 'plan-1',
          descripcion: 'Un pinchazo en el hombro',
        ),
      )
      ..sembrar(
        conMolestia(
          sesionId: 's3',
          planId: 'plan-1',
          descripcion: 'Molestia leve en la rodilla al patear',
        ),
      );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    // s3 es del viernes y s1 del lunes: la más reciente primero, como el resto
    // de la lectura. **Por fecha, que es un hecho**; cualquier otro orden
    // sería un juicio.
    expect(
      tester.getTopLeft(find.byKey(const Key('molestia-contada-en-s3'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('molestia-contada-en-s1'))).dy,
      ),
    );
  });
}
