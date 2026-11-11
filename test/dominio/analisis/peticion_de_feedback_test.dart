/// Las invariantes de una petición de feedback.
///
/// Tres, y cada una tiene un motivo que se puede decir en una frase:
///
/// 1. **La pregunta no está en blanco.** Una petición sin nada dentro no es
///    una petición: el entrenador recibiría un aviso que no dice qué mirar.
///    Se comprueba en el constructor, como `porQue` en `BloqueConfirmado`.
/// 2. **`vistaEn`, una vez puesta, no se quita.** Un entrenador no puede
///    des-ver algo.
/// 3. **`video` es nulo en esta feature.** El campo existe para que la forma
///    esté decidida y la puerta del servidor se pueda escribir y probar hoy;
///    la capacidad no existe, así que el constructor lo rechaza. Una feature
///    posterior quita el rechazo y **ninguna familia tiene que volver a
///    consentir** (decisión D2).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';

void main() {
  PeticionDeFeedback pedir({
    String pregunta = '¿El viraje del tercer 50 lo hice bien?',
    DateTime? vistaEn,
  }) => PeticionDeFeedback(
    nadadorId: 'n-ana',
    planId: 'plan-1',
    sesionId: 's1',
    pregunta: pregunta,
    pedidaEn: DateTime(2026, 11, 2, 19, 30),
    vistaEn: vistaEn,
  );

  test('el identificador es determinista: pedir dos veces no duplica', () {
    expect(pedir().id, 'n-ana|plan-1|s1');

    expect(
      PeticionDeFeedback.idDeterminista(
        nadadorId: 'n-ana',
        planId: 'plan-1',
        sesionId: 's1',
      ),
      pedir().id,
      reason:
          'si pierde la conexión y vuelve a preguntar, el entrenador recibe '
          'una petición y no dos (la misma decisión que la feature 003 tomó '
          'para los registros)',
    );
  });

  test('una pregunta en blanco se rechaza', () {
    expect(() => pedir(pregunta: ''), throwsA(isA<PreguntaVacia>()));
    expect(() => pedir(pregunta: '   '), throwsA(isA<PreguntaVacia>()));
    expect(
      () => pedir(pregunta: '\n\t  \n'),
      throwsA(isA<PreguntaVacia>()),
      reason: 'en blanco es en blanco después de recortar',
    );
  });

  test('la pregunta se guarda tal cual, sin recortar lo de dentro', () {
    final peticion = pedir(pregunta: '  ¿Y el viraje?  ');

    expect(
      peticion.pregunta,
      '¿Y el viraje?',
      reason:
          'se recortan los extremos, que son un accidente del teclado; lo de '
          'dentro son sus palabras',
    );
  });

  test('vistaEn nace nula: nadie la ha visto todavía', () {
    expect(pedir().vistaEn, isNull);
    expect(pedir().laVio, isFalse);
  });

  test('el entrenador la marca vista', () {
    final vista = pedir().vistaPor(DateTime(2026, 11, 3, 8));

    expect(vista.laVio, isTrue);
    expect(vista.vistaEn, DateTime(2026, 11, 3, 8));
  });

  test('marcarla vista no toca su pregunta', () {
    const suya = '¿El viraje del tercer 50 lo hice bien?';
    final vista = pedir(pregunta: suya).vistaPor(DateTime(2026, 11, 3));

    expect(
      vista.pregunta,
      suya,
      reason:
          'la única escritura del entrenador aquí es «la vi»; lo que ella '
          'escribió es suyo (la misma regla que para los registros desde la '
          'feature 004)',
    );
    expect(vista.id, pedir().id);
  });

  test('vistaEn, una vez puesta, no se quita ni se mueve', () {
    final primera = DateTime(2026, 11, 3, 8);
    final vista = pedir().vistaPor(primera);

    expect(
      vista.vistaPor(DateTime(2026, 11, 5, 10)).vistaEn,
      primera,
      reason:
          'un entrenador no puede des-ver algo, ni volver a verlo por '
          'primera vez',
    );
  });

  test('un vídeo se rechaza en esta feature', () {
    expect(
      () => PeticionDeFeedback(
        nadadorId: 'n-ana',
        planId: 'plan-1',
        sesionId: 's1',
        pregunta: '¿Mira el viraje?',
        pedidaEn: DateTime(2026, 11, 2),
        video: ReferenciaDeVideo(
          ruta: 'videos/n-ana/s1.mp4',
          subidoEn: DateTime(2026, 11, 2),
        ),
      ),
      throwsA(isA<VideoTodaviaNo>()),
    );
  });

  test('ReferenciaDeVideo existe, con su forma decidida', () {
    // **Existe y no se usa, a propósito.** Tener la forma y la puerta escritas
    // hoy es lo que hace que adjuntar un vídeo más adelante no cueste volver
    // a pedirle consentimiento a cada familia.
    final referencia = ReferenciaDeVideo(
      ruta: 'videos/n-ana/s1.mp4',
      subidoEn: DateTime(2026, 11, 2),
    );

    expect(referencia.ruta, 'videos/n-ana/s1.mp4');
    expect(referencia.subidoEn, DateTime(2026, 11, 2));
  });
}
